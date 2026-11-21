package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.request.ShareBatchRequest;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.time.Duration;
import java.util.*;

@Service
public class MessagingServiceImpl implements MessagingService {
    private static final int DEFAULT_PAGE_SIZE = 30;
    private static final int MAX_PAGE_SIZE = 100;
    private static final Duration MESSAGE_REQUEST_RETRY_DELAY = Duration.ofDays(1);

    private final UserRepository users;
    private final ConversationRepository conversations;
    private final MessageRepository messages;
    private final ConversationReadStateRepository readStates;
    private final FriendshipService friendships;
    private final ChatRateLimiter rateLimiter;
    private final ApplicationEventPublisher events;
    private final int maxMessageLength;
    private final ItineraryRepository itineraryRepository;
    private final PostRepository postRepository;
    private final PostMediaRepository postMediaRepository;
    private final ItineraryAccessGrantService accessGrantService;
    private final ObjectMapper objectMapper;

    public MessagingServiceImpl(UserRepository users, ConversationRepository conversations, MessageRepository messages,
            ConversationReadStateRepository readStates, FriendshipService friendships, ChatRateLimiter rateLimiter,
            ApplicationEventPublisher events, @Value("${chat.message.max-length:4000}") int maxMessageLength) {
        this(users, conversations, messages, readStates, friendships, rateLimiter, events, maxMessageLength,
                null, null, null, null, null);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public MessagingServiceImpl(UserRepository users, ConversationRepository conversations, MessageRepository messages,
            ConversationReadStateRepository readStates, FriendshipService friendships, ChatRateLimiter rateLimiter,
            ApplicationEventPublisher events, @Value("${chat.message.max-length:4000}") int maxMessageLength,
            ItineraryRepository itineraryRepository, PostRepository postRepository,
            PostMediaRepository postMediaRepository, ItineraryAccessGrantService accessGrantService,
            ObjectMapper objectMapper) {
        this.users = users;
        this.conversations = conversations;
        this.messages = messages;
        this.readStates = readStates;
        this.friendships = friendships;
        this.rateLimiter = rateLimiter;
        this.events = events;
        this.maxMessageLength = Math.min(4000, Math.max(1, maxMessageLength));
        this.itineraryRepository = itineraryRepository;
        this.postRepository = postRepository;
        this.postMediaRepository = postMediaRepository;
        this.accessGrantService = accessGrantService;
        this.objectMapper = objectMapper;
    }

    @Override
    @Transactional
    public ConversationSummaryResponse openDirect(Integer recipientUserId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        if (recipientUserId == null || recipientUserId.equals(actorLookup.getUserId())) throw new BadRequestException("Không thể mở cuộc trò chuyện với chính mình");
        User low = lockActiveUser(Math.min(actorLookup.getUserId(), recipientUserId));
        User high = lockActiveUser(Math.max(actorLookup.getUserId(), recipientUserId));
        User actor = low.getUserId().equals(actorLookup.getUserId()) ? low : high;
        User recipient = low.getUserId().equals(recipientUserId) ? low : high;
        if (!friendships.canContinueConversation(actor.getUserId(), recipient.getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        }
        Conversation conversation = conversations.findByUserLow_UserIdAndUserHigh_UserId(low.getUserId(), high.getUserId()).orElse(null);
        if (conversation == null) {
            if (!friendships.canContinueConversation(actor.getUserId(), recipient.getUserId())) throw new ForbiddenException("Không thể mở cuộc trò chuyện với người dùng này");
            conversation = new Conversation();
            conversation.setUserLow(low);
            conversation.setUserHigh(high);
            conversation.setLastMessageSequence(0L);
            if (friendships.areAcceptedFriends(actor.getUserId(), recipient.getUserId())) {
                conversation.setStatus(ConversationStatus.ACCEPTED);
            } else {
                conversation.setStatus(ConversationStatus.PENDING);
                conversation.setRequester(actor);
                conversation.setRequestRecipient(recipient);
                conversation.setRequestCreatedAt(LocalDateTime.now());
            }
            conversation = conversations.saveAndFlush(conversation);
            readStates.save(new ConversationReadState(conversation, low));
            readStates.save(new ConversationReadState(conversation, high));
        } else if (conversation.getStatus() == ConversationStatus.DECLINED
                && requestCanBeRetried(conversation)) {
            if (!friendships.canContinueConversation(actor.getUserId(), recipient.getUserId())) {
                throw new ForbiddenException("Không thể mở cuộc trò chuyện với người dùng này");
            }
            if (friendships.areAcceptedFriends(actor.getUserId(), recipient.getUserId())) {
                conversation.setStatus(ConversationStatus.ACCEPTED);
                conversation.setRequester(null);
                conversation.setRequestRecipient(null);
            } else {
                conversation.setStatus(ConversationStatus.PENDING);
                conversation.setRequester(actor);
                conversation.setRequestRecipient(recipient);
                conversation.setRequestCreatedAt(LocalDateTime.now());
            }
            conversation.setRequestDeclinedAt(null);
        } else if (conversation.getStatus() == ConversationStatus.PENDING
                && conversation.getRequestRecipient() != null
                && conversation.getRequestRecipient().getUserId().equals(actor.getUserId())
                && !friendships.canMessage(conversation.getRequester().getUserId(), actor.getUserId())) {
            throw new ForbiddenException("Người này chỉ nhận tin nhắn từ bạn bè");
        }
        Message latest = latestVisibleMessage(conversation.getConversationId(), actor.getUserId());
        return summary(conversation, actor.getUserId(), 0L, latest, canSend(conversation, actor, recipient));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ConversationSummaryResponse> conversations(int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (page < 0 || size < 1) throw new BadRequestException("Thông tin phân trang không hợp lệ");
        Pageable pageable = PageRequest.of(page, Math.min(size, 50), Sort.by(Sort.Direction.DESC, "lastMessageAt").and(Sort.by(Sort.Direction.DESC, "conversationId")));
        Page<Conversation> result = conversations.findInboxForUser(actor.getUserId(),
                ConversationStatus.ACCEPTED, ConversationStatus.PENDING, pageable);
        List<Conversation> items = result.getContent();
        if (items.isEmpty()) return PageResponse.from(result.map(c -> summary(c, actor.getUserId(), 0, null, false)));

        List<Long> ids = items.stream().map(Conversation::getConversationId).toList();
        Map<Long, Message> latestByConversation = new HashMap<>();
        for (Message message : messages.findLatestVisibleForUser(ids, actor.getUserId())) {
            latestByConversation.put(message.getConversation().getConversationId(), message);
        }
        Map<Long, Long> unreadByConversation = new HashMap<>();
        for (Object[] row : messages.countUnreadByConversation(actor.getUserId(), ids, ConversationStatus.ACCEPTED)) unreadByConversation.put((Long) row[0], ((Number) row[1]).longValue());
        List<Integer> peerIds = items.stream().map(c -> c.otherUser(actor.getUserId()).getUserId()).toList();
        Map<Integer, Boolean> permissions = friendships.canContinueConversationForPeers(actor.getUserId(), peerIds);

        List<ConversationSummaryResponse> content = items.stream().map(c -> summary(c, actor.getUserId(),
                unreadByConversation.getOrDefault(c.getConversationId(), 0L), latestByConversation.get(c.getConversationId()),
                permissions.getOrDefault(c.otherUser(actor.getUserId()).getUserId(), false))).toList();
        return PageResponse.<ConversationSummaryResponse>builder().content(content).pageNumber(result.getNumber())
                .pageSize(result.getSize()).totalElements(result.getTotalElements()).totalPages(result.getTotalPages()).last(result.isLast()).build();
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ConversationSummaryResponse> messageRequests(int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (page < 0 || size < 1) throw new BadRequestException("Thông tin phân trang không hợp lệ");
        Pageable pageable = PageRequest.of(page, Math.min(size, 50),
                Sort.by(Sort.Direction.DESC, "updatedAt").and(Sort.by(Sort.Direction.DESC, "conversationId")));
        Page<Conversation> result = conversations.findVisibleMessageRequests(
                actor.getUserId(), ConversationStatus.PENDING, 0L, InboundMessagePolicy.EVERYONE, pageable);
        List<Conversation> items = result.getContent();
        if (items.isEmpty()) return PageResponse.from(result.map(c -> summary(c, actor.getUserId(), 0L, null, false)));
        List<Long> ids = items.stream().map(Conversation::getConversationId).toList();
        Map<Long, Message> latestByConversation = new HashMap<>();
        for (Message message : messages.findLatestVisibleForUser(ids, actor.getUserId())) {
            latestByConversation.put(message.getConversation().getConversationId(), message);
        }
        List<ConversationSummaryResponse> content = items.stream().map(c -> summary(c, actor.getUserId(), 0L,
                latestByConversation.get(c.getConversationId()), false)).toList();
        return PageResponse.<ConversationSummaryResponse>builder().content(content).pageNumber(result.getNumber())
                .pageSize(result.getSize()).totalElements(result.getTotalElements()).totalPages(result.getTotalPages()).last(result.isLast()).build();
    }

    @Override
    @Transactional(readOnly = true)
    public long pendingMessageRequestCount(String actorUsername) {
        User actor = activeUser(actorUsername);
        return conversations.countVisibleMessageRequests(
                actor.getUserId(), ConversationStatus.PENDING, 0L, InboundMessagePolicy.EVERYONE);
    }

    @Override
    @Transactional(readOnly = true)
    public long unreadMessageRequestCount(String actorUsername) {
        User actor = activeUser(actorUsername);
        return messages.countUnreadMessageRequests(actor.getUserId(), ConversationStatus.PENDING,
                InboundMessagePolicy.EVERYONE);
    }

    @Override
    @Transactional
    public ConversationSummaryResponse acceptMessageRequest(Long conversationId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Conversation selected = conversations.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn"));
        if (!selected.includes(actorLookup.getUserId())) throw new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn");
        Integer peerId = selected.otherUser(actorLookup.getUserId()).getUserId();
        lockActiveUser(Math.min(actorLookup.getUserId(), peerId));
        lockActiveUser(Math.max(actorLookup.getUserId(), peerId));
        User actor = activeUser(actorUsername);
        Conversation conversation = conversations.findByIdForUpdate(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn"));
        if (!conversation.includes(actor.getUserId()) || conversation.getStatus() != ConversationStatus.PENDING
                || conversation.getRequestRecipient() == null
                || !conversation.getRequestRecipient().getUserId().equals(actor.getUserId())
                || !canRecipientSeePendingRequest(conversation, actor.getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn");
        }
        User requester = conversation.getRequester();
        if (!friendships.canContinueConversation(actor.getUserId(), requester.getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn");
        }
        conversation.setStatus(ConversationStatus.ACCEPTED);
        Long pendingLastSequence = messages.findLastVisibleRequestSequence(
                conversationId, requester.getUserId());
        ConversationReadState readState = readStates.findForUpdate(conversationId, actor.getUserId())
                .orElseGet(() -> new ConversationReadState(conversation, actor));
        if (pendingLastSequence != null && pendingLastSequence > readState.getLastReadSequence()) {
            readState.setLastReadSequence(pendingLastSequence);
            readState.setLastReadAt(LocalDateTime.now());
            readStates.saveAndFlush(readState);
            ChatEventResponse readEvent = ChatEventResponse.builder().eventId(UUID.randomUUID().toString())
                    .type("READ_CURSOR_UPDATED").occurredAt(readState.getLastReadAt())
                    .conversationId(conversationId).sequenceNumber(pendingLastSequence)
                    .readerUserId(actor.getUserId())
                    .readerName(actor.getFullName() == null ? actor.getHandle() : actor.getFullName())
                    .readAt(readState.getLastReadAt()).build();
            events.publishEvent(new CommittedChatEvent(actor.getUsername(), actor.getUserId(),
                    requester.getUsername(), requester.getUserId(), readEvent));
        }
        publishConversationEvent(conversation, actor, requester, "MESSAGE_REQUEST_ACCEPTED");
        return summary(conversation, actor.getUserId(), 0L, conversation.getLastMessage(),
                friendships.canContinueConversation(actor.getUserId(), requester.getUserId()));
    }

    @Override
    @Transactional
    public ConversationSummaryResponse declineMessageRequest(Long conversationId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Conversation selected = conversations.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn"));
        if (!selected.includes(actorLookup.getUserId())) throw new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn");
        Integer peerId = selected.otherUser(actorLookup.getUserId()).getUserId();
        lockActiveUser(Math.min(actorLookup.getUserId(), peerId));
        lockActiveUser(Math.max(actorLookup.getUserId(), peerId));
        User actor = activeUser(actorUsername);
        Conversation conversation = conversations.findByIdForUpdate(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn"));
        if (!conversation.includes(actor.getUserId()) || conversation.getStatus() != ConversationStatus.PENDING
                || conversation.getRequestRecipient() == null
                || !conversation.getRequestRecipient().getUserId().equals(actor.getUserId())
                || !canRecipientSeePendingRequest(conversation, actor.getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy yêu cầu tin nhắn");
        }
        messages.hideRequestMessagesFromRecipient(conversationId, conversation.getRequester().getUserId());
        conversation.setStatus(ConversationStatus.DECLINED);
        conversation.setRequestDeclinedAt(LocalDateTime.now());
        User requester = conversation.getRequester();
        publishConversationEvent(conversation, actor, requester, "MESSAGE_REQUEST_DECLINED");
        return summary(conversation, actor.getUserId(), 0L, conversation.getLastMessage(), false);
    }

    @Override
    @Transactional(readOnly = true)
    public MessagePageResponse messages(Long conversationId, Long beforeSequence, Long afterSequence, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (beforeSequence != null && afterSequence != null) throw new BadRequestException("Chỉ được dùng một cursor mỗi lần");
        if (size < 1) throw new BadRequestException("size phải lớn hơn 0");
        int limit = Math.min(size, MAX_PAGE_SIZE);
        Conversation conversation = memberConversation(conversationId, actor.getUserId());
        if (!friendships.canContinueConversation(actor.getUserId(), conversation.otherUser(actor.getUserId()).getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        }
        if (conversation.getStatus() == ConversationStatus.PENDING
                && conversation.getRequestRecipient() != null
                && conversation.getRequestRecipient().getUserId().equals(actor.getUserId())
                && !canRecipientSeePendingRequest(conversation, actor.getUserId())
                && messages.countVisibleMessages(conversationId, actor.getUserId()) == 0) {
            throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        }
        Integer peerId = conversation.otherUser(actor.getUserId()).getUserId();
        Long peerReadSequence = readStates.findByConversation_ConversationIdAndUser_UserId(conversationId, peerId)
                .map(ConversationReadState::getLastReadSequence).orElse(0L);
        List<Message> fetched;
        boolean hasMore;
        if (afterSequence != null) {
            fetched = messages.findVisibleAfter(conversationId, actor.getUserId(), afterSequence, PageRequest.of(0, limit + 1));
            hasMore = fetched.size() > limit;
            if (hasMore) fetched = new ArrayList<>(fetched.subList(0, limit));
        } else if (beforeSequence != null) {
            fetched = messages.findVisibleBefore(conversationId, actor.getUserId(), beforeSequence, PageRequest.of(0, limit + 1));
            hasMore = fetched.size() > limit;
            if (hasMore) fetched = new ArrayList<>(fetched.subList(0, limit));
            Collections.reverse(fetched);
        } else {
            fetched = messages.findVisibleLatest(conversationId, actor.getUserId(), PageRequest.of(0, limit + 1));
            hasMore = fetched.size() > limit;
            if (hasMore) fetched = new ArrayList<>(fetched.subList(0, limit));
            Collections.reverse(fetched);
        }
        Long nextBefore = hasMore && !fetched.isEmpty() ? fetched.get(0).getSequenceNumber() : null;
        Long lastSequence = fetched.isEmpty() ? null : fetched.get(fetched.size() - 1).getSequenceNumber();
        return MessagePageResponse.builder().content(fetched.stream().map(this::messageResponse).toList())
                .hasMore(hasMore).nextBeforeSequence(nextBefore).lastSequence(lastSequence).peerReadSequence(peerReadSequence).build();
    }

    @Override
    @Transactional
    public MessageResponse send(Long conversationId, SendMessageRequest request, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        String clientMessageId = request.getClientMessageId().toLowerCase(Locale.ROOT);
        Optional<Message> previous = messages.findBySender_UserIdAndClientMessageId(actorLookup.getUserId(), clientMessageId);
        if (previous.isPresent()) {
            Message old = previous.get();
            if (!old.getConversation().getConversationId().equals(conversationId)) throw new ConflictException("clientMessageId đã được sử dụng cho tin nhắn khác");
            if (!old.getConversation().includes(actorLookup.getUserId())
                    || !friendships.canContinueConversation(actorLookup.getUserId(),
                            old.getConversation().otherUser(actorLookup.getUserId()).getUserId())) {
                throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
            }
            return messageResponse(old);
        }

        Conversation selected = conversations.findById(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện"));
        if (!selected.includes(actorLookup.getUserId())) throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        Integer peerId = selected.otherUser(actorLookup.getUserId()).getUserId();
        User low = lockActiveUser(Math.min(actorLookup.getUserId(), peerId));
        User high = lockActiveUser(Math.max(actorLookup.getUserId(), peerId));
        User actor = low.getUserId().equals(actorLookup.getUserId()) ? low : high;
        User recipient = low.getUserId().equals(peerId) ? low : high;
        Conversation conversation = conversations.findByIdForUpdate(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện"));
        if (!conversation.includes(actor.getUserId())) throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        if (recipient.getStatus() != UserStatus.ACTIVE || !canSend(conversation, actor, recipient)) {
            throw new ForbiddenException("Không thể gửi tin nhắn cho người dùng này");
        }
        String content = request.getContent() == null ? "" : request.getContent().trim();
        if (content.isEmpty() || content.length() > maxMessageLength) throw new BadRequestException("Tin nhắn không hợp lệ");

        previous = messages.findBySender_UserIdAndClientMessageId(actor.getUserId(), clientMessageId);
        if (previous.isPresent()) {
            if (!previous.get().getConversation().getConversationId().equals(conversationId)) throw new ConflictException("clientMessageId đã được sử dụng cho tin nhắn khác");
            return messageResponse(previous.get());
        }
        if (!rateLimiter.allow(actor.getUserId())) throw new Travel_Planner.Travel_Planner.exception.RateLimitExceededException("Bạn gửi tin nhắn quá nhanh. Vui lòng thử lại sau.");

        if (conversation.getStatus() == ConversationStatus.PENDING) {
            conversation.setStatus(ConversationStatus.PENDING);
        }

        long nextSequence = conversation.getLastMessageSequence() + 1;
        Message message = new Message();
        message.setConversation(conversation);
        message.setSequenceNumber(nextSequence);
        message.setSender(actor);
        message.setClientMessageId(clientMessageId);
        message.setContent(content);
        message.setMessageType(MessageType.TEXT);
        message.setCreatedAt(LocalDateTime.now());
        boolean recipientVisible = conversation.getStatus() != ConversationStatus.PENDING
                || friendships.canMessage(actor.getUserId(), recipient.getUserId());
        message.setRecipientVisible(recipientVisible);
        message = messages.saveAndFlush(message);
        conversation.setLastMessageSequence(nextSequence);
        conversation.setLastMessage(message);
        conversation.setLastMessageAt(message.getCreatedAt());

        MessageResponse response = messageResponse(message);
        ChatEventResponse event = ChatEventResponse.builder().eventId(UUID.randomUUID().toString()).type("MESSAGE_CREATED")
                .occurredAt(message.getCreatedAt()).conversationId(conversationId).sequenceNumber(nextSequence).message(response).build();
        events.publishEvent(new CommittedChatEvent(actor.getUsername(), actor.getUserId(),
                recipient.getUsername(), recipient.getUserId(), event, recipientVisible));
        return response;
    }

    @Override
    @Transactional
    public void markRead(Long conversationId, Long lastReadSequence, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Conversation conversation = conversations.findByIdForUpdate(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện"));
        if (!conversation.includes(actorLookup.getUserId())) throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        User actor = activeUser(actorUsername);
        if (!friendships.canContinueConversation(actor.getUserId(), conversation.otherUser(actor.getUserId()).getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        }
        if (conversation.getStatus() == ConversationStatus.PENDING
                && conversation.getRequestRecipient() != null
                && conversation.getRequestRecipient().getUserId().equals(actor.getUserId())
                ) {
            throw new ForbiddenException("Chỉ có thể đánh dấu tin nhắn đã đọc sau khi chấp nhận yêu cầu");
        }
        if (lastReadSequence == null || lastReadSequence < 0 || lastReadSequence > conversation.getLastMessageSequence()) {
            throw new BadRequestException("Vị trí đã đọc không hợp lệ");
        }
        ConversationReadState state = readStates.findForUpdate(conversationId, actor.getUserId()).orElse(null);
        if (state != null && lastReadSequence <= state.getLastReadSequence()) return;
        if (state == null) {
            state = new ConversationReadState(conversation, actor);
            state.setLastReadSequence(lastReadSequence);
        } else {
            state.setLastReadSequence(lastReadSequence);
        }
        state.setLastReadAt(LocalDateTime.now());
        readStates.save(state);
        User peer = conversation.otherUser(actor.getUserId());
        ChatEventResponse event = ChatEventResponse.builder().eventId(UUID.randomUUID().toString()).type("READ_CURSOR_UPDATED")
                .occurredAt(state.getLastReadAt()).conversationId(conversationId).sequenceNumber(lastReadSequence)
                .readerUserId(actor.getUserId()).readerName(actor.getFullName() == null ? actor.getHandle() : actor.getFullName())
                .readAt(state.getLastReadAt()).build();
        events.publishEvent(new CommittedChatEvent(actor.getUsername(), actor.getUserId(),
                peer.getUsername(), peer.getUserId(), event));
    }

    @Override
    @Transactional(readOnly = true)
    public long totalUnread(String actorUsername) {
        User actor = activeUser(actorUsername);
        return messages.countTotalUnread(actor.getUserId(), ConversationStatus.ACCEPTED);
    }

    private User activeUser(String username) {
        if (username == null || username.isBlank()) throw new UnauthorizedException("Bạn cần đăng nhập");
        User user = users.findByUsername(username).orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new UnauthorizedException("Tài khoản không hoạt động");
        return user;
    }

    private User lockActiveUser(Integer userId) {
        User user = users.findByUserIdForUpdate(userId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy người dùng");
        return user;
    }

    private Conversation memberConversation(Long id, Integer userId) {
        Conversation conversation = conversations.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện"));
        if (!conversation.includes(userId)) throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        return conversation;
    }

    private ConversationSummaryResponse summary(Conversation conversation, Integer userId, long unread, Message latest, boolean canSend) {
        boolean recipientPrivacyRestricted = conversation.getStatus() == ConversationStatus.PENDING
                && conversation.getRequester() != null
                && conversation.getRequester().getUserId().equals(userId)
                && !friendships.canMessage(userId, conversation.getRequestRecipient().getUserId());
        boolean canRespond = conversation.getStatus() == ConversationStatus.PENDING
                && conversation.getRequestRecipient() != null
                && conversation.getRequestRecipient().getUserId().equals(userId)
                && latest != null
                && friendships.canMessage(conversation.getRequester().getUserId(), userId);
        return ConversationSummaryResponse.builder().conversationId(conversation.getConversationId())
                .peer(userSummary(conversation.otherUser(userId))).lastMessage(latest == null ? null : messageResponse(latest))
                .lastMessageSequence(conversation.getLastMessageSequence()).unreadCount(unread)
                .canSendMessage(canSend).status(conversation.getStatus() == null ? ConversationStatus.ACCEPTED : conversation.getStatus())
                .canRespondToMessageRequest(canRespond)
                .recipientPrivacyRestricted(recipientPrivacyRestricted)
                .requestAvailableAt(conversation.getStatus() == ConversationStatus.DECLINED
                        && conversation.getRequestDeclinedAt() != null
                        ? conversation.getRequestDeclinedAt().plus(MESSAGE_REQUEST_RETRY_DELAY) : null)
                .updatedAt(conversation.getLastMessageAt() == null ? conversation.getCreatedAt() : conversation.getLastMessageAt()).build();
    }

    private boolean canSend(Conversation conversation, User actor, User recipient) {
        ConversationStatus status = conversation.getStatus();
        if (status == null || status == ConversationStatus.ACCEPTED) {
            return friendships.canContinueConversation(actor.getUserId(), recipient.getUserId());
        }
        if (status != ConversationStatus.PENDING || conversation.getRequester() == null
                || conversation.getRequestRecipient() == null) return false;
        if (conversation.getRequester().getUserId().equals(actor.getUserId())) {
            return friendships.canContinueConversation(actor.getUserId(), recipient.getUserId());
        }
        return false;
    }

    private boolean canRecipientSeePendingRequest(Conversation conversation, Integer recipientId) {
        return conversation.getRequester() != null
                && conversation.getRequestRecipient() != null
                && conversation.getRequestRecipient().getUserId().equals(recipientId)
                && friendships.canMessage(conversation.getRequester().getUserId(), recipientId)
                && messages.countVisibleMessages(conversation.getConversationId(), recipientId) > 0;
    }

    private Message latestVisibleMessage(Long conversationId, Integer viewerId) {
        return messages.findLatestVisibleForUser(List.of(conversationId), viewerId).stream().findFirst().orElse(null);
    }

    private boolean requestCanBeRetried(Conversation conversation) {
        return conversation.getRequestDeclinedAt() != null
                && !LocalDateTime.now().isBefore(conversation.getRequestDeclinedAt().plus(MESSAGE_REQUEST_RETRY_DELAY));
    }

    private void publishConversationEvent(Conversation conversation, User actor, User peer, String type) {
        ChatEventResponse event = ChatEventResponse.builder().eventId(UUID.randomUUID().toString()).type(type)
                .occurredAt(LocalDateTime.now()).conversationId(conversation.getConversationId()).build();
        events.publishEvent(new CommittedChatEvent(actor.getUsername(), actor.getUserId(),
                peer.getUsername(), peer.getUserId(), event));
    }

    @Override
    @Transactional
    public ShareBatchResponse shareContent(ShareBatchRequest request, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (request == null) {
            throw new BadRequestException("Yêu cầu không hợp lệ");
        }
        if (request.getTargetType() == null || request.getTargetId() == null) {
            throw new BadRequestException("Nội dung chia sẻ không hợp lệ");
        }
        if (request.getRecipientUserIds() == null || request.getRecipientUserIds().isEmpty()) {
            throw new BadRequestException("Danh sách người nhận không được để trống");
        }
        if (request.getRecipientUserIds().size() > 10) {
            throw new BadRequestException("Chỉ được chia sẻ tối đa 10 người nhận mỗi lần");
        }
        if (request.getNote() != null && request.getNote().length() > maxMessageLength) {
            throw new BadRequestException("Lời nhắn không được vượt quá " + maxMessageLength + " ký tự");
        }
        if (!rateLimiter.allow(actor.getUserId())) {
            throw new Travel_Planner.Travel_Planner.exception.RateLimitExceededException("Bạn gửi tin nhắn quá nhanh. Vui lòng thử lại sau.");
        }

        Itinerary targetItinerary = null;
        boolean isPrivateItinerary = false;
        ShareMetadataDto metadata;

        if (request.getTargetType() == ShareTargetType.ITINERARY) {
            int itinId = request.getTargetId().intValue();
            targetItinerary = itineraryRepository.findById(itinId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình cần chia sẻ"));
            if (targetItinerary.getStatus() != ItineraryStatus.ACTIVE) {
                throw new ResourceNotFoundException("Không tìm thấy lịch trình cần chia sẻ");
            }
            isPrivateItinerary = targetItinerary.getVisibility() == Visibility.PRIVATE;
            if (isPrivateItinerary) {
                if (targetItinerary.getUser() == null || !targetItinerary.getUser().getUserId().equals(actor.getUserId())) {
                    throw new ForbiddenException("Bạn không có quyền chia sẻ lịch trình riêng tư này");
                }
            }
            String authorDisplay = targetItinerary.getUser() != null
                    ? (targetItinerary.getUser().getFullName() != null && !targetItinerary.getUser().getFullName().isBlank()
                            ? targetItinerary.getUser().getFullName()
                            : targetItinerary.getUser().getHandle())
                    : null;
            metadata = ShareMetadataDto.builder()
                    .title(targetItinerary.getTitle())
                    .coverImage(targetItinerary.getCoverImage())
                    .subtitle(targetItinerary.getLocation() != null ? targetItinerary.getLocation()
                            : ("Lịch trình " + (targetItinerary.getTotalDays() != null ? targetItinerary.getTotalDays() + " ngày" : "")))
                    .authorName(authorDisplay)
                    .authorAvatar(targetItinerary.getUser() != null ? targetItinerary.getUser().getAvatar() : null)
                    .visibility(targetItinerary.getVisibility() != null ? targetItinerary.getVisibility().name() : null)
                    .status(targetItinerary.getStatus() != null ? targetItinerary.getStatus().name() : null)
                    .build();
        } else if (request.getTargetType() == ShareTargetType.POST) {
            Long postId = request.getTargetId();
            Post post = postRepository.findById(postId)
                    .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy bài viết cần chia sẻ"));
            if (post.getStatus() != PostStatus.ACTIVE || post.getAuthor() == null || post.getAuthor().getStatus() != UserStatus.ACTIVE) {
                throw new ResourceNotFoundException("Không tìm thấy bài viết cần chia sẻ");
            }
            if (post.getVisibility() == PostVisibility.PRIVATE) {
                if (!post.getAuthor().getUserId().equals(actor.getUserId())) {
                    throw new ForbiddenException("Bạn không có quyền chia sẻ bài viết riêng tư này");
                }
            } else if (post.getVisibility() == PostVisibility.FRIENDS) {
                if (!post.getAuthor().getUserId().equals(actor.getUserId())) {
                    if (!friendships.areAcceptedFriends(actor.getUserId(), post.getAuthor().getUserId())) {
                        throw new ForbiddenException("Bạn không có quyền chia sẻ bài viết này");
                    }
                }
            }
            if (friendships.isBlockedBetween(actor.getUserId(), post.getAuthor().getUserId())) {
                throw new ForbiddenException("Không thể chia sẻ bài viết này");
            }

            String postCover = null;
            List<PostMedia> postMedias = postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(postId);
            if (postMedias != null && !postMedias.isEmpty() && postMedias.get(0).getMediaAsset() != null) {
                postCover = postMedias.get(0).getMediaAsset().getSecureUrl();
            }

            String authorDisplay = post.getAuthor().getFullName() != null && !post.getAuthor().getFullName().isBlank()
                    ? post.getAuthor().getFullName()
                    : post.getAuthor().getHandle();
            String subtitle = post.getContent() != null
                    ? (post.getContent().length() > 100 ? post.getContent().substring(0, 100) + "..." : post.getContent())
                    : "";

            metadata = ShareMetadataDto.builder()
                    .title("Bài viết của " + authorDisplay)
                    .coverImage(postCover)
                    .subtitle(subtitle)
                    .authorName(authorDisplay)
                    .authorAvatar(post.getAuthor().getAvatar())
                    .visibility(post.getVisibility() != null ? post.getVisibility().name() : null)
                    .status(post.getStatus() != null ? post.getStatus().name() : null)
                    .build();
        } else {
            throw new BadRequestException("Loại nội dung chia sẻ không được hỗ trợ");
        }

        ObjectMapper mapper = this.objectMapper != null ? this.objectMapper : new ObjectMapper();
        String metadataJson;
        try {
            metadataJson = mapper.writeValueAsString(metadata);
        } catch (Exception e) {
            metadataJson = "{}";
        }

        List<ShareBatchItemResponse> items = new ArrayList<>();
        int successCount = 0;
        int failedCount = 0;

        for (Integer recipientUserId : request.getRecipientUserIds()) {
            ShareBatchItemResponse item = ShareBatchItemResponse.builder()
                    .recipientUserId(recipientUserId)
                    .build();
            try {
                processSingleShare(actor, recipientUserId, request, metadataJson, targetItinerary, isPrivateItinerary, item);
                if (item.isSuccess()) {
                    successCount++;
                } else {
                    failedCount++;
                }
            } catch (Exception e) {
                item.setSuccess(false);
                item.setErrorMessage(e.getMessage() != null ? e.getMessage() : "Có lỗi xảy ra khi chia sẻ");
                failedCount++;
            }
            items.add(item);
        }

        return ShareBatchResponse.builder()
                .targetType(request.getTargetType())
                .targetId(request.getTargetId())
                .totalRequested(request.getRecipientUserIds().size())
                .successCount(successCount)
                .failedCount(failedCount)
                .results(items)
                .build();
    }

    private void processSingleShare(User actor, Integer recipientUserId, ShareBatchRequest request,
                                    String metadataJson, Itinerary targetItinerary, boolean isPrivateItinerary,
                                    ShareBatchItemResponse item) {
        if (recipientUserId == null || recipientUserId.equals(actor.getUserId())) {
            item.setSuccess(false);
            item.setErrorMessage("Không thể chia sẻ cho chính mình");
            return;
        }

        User recipient = users.findById(recipientUserId).orElse(null);
        if (recipient == null || recipient.getStatus() != UserStatus.ACTIVE) {
            item.setSuccess(false);
            item.setErrorMessage("Người nhận không tồn tại hoặc tài khoản không hoạt động");
            return;
        }
        item.setRecipientUsername(recipient.getUsername());
        item.setRecipientFullName(recipient.getFullName() != null && !recipient.getFullName().isBlank()
                ? recipient.getFullName() : recipient.getHandle());

        if (!friendships.canContinueConversation(actor.getUserId(), recipient.getUserId())) {
            item.setSuccess(false);
            item.setErrorMessage("Không thể gửi tin nhắn cho người dùng này");
            return;
        }

        User low = lockActiveUser(Math.min(actor.getUserId(), recipient.getUserId()));
        User high = lockActiveUser(Math.max(actor.getUserId(), recipient.getUserId()));
        User lockedActor = low.getUserId().equals(actor.getUserId()) ? low : high;
        User lockedRecipient = low.getUserId().equals(recipient.getUserId()) ? low : high;

        Conversation conversation = conversations.findByUserLow_UserIdAndUserHigh_UserId(low.getUserId(), high.getUserId()).orElse(null);
        if (conversation == null) {
            if (!friendships.canContinueConversation(lockedActor.getUserId(), lockedRecipient.getUserId())) {
                item.setSuccess(false);
                item.setErrorMessage("Không thể gửi tin nhắn cho người dùng này");
                return;
            }
            conversation = new Conversation();
            conversation.setUserLow(low);
            conversation.setUserHigh(high);
            conversation.setLastMessageSequence(0L);
            if (friendships.areAcceptedFriends(lockedActor.getUserId(), lockedRecipient.getUserId())) {
                conversation.setStatus(ConversationStatus.ACCEPTED);
            } else {
                conversation.setStatus(ConversationStatus.PENDING);
                conversation.setRequester(lockedActor);
                conversation.setRequestRecipient(lockedRecipient);
                conversation.setRequestCreatedAt(LocalDateTime.now());
            }
            conversation = conversations.saveAndFlush(conversation);
            readStates.save(new ConversationReadState(conversation, low));
            readStates.save(new ConversationReadState(conversation, high));
        } else {
            conversation = conversations.findByIdForUpdate(conversation.getConversationId()).orElse(conversation);
            if (conversation.getStatus() == ConversationStatus.DECLINED) {
                if (requestCanBeRetried(conversation)) {
                    if (!friendships.canContinueConversation(lockedActor.getUserId(), lockedRecipient.getUserId())) {
                        item.setSuccess(false);
                        item.setErrorMessage("Không thể gửi tin nhắn cho người dùng này");
                        return;
                    }
                    if (friendships.areAcceptedFriends(lockedActor.getUserId(), lockedRecipient.getUserId())) {
                        conversation.setStatus(ConversationStatus.ACCEPTED);
                        conversation.setRequester(null);
                        conversation.setRequestRecipient(null);
                    } else {
                        conversation.setStatus(ConversationStatus.PENDING);
                        conversation.setRequester(lockedActor);
                        conversation.setRequestRecipient(lockedRecipient);
                        conversation.setRequestCreatedAt(LocalDateTime.now());
                    }
                    conversation.setRequestDeclinedAt(null);
                } else {
                    item.setSuccess(false);
                    item.setErrorMessage("Yêu cầu tin nhắn trước đó đã bị từ chối");
                    return;
                }
            }
        }

        if (!canSend(conversation, lockedActor, lockedRecipient)) {
            item.setSuccess(false);
            item.setErrorMessage("Không thể gửi tin nhắn vào cuộc trò chuyện này");
            return;
        }

        if (request.getTargetType() == ShareTargetType.ITINERARY && isPrivateItinerary && targetItinerary != null) {
            accessGrantService.grantAccess(targetItinerary, lockedRecipient, lockedActor);
        }

        long nextSequence = conversation.getLastMessageSequence() + 1;
        Message message = new Message();
        message.setConversation(conversation);
        message.setSequenceNumber(nextSequence);
        message.setSender(lockedActor);
        message.setClientMessageId(UUID.randomUUID().toString());
        String content = (request.getNote() != null && !request.getNote().isBlank()) ? request.getNote().trim() : "";
        message.setContent(content);
        message.setMessageType(MessageType.SHARE);
        message.setShareTargetType(request.getTargetType());
        message.setShareTargetId(request.getTargetId());
        message.setShareMetadata(metadataJson);
        message.setCreatedAt(LocalDateTime.now());

        boolean recipientVisible = conversation.getStatus() != ConversationStatus.PENDING
                || friendships.canMessage(lockedActor.getUserId(), lockedRecipient.getUserId());
        message.setRecipientVisible(recipientVisible);
        message = messages.saveAndFlush(message);

        conversation.setLastMessageSequence(nextSequence);
        conversation.setLastMessage(message);
        conversation.setLastMessageAt(message.getCreatedAt());
        conversations.saveAndFlush(conversation);

        MessageResponse response = messageResponse(message);
        ChatEventResponse event = ChatEventResponse.builder()
                .eventId(UUID.randomUUID().toString())
                .type("MESSAGE_CREATED")
                .occurredAt(message.getCreatedAt())
                .conversationId(conversation.getConversationId())
                .sequenceNumber(nextSequence)
                .message(response)
                .build();
        events.publishEvent(new CommittedChatEvent(lockedActor.getUsername(), lockedActor.getUserId(),
                lockedRecipient.getUsername(), lockedRecipient.getUserId(), event, recipientVisible));

        item.setSuccess(true);
        item.setConversationId(conversation.getConversationId());
        item.setMessageId(message.getMessageId());
        item.setSequenceNumber(nextSequence);
    }

    private MessageResponse messageResponse(Message message) {
        User sender = message.getSender();
        return MessageResponse.builder().messageId(message.getMessageId()).conversationId(message.getConversation().getConversationId())
                .sequenceNumber(message.getSequenceNumber()).senderUserId(sender.getUserId()).senderHandle(sender.getHandle())
                .senderName(sender.getFullName() == null || sender.getFullName().isBlank() ? sender.getHandle() : sender.getFullName())
                .senderAvatar(sender.getAvatar()).clientMessageId(message.getClientMessageId()).content(message.getContent())
                .createdAt(message.getCreatedAt())
                .messageType(message.getMessageType() == null ? MessageType.TEXT.name() : message.getMessageType().name())
                .shareTargetType(message.getShareTargetType() == null ? null : message.getShareTargetType().name())
                .shareTargetId(message.getShareTargetId())
                .shareMetadata(message.getShareMetadata())
                .conversationStatus(message.getConversation().getStatus() == null
                        ? ConversationStatus.ACCEPTED.name() : message.getConversation().getStatus().name())
                .recipientVisible(!Boolean.FALSE.equals(message.getRecipientVisible())).build();
    }

    private PublicUserSummaryResponse userSummary(User user) {
        return PublicUserSummaryResponse.builder().userId(user.getUserId()).handle(user.getHandle()).username(user.getUsername())
                .fullName(user.getFullName()).avatar(user.getAvatar()).build();
    }
}



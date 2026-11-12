package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.*;

@Service
public class MessagingServiceImpl implements MessagingService {
    private static final int DEFAULT_PAGE_SIZE = 30;
    private static final int MAX_PAGE_SIZE = 100;

    private final UserRepository users;
    private final ConversationRepository conversations;
    private final MessageRepository messages;
    private final ConversationReadStateRepository readStates;
    private final FriendshipService friendships;
    private final ChatRateLimiter rateLimiter;
    private final ApplicationEventPublisher events;
    private final int maxMessageLength;

    public MessagingServiceImpl(UserRepository users, ConversationRepository conversations, MessageRepository messages,
            ConversationReadStateRepository readStates, FriendshipService friendships, ChatRateLimiter rateLimiter,
            ApplicationEventPublisher events, @Value("${chat.message.max-length:4000}") int maxMessageLength) {
        this.users = users;
        this.conversations = conversations;
        this.messages = messages;
        this.readStates = readStates;
        this.friendships = friendships;
        this.rateLimiter = rateLimiter;
        this.events = events;
        this.maxMessageLength = Math.min(4000, Math.max(1, maxMessageLength));
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
        Conversation conversation = conversations.findByUserLow_UserIdAndUserHigh_UserId(low.getUserId(), high.getUserId()).orElse(null);
        if (conversation == null) {
            if (!friendships.canMessage(actor.getUserId(), recipient.getUserId())) throw new ForbiddenException("Người dùng này hiện không nhận tin nhắn mới");
            conversation = new Conversation();
            conversation.setUserLow(low);
            conversation.setUserHigh(high);
            conversation.setLastMessageSequence(0L);
            conversation = conversations.saveAndFlush(conversation);
            readStates.save(new ConversationReadState(conversation, low));
            readStates.save(new ConversationReadState(conversation, high));
        }
        Message latest = conversation.getLastMessage();
        return summary(conversation, actor.getUserId(), 0L, latest, friendships.canMessage(actor.getUserId(), recipient.getUserId()));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ConversationSummaryResponse> conversations(int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (page < 0 || size < 1) throw new BadRequestException("Thông tin phân trang không hợp lệ");
        Pageable pageable = PageRequest.of(page, Math.min(size, 50), Sort.by(Sort.Direction.DESC, "lastMessageAt").and(Sort.by(Sort.Direction.DESC, "conversationId")));
        Page<Conversation> result = conversations.findByUserLow_UserIdOrUserHigh_UserId(actor.getUserId(), actor.getUserId(), pageable);
        List<Conversation> items = result.getContent();
        if (items.isEmpty()) return PageResponse.from(result.map(c -> summary(c, actor.getUserId(), 0, null, false)));

        List<Long> ids = items.stream().map(Conversation::getConversationId).toList();
        Map<Long, Message> latestByConversation = new HashMap<>();
        for (Conversation item : items) {
            if (item.getLastMessage() != null) latestByConversation.put(item.getConversationId(), item.getLastMessage());
        }
        Map<Long, Long> unreadByConversation = new HashMap<>();
        for (Object[] row : messages.countUnreadByConversation(actor.getUserId(), ids)) unreadByConversation.put((Long) row[0], ((Number) row[1]).longValue());
        List<Integer> peerIds = items.stream().map(c -> c.otherUser(actor.getUserId()).getUserId()).toList();
        Map<Integer, Boolean> permissions = friendships.canMessageForPeers(actor.getUserId(), peerIds);

        List<ConversationSummaryResponse> content = items.stream().map(c -> summary(c, actor.getUserId(),
                unreadByConversation.getOrDefault(c.getConversationId(), 0L), latestByConversation.get(c.getConversationId()),
                permissions.getOrDefault(c.otherUser(actor.getUserId()).getUserId(), false))).toList();
        return PageResponse.<ConversationSummaryResponse>builder().content(content).pageNumber(result.getNumber())
                .pageSize(result.getSize()).totalElements(result.getTotalElements()).totalPages(result.getTotalPages()).last(result.isLast()).build();
    }

    @Override
    @Transactional(readOnly = true)
    public MessagePageResponse messages(Long conversationId, Long beforeSequence, Long afterSequence, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        if (beforeSequence != null && afterSequence != null) throw new BadRequestException("Chỉ được dùng một cursor mỗi lần");
        if (size < 1) throw new BadRequestException("size phải lớn hơn 0");
        int limit = Math.min(size, MAX_PAGE_SIZE);
        Conversation conversation = memberConversation(conversationId, actor.getUserId());
        Integer peerId = conversation.otherUser(actor.getUserId()).getUserId();
        Long peerReadSequence = readStates.findByConversation_ConversationIdAndUser_UserId(conversationId, peerId)
                .map(ConversationReadState::getLastReadSequence).orElse(0L);
        List<Message> fetched;
        boolean hasMore;
        if (afterSequence != null) {
            fetched = messages.findByConversation_ConversationIdAndSequenceNumberGreaterThanOrderBySequenceNumberAsc(conversationId, afterSequence, PageRequest.of(0, limit + 1));
            hasMore = fetched.size() > limit;
            if (hasMore) fetched = new ArrayList<>(fetched.subList(0, limit));
        } else if (beforeSequence != null) {
            fetched = messages.findByConversation_ConversationIdAndSequenceNumberLessThanOrderBySequenceNumberDesc(conversationId, beforeSequence, PageRequest.of(0, limit + 1));
            hasMore = fetched.size() > limit;
            if (hasMore) fetched = new ArrayList<>(fetched.subList(0, limit));
            Collections.reverse(fetched);
        } else {
            fetched = messages.findByConversation_ConversationIdOrderBySequenceNumberDesc(conversationId, PageRequest.of(0, limit + 1));
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
        User actorLocked = lockActiveUser(actorLookup.getUserId());
        String clientMessageId = request.getClientMessageId().toLowerCase(Locale.ROOT);
        Optional<Message> previous = messages.findBySender_UserIdAndClientMessageId(actorLookup.getUserId(), clientMessageId);
        if (previous.isPresent()) {
            Message old = previous.get();
            if (!old.getConversation().getConversationId().equals(conversationId)) throw new ConflictException("clientMessageId đã được sử dụng cho tin nhắn khác");
            return messageResponse(old);
        }

        Conversation conversation = conversations.findByIdForUpdate(conversationId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện"));
        if (!conversation.includes(actorLookup.getUserId())) throw new ResourceNotFoundException("Không tìm thấy cuộc trò chuyện");
        User actor = actorLocked;
        User recipient = conversation.otherUser(actor.getUserId());
        if (recipient.getStatus() != UserStatus.ACTIVE || !friendships.canMessage(actor.getUserId(), recipient.getUserId())) {
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

        long nextSequence = conversation.getLastMessageSequence() + 1;
        Message message = new Message();
        message.setConversation(conversation);
        message.setSequenceNumber(nextSequence);
        message.setSender(actor);
        message.setClientMessageId(clientMessageId);
        message.setContent(content);
        message.setCreatedAt(LocalDateTime.now());
        message = messages.saveAndFlush(message);
        conversation.setLastMessageSequence(nextSequence);
        conversation.setLastMessage(message);
        conversation.setLastMessageAt(message.getCreatedAt());

        MessageResponse response = messageResponse(message);
        ChatEventResponse event = ChatEventResponse.builder().eventId(UUID.randomUUID().toString()).type("MESSAGE_CREATED")
                .occurredAt(message.getCreatedAt()).conversationId(conversationId).sequenceNumber(nextSequence).message(response).build();
        events.publishEvent(new CommittedChatEvent(actor.getUsername(), recipient.getUsername(), event));
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
        events.publishEvent(new CommittedChatEvent(actor.getUsername(), peer.getUsername(), event));
    }

    @Override
    @Transactional(readOnly = true)
    public long totalUnread(String actorUsername) {
        User actor = activeUser(actorUsername);
        return messages.countTotalUnread(actor.getUserId());
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
        return ConversationSummaryResponse.builder().conversationId(conversation.getConversationId())
                .peer(userSummary(conversation.otherUser(userId))).lastMessage(latest == null ? null : messageResponse(latest))
                .lastMessageSequence(conversation.getLastMessageSequence()).unreadCount(unread)
                .canSendMessage(canSend).updatedAt(conversation.getLastMessageAt() == null ? conversation.getCreatedAt() : conversation.getLastMessageAt()).build();
    }

    private MessageResponse messageResponse(Message message) {
        User sender = message.getSender();
        return MessageResponse.builder().messageId(message.getMessageId()).conversationId(message.getConversation().getConversationId())
                .sequenceNumber(message.getSequenceNumber()).senderUserId(sender.getUserId()).senderHandle(sender.getHandle())
                .senderName(sender.getFullName() == null || sender.getFullName().isBlank() ? sender.getHandle() : sender.getFullName())
                .senderAvatar(sender.getAvatar()).clientMessageId(message.getClientMessageId()).content(message.getContent()).createdAt(message.getCreatedAt()).build();
    }

    private PublicUserSummaryResponse userSummary(User user) {
        return PublicUserSummaryResponse.builder().userId(user.getUserId()).handle(user.getHandle()).username(user.getUsername())
                .fullName(user.getFullName()).avatar(user.getAvatar()).build();
    }
}



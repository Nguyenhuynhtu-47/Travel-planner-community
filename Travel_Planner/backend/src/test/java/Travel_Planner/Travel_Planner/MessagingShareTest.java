package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.request.ShareBatchRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.MessageResponse;
import Travel_Planner.Travel_Planner.dto.response.ShareBatchResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.ChatRateLimiter;
import Travel_Planner.Travel_Planner.service.CommittedChatEvent;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.ItineraryAccessGrantService;
import Travel_Planner.Travel_Planner.service.impl.ItineraryAccessGrantServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.ItineraryServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.MessagingServiceImpl;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

import java.time.LocalDateTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class MessagingShareTest {

    @Mock private UserRepository userRepository;
    @Mock private ConversationRepository conversationRepository;
    @Mock private MessageRepository messageRepository;
    @Mock private ConversationReadStateRepository conversationReadStateRepository;
    @Mock private FriendshipService friendshipService;
    @Mock private ChatRateLimiter chatRateLimiter;
    @Mock private ApplicationEventPublisher eventPublisher;
    @Mock private ItineraryRepository itineraryRepository;
    @Mock private PostRepository postRepository;
    @Mock private PostMediaRepository postMediaRepository;
    @Mock private ItineraryAccessGrantService itineraryAccessGrantService;
    @Mock private ItineraryAccessGrantRepository itineraryAccessGrantRepository;

    @Mock private RatingRepository ratingRepository;
    @Mock private ItineraryDayRepository itineraryDayRepository;
    @Mock private ActivityRepository activityRepository;
    @Mock private PlaceRepository placeRepository;
    @Mock private FavoriteRepository favoriteRepository;
    @Mock private SavedItineraryRepository savedItineraryRepository;
    @Mock private CommentRepository commentRepository;
    @Mock private ItineraryPlaceRepository itineraryPlaceRepository;

    private MessagingServiceImpl messagingService;
    private ItineraryAccessGrantServiceImpl accessGrantServiceImpl;
    private ItineraryServiceImpl itineraryService;

    private User owner;
    private User recipient1;
    private User recipient2;
    private User stranger;
    private Itinerary publicItinerary;
    private Itinerary privateItinerary;
    private Post publicPost;
    private Post privatePost;
    private Conversation conversation;

    @BeforeEach
    void setUp() {
        ObjectMapper objectMapper = new ObjectMapper();

        messagingService = new MessagingServiceImpl(
                userRepository,
                conversationRepository,
                messageRepository,
                conversationReadStateRepository,
                friendshipService,
                chatRateLimiter,
                eventPublisher,
                4000,
                itineraryRepository,
                postRepository,
                postMediaRepository,
                itineraryAccessGrantService,
                objectMapper
        );

        accessGrantServiceImpl = new ItineraryAccessGrantServiceImpl(
                itineraryAccessGrantRepository,
                itineraryRepository
        );

        itineraryService = new ItineraryServiceImpl(
                itineraryRepository,
                ratingRepository,
                itineraryDayRepository,
                activityRepository,
                userRepository,
                placeRepository,
                favoriteRepository,
                savedItineraryRepository,
                commentRepository,
                itineraryPlaceRepository,
                friendshipService,
                accessGrantServiceImpl
        );

        owner = User.builder()
                .userId(1)
                .username("owner")
                .handle("owner")
                .fullName("Owner User")
                .status(UserStatus.ACTIVE)
                .build();

        recipient1 = User.builder()
                .userId(2)
                .username("recipient1")
                .handle("recipient1")
                .fullName("Recipient One")
                .status(UserStatus.ACTIVE)
                .build();

        recipient2 = User.builder()
                .userId(3)
                .username("recipient2")
                .handle("recipient2")
                .fullName("Recipient Two")
                .status(UserStatus.ACTIVE)
                .build();

        stranger = User.builder()
                .userId(4)
                .username("stranger")
                .handle("stranger")
                .fullName("Stranger User")
                .status(UserStatus.ACTIVE)
                .build();

        publicItinerary = Itinerary.builder()
                .itineraryId(100)
                .user(owner)
                .title("Public Da Lat Trip")
                .location("Da Lat")
                .totalDays(3)
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .build();

        privateItinerary = Itinerary.builder()
                .itineraryId(200)
                .user(owner)
                .title("Private Secret Trip")
                .location("Sa Pa")
                .totalDays(2)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .build();

        publicPost = Post.builder()
                .postId(300L)
                .author(owner)
                .content("Exploring Da Lat coffee shops!")
                .visibility(PostVisibility.PUBLIC)
                .status(PostStatus.ACTIVE)
                .build();

        privatePost = Post.builder()
                .postId(400L)
                .author(owner)
                .content("My private diary entry")
                .visibility(PostVisibility.PRIVATE)
                .status(PostStatus.ACTIVE)
                .build();

        conversation = new Conversation();
        conversation.setConversationId(10L);
        conversation.setUserLow(owner);
        conversation.setUserHigh(recipient1);
        conversation.setStatus(ConversationStatus.ACCEPTED);
        conversation.setLastMessageSequence(5L);
    }

    // 1. Chia sẻ PUBLIC itinerary -> thành công, tin nhắn hiển thị đúng snapshot
    @Test
    @DisplayName("Case 1: Share PUBLIC itinerary -> success, metadata snapshot generated")
    void test1_sharePublicItinerary_success() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(100)).thenReturn(Optional.of(publicItinerary));

        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));

        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(invocation -> {
            Message m = invocation.getArgument(0);
            m.setMessageId(101L);
            return m;
        });

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(List.of(2))
                .note("Check out this Da Lat trip!")
                .build();

        ShareBatchResponse response = messagingService.shareContent(request, "owner");

        assertNotNull(response);
        assertEquals(1, response.getSuccessCount());
        assertEquals(0, response.getFailedCount());
        assertEquals(1, response.getResults().size());
        assertTrue(response.getResults().get(0).isSuccess());
        assertEquals(6L, response.getResults().get(0).getSequenceNumber());

        ArgumentCaptor<Message> messageCaptor = ArgumentCaptor.forClass(Message.class);
        verify(messageRepository).saveAndFlush(messageCaptor.capture());
        Message saved = messageCaptor.getValue();
        assertEquals(MessageType.SHARE, saved.getMessageType());
        assertEquals(ShareTargetType.ITINERARY, saved.getShareTargetType());
        assertEquals(100L, saved.getShareTargetId());
        assertTrue(saved.getShareMetadata().contains("Public Da Lat Trip"));
        verify(itineraryAccessGrantService, never()).grantAccess(any(), any(), any());
    }

    // 2. Chia sẻ PRIVATE itinerary bởi chính chủ sở hữu -> thành công, Access Grant được tạo với status ACTIVE
    @Test
    @DisplayName("Case 2: Share PRIVATE itinerary by owner -> success and Access Grant created")
    void test2_sharePrivateItinerary_byOwner_success_andGrantCreated() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));

        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));

        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(invocation -> {
            Message m = invocation.getArgument(0);
            m.setMessageId(102L);
            return m;
        });

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(200L)
                .recipientUserIds(List.of(2))
                .note("Sharing my private plan with you")
                .build();

        ShareBatchResponse response = messagingService.shareContent(request, "owner");

        assertEquals(1, response.getSuccessCount());
        verify(itineraryAccessGrantService).grantAccess(eq(privateItinerary), any(User.class), any(User.class));
    }

    // 3. Chia sẻ Post hợp lệ -> thành công, tin nhắn chứa Post snapshot
    @Test
    @DisplayName("Case 3: Share valid Post -> success, snapshot in metadata")
    void test3_shareValidPost_success() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(postRepository.findById(300L)).thenReturn(Optional.of(publicPost));
        when(postMediaRepository.findByPost_PostIdOrderByDisplayOrderAsc(300L)).thenReturn(Collections.emptyList());

        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));

        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(invocation -> {
            Message m = invocation.getArgument(0);
            m.setMessageId(103L);
            return m;
        });

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.POST)
                .targetId(300L)
                .recipientUserIds(List.of(2))
                .build();

        ShareBatchResponse response = messagingService.shareContent(request, "owner");

        assertEquals(1, response.getSuccessCount());
        ArgumentCaptor<Message> captor = ArgumentCaptor.forClass(Message.class);
        verify(messageRepository).saveAndFlush(captor.capture());
        Message saved = captor.getValue();
        assertEquals(ShareTargetType.POST, saved.getShareTargetType());
        assertEquals(300L, saved.getShareTargetId());
        assertTrue(saved.getShareMetadata().contains("Exploring Da Lat"));
    }

    // 4. Chia sẻ nội dung không tồn tại -> báo lỗi 404
    @Test
    @DisplayName("Case 4: Share non-existent content -> throws ResourceNotFoundException (404)")
    void test4_shareNonExistentContent_throws404() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(999)).thenReturn(Optional.empty());

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(999L)
                .recipientUserIds(List.of(2))
                .build();

        assertThrows(ResourceNotFoundException.class, () -> messagingService.shareContent(request, "owner"));
    }

    // 5. Non-owner cố tình chia sẻ PRIVATE itinerary -> báo lỗi 403
    @Test
    @DisplayName("Case 5: Non-owner trying to share PRIVATE itinerary -> throws ForbiddenException (403)")
    void test5_nonOwnerSharePrivateItinerary_throws403() {
        when(userRepository.findByUsername("recipient1")).thenReturn(Optional.of(recipient1));
        when(chatRateLimiter.allow(recipient1.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(200L)
                .recipientUserIds(List.of(3))
                .build();

        assertThrows(ForbiddenException.class, () -> messagingService.shareContent(request, "recipient1"));
    }

    // 6. Người nhận bị chặn hoặc không nhận tin -> batch item báo lỗi mà không làm fail toàn bộ batch
    @Test
    @DisplayName("Case 6: Recipient blocked -> individual item reports error, batch still returns")
    void test6_recipientBlocked_failsItemWithoutFailingBatch() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(100)).thenReturn(Optional.of(publicItinerary));

        when(userRepository.findById(4)).thenReturn(Optional.of(stranger));
        when(friendshipService.canContinueConversation(1, 4)).thenReturn(false);

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(List.of(4))
                .build();

        ShareBatchResponse response = messagingService.shareContent(request, "owner");

        assertEquals(0, response.getSuccessCount());
        assertEquals(1, response.getFailedCount());
        assertFalse(response.getResults().get(0).isSuccess());
        assertEquals("Không thể gửi tin nhắn cho người dùng này", response.getResults().get(0).getErrorMessage());
    }

    // 7. Chia sẻ hàng loạt (batch) với danh sách người nhận hợp lệ và không hợp lệ hỗn hợp
    @Test
    @DisplayName("Case 7: Mixed recipients in batch (valid, blocked, self) -> partial success")
    void test7_batchMixedRecipients_partialSuccess() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(100)).thenReturn(Optional.of(publicItinerary));

        // Recipient 1: Valid
        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));
        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));

        // Recipient 4: Blocked
        when(userRepository.findById(4)).thenReturn(Optional.of(stranger));
        when(friendshipService.canContinueConversation(1, 4)).thenReturn(false);

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(List.of(2, 1, 4)) // 2: success, 1: self, 4: blocked
                .build();

        ShareBatchResponse response = messagingService.shareContent(request, "owner");

        assertEquals(3, response.getTotalRequested());
        assertEquals(1, response.getSuccessCount());
        assertEquals(2, response.getFailedCount());

        assertTrue(response.getResults().get(0).isSuccess());
        assertFalse(response.getResults().get(1).isSuccess());
        assertEquals("Không thể chia sẻ cho chính mình", response.getResults().get(1).getErrorMessage());
        assertFalse(response.getResults().get(2).isSuccess());
    }

    // 8. Chia sẻ hàng loạt vượt quá 10 người nhận -> validation lỗi 400
    @Test
    @DisplayName("Case 8: Batch exceeding 10 recipients -> throws BadRequestException (400)")
    void test8_batchExceedingTenRecipients_throws400() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));

        List<Integer> elevenRecipients = List.of(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11);
        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(elevenRecipients)
                .build();

        assertThrows(BadRequestException.class, () -> messagingService.shareContent(request, "owner"));
    }

    // 9. Thu hồi Access Grant qua DELETE /api/itineraries/{id}/access-grants/{granteeUserId} bởi owner
    @Test
    @DisplayName("Case 9: Revoke Access Grant by owner -> grant status becomes REVOKED")
    void test9_revokeAccessGrant_byOwner_success() {
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));

        ItineraryAccessGrant grant = ItineraryAccessGrant.builder()
                .grantId(55L)
                .itinerary(privateItinerary)
                .grantee(recipient1)
                .grantedBy(owner)
                .status(GrantStatus.ACTIVE)
                .build();

        when(itineraryAccessGrantRepository.findByItinerary_ItineraryIdAndGrantee_UserId(200, 2))
                .thenReturn(Optional.of(grant));

        accessGrantServiceImpl.revokeAccess(200, 2, "owner");

        assertEquals(GrantStatus.REVOKED, grant.getStatus());
        assertNotNull(grant.getRevokedAt());
        verify(itineraryAccessGrantRepository).save(grant);
    }

    // 10. Đọc chi tiết của PRIVATE itinerary sau khi Access Grant bị REVOKED -> bị chặn 404
    @Test
    @DisplayName("Case 10: Read PRIVATE itinerary after grant REVOKED -> throws ResourceNotFoundException (404)")
    void test10_readPrivateItineraryAfterGrantRevoked_throws404() {
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));
        when(userRepository.findByUsername("recipient1")).thenReturn(Optional.of(recipient1));
        when(itineraryAccessGrantRepository.existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus(200, 2, GrantStatus.ACTIVE))
                .thenReturn(false);

        assertThrows(ResourceNotFoundException.class, () ->
                itineraryService.getItineraryDetail(200, "recipient1"));
    }

    // 11. Clone PRIVATE itinerary khi Access Grant còn ACTIVE -> thành công
    @Test
    @DisplayName("Case 11: Clone PRIVATE itinerary when grant ACTIVE -> success")
    void test11_clonePrivateItinerary_whenGrantActive_success() {
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));
        when(userRepository.findByUsername("recipient1")).thenReturn(Optional.of(recipient1));
        when(itineraryAccessGrantRepository.existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus(200, 2, GrantStatus.ACTIVE))
                .thenReturn(true);
        when(itineraryRepository.incrementReuseCount(200)).thenReturn(1);
        when(itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(200))
                .thenReturn(Collections.emptyList());

        Itinerary cloned = Itinerary.builder()
                .itineraryId(999)
                .user(recipient1)
                .title("Private Secret Trip (Bản sao)")
                .location("Sa Pa")
                .totalDays(2)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .build();

        when(itineraryRepository.save(any(Itinerary.class))).thenReturn(cloned);
        when(itineraryRepository.findById(999)).thenReturn(Optional.of(cloned));
        when(itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(999))
                .thenReturn(Collections.emptyList());

        var result = itineraryService.cloneItinerary(200, "recipient1");
        assertNotNull(result);
        assertEquals("Private Secret Trip (Bản sao)", result.getTitle());
    }

    // 12. Clone PRIVATE itinerary sau khi Access Grant bị REVOKED -> bị chặn 403
    @Test
    @DisplayName("Case 12: Clone PRIVATE itinerary after grant REVOKED -> throws ForbiddenException (403)")
    void test12_clonePrivateItinerary_whenGrantRevoked_throws403() {
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));
        when(userRepository.findByUsername("recipient1")).thenReturn(Optional.of(recipient1));
        when(itineraryAccessGrantRepository.existsByItinerary_ItineraryIdAndGrantee_UserIdAndStatus(200, 2, GrantStatus.ACTIVE))
                .thenReturn(false);

        assertThrows(ForbiddenException.class, () ->
                itineraryService.cloneItinerary(200, "recipient1"));
    }

    // 13. Người được cấp grant (non-owner) cố tình sửa hoặc xóa itinerary -> bị chặn 403
    @Test
    @DisplayName("Case 13: Non-owner with grant attempting update -> throws ForbiddenException (403, read-only)")
    void test13_nonOwnerWithGrant_updateOrDeleteItinerary_throws403() {
        when(itineraryRepository.findById(200)).thenReturn(Optional.of(privateItinerary));

        UpdateItineraryRequest updateReq = UpdateItineraryRequest.builder()
                .title("Hacked Title")
                .build();

        assertThrows(ForbiddenException.class, () ->
                itineraryService.updateItinerary(200, updateReq, "recipient1"));
    }

    // 14. Tin nhắn TEXT cũ và mới vẫn hoạt động bình thường, không bị ảnh hưởng bởi các trường SHARE
    @Test
    @DisplayName("Case 14: Normal TEXT message sent and response mapped correctly with messageType=TEXT")
    void test14_legacyTextMessage_sentAndReadNormally() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(conversationRepository.findById(10L)).thenReturn(Optional.of(conversation));
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(chatRateLimiter.allow(1)).thenReturn(true);

        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(inv -> {
            Message m = inv.getArgument(0);
            m.setMessageId(888L);
            return m;
        });

        SendMessageRequest sendReq = new SendMessageRequest();
        sendReq.setClientMessageId(UUID.randomUUID().toString());
        sendReq.setContent("Hello friend");

        MessageResponse response = messagingService.send(10L, sendReq, "owner");

        assertNotNull(response);
        assertEquals("TEXT", response.getMessageType());
        assertNull(response.getShareTargetType());
        assertNull(response.getShareTargetId());
        assertNull(response.getShareMetadata());
        assertEquals("Hello friend", response.getContent());
    }

    // 15. Realtime event (STOMP WebSocket / CommittedChatEvent) được publish đúng payload và đúng người nhận
    @Test
    @DisplayName("Case 15: Realtime event published to ApplicationEventPublisher for STOMP relay")
    void test15_realtimeEventPublished_withCorrectPayload() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(100)).thenReturn(Optional.of(publicItinerary));

        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));
        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(List.of(2))
                .build();

        messagingService.shareContent(request, "owner");

        ArgumentCaptor<CommittedChatEvent> eventCaptor = ArgumentCaptor.forClass(CommittedChatEvent.class);
        verify(eventPublisher).publishEvent(eventCaptor.capture());

        CommittedChatEvent event = eventCaptor.getValue();
        assertEquals("owner", event.firstUsername());
        assertEquals("recipient1", event.secondUsername());
        assertNotNull(event.payload());
        assertEquals("MESSAGE_CREATED", event.payload().getType());
        assertEquals(10L, event.payload().getConversationId());
    }

    // 16. Sequence number tăng đơn điệu, conversation lastMessage được cập nhật
    @Test
    @DisplayName("Case 16: Monotonic sequence numbers and conversation lastMessage updated")
    void test16_monotonicSequenceNumbers_andUnreadTracking() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);
        when(itineraryRepository.findById(100)).thenReturn(Optional.of(publicItinerary));

        when(userRepository.findById(2)).thenReturn(Optional.of(recipient1));
        when(friendshipService.canContinueConversation(1, 2)).thenReturn(true);
        when(userRepository.findByUserIdForUpdate(1)).thenReturn(Optional.of(owner));
        when(userRepository.findByUserIdForUpdate(2)).thenReturn(Optional.of(recipient1));
        when(conversationRepository.findByUserLow_UserIdAndUserHigh_UserId(1, 2)).thenReturn(Optional.of(conversation));
        when(conversationRepository.findByIdForUpdate(10L)).thenReturn(Optional.of(conversation));
        when(messageRepository.saveAndFlush(any(Message.class))).thenAnswer(inv -> inv.getArgument(0));

        assertEquals(5L, conversation.getLastMessageSequence());

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.ITINERARY)
                .targetId(100L)
                .recipientUserIds(List.of(2))
                .build();

        messagingService.shareContent(request, "owner");

        assertEquals(6L, conversation.getLastMessageSequence());
        assertNotNull(conversation.getLastMessage());
        assertNotNull(conversation.getLastMessageAt());
    }

    // 17. Concurrent share: cấp grant không tạo bản ghi trùng lặp (idempotent reactivate)
    @Test
    @DisplayName("Case 17: Concurrent share / idempotent grant reactivates without duplicate key violation")
    void test17_concurrentShare_idempotentGrantActivation() {
        ItineraryAccessGrant existingRevokedGrant = ItineraryAccessGrant.builder()
                .grantId(77L)
                .itinerary(privateItinerary)
                .grantee(recipient1)
                .grantedBy(owner)
                .status(GrantStatus.REVOKED)
                .revokedAt(LocalDateTime.now().minusDays(1))
                .build();

        when(itineraryAccessGrantRepository.findByItinerary_ItineraryIdAndGrantee_UserId(200, 2))
                .thenReturn(Optional.of(existingRevokedGrant));
        when(itineraryAccessGrantRepository.save(existingRevokedGrant)).thenReturn(existingRevokedGrant);

        ItineraryAccessGrant result = accessGrantServiceImpl.grantAccess(privateItinerary, recipient1, owner);

        assertEquals(GrantStatus.ACTIVE, result.getStatus());
        assertNull(result.getRevokedAt());
        verify(itineraryAccessGrantRepository, times(1)).save(existingRevokedGrant);
    }

    // 18. Post bị xóa hoặc ẩn -> share post báo lỗi 404
    @Test
    @DisplayName("Case 18: Share deleted or hidden post -> throws ResourceNotFoundException (404)")
    void test18_shareDeletedOrHiddenPost_throwsError() {
        when(userRepository.findByUsername("owner")).thenReturn(Optional.of(owner));
        when(chatRateLimiter.allow(owner.getUserId())).thenReturn(true);

        Post hiddenPost = Post.builder()
                .postId(500L)
                .author(owner)
                .content("Hidden post")
                .status(PostStatus.HIDDEN)
                .build();

        when(postRepository.findById(500L)).thenReturn(Optional.of(hiddenPost));

        ShareBatchRequest request = ShareBatchRequest.builder()
                .targetType(ShareTargetType.POST)
                .targetId(500L)
                .recipientUserIds(List.of(2))
                .build();

        assertThrows(ResourceNotFoundException.class, () -> messagingService.shareContent(request, "owner"));
    }
}

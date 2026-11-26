package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.service.NotificationService;
import Travel_Planner.Travel_Planner.service.impl.SocialNotificationServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.LocalDateTime;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SocialNotificationServiceImplTest {
    @Mock private NotificationService notifications;
    private SocialNotificationServiceImpl service;
    @BeforeEach void setUp() { service = new SocialNotificationServiceImpl(notifications); }

    @Test void friendRequestTargetsRequestedUserAndUsesTransitionKey() {
        User actor = user(1, "Alice"); User recipient = user(2, "Bob");
        Friendship relation = new Friendship(); relation.setFriendshipId(12L);
        service.friendRequest(actor, recipient, relation);
        ArgumentCaptor<String> key = ArgumentCaptor.forClass(String.class);
        verify(notifications).create(eq(2), eq(1), eq(NotificationType.FRIEND_REQUEST), anyString(), anyString(),
                eq(NotificationTargetType.USER), eq("1"), key.capture());
        assertTrue(key.getValue().startsWith("friend-request:12:"));
    }

    @Test void acceptanceNotifiesOnlyOriginalRequester() {
        User accepter = user(1, "Accepter"); User requester = user(2, "Requester");
        Friendship relation = new Friendship(); relation.setFriendshipId(13L);
        service.friendRequestAccepted(accepter, requester, relation);
        verify(notifications).create(eq(2), eq(1), eq(NotificationType.FRIEND_REQUEST_ACCEPTED), anyString(),
                anyString(), eq(NotificationTargetType.USER), eq("1"), eq("friend-accepted:13"));
    }

    @Test void rootPostCommentNotifiesPostOwnerWithoutCopyingCommentText() {
        User actor = user(3, "Commenter"); User owner = user(4, "Owner");
        Post post = new Post(); post.setPostId(89L); post.setAuthor(owner);
        PostComment comment = PostComment.builder().post(post).user(actor).postCommentId(104L)
                .content("comment content should not be copied").build();
        service.postComment(comment);
        verify(notifications).create(eq(4), eq(3), eq(NotificationType.POST_COMMENT), anyString(),
                argThat(body -> !body.contains("comment content should not be copied")),
                eq(NotificationTargetType.POST), eq("89"), eq("post-comment:104"));
    }

    @Test void postReplyTargetsOnlyExactParentWriterAndParentPost() {
        User actor = user(3, "Reply writer"); User rootWriter = user(4, "Root writer");
        User parentWriter = user(5, "Parent writer"); User postOwner = user(6, "Post owner");
        Post post = new Post(); post.setPostId(88L); post.setAuthor(postOwner);
        PostComment root = PostComment.builder().post(post).user(rootWriter).postCommentId(101L).build();
        PostComment parent = PostComment.builder().post(post).user(parentWriter).postCommentId(102L).rootComment(root).build();
        PostComment reply = PostComment.builder().post(post).user(actor).postCommentId(103L).parentComment(parent).rootComment(root).content("private comment text").build();

        service.postComment(reply);

        verify(notifications).create(eq(5), eq(3), eq(NotificationType.POST_COMMENT_REPLY), anyString(),
                argThat(body -> !body.contains("private comment text")), eq(NotificationTargetType.POST),
                eq("88"), eq("post-comment-reply:103"));
        verify(notifications, never()).create(eq(4), any(), any(), any(), any(), any(), any(), any());
        verify(notifications, never()).create(eq(6), any(), any(), any(), any(), any(), any(), any());
    }

    @Test void activityReplyUsesParentAuthorAndItineraryRoute() {
        User actor = user(7, "Activity writer"); User parentWriter = user(8, "Parent writer");
        User owner = user(9, "Itinerary owner");
        Itinerary itinerary = new Itinerary(); itinerary.setItineraryId(24); itinerary.setUser(owner);
        Activity activity = new Activity();
        ItineraryDay day = new ItineraryDay(); day.setItinerary(itinerary); activity.setItineraryDay(day);
        Comment parent = Comment.builder().commentId(31).user(parentWriter).itinerary(itinerary).activity(activity).build();
        Comment reply = Comment.builder().commentId(32).user(actor).itinerary(itinerary).activity(activity).parentComment(parent).build();

        service.itineraryComment(reply);

        verify(notifications).create(eq(8), eq(7), eq(NotificationType.COMMENT_REPLY), anyString(), anyString(),
                eq(NotificationTargetType.ITINERARY), eq("24"), eq("itinerary-comment-reply:32"));
        verify(notifications, never()).create(eq(9), any(), any(), any(), any(), any(), any(), any());
    }

    @Test void activityRootCommentNotifiesItineraryOwnerAndUsesItineraryRoute() {
        User actor = user(12, "Activity commenter"); User owner = user(13, "Itinerary owner");
        Itinerary itinerary = new Itinerary(); itinerary.setItineraryId(25); itinerary.setUser(owner);
        Activity activity = new Activity();
        ItineraryDay day = new ItineraryDay(); day.setItinerary(itinerary); activity.setItineraryDay(day);
        Comment comment = Comment.builder().commentId(33).user(actor).itinerary(itinerary).activity(activity).build();
        service.itineraryComment(comment);
        verify(notifications).create(eq(13), eq(12), eq(NotificationType.ITINERARY_COMMENT), anyString(),
                anyString(), eq(NotificationTargetType.ITINERARY), eq("25"), eq("itinerary-comment:33"));
    }

    @Test void followEventUsesPersistedFollowIdAndSuppressesInactiveRecipient() {
        User actor = user(10, "Follower"); User recipient = user(11, "Target");
        Follow follow = Follow.builder().followId(44).follower(actor).following(recipient)
                .createdAt(LocalDateTime.of(2026, 11, 26, 10, 0)).build();
        service.followed(follow);
        verify(notifications).create(eq(11), eq(10), eq(NotificationType.NEW_FOLLOWER), anyString(), anyString(),
                eq(NotificationTargetType.USER), eq("10"), eq("follow:44:2026-11-26T10:00"));

        reset(notifications);
        recipient.setStatus(UserStatus.INACTIVE);
        service.followed(follow);
        verifyNoInteractions(notifications);
    }

    @Test void postModerationNotifiesAuthorForEachRealTransitionAndCarriesAdminAndReason() {
        User author = user(21, "Post author");
        User admin = user(22, "Admin");
        Post post = new Post();
        post.setPostId(221L);
        post.setAuthor(author);

        service.postModerationTransition(post, admin, PostStatus.ACTIVE, PostStatus.HIDDEN, "Vi phạm cộng đồng");

        verify(notifications).createAdminAction(eq(21), eq(22), eq(NotificationActionType.POST_HIDDEN), anyString(),
                contains("Vi phạm cộng đồng"), eq(NotificationTargetType.POST), eq("221"), anyString());
        reset(notifications);
        service.postModerationTransition(post, admin, PostStatus.HIDDEN, PostStatus.DELETED, null);
        verify(notifications).createAdminAction(eq(21), eq(22), eq(NotificationActionType.POST_REMOVED), anyString(),
                anyString(), eq(NotificationTargetType.POST), eq("221"), anyString());
        reset(notifications);
        service.postModerationTransition(post, admin, PostStatus.DELETED, PostStatus.ACTIVE, null);
        verify(notifications).createAdminAction(eq(21), eq(22), eq(NotificationActionType.POST_RESTORED), anyString(),
                anyString(), eq(NotificationTargetType.POST), eq("221"), anyString());
    }

    @Test void accountModerationNotifiesBanAndRestoreWithAdminIdentityAndPublicReason() {
        User target = user(31, "Target account");
        User admin = user(32, "Admin");
        service.accountModerationTransition(target, admin, UserStatus.ACTIVE, UserStatus.BANNED, "Vi phạm quy định");

        verify(notifications).createAdminAction(eq(31), eq(32), eq(NotificationActionType.ACCOUNT_SUSPENDED),
                anyString(), contains("Vi phạm quy định"), eq(NotificationTargetType.USER), eq("31"), anyString());
        reset(notifications);
        target.setStatus(UserStatus.BANNED);
        service.accountModerationTransition(target, admin, UserStatus.BANNED, UserStatus.ACTIVE, null);
        verify(notifications).createAdminAction(eq(31), eq(32), eq(NotificationActionType.ACCOUNT_RESTORED),
                anyString(), contains("khôi phục"), eq(NotificationTargetType.USER), eq("31"), anyString());
    }

    @Test void reportResolutionNotifiesReporterWithNeutralCopyAndNoReportEvidence() {
        User reporter = user(40, "Reporter");
        User admin = user(41, "Admin");
        PostReport report = PostReport.builder().reportId(42L).reporter(reporter)
                .status(ReportStatus.DISMISSED).details("private evidence").build();

        service.reportResolved(report, admin);

        verify(notifications).createAdminAction(eq(40), eq(41), eq(NotificationActionType.REPORT_DISMISSED),
                anyString(), argThat(body -> !body.contains("private evidence")),
                eq(NotificationTargetType.REPORT), eq("42"), eq("admin-report:42:REPORT_DISMISSED"));
    }

    private static User user(Integer id, String name) {
        return User.builder().userId(id).username(name.toLowerCase().replace(' ', '_'))
                .handle(name.toLowerCase().replace(' ', '_')).fullName(name).status(UserStatus.ACTIVE).build();
    }
}

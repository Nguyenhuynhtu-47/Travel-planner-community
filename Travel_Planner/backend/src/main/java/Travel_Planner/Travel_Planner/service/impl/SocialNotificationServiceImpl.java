package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.Follow;
import Travel_Planner.Travel_Planner.model.Friendship;
import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.PostComment;
import Travel_Planner.Travel_Planner.model.PostReport;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.service.NotificationService;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import org.springframework.stereotype.Service;
import java.util.UUID;

/** Creates social notification records within the calling domain transaction. */
@Service
public class SocialNotificationServiceImpl implements SocialNotificationService {
    private final NotificationService notifications;
    public SocialNotificationServiceImpl(NotificationService notifications) { this.notifications = notifications; }

    @Override
    public void friendRequest(User actor, User recipient, Friendship relation) {
        create(recipient, actor, NotificationType.FRIEND_REQUEST, "Lời mời kết bạn mới",
                displayName(actor) + " đã gửi lời mời kết bạn cho bạn.", NotificationTargetType.USER,
                actor.getUserId(), "friend-request:" + relation.getFriendshipId() + ":" + UUID.randomUUID());
    }

    @Override
    public void friendRequestAccepted(User actor, User recipient, Friendship relation) {
        create(recipient, actor, NotificationType.FRIEND_REQUEST_ACCEPTED, "Lời mời kết bạn được chấp nhận",
                displayName(actor) + " đã chấp nhận lời mời kết bạn của bạn.", NotificationTargetType.USER,
                actor.getUserId(), "friend-accepted:" + relation.getFriendshipId());
    }

    @Override
    public void followed(Follow follow) {
        User actor = follow.getFollower();
        User recipient = follow.getFollowing();
        create(recipient, actor, NotificationType.NEW_FOLLOWER, "Bạn có người theo dõi mới",
                displayName(actor) + " đã bắt đầu theo dõi bạn.", NotificationTargetType.USER,
                actor.getUserId(), "follow:" + follow.getFollowId() + ":" + follow.getCreatedAt());
    }

    @Override
    public void postLiked(Post post, User actor) {
        if (post == null || post.getAuthor() == null || actor == null
                || post.getAuthor().getUserId() == null || actor.getUserId() == null
                || post.getAuthor().getUserId().equals(actor.getUserId())) return;
        notifications.recordPostLike(post.getAuthor(), actor, post);
    }

    @Override
    public void postUnliked(Post post, User actor) {
        if (post == null || post.getAuthor() == null || actor == null
                || post.getAuthor().getUserId() == null || actor.getUserId() == null
                || post.getAuthor().getUserId().equals(actor.getUserId())) return;
        notifications.removePostLikeFromUnreadGroup(post.getAuthor(), actor, post);
    }

    @Override
    public void postComment(PostComment comment) {
        User actor = comment.getUser();
        User recipient = comment.getParentComment() == null
                ? comment.getPost().getAuthor()
                : comment.getParentComment().getUser();
        boolean reply = comment.getParentComment() != null;
        create(recipient, actor, reply ? NotificationType.POST_COMMENT_REPLY : NotificationType.POST_COMMENT,
                reply ? "Có người trả lời bình luận của bạn" : "Bài viết của bạn có bình luận mới",
                displayName(actor) + (reply ? " đã trả lời bình luận của bạn." : " đã bình luận bài viết của bạn."),
                NotificationTargetType.POST, comment.getPost().getPostId(),
                (reply ? "post-comment-reply:" : "post-comment:") + comment.getPostCommentId());
    }

    @Override
    public void itineraryComment(Comment comment) {
        User actor = comment.getUser();
        User recipient = comment.getParentComment() == null
                ? comment.getItinerary().getUser()
                : comment.getParentComment().getUser();
        boolean reply = comment.getParentComment() != null;
        boolean activityComment = comment.getActivity() != null;
        NotificationType type = reply ? NotificationType.COMMENT_REPLY
                : activityComment ? NotificationType.ACTIVITY_COMMENT : NotificationType.ITINERARY_COMMENT;
        create(recipient, actor, type,
                reply ? "Có người trả lời bình luận của bạn"
                        : activityComment ? "Hoạt động có bình luận mới" : "Lịch trình của bạn có bình luận mới",
                displayName(actor) + (reply ? " đã trả lời bình luận của bạn."
                        : activityComment ? " đã bình luận hoạt động trong lịch trình của bạn."
                                : " đã bình luận lịch trình của bạn."),
                NotificationTargetType.ITINERARY, comment.getItinerary().getItineraryId(),
                (reply ? "itinerary-comment-reply:" : "itinerary-comment:") + comment.getCommentId());
    }

    @Override
    public void postModerationTransition(Post post, User admin, PostStatus previousStatus,
            PostStatus nextStatus, String publicReason) {
        if (post == null || post.getAuthor() == null || post.getPostId() == null
                || post.getAuthor().getUserId() == null || admin == null || admin.getUserId() == null
                || previousStatus == nextStatus || nextStatus == null) return;
        NotificationActionType action = switch (nextStatus) {
            case HIDDEN -> NotificationActionType.POST_HIDDEN;
            case DELETED -> NotificationActionType.POST_REMOVED;
            case ACTIVE -> NotificationActionType.POST_RESTORED;
        };
        String body = switch (action) {
            case POST_HIDDEN -> "Bài viết của bạn đã bị ẩn sau khi kiểm duyệt.";
            case POST_REMOVED -> "Bài viết của bạn đã bị gỡ sau khi kiểm duyệt.";
            default -> "Bài viết của bạn đã được khôi phục.";
        };
        notifications.createAdminAction(post.getAuthor().getUserId(), admin.getUserId(), action,
                "Cập nhật về bài viết", appendPublicReason(body, publicReason),
                NotificationTargetType.POST, post.getPostId().toString(),
                "admin-post:" + post.getPostId() + ":" + action + ":" + UUID.randomUUID());
    }

    @Override
    public void postPurged(Post post, User admin) {
        if (post == null || post.getAuthor() == null || post.getPostId() == null
                || post.getAuthor().getUserId() == null || admin == null || admin.getUserId() == null) return;
        notifications.createAdminAction(post.getAuthor().getUserId(), admin.getUserId(),
                NotificationActionType.POST_PURGED, "Bài viết đã bị gỡ khỏi hệ thống",
                "Bài viết của bạn đã bị xóa vĩnh viễn sau khi kiểm duyệt.", NotificationTargetType.POST,
                post.getPostId().toString(), "admin-post-purged:" + post.getPostId() + ":" + UUID.randomUUID());
    }

    @Override
    public void itineraryModerationTransition(Itinerary itinerary, User admin, ItineraryStatus previousStatus,
            ItineraryStatus nextStatus, String publicReason) {
        if (itinerary == null || itinerary.getUser() == null || itinerary.getItineraryId() == null
                || itinerary.getUser().getUserId() == null || admin == null || admin.getUserId() == null
                || previousStatus == nextStatus
                || (nextStatus != ItineraryStatus.HIDDEN && nextStatus != ItineraryStatus.ACTIVE)) return;
        NotificationActionType action = nextStatus == ItineraryStatus.HIDDEN
                ? NotificationActionType.ITINERARY_HIDDEN : NotificationActionType.ITINERARY_RESTORED;
        String body = nextStatus == ItineraryStatus.HIDDEN
                ? "Lịch trình của bạn đã bị ẩn sau khi kiểm duyệt."
                : "Lịch trình của bạn đã được khôi phục.";
        notifications.createAdminAction(itinerary.getUser().getUserId(), admin.getUserId(), action,
                "Cập nhật về lịch trình", appendPublicReason(body, publicReason),
                NotificationTargetType.ITINERARY, itinerary.getItineraryId().toString(),
                "admin-itinerary:" + itinerary.getItineraryId() + ":" + action + ":" + UUID.randomUUID());
    }

    @Override
    public void accountModerationTransition(User recipient, User admin, UserStatus previousStatus,
            UserStatus nextStatus, String publicReason) {
        if (recipient == null || recipient.getUserId() == null || admin == null || admin.getUserId() == null
                || previousStatus == nextStatus
                || (nextStatus != UserStatus.BANNED && nextStatus != UserStatus.ACTIVE)) return;
        NotificationActionType action = nextStatus == UserStatus.BANNED
                ? NotificationActionType.ACCOUNT_SUSPENDED : NotificationActionType.ACCOUNT_RESTORED;
        String body = nextStatus == UserStatus.BANNED
                ? "Tài khoản của bạn đã bị tạm ngưng theo quyết định kiểm duyệt."
                : "Tài khoản của bạn đã được khôi phục.";
        notifications.createAdminAction(recipient.getUserId(), admin.getUserId(), action,
                "Cập nhật trạng thái tài khoản", appendPublicReason(body, publicReason),
                NotificationTargetType.USER, recipient.getUserId().toString(),
                "admin-account:" + recipient.getUserId() + ":" + action + ":" + UUID.randomUUID());
    }

    @Override
    public void accountRoleChanged(User recipient, User admin) {
        if (recipient == null || recipient.getUserId() == null || admin == null || admin.getUserId() == null) return;
        notifications.createAdminAction(recipient.getUserId(), admin.getUserId(),
                NotificationActionType.ACCOUNT_ROLE_CHANGED, "Vai trò tài khoản đã thay đổi",
                "Vai trò tài khoản của bạn đã được quản trị viên cập nhật.", NotificationTargetType.USER,
                recipient.getUserId().toString(), "admin-role:" + recipient.getUserId() + ":" + UUID.randomUUID());
    }

    @Override
    public void accountSessionsRevoked(User recipient, User admin) {
        if (recipient == null || recipient.getUserId() == null || admin == null || admin.getUserId() == null) return;
        notifications.createAdminAction(recipient.getUserId(), admin.getUserId(),
                NotificationActionType.ACCOUNT_SESSIONS_REVOKED, "Phiên đăng nhập đã được làm mới",
                "Quản trị viên đã đăng xuất các phiên đang hoạt động của bạn.",
                NotificationTargetType.USER, recipient.getUserId().toString(),
                "admin-sessions:" + recipient.getUserId() + ":" + UUID.randomUUID());
    }

    @Override
    public void reportResolved(PostReport report, User admin) {
        if (report == null || report.getReportId() == null || report.getReporter() == null
                || report.getReporter().getUserId() == null || admin == null || admin.getUserId() == null) return;
        boolean resolved = report.getStatus() == Travel_Planner.Travel_Planner.model.enums.ReportStatus.RESOLVED;
        NotificationActionType action = resolved ? NotificationActionType.REPORT_RESOLVED
                : NotificationActionType.REPORT_DISMISSED;
        String body = resolved
                ? "Báo cáo bạn gửi đã được xem xét và xử lý."
                : "Báo cáo bạn gửi đã được xem xét và đóng.";
        notifications.createAdminAction(report.getReporter().getUserId(), admin.getUserId(), action,
                "Cập nhật báo cáo của bạn", body, NotificationTargetType.REPORT,
                report.getReportId().toString(), "admin-report:" + report.getReportId() + ":" + action);
    }

    private static String appendPublicReason(String message, String reason) {
        return reason == null || reason.isBlank() ? message : message + " Lý do: " + reason.trim();
    }

    private void create(User recipient, User actor, NotificationType type, String title, String body,
            NotificationTargetType targetType, Object targetId, String eventKey) {
        if (recipient == null || recipient.getUserId() == null || recipient.getStatus() != UserStatus.ACTIVE
                || actor == null || actor.getUserId() == null || actor.getStatus() != UserStatus.ACTIVE) return;
        notifications.create(recipient.getUserId(), actor.getUserId(), type, title, body,
                targetType, String.valueOf(targetId), eventKey);
    }

    private static String displayName(User user) {
        String name = user.getFullName();
        return name == null || name.isBlank() ? user.getHandle() : name;
    }
}

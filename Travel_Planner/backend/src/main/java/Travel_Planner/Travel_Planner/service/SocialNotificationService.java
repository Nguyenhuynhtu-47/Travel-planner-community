package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.Follow;
import Travel_Planner.Travel_Planner.model.Friendship;
import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.PostComment;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.PostReport;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;

public interface SocialNotificationService {
    void friendRequest(User actor, User recipient, Friendship relation);

    void friendRequestAccepted(User actor, User recipient, Friendship relation);

    void followed(Follow follow);

    void postLiked(Post post, User actor);

    void postUnliked(Post post, User actor);

    void postComment(PostComment comment);

    void itineraryComment(Comment comment);

    void postModerationTransition(Post post, User admin, PostStatus previousStatus,
            PostStatus nextStatus, String publicReason);

    void postPurged(Post post, User admin);

    void accountModerationTransition(User recipient, User admin, UserStatus previousStatus,
            UserStatus nextStatus, String publicReason);

    void accountRoleChanged(User recipient, User admin);

    void accountSessionsRevoked(User recipient, User admin);

    void reportResolved(PostReport report, User admin);
}

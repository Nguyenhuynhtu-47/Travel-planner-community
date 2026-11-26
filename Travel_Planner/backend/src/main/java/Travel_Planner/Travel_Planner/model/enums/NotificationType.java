package Travel_Planner.Travel_Planner.model.enums;

/** Notification Center types. Messaging events are intentionally excluded. */
public enum NotificationType {
    FRIEND_REQUEST,
    FRIEND_REQUEST_ACCEPTED,
    NEW_FOLLOWER,
    POST_LIKE,
    POST_COMMENT,
    POST_COMMENT_REPLY,
    ITINERARY_COMMENT,
    ACTIVITY_COMMENT,
    COMMENT_REPLY,
    SYSTEM,
    /** @deprecated Stored rows from the original moderation implementation. */
    @Deprecated
    MODERATION_UPDATE
}

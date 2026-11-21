package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Message;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface MessageRepository extends JpaRepository<Message, Long> {
    Optional<Message> findBySender_UserIdAndClientMessageId(Integer senderId, String clientMessageId);

    @Query("select m from Message m where m.conversation.conversationId = :conversationId "
            + "and (m.sender.userId = :viewerId or m.recipientVisible is null or m.recipientVisible = true) "
            + "order by m.sequenceNumber desc")
    List<Message> findVisibleLatest(@Param("conversationId") Long conversationId,
            @Param("viewerId") Integer viewerId, Pageable pageable);

    @Query("select m from Message m where m.conversation.conversationId = :conversationId "
            + "and m.sequenceNumber < :sequence "
            + "and (m.sender.userId = :viewerId or m.recipientVisible is null or m.recipientVisible = true) "
            + "order by m.sequenceNumber desc")
    List<Message> findVisibleBefore(@Param("conversationId") Long conversationId,
            @Param("viewerId") Integer viewerId, @Param("sequence") Long sequence, Pageable pageable);

    @Query("select m from Message m where m.conversation.conversationId = :conversationId "
            + "and m.sequenceNumber > :sequence "
            + "and (m.sender.userId = :viewerId or m.recipientVisible is null or m.recipientVisible = true) "
            + "order by m.sequenceNumber asc")
    List<Message> findVisibleAfter(@Param("conversationId") Long conversationId,
            @Param("viewerId") Integer viewerId, @Param("sequence") Long sequence, Pageable pageable);

    @Query("select m from Message m where m.conversation.conversationId in :conversationIds "
            + "and (m.sender.userId = :viewerId or m.recipientVisible is null or m.recipientVisible = true) "
            + "and m.sequenceNumber = (select max(m2.sequenceNumber) from Message m2 "
            + "where m2.conversation = m.conversation "
            + "and (m2.sender.userId = :viewerId or m2.recipientVisible is null or m2.recipientVisible = true))")
    List<Message> findLatestVisibleForUser(@Param("conversationIds") List<Long> conversationIds,
            @Param("viewerId") Integer viewerId);

    @Query("select count(m) from Message m where m.conversation.conversationId = :conversationId "
            + "and (m.sender.userId = :viewerId or m.recipientVisible is null or m.recipientVisible = true)")
    long countVisibleMessages(@Param("conversationId") Long conversationId, @Param("viewerId") Integer viewerId);

@Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select m from Message m where m.messageId = :id")
    Optional<Message> findByIdForUpdate(@Param("id") Long id);

    @Query("select m.conversation.conversationId, count(m) from Message m, ConversationReadState r " +
           "where r.conversation = m.conversation and r.user.userId = :readerId " +
           "and m.conversation.conversationId in :conversationIds " +
           "and (m.conversation.status is null or m.conversation.status = :accepted) " +
           "and m.sequenceNumber > r.lastReadSequence and m.sender.userId <> :readerId " +
           "and (m.recipientVisible is null or m.recipientVisible = true) " +
           "group by m.conversation.conversationId")
    List<Object[]> countUnreadByConversation(@Param("readerId") Integer readerId,
            @Param("conversationIds") List<Long> conversationIds, @Param("accepted") ConversationStatus accepted);

    @Query("select count(m) from Message m " +
           "where m.sender.userId <> :readerId " +
           "and (m.conversation.status is null or m.conversation.status = :accepted) " +
           "and (m.conversation.userLow.userId = :readerId or m.conversation.userHigh.userId = :readerId) " +
           "and (m.recipientVisible is null or m.recipientVisible = true) " +
           "and not exists (select b from UserBlock b where " +
           "(b.blocker.userId = :readerId and b.blockedUser.userId = case when m.conversation.userLow.userId = :readerId then m.conversation.userHigh.userId else m.conversation.userLow.userId end) " +
           "or (b.blockedUser.userId = :readerId and b.blocker.userId = case when m.conversation.userLow.userId = :readerId then m.conversation.userHigh.userId else m.conversation.userLow.userId end)) " +
           "and m.sequenceNumber > coalesce((select r.lastReadSequence from ConversationReadState r where r.conversation = m.conversation and r.user.userId = :readerId), 0L)")
    long countTotalUnread(@Param("readerId") Integer readerId, @Param("accepted") ConversationStatus accepted);

    @Query("select count(m) from Message m " +
           "where m.sender.userId <> :readerId " +
           "and m.conversation.requestRecipient.userId = :readerId " +
           "and m.conversation.status = :pending " +
           "and (m.recipientVisible is null or m.recipientVisible = true) " +
           "and (exists (select f from Friendship f where f.status = Travel_Planner.Travel_Planner.model.enums.FriendshipStatus.ACCEPTED " +
           "and ((f.userLow.userId = :readerId and f.userHigh.userId = m.conversation.requester.userId) " +
           "or (f.userHigh.userId = :readerId and f.userLow.userId = m.conversation.requester.userId))) " +
           "or not exists (select s from UserMessagingSettings s where s.user.userId = :readerId and s.inboundPolicy <> :everyone)) " +
           "and m.sequenceNumber > coalesce((select r.lastReadSequence from ConversationReadState r " +
           "where r.conversation = m.conversation and r.user.userId = :readerId), 0L) " +
           "and not exists (select b from UserBlock b where " +
           "(b.blocker.userId = :readerId and b.blockedUser.userId = m.conversation.requester.userId) " +
           "or (b.blocker.userId = m.conversation.requester.userId and b.blockedUser.userId = :readerId))")
    long countUnreadMessageRequests(@Param("readerId") Integer readerId,
            @Param("pending") ConversationStatus pending,
            @Param("everyone") Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy everyone);

    @org.springframework.data.jpa.repository.Modifying
    @Query("update Message m set m.recipientVisible = false where m.conversation.conversationId = :conversationId "
            + "and m.sender.userId = :requesterId and (m.recipientVisible is null or m.recipientVisible = true)")
    int hideRequestMessagesFromRecipient(@Param("conversationId") Long conversationId,
            @Param("requesterId") Integer requesterId);

    @Query("select max(m.sequenceNumber) from Message m where m.conversation.conversationId = :conversationId "
            + "and m.sender.userId = :requesterId and (m.recipientVisible is null or m.recipientVisible = true)")
    Long findLastVisibleRequestSequence(@Param("conversationId") Long conversationId,
            @Param("requesterId") Integer requesterId);

    boolean existsByShareBatchIdAndShareTargetTypeAndShareTargetId(
            String shareBatchId,
            Travel_Planner.Travel_Planner.model.enums.ShareTargetType shareTargetType,
            Long shareTargetId);

    @Query("select count(distinct coalesce(m.shareBatchId, cast(m.messageId as string))) "
            + "from Message m "
            + "where m.messageType = Travel_Planner.Travel_Planner.model.enums.MessageType.SHARE "
            + "and m.shareTargetType = Travel_Planner.Travel_Planner.model.enums.ShareTargetType.POST "
            + "and m.shareTargetId = :postId")
    long countSharesByPostId(@Param("postId") Long postId);

    @Query("select m.shareTargetId, count(distinct coalesce(m.shareBatchId, cast(m.messageId as string))) "
            + "from Message m "
            + "where m.messageType = Travel_Planner.Travel_Planner.model.enums.MessageType.SHARE "
            + "and m.shareTargetType = Travel_Planner.Travel_Planner.model.enums.ShareTargetType.POST "
            + "and m.shareTargetId in :postIds "
            + "group by m.shareTargetId")
    List<Object[]> countSharesByPostIds(@Param("postIds") List<Long> postIds);
}



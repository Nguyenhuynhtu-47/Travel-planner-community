package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Conversation;
import Travel_Planner.Travel_Planner.model.enums.ConversationStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;
import java.util.List;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    Optional<Conversation> findByUserLow_UserIdAndUserHigh_UserId(Integer lowId, Integer highId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Conversation c where c.conversationId = :id")
    Optional<Conversation> findByIdForUpdate(@Param("id") Long id);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage", "lastMessage.sender"})
    Page<Conversation> findByUserLow_UserIdOrUserHigh_UserId(Integer lowId, Integer highId, Pageable pageable);

    @Query("select c from Conversation c where c.userLow.userId = :userId or c.userHigh.userId = :userId")
    Page<Conversation> findAllForUser(@Param("userId") Integer userId, Pageable pageable);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage", "lastMessage.sender"})
    @Query("select c from Conversation c where c.requestRecipient.userId = :recipientId "
            + "and c.status = :status and c.lastMessageSequence > :minimumSequence "
            + "and (exists (select f from Friendship f where f.status = Travel_Planner.Travel_Planner.model.enums.FriendshipStatus.ACCEPTED and ((f.userLow.userId = :recipientId and f.userHigh.userId = c.requester.userId) or (f.userHigh.userId = :recipientId and f.userLow.userId = c.requester.userId))) "
            + "or not exists (select s from UserMessagingSettings s where s.user.userId = :recipientId and s.inboundPolicy <> :everyone)) "
            + "and exists (select m from Message m where m.conversation = c and (m.recipientVisible is null or m.recipientVisible = true)) "
            + "and not exists (select b from UserBlock b where "
            + "(b.blocker.userId = :recipientId and b.blockedUser.userId = c.requester.userId) "
            + "or (b.blocker.userId = c.requester.userId and b.blockedUser.userId = :recipientId))")
    Page<Conversation> findVisibleMessageRequests(@Param("recipientId") Integer recipientId,
            @Param("status") ConversationStatus status, @Param("minimumSequence") Long minimumSequence,
            @Param("everyone") Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy everyone,
            Pageable pageable);

    @Query("select count(c) from Conversation c where c.requestRecipient.userId = :recipientId "
            + "and c.status = :status and c.lastMessageSequence > :minimumSequence "
            + "and (exists (select f from Friendship f where f.status = Travel_Planner.Travel_Planner.model.enums.FriendshipStatus.ACCEPTED and ((f.userLow.userId = :recipientId and f.userHigh.userId = c.requester.userId) or (f.userHigh.userId = :recipientId and f.userLow.userId = c.requester.userId))) "
            + "or not exists (select s from UserMessagingSettings s where s.user.userId = :recipientId and s.inboundPolicy <> :everyone)) "
            + "and exists (select m from Message m where m.conversation = c and (m.recipientVisible is null or m.recipientVisible = true)) "
            + "and not exists (select b from UserBlock b where "
            + "(b.blocker.userId = :recipientId and b.blockedUser.userId = c.requester.userId) "
            + "or (b.blocker.userId = c.requester.userId and b.blockedUser.userId = :recipientId))")
    long countVisibleMessageRequests(@Param("recipientId") Integer recipientId,
            @Param("status") ConversationStatus status, @Param("minimumSequence") Long minimumSequence,
            @Param("everyone") Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy everyone);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage", "lastMessage.sender"})
    @Query("select distinct c from Conversation c where (c.userLow.userId = :userId or c.userHigh.userId = :userId) "
            + "and ((c.status is null or c.status = :accepted) or (c.status = :pending and c.requester.userId = :userId)) "
            + "and not exists (select b from UserBlock b where (b.blocker.userId = :userId and b.blockedUser.userId = case when c.userLow.userId = :userId then c.userHigh.userId else c.userLow.userId end) or (b.blockedUser.userId = :userId and b.blocker.userId = case when c.userLow.userId = :userId then c.userHigh.userId else c.userLow.userId end)) "
            + "and exists (select m from Message m where m.conversation = c "
            + "and (m.sender.userId = :userId or m.recipientVisible is null or m.recipientVisible = true))")
    Page<Conversation> findInboxForUser(@Param("userId") Integer userId,
            @Param("accepted") ConversationStatus accepted, @Param("pending") ConversationStatus pending,
            Pageable pageable);

    @Query("select case when c.userLow.userId = :userId then c.userHigh.userId else c.userLow.userId end "
            + "from Conversation c where ((c.userLow.userId = :userId and c.userHigh.userId in :peerIds) "
            + "or (c.userHigh.userId = :userId and c.userLow.userId in :peerIds)) "
            + "and (c.status is null or c.status = :accepted)")
    List<Integer> findAcceptedPeerIds(@Param("userId") Integer userId, @Param("peerIds") List<Integer> peerIds,
            @Param("accepted") ConversationStatus accepted);
}

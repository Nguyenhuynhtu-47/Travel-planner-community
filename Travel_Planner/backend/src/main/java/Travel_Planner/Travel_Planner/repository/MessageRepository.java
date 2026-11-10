package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Message;
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

    List<Message> findByConversation_ConversationIdOrderBySequenceNumberDesc(Long conversationId, Pageable pageable);
    List<Message> findByConversation_ConversationIdAndSequenceNumberLessThanOrderBySequenceNumberDesc(Long conversationId, Long sequence, Pageable pageable);
    List<Message> findByConversation_ConversationIdAndSequenceNumberGreaterThanOrderBySequenceNumberAsc(Long conversationId, Long sequence, Pageable pageable);

@Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select m from Message m where m.messageId = :id")
    Optional<Message> findByIdForUpdate(@Param("id") Long id);

    @Query("select m.conversation.conversationId, count(m) from Message m, ConversationReadState r " +
           "where r.conversation = m.conversation and r.user.userId = :readerId " +
           "and m.conversation.conversationId in :conversationIds " +
           "and m.sequenceNumber > r.lastReadSequence and m.sender.userId <> :readerId " +
           "group by m.conversation.conversationId")
    List<Object[]> countUnreadByConversation(@Param("readerId") Integer readerId, @Param("conversationIds") List<Long> conversationIds);
}



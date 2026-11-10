package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ConversationReadState;
import Travel_Planner.Travel_Planner.model.ConversationReadStateId;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ConversationReadStateRepository extends JpaRepository<ConversationReadState, ConversationReadStateId> {
    Optional<ConversationReadState> findByConversation_ConversationIdAndUser_UserId(Long conversationId, Integer userId);
    List<ConversationReadState> findByUser_UserIdAndConversation_ConversationIdIn(Integer userId, List<Long> conversationIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select r from ConversationReadState r where r.conversation.conversationId = :conversationId and r.user.userId = :userId")
    Optional<ConversationReadState> findForUpdate(@Param("conversationId") Long conversationId, @Param("userId") Integer userId);
}

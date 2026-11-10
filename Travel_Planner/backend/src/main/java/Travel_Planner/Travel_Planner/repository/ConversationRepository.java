package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Conversation;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface ConversationRepository extends JpaRepository<Conversation, Long> {
    Optional<Conversation> findByUserLow_UserIdAndUserHigh_UserId(Integer lowId, Integer highId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select c from Conversation c where c.conversationId = :id")
    Optional<Conversation> findByIdForUpdate(@Param("id") Long id);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "lastMessage", "lastMessage.sender"})
    Page<Conversation> findByUserLow_UserIdOrUserHigh_UserId(Integer lowId, Integer highId, Pageable pageable);
}

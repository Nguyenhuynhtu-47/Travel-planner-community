package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Append-only Spring Data JPA Repository for {@link AuditLog}.
 * Intentionally extends {@link Repository} (without CrudRepository/JpaRepository/JpaSpecificationExecutor)
 * so that delete, deleteById, deleteAll, delete(Specification), and bulk update methods
 * are completely absent from the repository contract.
 */
public interface AuditLogRepository extends Repository<AuditLog, Long> {

    AuditLog save(AuditLog auditLog);

    AuditLog saveAndFlush(AuditLog auditLog);

    Optional<AuditLog> findById(Long logId);

    boolean existsById(Long logId);

    List<AuditLog> findAll();

    Page<AuditLog> findAll(Pageable pageable);

    long count();

    Page<AuditLog> findByOrderByCreatedAtDescLogIdDesc(Pageable pageable);

    Page<AuditLog> findByActorIdOrderByCreatedAtDescLogIdDesc(Integer actorId, Pageable pageable);

    Page<AuditLog> findByActionTypeOrderByCreatedAtDescLogIdDesc(AuditActionType actionType, Pageable pageable);

    Page<AuditLog> findByTargetTypeAndTargetIdOrderByCreatedAtDescLogIdDesc(
            AuditTargetType targetType,
            String targetId,
            Pageable pageable);

    @Query("""
            SELECT a FROM AuditLog a
            WHERE (:keyword IS NULL OR
                   LOWER(a.actorUsername) LIKE LOWER(CONCAT('%', :keyword, '%')) OR
                   LOWER(a.targetId) LIKE LOWER(CONCAT('%', :keyword, '%')) OR
                   LOWER(COALESCE(a.reason, '')) LIKE LOWER(CONCAT('%', :keyword, '%')) OR
                   LOWER(COALESCE(a.correlationId, '')) LIKE LOWER(CONCAT('%', :keyword, '%')))
              AND (:actorId IS NULL OR a.actorId = :actorId)
              AND (:actorUsername IS NULL OR LOWER(a.actorUsername) LIKE LOWER(CONCAT('%', :actorUsername, '%')))
              AND (:actionType IS NULL OR a.actionType = :actionType)
              AND (:targetType IS NULL OR a.targetType = :targetType)
              AND (:targetId IS NULL OR LOWER(a.targetId) LIKE LOWER(CONCAT('%', :targetId, '%')))
              AND (:resultStatus IS NULL OR a.resultStatus = :resultStatus)
              AND (:fromDate IS NULL OR a.createdAt >= :fromDate)
              AND (:toDate IS NULL OR a.createdAt <= :toDate)
            ORDER BY a.createdAt DESC, a.logId DESC
            """)
    Page<AuditLog> searchAuditLogs(
            @Param("keyword") String keyword,
            @Param("actorId") Integer actorId,
            @Param("actorUsername") String actorUsername,
            @Param("actionType") AuditActionType actionType,
            @Param("targetType") AuditTargetType targetType,
            @Param("targetId") String targetId,
            @Param("resultStatus") AuditResultStatus resultStatus,
            @Param("fromDate") LocalDateTime fromDate,
            @Param("toDate") LocalDateTime toDate,
            Pageable pageable);

    /**
     * Compound deterministic sort guaranteeing stable pagination without record drift
     * when multiple audit entries share identical timestamp granularity.
     */
    static Sort stableAuditSort() {
        return Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("logId"));
    }
}

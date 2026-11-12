package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface MediaAssetRepository extends JpaRepository<MediaAsset, Long> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT ma FROM MediaAsset ma WHERE ma.mediaAssetId IN :ids")
    List<MediaAsset> findByIdsForUpdate(@Param("ids") List<Long> sortedIds);

    Optional<MediaAsset> findByCloudinaryPublicId(String cloudinaryPublicId);

    @Query(value = "SELECT media_asset_id FROM media_assets " +
            "WHERE ((status = 'UNATTACHED' AND created_at < :unattachedCutoff) " +
            "    OR (status = 'DELETING' AND (locked_at IS NULL OR locked_at < :leaseCutoff) AND (next_retry_at IS NULL OR next_retry_at <= :now))) " +
            "AND dead_lettered_at IS NULL AND retry_count < 5 " +
            "ORDER BY media_asset_id ASC LIMIT :limit FOR UPDATE SKIP LOCKED",
            nativeQuery = true)
    List<Long> findCandidateIdsForCleanup(
            @Param("unattachedCutoff") LocalDateTime unattachedCutoff,
            @Param("leaseCutoff") LocalDateTime leaseCutoff,
            @Param("now") LocalDateTime now,
            @Param("limit") int limit);

    @Modifying
    @Query("UPDATE MediaAsset ma SET ma.status = :newStatus, ma.claimToken = :claimToken, " +
            "ma.lockedAt = :now, ma.lockedBy = :workerId, ma.updatedAt = :now " +
            "WHERE ma.mediaAssetId IN :ids")
    int claimBatch(
            @Param("ids") List<Long> ids,
            @Param("newStatus") MediaAssetStatus newStatus,
            @Param("claimToken") String claimToken,
            @Param("workerId") String workerId,
            @Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE MediaAsset ma SET ma.status = :newStatus, ma.claimToken = NULL, " +
            "ma.lockedAt = NULL, ma.lockedBy = NULL, ma.updatedAt = :now " +
            "WHERE ma.mediaAssetId = :assetId AND ma.claimToken = :claimToken AND ma.status = 'DELETING'")
    int updateCleanedAsset(
            @Param("assetId") Long assetId,
            @Param("claimToken") String claimToken,
            @Param("newStatus") MediaAssetStatus newStatus,
            @Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE MediaAsset ma SET ma.claimToken = NULL, ma.lockedAt = NULL, ma.lockedBy = NULL, " +
            "ma.retryCount = ma.retryCount + 1, ma.nextRetryAt = :nextRetryAt, ma.lastError = :lastError, ma.updatedAt = :now " +
            "WHERE ma.mediaAssetId = :assetId AND ma.claimToken = :claimToken")
    int recordRetryFailure(
            @Param("assetId") Long assetId,
            @Param("claimToken") String claimToken,
            @Param("nextRetryAt") LocalDateTime nextRetryAt,
            @Param("lastError") String lastError,
            @Param("now") LocalDateTime now);

    @Modifying
    @Query("UPDATE MediaAsset ma SET ma.claimToken = NULL, ma.lockedAt = NULL, ma.lockedBy = NULL, " +
            "ma.deadLetteredAt = :now, ma.lastError = :lastError, ma.updatedAt = :now " +
            "WHERE ma.mediaAssetId = :assetId AND ma.claimToken = :claimToken")
    int markDeadLettered(
            @Param("assetId") Long assetId,
            @Param("claimToken") String claimToken,
            @Param("lastError") String lastError,
            @Param("now") LocalDateTime now);

    Page<MediaAsset> findByDeadLetteredAtIsNotNull(Pageable pageable);

    Page<MediaAsset> findByStatus(MediaAssetStatus status, Pageable pageable);
}


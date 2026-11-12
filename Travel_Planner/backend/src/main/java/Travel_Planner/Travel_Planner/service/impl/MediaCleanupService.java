package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.repository.MediaAssetRepository;
import Travel_Planner.Travel_Planner.service.ImageUploadService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

@Service
public class MediaCleanupService {

    private static final Logger logger = LoggerFactory.getLogger(MediaCleanupService.class);
    private static final int BATCH_SIZE = 50;
    private static final int LEASE_MINUTES = 10;
    private static final int UNATTACHED_HOURS = 24;
    private static final int MAX_RETRIES = 5;

    private final MediaAssetRepository mediaAssetRepository;
    private final ImageUploadService imageUploadService;
    private final boolean cleanupEnabled;
    private final String workerId = "worker-" + UUID.randomUUID().toString().substring(0, 8);

    private volatile boolean circuitBreakerTripped = false;

    public MediaCleanupService(
            MediaAssetRepository mediaAssetRepository,
            ImageUploadService imageUploadService,
            @Value("${app.media.cleanup.enabled:true}") boolean cleanupEnabled) {
        this.mediaAssetRepository = mediaAssetRepository;
        this.imageUploadService = imageUploadService;
        this.cleanupEnabled = cleanupEnabled;
    }

    @Scheduled(fixedDelayString = "${app.media.cleanup.interval-ms:60000}", initialDelay = 30000)
    public void scheduledCleanup() {
        if (!cleanupEnabled) {
            return;
        }
        if (circuitBreakerTripped) {
            logger.warn("MediaCleanupService: Circuit breaker is tripped due to systemic configuration failure. Skipping sweep.");
            return;
        }
        try {
            cleanupOrphanAndDeletedAssets();
        } catch (Exception ex) {
            logger.error("Unexpected error during scheduled media cleanup", ex);
        }
    }

    public int cleanupOrphanAndDeletedAssets() {
        // Step 1: Claim Transaction (< 50ms)
        ClaimResult claim = claimBatch(BATCH_SIZE);
        if (claim.claimedIds().isEmpty()) {
            return 0;
        }

        logger.info("MediaCleanupService [{}]: Claimed {} assets with token {}",
                workerId, claim.claimedIds().size(), claim.claimToken());

        int processed = 0;
        // Step 2: Outside DB Transaction, loop and invoke remote Cloudinary destroy
        for (Long assetId : claim.claimedIds()) {
            MediaAsset asset = mediaAssetRepository.findById(assetId).orElse(null);
            if (asset == null) continue;

            String publicId = asset.getCloudinaryPublicId();
            try {
                imageUploadService.deleteCloudinaryImage(publicId);
                // Step 3: Success update transaction
                int updated = recordSuccess(assetId, claim.claimToken());
                if (updated > 0) {
                    processed++;
                } else {
                    logger.warn("MediaCleanupService: Lease lost for asset id={}, claim token expired or revoked", assetId);
                }
            } catch (AppException ex) {
                if (ex.getStatus() == HttpStatus.UNAUTHORIZED) {
                    // Systemic Configuration Failure: Trip Circuit Breaker, do NOT increment retries
                    circuitBreakerTripped = true;
                    logger.error("SYSTEMIC_CONFIGURATION_FAILURE detected during cleanup. Tripping circuit breaker without incrementing retry count.", ex);
                    break;
                } else {
                    handleFailure(assetId, claim.claimToken(), asset.getRetryCount(), ex.getMessage());
                }
            } catch (Exception ex) {
                handleFailure(assetId, claim.claimToken(), asset.getRetryCount(), ex.getMessage());
            }
        }
        return processed;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public ClaimResult claimBatch(int limit) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime unattachedCutoff = now.minusHours(UNATTACHED_HOURS);
        LocalDateTime leaseCutoff = now.minusMinutes(LEASE_MINUTES);

        List<Long> candidateIds;
        try {
            candidateIds = mediaAssetRepository.findCandidateIdsForCleanup(unattachedCutoff, leaseCutoff, now, limit);
        } catch (Exception ex) {
            logger.debug("Native SKIP LOCKED query failed, falling back to standard claim", ex);
            candidateIds = Collections.emptyList();
        }

        if (candidateIds.isEmpty()) {
            return new ClaimResult(Collections.emptyList(), null);
        }

        String claimToken = UUID.randomUUID().toString();
        mediaAssetRepository.claimBatch(candidateIds, MediaAssetStatus.DELETING, claimToken, workerId, now);

        return new ClaimResult(candidateIds, claimToken);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int recordSuccess(Long assetId, String claimToken) {
        return mediaAssetRepository.updateCleanedAsset(assetId, claimToken, MediaAssetStatus.DELETED, LocalDateTime.now());
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void handleFailure(Long assetId, String claimToken, int currentRetries, String error) {
        LocalDateTime now = LocalDateTime.now();
        if (currentRetries + 1 >= MAX_RETRIES) {
            logger.error("MediaCleanupService: Asset id={} exhausted retries ({}). Marking DEAD-LETTER.", assetId, currentRetries + 1);
            mediaAssetRepository.markDeadLettered(assetId, claimToken, "Max retry limit reached: " + error, now);
        } else {
            // Exponential backoff with jitter: 2^retry * 15s + random(0..5s)
            long delaySec = (long) (Math.pow(2, currentRetries) * 15) + ThreadLocalRandom.current().nextInt(6);
            LocalDateTime nextRetryAt = now.plusSeconds(delaySec);
            logger.warn("MediaCleanupService: Asset id={} failed (attempt {}), scheduling retry at {}: {}",
                    assetId, currentRetries + 1, nextRetryAt, error);
            mediaAssetRepository.recordRetryFailure(assetId, claimToken, nextRetryAt, error, now);
        }
    }

    public void resetCircuitBreaker() {
        this.circuitBreakerTripped = false;
    }

    public boolean isCircuitBreakerTripped() {
        return circuitBreakerTripped;
    }

    public record ClaimResult(List<Long> claimedIds, String claimToken) {
    }
}


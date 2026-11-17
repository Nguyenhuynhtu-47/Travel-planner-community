package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.MediaAssetRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.ImageUploadService;
import Travel_Planner.Travel_Planner.service.impl.MediaCleanupService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.PlatformTransactionManager;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@SpringBootTest
public class MediaCleanupTransactionTest {

    @Autowired
    private MediaAssetRepository mediaAssetRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private ImageUploadService imageUploadService;
    private MediaCleanupService mediaCleanupService;
    private User testUser;
    private final List<Long> createdAssetIds = new CopyOnWriteArrayList<>();

    @BeforeEach
    void setUp() {
        imageUploadService = mock(ImageUploadService.class);
        String suffix = UUID.randomUUID().toString().substring(0, 8);
        testUser = userRepository.save(User.builder()
                .username("media_cleanup_" + suffix)
                .email("cleanup_" + suffix + "@example.com")
                .handle("cleanup_" + suffix)
                .password("TestPassword@123")
                .fullName("Media Cleanup Test")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .tokenVersion(1)
                .build());

        mediaCleanupService = new MediaCleanupService(mediaAssetRepository, imageUploadService, transactionManager, true);
    }

    @AfterEach
    void tearDown() {
        for (Long id : createdAssetIds) {
            try {
                mediaAssetRepository.deleteById(id);
            } catch (Exception ignored) {}
        }
        if (testUser != null && testUser.getUserId() != null) {
            try {
                userRepository.deleteById(testUser.getUserId());
            } catch (Exception ignored) {}
        }
    }

    private MediaAsset createTestAsset(MediaAssetStatus status, int retryCount) {
        String suffix = UUID.randomUUID().toString();
        MediaAsset asset = MediaAsset.builder()
                .uploadedBy(testUser)
                .cloudinaryPublicId("test_pub_" + suffix)
                .secureUrl("https://res.cloudinary.com/test/" + suffix + ".jpg")
                .status(status)
                .retryCount(retryCount)
                .createdAt(LocalDateTime.now().minusHours(25))
                .updatedAt(LocalDateTime.now().minusHours(25))
                .build();
        MediaAsset saved = mediaAssetRepository.save(asset);
        createdAssetIds.add(saved.getMediaAssetId());
        return saved;
    }

    @Test
    @DisplayName("Scheduled cleanup claims batch and updates status to DELETED without transaction error")
    void testScheduledCleanup_claimsBatchInsideTransactionAndDeletes() {
        MediaAsset asset = createTestAsset(MediaAssetStatus.DELETING, 0);
        doNothing().when(imageUploadService).deleteCloudinaryImage(anyString());

        // Invoke scheduled cleanup (simulates scheduled runner from non-transactional thread)
        mediaCleanupService.scheduledCleanup();

        MediaAsset updated = mediaAssetRepository.findById(asset.getMediaAssetId()).orElseThrow();
        assertEquals(MediaAssetStatus.DELETED, updated.getStatus());
        assertNull(updated.getClaimToken());
        verify(imageUploadService).deleteCloudinaryImage(asset.getCloudinaryPublicId());
    }

    @Test
    @DisplayName("claimBatch modifying query runs successfully inside an active transaction")
    void testClaimBatch_runsModifyingQueryInsideTransaction() {
        MediaAsset asset = createTestAsset(MediaAssetStatus.DELETING, 0);

        // Direct call from non-transactional thread must not throw InvalidDataAccessApiUsageException
        MediaCleanupService.ClaimResult result = assertDoesNotThrow(() -> mediaCleanupService.claimBatch(10));

        assertNotNull(result);
        assertTrue(result.claimedIds().contains(asset.getMediaAssetId()));
        assertNotNull(result.claimToken());

        MediaAsset updated = mediaAssetRepository.findById(asset.getMediaAssetId()).orElseThrow();
        assertEquals(MediaAssetStatus.DELETING, updated.getStatus());
        assertEquals(result.claimToken(), updated.getClaimToken());
        assertNotNull(updated.getLockedAt());
        assertNotNull(updated.getLockedBy());
    }

    @Test
    @DisplayName("Empty batch returns empty ClaimResult without errors")
    void testEmptyBatch_handlesGracefully() {
        // Ensure no candidates
        MediaCleanupService.ClaimResult result = mediaCleanupService.claimBatch(10);
        assertNotNull(result);
        assertTrue(result.claimedIds().isEmpty());
        assertNull(result.claimToken());

        int processed = mediaCleanupService.cleanupOrphanAndDeletedAssets();
        assertEquals(0, processed);
    }

    @Test
    @DisplayName("Concurrent cleanup execution claims candidate assets without collision")
    void testConcurrentCleanup_noCollisions() throws Exception {
        int assetCount = 8;
        List<Long> assetIds = new ArrayList<>();
        for (int i = 0; i < assetCount; i++) {
            MediaAsset a = createTestAsset(MediaAssetStatus.DELETING, 0);
            assetIds.add(a.getMediaAssetId());
        }

        int threadCount = 4;
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);

        List<MediaCleanupService.ClaimResult> results = new CopyOnWriteArrayList<>();

        for (int i = 0; i < threadCount; i++) {
            executor.submit(() -> {
                try {
                    startLatch.await();
                    // Each thread has its own worker instance
                    MediaCleanupService worker = new MediaCleanupService(mediaAssetRepository, imageUploadService, transactionManager, true);
                    MediaCleanupService.ClaimResult claim = worker.claimBatch(10);
                    if (!claim.claimedIds().isEmpty()) {
                        results.add(claim);
                    }
                } catch (Exception e) {
                    fail("Worker failed with exception: " + e.getMessage());
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        startLatch.countDown();
        assertTrue(doneLatch.await(10, TimeUnit.SECONDS));
        executor.shutdown();

        Set<Long> allClaimedIds = new HashSet<>();
        int totalClaimed = 0;
        for (MediaCleanupService.ClaimResult r : results) {
            for (Long id : r.claimedIds()) {
                assertTrue(allClaimedIds.add(id), "Duplicate claim detected for asset ID: " + id);
                totalClaimed++;
            }
        }

        assertEquals(assetCount, totalClaimed);
    }

    @Test
    @DisplayName("Failure during external media deletion schedules retry with backoff and does not mark DELETED")
    void testExternalDeletionFailure_schedulesRetryAndDoesNotMarkDeleted() {
        MediaAsset asset = createTestAsset(MediaAssetStatus.DELETING, 1);
        doThrow(new RuntimeException("Cloudinary network timeout"))
                .when(imageUploadService).deleteCloudinaryImage(asset.getCloudinaryPublicId());

        int processed = mediaCleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(0, processed);
        MediaAsset updated = mediaAssetRepository.findById(asset.getMediaAssetId()).orElseThrow();
        assertNotEquals(MediaAssetStatus.DELETED, updated.getStatus());
        assertEquals(2, updated.getRetryCount());
        assertNotNull(updated.getNextRetryAt());
        assertTrue(updated.getLastError().contains("Cloudinary network timeout"));
        assertNull(updated.getClaimToken()); // Lease unlocked for retry
    }

    @Test
    @DisplayName("Exhausted retries (> 5) transitions to DEAD-LETTER")
    void testExternalDeletionExhaustedRetries_marksDeadLetter() {
        MediaAsset asset = createTestAsset(MediaAssetStatus.DELETING, 4); // 4 + 1 = 5 (max)
        doThrow(new RuntimeException("Resource corrupted on Cloudinary"))
                .when(imageUploadService).deleteCloudinaryImage(asset.getCloudinaryPublicId());

        int processed = mediaCleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(0, processed);
        MediaAsset updated = mediaAssetRepository.findById(asset.getMediaAssetId()).orElseThrow();
        assertNotNull(updated.getDeadLetteredAt());
        assertTrue(updated.getLastError().contains("Max retry limit reached"));
        assertNull(updated.getClaimToken());
    }
}

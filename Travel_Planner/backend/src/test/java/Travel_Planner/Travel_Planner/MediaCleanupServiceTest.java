package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.exception.AppException;
import Travel_Planner.Travel_Planner.model.MediaAsset;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.repository.MediaAssetRepository;
import Travel_Planner.Travel_Planner.service.ImageUploadService;
import Travel_Planner.Travel_Planner.service.impl.MediaCleanupService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class MediaCleanupServiceTest {

    @Mock
    private MediaAssetRepository mediaAssetRepository;
    @Mock
    private ImageUploadService imageUploadService;

    private MediaCleanupService cleanupService;

    @BeforeEach
    void setUp() {
        cleanupService = new MediaCleanupService(mediaAssetRepository, imageUploadService, true);
    }

    @Test
    @DisplayName("Cleanup successfully claims candidate assets and updates to DELETED")
    void cleanupOrphanAndDeletedAssets_success() {
        when(mediaAssetRepository.findCandidateIdsForCleanup(any(), any(), any(), anyInt()))
                .thenReturn(List.of(100L));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(100L)
                .cloudinaryPublicId("public_100")
                .status(MediaAssetStatus.DELETING)
                .retryCount(0)
                .build();

        when(mediaAssetRepository.findById(100L)).thenReturn(Optional.of(asset));
        when(mediaAssetRepository.updateCleanedAsset(eq(100L), anyString(), eq(MediaAssetStatus.DELETED), any()))
                .thenReturn(1);

        int processed = cleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(1, processed);
        verify(mediaAssetRepository).claimBatch(eq(List.of(100L)), eq(MediaAssetStatus.DELETING), anyString(), anyString(), any());
        verify(imageUploadService).deleteCloudinaryImage("public_100");
        verify(mediaAssetRepository).updateCleanedAsset(eq(100L), anyString(), eq(MediaAssetStatus.DELETED), any());
    }

    @Test
    @DisplayName("Transient error schedules retry with exponential backoff")
    void cleanup_transientError_schedulesRetry() {
        when(mediaAssetRepository.findCandidateIdsForCleanup(any(), any(), any(), anyInt()))
                .thenReturn(List.of(101L));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(101L)
                .cloudinaryPublicId("public_101")
                .status(MediaAssetStatus.DELETING)
                .retryCount(1)
                .build();

        when(mediaAssetRepository.findById(101L)).thenReturn(Optional.of(asset));
        doThrow(new RuntimeException("Cloudinary timeout"))
                .when(imageUploadService).deleteCloudinaryImage("public_101");

        int processed = cleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(0, processed);
        verify(mediaAssetRepository).recordRetryFailure(eq(101L), anyString(), any(LocalDateTime.class), contains("Cloudinary timeout"), any());
    }

    @Test
    @DisplayName("Exhausted retries (> 5) transitions to DEAD-LETTER")
    void cleanup_exhaustedRetries_marksDeadLetter() {
        when(mediaAssetRepository.findCandidateIdsForCleanup(any(), any(), any(), anyInt()))
                .thenReturn(List.of(102L));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(102L)
                .cloudinaryPublicId("public_102")
                .status(MediaAssetStatus.DELETING)
                .retryCount(4) // 4 + 1 = 5 (>= MAX_RETRIES)
                .build();

        when(mediaAssetRepository.findById(102L)).thenReturn(Optional.of(asset));
        doThrow(new RuntimeException("Resource corrupted"))
                .when(imageUploadService).deleteCloudinaryImage("public_102");

        int processed = cleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(0, processed);
        verify(mediaAssetRepository).markDeadLettered(eq(102L), anyString(), contains("Max retry limit reached"), any());
    }

    @Test
    @DisplayName("Systemic configuration failure (HTTP 401) trips Circuit Breaker without incrementing retry count")
    void cleanup_systemicConfigurationFailure_tripsCircuitBreaker() {
        when(mediaAssetRepository.findCandidateIdsForCleanup(any(), any(), any(), anyInt()))
                .thenReturn(List.of(103L));

        MediaAsset asset = MediaAsset.builder()
                .mediaAssetId(103L)
                .cloudinaryPublicId("public_103")
                .status(MediaAssetStatus.DELETING)
                .retryCount(0)
                .build();

        when(mediaAssetRepository.findById(103L)).thenReturn(Optional.of(asset));
        doThrow(new AppException("Lỗi cấu hình xác thực Cloudinary", HttpStatus.UNAUTHORIZED))
                .when(imageUploadService).deleteCloudinaryImage("public_103");

        int processed = cleanupService.cleanupOrphanAndDeletedAssets();

        assertEquals(0, processed);
        assertTrue(cleanupService.isCircuitBreakerTripped());
        // Retry count should NOT be recorded!
        verify(mediaAssetRepository, never()).recordRetryFailure(anyLong(), anyString(), any(), anyString(), any());
        verify(mediaAssetRepository, never()).markDeadLettered(anyLong(), anyString(), anyString(), any());
    }
}


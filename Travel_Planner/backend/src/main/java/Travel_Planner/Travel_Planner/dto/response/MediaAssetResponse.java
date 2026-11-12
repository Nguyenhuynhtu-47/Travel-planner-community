package Travel_Planner.Travel_Planner.dto.response;

import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MediaAssetResponse {
    private Long mediaAssetId;
    private Integer uploadedByUserId;
    private String uploadedByUsername;
    private String cloudinaryPublicId;
    private String secureUrl;
    private String mediaType;
    private MediaAssetStatus status;
    private String claimToken;
    private LocalDateTime lockedAt;
    private String lockedBy;
    private Integer retryCount;
    private LocalDateTime nextRetryAt;
    private LocalDateTime deadLetteredAt;
    private String lastError;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


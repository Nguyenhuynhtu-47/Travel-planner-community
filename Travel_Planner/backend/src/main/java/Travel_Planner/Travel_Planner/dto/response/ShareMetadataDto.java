package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ShareMetadataDto {
    private String title;
    private String coverImage;
    private String subtitle;
    private String authorName;
    private String authorAvatar;
    private String visibility;
    private String status;
}

package Travel_Planner.Travel_Planner.dto.request;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import java.time.LocalDateTime;

@Getter @Setter @NoArgsConstructor
public class SaveAnnouncementRequest {
    @NotBlank @Size(max = 160) private String title;
    @NotBlank @Size(max = 10000) private String body;
    private LocalDateTime publishedAt;
    private LocalDateTime expiresAt;
}

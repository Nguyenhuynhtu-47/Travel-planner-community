package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostCommentResponse {
    private Long commentId;
    private Long postId;
    private String content;
    private PostAuthorResponse author;
    private boolean isOwner;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}


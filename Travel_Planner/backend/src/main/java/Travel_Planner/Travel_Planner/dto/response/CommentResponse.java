package Travel_Planner.Travel_Planner.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.LocalDateTime;

@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommentResponse {
    private Integer commentId;
    private String content;
    private CreatorSummaryResponse creator;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private Integer parentCommentId;
    private Integer rootCommentId;
    private Integer replyCount;
    private boolean deleted;
    private CreatorSummaryResponse replyToCreator;
    private String targetType;
    private Integer targetId;
}

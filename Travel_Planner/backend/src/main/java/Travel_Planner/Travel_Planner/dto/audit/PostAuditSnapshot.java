package Travel_Planner.Travel_Planner.dto.audit;

import Travel_Planner.Travel_Planner.model.Post;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * Allowlist-only snapshot DTO for Community Post audit records.
 */
@Getter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PostAuditSnapshot implements AuditSnapshot {

    private Long postId;
    private Integer authorId;
    private String visibility;
    private String status;
    private String moderationReason;

    public static PostAuditSnapshot from(Post post) {
        if (post == null) {
            return null;
        }
        return PostAuditSnapshot.builder()
                .postId(post.getPostId())
                .authorId(post.getAuthor() != null ? post.getAuthor().getUserId() : null)
                .visibility(post.getVisibility() != null ? post.getVisibility().name() : null)
                .status(post.getStatus() != null ? post.getStatus().name() : null)
                .moderationReason(post.getModerationReason())
                .build();
    }
}

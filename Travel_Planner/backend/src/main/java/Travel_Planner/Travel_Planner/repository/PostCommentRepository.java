package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostComment;
import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    @Query(value = "SELECT c FROM PostComment c " +
            "JOIN FETCH c.user u " +
            "LEFT JOIN FETCH c.parentComment pc " +
            "LEFT JOIN FETCH pc.user pcu " +
            "LEFT JOIN FETCH c.rootComment rc " +
            "WHERE c.post.postId = :postId AND c.status = 'ACTIVE' " +
            "ORDER BY c.createdAt ASC, c.postCommentId ASC",
            countQuery = "SELECT count(c) FROM PostComment c " +
            "WHERE c.post.postId = :postId AND c.status = 'ACTIVE'")
    Page<PostComment> findByPostIdActive(@Param("postId") Long postId, Pageable pageable);

    @Query(value = "SELECT c FROM PostComment c " +
            "JOIN FETCH c.user u " +
            "WHERE c.post.postId = :postId AND c.parentComment IS NULL " +
            "AND (c.status = 'ACTIVE' OR (c.status = 'DELETED' AND EXISTS " +
            "(SELECT reply.postCommentId FROM PostComment reply WHERE reply.rootComment = c AND reply.status = 'ACTIVE'))) " +
            "ORDER BY c.createdAt ASC, c.postCommentId ASC",
            countQuery = "SELECT count(c) FROM PostComment c " +
            "WHERE c.post.postId = :postId AND c.parentComment IS NULL " +
            "AND (c.status = 'ACTIVE' OR (c.status = 'DELETED' AND EXISTS " +
            "(SELECT reply.postCommentId FROM PostComment reply WHERE reply.rootComment = c AND reply.status = 'ACTIVE')))")
    Page<PostComment> findVisibleRootsByPostId(@Param("postId") Long postId, Pageable pageable);

    @Query(value = "SELECT c FROM PostComment c " +
            "JOIN FETCH c.user u " +
            "LEFT JOIN FETCH c.parentComment pc " +
            "LEFT JOIN FETCH pc.user pcu " +
            "LEFT JOIN FETCH c.rootComment rc " +
            "WHERE c.post.postId = :postId AND c.rootComment.postCommentId = :rootCommentId " +
            "AND c.status = 'ACTIVE' " +
            "ORDER BY c.createdAt ASC, c.postCommentId ASC",
            countQuery = "SELECT count(c) FROM PostComment c " +
            "WHERE c.post.postId = :postId AND c.rootComment.postCommentId = :rootCommentId " +
            "AND c.status = 'ACTIVE'")
    Page<PostComment> findActiveRepliesByPostAndRoot(@Param("postId") Long postId,
            @Param("rootCommentId") Long rootCommentId, Pageable pageable);

    @Query("SELECT c.rootComment.postCommentId, COUNT(c) FROM PostComment c " +
            "WHERE c.rootComment.postCommentId IN :rootCommentIds AND c.status = :status " +
            "GROUP BY c.rootComment.postCommentId")
    List<Object[]> countActiveRepliesByRootIds(@Param("rootCommentIds") Collection<Long> rootCommentIds,
            @Param("status") CommentStatus status);

    void deleteByPost_PostId(Long postId);
}


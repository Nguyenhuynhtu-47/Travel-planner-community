package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostComment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PostCommentRepository extends JpaRepository<PostComment, Long> {

    @Query(value = "SELECT c FROM PostComment c JOIN FETCH c.user u " +
            "WHERE c.post.postId = :postId AND c.status = 'ACTIVE' " +
            "ORDER BY c.createdAt ASC, c.postCommentId ASC",
            countQuery = "SELECT count(c) FROM PostComment c " +
            "WHERE c.post.postId = :postId AND c.status = 'ACTIVE'")
    Page<PostComment> findByPostIdActive(@Param("postId") Long postId, Pageable pageable);

    void deleteByPost_PostId(Long postId);
}


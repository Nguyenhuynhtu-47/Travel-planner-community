package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PostLike;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface PostLikeRepository extends JpaRepository<PostLike, Long> {

    boolean existsByPost_PostIdAndUser_UserId(Long postId, Integer userId);

    Optional<PostLike> findByPost_PostIdAndUser_UserId(Long postId, Integer userId);

    void deleteByPost_PostIdAndUser_UserId(Long postId, Integer userId);

    void deleteByPost_PostId(Long postId);

    @Query("SELECT l.post.postId FROM PostLike l WHERE l.post.postId IN :postIds AND l.user.userId = :userId")
    List<Long> findLikedPostIds(@Param("postIds") List<Long> postIds, @Param("userId") Integer userId);
}


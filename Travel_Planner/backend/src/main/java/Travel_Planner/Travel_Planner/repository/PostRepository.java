package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Optional;

public interface PostRepository extends JpaRepository<Post, Long> {

    @Query(value = "SELECT p FROM Post p " +
            "JOIN FETCH p.author a " +
            "LEFT JOIN FETCH p.itinerary i " +
            "LEFT JOIN FETCH i.user iu " +
            "WHERE p.status = 'ACTIVE' AND p.visibility = 'PUBLIC' AND a.status = 'ACTIVE' " +
            "ORDER BY p.createdAt DESC, p.postId DESC",
            countQuery = "SELECT count(p) FROM Post p " +
            "WHERE p.status = 'ACTIVE' AND p.visibility = 'PUBLIC' AND p.author.status = 'ACTIVE'")
    Page<Post> findPublicFeed(Pageable pageable);

    @Query(value = "SELECT p FROM Post p " +
            "JOIN FETCH p.author a " +
            "LEFT JOIN FETCH p.itinerary i " +
            "LEFT JOIN FETCH i.user iu " +
            "WHERE p.status = 'ACTIVE' AND a.status = 'ACTIVE' AND (" +
            "   p.author.userId = :viewerId " +
            "   OR (p.visibility = 'PUBLIC' AND p.author.userId IN (SELECT f.following.userId FROM Follow f WHERE f.follower.userId = :viewerId)) " +
            "   OR (p.visibility = 'FRIENDS' AND p.author.userId IN (SELECT f.following.userId FROM Follow f WHERE f.follower.userId = :viewerId) " +
            "       AND EXISTS (SELECT 1 FROM Friendship fs WHERE fs.status = 'ACCEPTED' AND ((fs.userLow.userId = :viewerId AND fs.userHigh.userId = p.author.userId) OR (fs.userHigh.userId = :viewerId AND fs.userLow.userId = p.author.userId))))" +
            ") " +
            "ORDER BY p.createdAt DESC, p.postId DESC",
            countQuery = "SELECT count(p) FROM Post p " +
            "WHERE p.status = 'ACTIVE' AND p.author.status = 'ACTIVE' AND (" +
            "   p.author.userId = :viewerId " +
            "   OR (p.visibility = 'PUBLIC' AND p.author.userId IN (SELECT f.following.userId FROM Follow f WHERE f.follower.userId = :viewerId)) " +
            "   OR (p.visibility = 'FRIENDS' AND p.author.userId IN (SELECT f.following.userId FROM Follow f WHERE f.follower.userId = :viewerId) " +
            "       AND EXISTS (SELECT 1 FROM Friendship fs WHERE fs.status = 'ACCEPTED' AND ((fs.userLow.userId = :viewerId AND fs.userHigh.userId = p.author.userId) OR (fs.userHigh.userId = :viewerId AND fs.userLow.userId = p.author.userId))))" +
            ")")
    Page<Post> findFollowingFeed(@Param("viewerId") Integer viewerId, Pageable pageable);

    @Query("SELECT p FROM Post p " +
            "JOIN FETCH p.author a " +
            "LEFT JOIN FETCH p.itinerary i " +
            "LEFT JOIN FETCH i.user iu " +
            "WHERE p.postId = :postId")
    Optional<Post> findByIdWithDetails(@Param("postId") Long postId);

    @Modifying
    @Query("UPDATE Post p SET p.likeCount = p.likeCount + 1 WHERE p.postId = :postId")
    int incrementLikeCount(@Param("postId") Long postId);

    @Modifying
    @Query("UPDATE Post p SET p.likeCount = CASE WHEN p.likeCount > 0 THEN p.likeCount - 1 ELSE 0 END WHERE p.postId = :postId")
    int decrementLikeCount(@Param("postId") Long postId);

    @Modifying
    @Query("UPDATE Post p SET p.commentCount = p.commentCount + 1 WHERE p.postId = :postId")
    int incrementCommentCount(@Param("postId") Long postId);

    @Modifying
    @Query("UPDATE Post p SET p.commentCount = CASE WHEN p.commentCount > 0 THEN p.commentCount - 1 ELSE 0 END WHERE p.postId = :postId")
    int decrementCommentCount(@Param("postId") Long postId);

    Page<Post> findByStatus(PostStatus status, Pageable pageable);
}


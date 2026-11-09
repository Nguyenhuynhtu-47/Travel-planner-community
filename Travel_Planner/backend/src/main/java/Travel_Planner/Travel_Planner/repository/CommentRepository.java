package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Comment;
import Travel_Planner.Travel_Planner.model.enums.CommentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

@Repository
public interface CommentRepository extends JpaRepository<Comment, Integer> {

    @EntityGraph(attributePaths = {"user", "parentComment", "parentComment.user", "rootComment"})
    @Query("select c from Comment c where c.itinerary.itineraryId = :targetId and c.parentComment is null and " +
            "(c.status = :active or (c.status = :deleted and exists (select r.commentId from Comment r where r.rootComment.commentId = c.commentId and r.status = :active)))")
    Page<Comment> pageItineraryRoots(@Param("targetId") Integer targetId, @Param("active") CommentStatus active,
                                     @Param("deleted") CommentStatus deleted, Pageable pageable);

    @EntityGraph(attributePaths = {"user", "parentComment", "parentComment.user", "rootComment"})
    @Query("select c from Comment c where c.activity.activityId = :targetId and c.parentComment is null and " +
            "(c.status = :active or (c.status = :deleted and exists (select r.commentId from Comment r where r.rootComment.commentId = c.commentId and r.status = :active)))")
    Page<Comment> pageActivityRoots(@Param("targetId") Integer targetId, @Param("active") CommentStatus active,
                                    @Param("deleted") CommentStatus deleted, Pageable pageable);

    @EntityGraph(attributePaths = {"user", "parentComment", "parentComment.user", "rootComment"})
    @Query("select c from Comment c where c.rootComment.commentId = :rootId and c.commentId <> :rootId and " +
            "(c.status = :active or (c.status = :deleted and exists (select r.commentId from Comment r where r.parentComment.commentId = c.commentId and r.status = :active)))")
    Page<Comment> pageThreadReplies(@Param("rootId") Integer rootId, @Param("active") CommentStatus active,
                                    @Param("deleted") CommentStatus deleted, Pageable pageable);

    long countByRootComment_CommentIdAndStatus(Integer rootId, CommentStatus status);

    @Query("select c.rootComment.commentId, count(c) from Comment c where c.rootComment.commentId in :rootIds " +
            "and c.commentId <> c.rootComment.commentId and c.status = :status group by c.rootComment.commentId")
    List<Object[]> countActiveRepliesByRootIds(@Param("rootIds") java.util.Collection<Integer> rootIds,
                                                @Param("status") CommentStatus status);

    long countByActivity_ActivityIdAndStatus(Integer activityId, CommentStatus status);

    long countByItinerary_ItineraryIdAndStatus(Integer itineraryId, CommentStatus status);

    long countByActivity_ActivityIdInAndStatus(java.util.Collection<Integer> activityIds, CommentStatus status);

    @Modifying
    @Query("update Comment c set c.activity = null, c.itinerary = :itinerary where c.activity.activityId in :activityIds")
    int moveActivityCommentsToItinerary(@Param("activityIds") java.util.Collection<Integer> activityIds,
                                        @Param("itinerary") Travel_Planner.Travel_Planner.model.Itinerary itinerary);

    @Modifying
    @Query("delete from Comment c where c.itinerary.itineraryId = :itineraryId")
    int deleteByItineraryId(@Param("itineraryId") Integer itineraryId);

    List<Comment> findByItinerary_ItineraryIdOrderByCreatedAtDesc(Integer itineraryId);

    List<Comment> findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(Integer itineraryId, CommentStatus status);

    @EntityGraph(attributePaths = {"user"})
    Page<Comment> findByItinerary_ItineraryIdAndStatusOrderByCreatedAtDesc(
            Integer itineraryId, CommentStatus status, Pageable pageable);

    long countByItinerary_ItineraryId(Integer itineraryId);

}

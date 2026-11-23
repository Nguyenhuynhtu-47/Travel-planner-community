package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.ActivityVisit;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

@Repository
public interface ActivityVisitRepository extends JpaRepository<ActivityVisit, Long> {

    @Modifying(clearAutomatically = true, flushAutomatically = true)
    @Query(value = "INSERT INTO activity_visits (user_id, activity_id, visited, updated_at) " +
            "VALUES (:userId, :activityId, :visited, CURRENT_TIMESTAMP) " +
            "ON DUPLICATE KEY UPDATE visited = VALUES(visited), updated_at = CURRENT_TIMESTAMP",
            nativeQuery = true)
    void upsertVisitStatus(@Param("userId") Integer userId,
                           @Param("activityId") Integer activityId,
                           @Param("visited") boolean visited);

    @Query("select visit.activity.activityId from ActivityVisit visit " +
            "where visit.user.userId = :userId and visit.activity.activityId in :activityIds " +
            "and visit.visited = true")
    List<Integer> findVisitedActivityIds(@Param("userId") Integer userId,
                                        @Param("activityIds") Collection<Integer> activityIds);

    Optional<ActivityVisit> findByUser_UserIdAndActivity_ActivityId(Integer userId, Integer activityId);

    @Modifying
    @Query("delete from ActivityVisit visit where visit.activity.activityId = :activityId")
    void deleteByActivityId(@Param("activityId") Integer activityId);
}

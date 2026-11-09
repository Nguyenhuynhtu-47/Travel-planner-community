package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Follow;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;

import java.util.List;
import java.util.Optional;

@Repository
public interface FollowRepository extends JpaRepository<Follow, Integer> {

    Optional<Follow> findByFollower_UserIdAndFollowing_UserId(Integer followerId, Integer followingId);

    boolean existsByFollower_UserIdAndFollowing_UserId(Integer followerId, Integer followingId);

    List<Follow> findByFollower_UserIdOrderByCreatedAtDesc(Integer followerId);

    List<Follow> findByFollowing_UserIdOrderByCreatedAtDesc(Integer followingId);

    long countByFollower_UserId(Integer followerId);

    long countByFollowing_UserId(Integer followingId);

    @EntityGraph(attributePaths = {"follower"})
    Page<Follow> findByFollowing_UserIdAndFollower_StatusOrderByCreatedAtDesc(Integer followingId,
            Travel_Planner.Travel_Planner.model.enums.UserStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"following"})
    Page<Follow> findByFollower_UserIdAndFollowing_StatusOrderByCreatedAtDesc(Integer followerId,
            Travel_Planner.Travel_Planner.model.enums.UserStatus status, Pageable pageable);
}

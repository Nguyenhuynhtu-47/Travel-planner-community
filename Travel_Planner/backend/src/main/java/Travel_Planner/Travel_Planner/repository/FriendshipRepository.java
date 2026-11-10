package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.Friendship;
import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface FriendshipRepository extends JpaRepository<Friendship, Long> {
    Optional<Friendship> findByUserLow_UserIdAndUserHigh_UserId(Integer lowId, Integer highId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select f from Friendship f where f.friendshipId = :id")
    Optional<Friendship> findByIdForUpdate(@Param("id") Long id);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "requestedByUser"})
    @Query("select f from Friendship f where f.status = :status and (f.userLow.userId = :userId or f.userHigh.userId = :userId) and f.requestedByUser.userId <> :userId order by f.updatedAt desc, f.friendshipId desc")
    Page<Friendship> findReceived(@Param("userId") Integer userId, @Param("status") FriendshipStatus status, Pageable pageable);

    @EntityGraph(attributePaths = {"userLow", "userHigh", "requestedByUser"})
    @Query("select f from Friendship f where f.status = :status and f.requestedByUser.userId = :userId order by f.updatedAt desc, f.friendshipId desc")
    Page<Friendship> findSent(@Param("userId") Integer userId, @Param("status") FriendshipStatus status, Pageable pageable);

    @Query("select f.userLow.userId, f.userHigh.userId from Friendship f where f.status = :status and ((f.userLow.userId = :userId and f.userHigh.userId in :otherIds) or (f.userHigh.userId = :userId and f.userLow.userId in :otherIds))")
    java.util.List<Object[]> findPairsByUserAndStatus(@Param("userId") Integer userId, @Param("otherIds") java.util.List<Integer> otherIds, @Param("status") FriendshipStatus status);

    @EntityGraph(attributePaths = {"userLow", "userHigh"})
    @Query("select f from Friendship f where f.status = :status and (f.userLow.userId = :userId or f.userHigh.userId = :userId) order by f.updatedAt desc, f.friendshipId desc")
    Page<Friendship> findByUserAndStatus(@Param("userId") Integer userId, @Param("status") FriendshipStatus status, Pageable pageable);
}


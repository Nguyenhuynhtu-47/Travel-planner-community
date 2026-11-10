package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.UserBlock;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface UserBlockRepository extends JpaRepository<UserBlock, Long> {
    boolean existsByBlocker_UserIdAndBlockedUser_UserId(Integer blockerId, Integer blockedId);

    @Query("select count(b) > 0 from UserBlock b where (b.blocker.userId = :first and b.blockedUser.userId = :second) or (b.blocker.userId = :second and b.blockedUser.userId = :first)")
    boolean existsBetween(@Param("first") Integer first, @Param("second") Integer second);

    @Query("select b.blocker.userId, b.blockedUser.userId from UserBlock b where (b.blocker.userId = :userId and b.blockedUser.userId in :otherIds) or (b.blockedUser.userId = :userId and b.blocker.userId in :otherIds)")
    java.util.List<Object[]> findPairsForUser(@Param("userId") Integer userId, @Param("otherIds") java.util.List<Integer> otherIds);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select b from UserBlock b where b.blocker.userId = :blocker and b.blockedUser.userId = :blocked")
    Optional<UserBlock> findForUpdate(@Param("blocker") Integer blockerId, @Param("blocked") Integer blockedId);

    @EntityGraph(attributePaths = "blockedUser")
    Page<UserBlock> findByBlocker_UserIdOrderByCreatedAtDesc(Integer blockerId, Pageable pageable);
}


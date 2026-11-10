package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, Integer> {

    Optional<User> findByUsername(String username);

    Optional<User> findByEmail(String email);

    Optional<User> findByUsernameOrEmail(String username, String email);

    Optional<User> findByHandle(String handle);

    boolean existsByUsername(String username);

    boolean existsByEmail(String email);

    boolean existsByHandle(String handle);

    boolean existsByHandleAndUserIdNot(String handle, Integer userId);

    @Query("select u from User u where u.handle is null or trim(u.handle) = ''")
    List<User> findUsersNeedingHandle();

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.userId = :userId")
    Optional<User> findByUserIdForUpdate(@Param("userId") Integer userId);
}

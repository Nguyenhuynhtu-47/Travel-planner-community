package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.AdminRoleGuard;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface AdminRoleGuardRepository extends JpaRepository<AdminRoleGuard, Integer> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT g FROM AdminRoleGuard g WHERE g.guardName = :guardName")
    Optional<AdminRoleGuard> findByGuardNameForUpdate(@Param("guardName") String guardName);
}

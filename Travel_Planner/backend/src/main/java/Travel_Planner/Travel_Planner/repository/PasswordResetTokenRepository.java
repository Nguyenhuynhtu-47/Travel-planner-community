package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.PasswordResetToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {

    Optional<PasswordResetToken> findTopByUser_UserIdOrderByCreatedAtDesc(Integer userId);

    void deleteByUser_UserId(Integer userId);

    Optional<PasswordResetToken> findByTokenHash(String tokenHash);
}

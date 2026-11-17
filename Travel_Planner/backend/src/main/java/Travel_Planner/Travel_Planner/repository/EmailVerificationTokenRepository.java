package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.EmailVerificationToken;
import Travel_Planner.Travel_Planner.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.Optional;

@Repository
public interface EmailVerificationTokenRepository extends JpaRepository<EmailVerificationToken, Long> {

    Optional<EmailVerificationToken> findByTokenHash(String tokenHash);

    Optional<EmailVerificationToken> findByUser_UserIdAndTokenType(Integer userId, String tokenType);

    Optional<EmailVerificationToken> findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(Integer userId, String tokenType);

    Optional<EmailVerificationToken> findByUser(User user);

    @Modifying
    @Query("DELETE FROM EmailVerificationToken t WHERE t.user.userId = :userId")
    void deleteByUserId(@Param("userId") Integer userId);

    @Modifying
    @Query("DELETE FROM EmailVerificationToken t WHERE t.user.userId = :userId AND t.tokenType = :tokenType")
    void deleteByUserIdAndTokenType(@Param("userId") Integer userId, @Param("tokenType") String tokenType);

    @Modifying
    @Query("DELETE FROM EmailVerificationToken t WHERE t.expiresAt < :now")
    void deleteExpiredTokens(@Param("now") LocalDateTime now);
}

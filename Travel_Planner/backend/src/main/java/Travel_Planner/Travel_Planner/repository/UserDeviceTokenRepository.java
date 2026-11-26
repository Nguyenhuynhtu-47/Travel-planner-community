package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

public interface UserDeviceTokenRepository extends JpaRepository<UserDeviceToken, Long> {
    Optional<UserDeviceToken> findByFcmTokenHash(String fcmTokenHash);

    List<UserDeviceToken> findAllByUser_UserIdAndDisabledAtIsNull(Integer userId);

    @Modifying
    @Transactional
    @Query("update UserDeviceToken t set t.disabledAt = current_timestamp where t.deviceTokenId = :id")
    int disable(@Param("id") Long id);

    @Modifying
    @Query("delete from UserDeviceToken t where t.fcmTokenHash = :tokenHash and t.user.userId = :userId")
    int deleteOwnedToken(@Param("tokenHash") String tokenHash, @Param("userId") Integer userId);
}

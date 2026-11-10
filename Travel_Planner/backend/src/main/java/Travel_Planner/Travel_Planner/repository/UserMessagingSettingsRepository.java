package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.UserMessagingSettings;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserMessagingSettingsRepository extends JpaRepository<UserMessagingSettings, Integer> {
    Optional<UserMessagingSettings> findByUser_UserId(Integer userId);
    java.util.List<UserMessagingSettings> findByUser_UserIdIn(java.util.List<Integer> userIds);
}


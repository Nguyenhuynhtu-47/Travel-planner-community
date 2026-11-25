package Travel_Planner.Travel_Planner.repository;

import Travel_Planner.Travel_Planner.model.SystemSetting;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface SystemSettingRepository extends JpaRepository<SystemSetting, String> {
    List<SystemSetting> findAllByOrderBySettingGroupAscSettingKeyAsc();
}

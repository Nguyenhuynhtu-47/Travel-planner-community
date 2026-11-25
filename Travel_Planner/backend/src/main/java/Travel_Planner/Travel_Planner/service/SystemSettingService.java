package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.UpdateSystemSettingRequest;
import Travel_Planner.Travel_Planner.dto.response.SystemSettingResponse;

import java.util.List;

public interface SystemSettingService {

    List<SystemSettingResponse> getSettings();

    SystemSettingResponse updateSetting(String key, UpdateSystemSettingRequest request, String actorUsername);

    boolean isMaintenanceModeEnabled();

    String getMaintenanceMessage();

    int getMaxImageSizeMb();

    int getModerationAutoHideThreshold();

    double getGeoConfidenceThreshold();

    void refreshCache();
}

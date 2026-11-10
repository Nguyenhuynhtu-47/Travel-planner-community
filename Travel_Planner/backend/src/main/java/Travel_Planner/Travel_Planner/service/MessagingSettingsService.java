package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.response.MessagingSettingsResponse;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;

public interface MessagingSettingsService {
    MessagingSettingsResponse get(String actorUsername);
    MessagingSettingsResponse update(InboundMessagePolicy policy, String actorUsername);
}

package Travel_Planner.Travel_Planner.service;

public interface DeviceTokenService {
    void upsert(String username, String token, String platform);
    void unregister(String username, String token);
}

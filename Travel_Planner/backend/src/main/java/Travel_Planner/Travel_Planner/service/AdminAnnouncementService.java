package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.SaveAnnouncementRequest;
import Travel_Planner.Travel_Planner.dto.response.AdminAnnouncementResponse;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import org.springframework.data.domain.Page;
import java.util.Map;

public interface AdminAnnouncementService {
    Page<AdminAnnouncementResponse> list(AnnouncementStatus status, String type, String query, int page, int size);
    Map<String, Long> summary();
    AdminAnnouncementResponse get(Long id);
    AdminAnnouncementResponse create(SaveAnnouncementRequest request, String adminUsername);
    AdminAnnouncementResponse update(Long id, SaveAnnouncementRequest request, String adminUsername);
    AdminAnnouncementResponse publish(Long id, String adminUsername);
    AdminAnnouncementResponse cancel(Long id, String adminUsername);
    void synchronizeLifecycle();
}

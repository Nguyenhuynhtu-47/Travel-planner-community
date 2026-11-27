package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.request.SaveAnnouncementRequest;
import Travel_Planner.Travel_Planner.dto.response.AdminAnnouncementResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.SystemAnnouncement;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import Travel_Planner.Travel_Planner.repository.SystemAnnouncementRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.AdminAnnouncementService;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.NotificationPushListener.AnnouncementEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.util.Map;

@Service
public class AdminAnnouncementServiceImpl implements AdminAnnouncementService {
    private final SystemAnnouncementRepository repository;
    private final UserRepository users;
    private final AuditLogService audit;
    private final ApplicationEventPublisher events;
    public AdminAnnouncementServiceImpl(SystemAnnouncementRepository repository, UserRepository users,
            AuditLogService audit, ApplicationEventPublisher events) {
        this.repository = repository; this.users = users; this.audit = audit; this.events = events;
    }

    @Override @Transactional(readOnly = true)
    public Page<AdminAnnouncementResponse> list(AnnouncementStatus status, String query, int page, int size) {
        if (page < 0 || size < 1 || size > 50) throw new BadRequestException("Phân trang không hợp lệ");
        PageRequest pageable = PageRequest.of(page, size);
        return repository.findAdminPage(status, normalize(query), pageable)
                .map(AdminAnnouncementResponse::from);
    }

    @Override @Transactional(readOnly = true)
    public AdminAnnouncementResponse get(Long id) { return AdminAnnouncementResponse.from(find(id)); }

    @Override @Transactional
    public AdminAnnouncementResponse create(SaveAnnouncementRequest request, String username) {
        validate(request, false);
        var admin = users.findByUsername(username).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy quản trị viên"));
        var saved = repository.save(SystemAnnouncement.builder().createdBy(admin).title(request.getTitle().trim())
                .body(request.getBody().trim()).type("SYSTEM").expiresAt(request.getExpiresAt()).status(AnnouncementStatus.DRAFT).build());
        log(AuditActionType.ANNOUNCEMENT_CREATE, saved, username);
        return AdminAnnouncementResponse.from(saved);
    }

    @Override @Transactional
    public AdminAnnouncementResponse update(Long id, SaveAnnouncementRequest request, String username) {
        validate(request, false);
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() != AnnouncementStatus.DRAFT) throw new BadRequestException("Chỉ có thể sửa announcement ở trạng thái nháp");
        a.setTitle(request.getTitle().trim()); a.setBody(request.getBody().trim()); a.setType("SYSTEM"); a.setExpiresAt(request.getExpiresAt());
        log(AuditActionType.ANNOUNCEMENT_UPDATE, a, username);
        return AdminAnnouncementResponse.from(a);
    }

    @Override @Transactional
    public AdminAnnouncementResponse publish(Long id, String username) {
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() != AnnouncementStatus.DRAFT) throw new BadRequestException("Announcement không còn ở trạng thái nháp");
        validateExpiry(a.getExpiresAt()); a.setStatus(AnnouncementStatus.PUBLISHED); a.setPublishedAt(LocalDateTime.now());
        log(AuditActionType.ANNOUNCEMENT_PUBLISH, a, username);
        events.publishEvent(new AnnouncementEvent(a.getAnnouncementId(), a.getTitle(), a.getBody()));
        return AdminAnnouncementResponse.from(a);
    }

    @Override @Transactional
    public AdminAnnouncementResponse cancel(Long id, String username) {
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() != AnnouncementStatus.PUBLISHED) throw new BadRequestException("Chỉ có thể hủy announcement đã phát hành");
        a.setStatus(AnnouncementStatus.CANCELLED); log(AuditActionType.ANNOUNCEMENT_CANCEL, a, username);
        return AdminAnnouncementResponse.from(a);
    }

    private SystemAnnouncement find(Long id) { return repository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement")); }
    private void log(AuditActionType type, SystemAnnouncement a, String username) {
        audit.logStrictAction(AuditCommand.builder().actionType(type).targetType(AuditTargetType.SYSTEM_ANNOUNCEMENT)
                .targetId(String.valueOf(a.getAnnouncementId())).reason("Quản lý thông báo hệ thống")
                .afterSnapshot(Map.of("title", a.getTitle(), "status", a.getStatus().name(), "type", "SYSTEM"))
                .expectedActorUsername(username).build());
    }
    private static String normalize(String q) { return q == null || q.isBlank() ? null : q.trim(); }
    private static void validate(SaveAnnouncementRequest r, boolean publishing) {
        if (r.getTitle() == null || r.getTitle().isBlank() || r.getTitle().trim().length() > 160 || r.getBody() == null || r.getBody().isBlank() || r.getBody().trim().length() > 10000)
            throw new BadRequestException("Tiêu đề và nội dung thông báo hệ thống là bắt buộc");
        validateExpiry(r.getExpiresAt());
    }
    private static void validateExpiry(LocalDateTime expiresAt) {
        if (expiresAt != null && !expiresAt.isAfter(LocalDateTime.now())) throw new BadRequestException("Thời điểm hết hạn phải ở tương lai");
    }
}

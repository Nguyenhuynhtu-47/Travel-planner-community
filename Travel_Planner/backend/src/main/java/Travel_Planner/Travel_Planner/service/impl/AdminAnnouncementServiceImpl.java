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
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class AdminAnnouncementServiceImpl implements AdminAnnouncementService {
    private static final ZoneId VIETNAM_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");
    private final SystemAnnouncementRepository repository;
    private final UserRepository users;
    private final AuditLogService audit;
    private final ApplicationEventPublisher events;
    public AdminAnnouncementServiceImpl(SystemAnnouncementRepository repository, UserRepository users,
            AuditLogService audit, ApplicationEventPublisher events) {
        this.repository = repository; this.users = users; this.audit = audit; this.events = events;
    }

    @Override @Transactional
    public Page<AdminAnnouncementResponse> list(AnnouncementStatus status, String type, String query, int page, int size) {
        if (page < 0 || size < 1 || size > 50) throw new BadRequestException("Phân trang không hợp lệ");
        synchronizeLifecycleInternal(now());
        PageRequest pageable = PageRequest.of(page, size);
        return repository.findAdminPage(status, normalizeType(type), normalize(query), pageable)
                .map(AdminAnnouncementResponse::from);
    }

    @Override @Transactional
    public Map<String, Long> summary() {
        synchronizeLifecycleInternal(now());
        Map<String, Long> result = new LinkedHashMap<>();
        long draft = repository.countByStatus(AnnouncementStatus.DRAFT);
        long published = repository.countByStatus(AnnouncementStatus.PUBLISHED);
        long cancelled = repository.countByStatus(AnnouncementStatus.CANCELLED);
        result.put("total", draft + published + cancelled);
        result.put("draft", draft);
        result.put("published", published);
        result.put("cancelled", cancelled);
        return result;
    }

    @Override @Transactional(readOnly = true)
    public AdminAnnouncementResponse get(Long id) { return AdminAnnouncementResponse.from(find(id)); }

    @Override @Transactional
    public AdminAnnouncementResponse create(SaveAnnouncementRequest request, String username) {
        validate(request);
        var admin = users.findByUsername(username).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy quản trị viên"));
        var saved = repository.save(SystemAnnouncement.builder().createdBy(admin).title(request.getTitle().trim())
                .body(request.getBody().trim()).type("SYSTEM").publishedAt(request.getPublishedAt())
                .expiresAt(request.getExpiresAt()).status(AnnouncementStatus.DRAFT).build());
        log(AuditActionType.ANNOUNCEMENT_CREATE, saved, username);
        return AdminAnnouncementResponse.from(saved);
    }

    @Override @Transactional
    public AdminAnnouncementResponse update(Long id, SaveAnnouncementRequest request, String username) {
        validate(request);
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() != AnnouncementStatus.DRAFT) throw new BadRequestException("Chỉ có thể sửa announcement ở trạng thái nháp");
        a.setTitle(request.getTitle().trim()); a.setBody(request.getBody().trim()); a.setType("SYSTEM");
        a.setPublishedAt(request.getPublishedAt()); a.setExpiresAt(request.getExpiresAt());
        log(AuditActionType.ANNOUNCEMENT_UPDATE, a, username);
        return AdminAnnouncementResponse.from(a);
    }

    @Override @Transactional
    public AdminAnnouncementResponse publish(Long id, String username) {
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() != AnnouncementStatus.DRAFT) throw new BadRequestException("Announcement không còn ở trạng thái nháp");
        validatePublishWindow(a.getExpiresAt()); a.setStatus(AnnouncementStatus.PUBLISHED); a.setPublishedAt(now());
        log(AuditActionType.ANNOUNCEMENT_PUBLISH, a, username);
        events.publishEvent(new AnnouncementEvent(a.getAnnouncementId(), a.getTitle(), a.getBody()));
        return AdminAnnouncementResponse.from(a);
    }

    @Override @Transactional
    public AdminAnnouncementResponse cancel(Long id, String username) {
        var a = repository.findByIdForUpdate(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement"));
        if (a.getStatus() == AnnouncementStatus.CANCELLED) throw new BadRequestException("Announcement đã bị hủy hoặc hết hạn");
        a.setStatus(AnnouncementStatus.CANCELLED); log(AuditActionType.ANNOUNCEMENT_CANCEL, a, username);
        return AdminAnnouncementResponse.from(a);
    }

    @Override
    @Scheduled(fixedDelayString = "${app.announcements.lifecycle.interval-ms:60000}",
            initialDelayString = "${app.announcements.lifecycle.initial-delay-ms:5000}")
    @Transactional
    public void synchronizeLifecycle() {
        synchronizeLifecycleInternal(now());
    }

    private void synchronizeLifecycleInternal(LocalDateTime currentTime) {
        for (SystemAnnouncement announcement : repository.findExpiredForUpdate(currentTime)) {
            if (announcement.getStatus() != AnnouncementStatus.CANCELLED) {
                announcement.setStatus(AnnouncementStatus.CANCELLED);
            }
        }
        for (SystemAnnouncement announcement : repository.findScheduledForUpdate(currentTime)) {
            if (announcement.getStatus() == AnnouncementStatus.DRAFT
                    && (announcement.getExpiresAt() == null || announcement.getExpiresAt().isAfter(currentTime))) {
                announcement.setStatus(AnnouncementStatus.PUBLISHED);
                announcement.setPublishedAt(currentTime);
                events.publishEvent(new AnnouncementEvent(announcement.getAnnouncementId(),
                        announcement.getTitle(), announcement.getBody()));
            }
        }
    }

    private SystemAnnouncement find(Long id) { return repository.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy announcement")); }
    private void log(AuditActionType type, SystemAnnouncement a, String username) {
        audit.logStrictAction(AuditCommand.builder().actionType(type).targetType(AuditTargetType.SYSTEM_ANNOUNCEMENT)
                .targetId(String.valueOf(a.getAnnouncementId())).reason("Quản lý thông báo hệ thống")
                .afterSnapshot(Map.of("title", a.getTitle(), "status", a.getStatus().name(), "type", "SYSTEM"))
                .expectedActorUsername(username).build());
    }
    private static String normalize(String q) { return q == null || q.isBlank() ? null : q.trim(); }
    private static String normalizeType(String type) {
        if (type == null || type.isBlank()) return null;
        if (!"SYSTEM".equalsIgnoreCase(type.trim())) throw new BadRequestException("Loại thông báo không hợp lệ");
        return "SYSTEM";
    }
    private static void validate(SaveAnnouncementRequest r) {
        if (r.getTitle() == null || r.getTitle().isBlank() || r.getTitle().trim().length() > 160 || r.getBody() == null || r.getBody().isBlank() || r.getBody().trim().length() > 10000)
            throw new BadRequestException("Tiêu đề và nội dung thông báo hệ thống là bắt buộc");
        LocalDateTime currentTime = now();
        if (r.getPublishedAt() != null && !r.getPublishedAt().isAfter(currentTime))
            throw new BadRequestException("Thời điểm công khai phải ở tương lai");
        LocalDateTime start = r.getPublishedAt() == null ? currentTime : r.getPublishedAt();
        if (r.getExpiresAt() != null && !r.getExpiresAt().isAfter(start))
            throw new BadRequestException("Thời điểm hết hạn phải sau thời điểm công khai");
    }
    private static void validatePublishWindow(LocalDateTime expiresAt) {
        if (expiresAt != null && !expiresAt.isAfter(now())) throw new BadRequestException("Không thể công khai thông báo đã hết hạn");
    }
    private static LocalDateTime now() { return LocalDateTime.now(VIETNAM_ZONE); }
}

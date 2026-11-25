package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.audit.SettingAuditSnapshot;
import Travel_Planner.Travel_Planner.dto.request.UpdateSystemSettingRequest;
import Travel_Planner.Travel_Planner.dto.response.SystemSettingResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.SystemSetting;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import Travel_Planner.Travel_Planner.repository.SystemSettingRepository;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.SystemSettingService;
import jakarta.annotation.PostConstruct;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class SystemSettingServiceImpl implements SystemSettingService {

    public static final String KEY_MODERATION_AUTO_HIDE = "MODERATION_AUTO_HIDE_THRESHOLD";
    public static final String KEY_GEO_CONFIDENCE = "GEO_AUTO_RESOLVE_CONFIDENCE_THRESHOLD";
    public static final String KEY_MEDIA_MAX_IMAGE_MB = "MEDIA_MAX_IMAGE_SIZE_MB";
    public static final String KEY_MAINTENANCE_MODE = "SYSTEM_MAINTENANCE_MODE";
    public static final String KEY_MAINTENANCE_MESSAGE = "SYSTEM_MAINTENANCE_MESSAGE";

    private static final Set<String> ALLOWED_BUSINESS_KEYS = Set.of(
            KEY_MODERATION_AUTO_HIDE,
            KEY_GEO_CONFIDENCE,
            KEY_MEDIA_MAX_IMAGE_MB,
            KEY_MAINTENANCE_MODE,
            KEY_MAINTENANCE_MESSAGE
    );

    private static final String DEFAULT_MAINTENANCE_MESSAGE =
            "Hệ thống đang bảo trì định kỳ. Vui lòng quay lại sau.";

    private final SystemSettingRepository settingRepository;
    private final AuditLogService auditLogService;
    private final Map<String, String> cache = new ConcurrentHashMap<>();

    public SystemSettingServiceImpl(
            SystemSettingRepository settingRepository,
            AuditLogService auditLogService) {
        this.settingRepository = settingRepository;
        this.auditLogService = auditLogService;
    }

    @PostConstruct
    @Override
    public void refreshCache() {
        List<SystemSetting> all = settingRepository.findAllByOrderBySettingGroupAscSettingKeyAsc();
        Map<String, String> next = new ConcurrentHashMap<>();
        for (SystemSetting s : all) {
            if (ALLOWED_BUSINESS_KEYS.contains(s.getSettingKey()) && s.getSettingValue() != null) {
                next.put(s.getSettingKey(), s.getSettingValue());
            }
        }
        cache.clear();
        cache.putAll(next);
    }

    @Override
    @Transactional(readOnly = true)
    public List<SystemSettingResponse> getSettings() {
        return settingRepository.findAllByOrderBySettingGroupAscSettingKeyAsc().stream()
                .filter(s -> ALLOWED_BUSINESS_KEYS.contains(s.getSettingKey()))
                .map(SystemSettingResponse::fromEntity)
                .toList();
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRED, readOnly = false)
    public SystemSettingResponse updateSetting(
            String key,
            UpdateSystemSettingRequest request,
            String actorUsername) {
        if (key == null || !ALLOWED_BUSINESS_KEYS.contains(key.trim())) {
            throw new BadRequestException("Khóa cấu hình không hợp lệ hoặc không được phép quản trị: " + key);
        }

        String normalizedKey = key.trim();
        SystemSetting setting = settingRepository.findById(normalizedKey)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy cấu hình: " + normalizedKey));

        String normalizedValue = validateAndNormalizeValue(normalizedKey, request.getSettingValue());
        String previousValue = setting.getSettingValue();

        setting.setSettingValue(normalizedValue);
        setting.setUpdatedBy(actorUsername != null && !actorUsername.isBlank() ? actorUsername : "ADMIN");
        SystemSetting saved = settingRepository.saveAndFlush(setting);

        AuditActionType actionType = KEY_MAINTENANCE_MODE.equals(normalizedKey)
                ? AuditActionType.MAINTENANCE_TOGGLE
                : AuditActionType.SETTING_UPDATE;

        String auditReason = (request.getReason() != null && !request.getReason().isBlank())
                ? request.getReason().trim()
                : "Cập nhật cấu hình " + normalizedKey;

        auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(actionType)
                .targetType(AuditTargetType.SYSTEM_SETTING)
                .targetId(normalizedKey)
                .reason(auditReason)
                .beforeSnapshot(SettingAuditSnapshot.builder()
                        .settingKey(normalizedKey)
                        .settingValue(previousValue)
                        .settingGroup(saved.getSettingGroup())
                        .build())
                .afterSnapshot(SettingAuditSnapshot.builder()
                        .settingKey(normalizedKey)
                        .settingValue(normalizedValue)
                        .settingGroup(saved.getSettingGroup())
                        .build())
                .build());

        cache.put(normalizedKey, normalizedValue);
        return SystemSettingResponse.fromEntity(saved);
    }

    @Override
    public boolean isMaintenanceModeEnabled() {
        String raw = getCachedOrDb(KEY_MAINTENANCE_MODE, "false");
        return Boolean.parseBoolean(raw);
    }

    @Override
    public String getMaintenanceMessage() {
        String raw = getCachedOrDb(KEY_MAINTENANCE_MESSAGE, DEFAULT_MAINTENANCE_MESSAGE);
        return (raw == null || raw.isBlank()) ? DEFAULT_MAINTENANCE_MESSAGE : raw;
    }

    @Override
    public int getMaxImageSizeMb() {
        try {
            int val = Integer.parseInt(getCachedOrDb(KEY_MEDIA_MAX_IMAGE_MB, "2"));
            return Math.min(5, Math.max(1, val));
        } catch (NumberFormatException ex) {
            return 2;
        }
    }

    @Override
    public int getModerationAutoHideThreshold() {
        try {
            int val = Integer.parseInt(getCachedOrDb(KEY_MODERATION_AUTO_HIDE, "5"));
            return Math.min(50, Math.max(1, val));
        } catch (NumberFormatException ex) {
            return 5;
        }
    }

    @Override
    public double getGeoConfidenceThreshold() {
        try {
            double val = Double.parseDouble(getCachedOrDb(KEY_GEO_CONFIDENCE, "0.85"));
            return Math.min(1.0, Math.max(0.5, val));
        } catch (NumberFormatException ex) {
            return 0.85;
        }
    }

    private String getCachedOrDb(String key, String fallback) {
        String val = cache.get(key);
        if (val != null) {
            return val;
        }
        return settingRepository.findById(key)
                .map(s -> {
                    cache.put(key, s.getSettingValue());
                    return s.getSettingValue();
                })
                .orElse(fallback);
    }

    private String validateAndNormalizeValue(String key, String rawValue) {
        String trimmed = rawValue == null ? "" : rawValue.trim();
        return switch (key) {
            case KEY_MODERATION_AUTO_HIDE -> {
                int parsed = parseIntStrict(trimmed, "Ngưỡng ẩn tự động phải là số nguyên.");
                if (parsed < 1 || parsed > 50) {
                    throw new BadRequestException("Ngưỡng ẩn tự động phải nằm trong khoảng 1 đến 50.");
                }
                yield String.valueOf(parsed);
            }
            case KEY_GEO_CONFIDENCE -> {
                double parsed = parseDoubleStrict(trimmed, "Ngưỡng độ tin cậy địa lý phải là số thập phân.");
                if (Double.isNaN(parsed) || parsed < 0.50 || parsed > 1.00) {
                    throw new BadRequestException("Ngưỡng độ tin cậy địa lý phải nằm trong khoảng 0.50 đến 1.00.");
                }
                yield String.valueOf(parsed);
            }
            case KEY_MEDIA_MAX_IMAGE_MB -> {
                int parsed = parseIntStrict(trimmed, "Dung lượng ảnh tối đa phải là số nguyên (MB).");
                if (parsed < 1 || parsed > 5) {
                    throw new BadRequestException("Dung lượng ảnh tối đa phải nằm trong khoảng 1 đến 5 MB (giới hạn Servlet container là 5MB).");
                }
                yield String.valueOf(parsed);
            }
            case KEY_MAINTENANCE_MODE -> {
                if (!"true".equalsIgnoreCase(trimmed) && !"false".equalsIgnoreCase(trimmed)) {
                    throw new BadRequestException("Chế độ bảo trì chỉ chấp nhận giá trị true hoặc false.");
                }
                yield trimmed.toLowerCase();
            }
            case KEY_MAINTENANCE_MESSAGE -> {
                if (trimmed.isEmpty() || trimmed.length() > 255) {
                    throw new BadRequestException("Thông điệp bảo trì phải từ 1 đến 255 ký tự.");
                }
                yield trimmed;
            }
            default -> throw new BadRequestException("Khóa cấu hình không được hỗ trợ: " + key);
        };
    }

    private int parseIntStrict(String raw, String errMsg) {
        try {
            return Integer.parseInt(raw);
        } catch (NumberFormatException ex) {
            throw new BadRequestException(errMsg);
        }
    }

    private double parseDoubleStrict(String raw, String errMsg) {
        try {
            return Double.parseDouble(raw);
        } catch (NumberFormatException ex) {
            throw new BadRequestException(errMsg);
        }
    }
}

package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.AuditLogDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.AuditLogResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AuditLog;
import Travel_Planner.Travel_Planner.model.enums.AuditActionType;
import Travel_Planner.Travel_Planner.model.enums.AuditPolicy;
import Travel_Planner.Travel_Planner.model.enums.AuditResultStatus;
import Travel_Planner.Travel_Planner.model.enums.AuditTargetType;
import Travel_Planner.Travel_Planner.repository.AuditLogRepository;
import Travel_Planner.Travel_Planner.service.AdminAuditLogService;
import Travel_Planner.Travel_Planner.util.DataMaskingUtil;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class AdminAuditLogServiceImpl implements AdminAuditLogService {

    public static final int MAX_PAGE_SIZE = 100;

    private final AuditLogRepository auditLogRepository;
    private final DataMaskingUtil dataMaskingUtil;

    public AdminAuditLogServiceImpl(
            AuditLogRepository auditLogRepository,
            DataMaskingUtil dataMaskingUtil) {
        this.auditLogRepository = auditLogRepository;
        this.dataMaskingUtil = dataMaskingUtil;
    }

    @Override
    public PageResponse<AuditLogResponse> getAuditLogs(
            String keyword,
            Integer actorId,
            String actorUsername,
            AuditActionType actionType,
            AuditTargetType targetType,
            String targetId,
            AuditResultStatus resultStatus,
            String fromDate,
            String toDate,
            int page,
            int size) {

        if (page < 0) {
            throw new BadRequestException("Số trang (page) phải lớn hơn hoặc bằng 0.");
        }
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new BadRequestException("Kích thước trang (size) phải từ 1 đến " + MAX_PAGE_SIZE + ".");
        }

        LocalDateTime parsedFrom = parseDateBoundary(fromDate, true);
        LocalDateTime parsedTo = parseDateBoundary(toDate, false);
        if (parsedFrom != null && parsedTo != null && parsedFrom.isAfter(parsedTo)) {
            throw new BadRequestException("Khoảng thời gian không hợp lệ: ngày bắt đầu phải nhỏ hơn hoặc bằng ngày kết thúc.");
        }

        String normalizedKeyword = normalizeBlank(keyword);
        String normalizedActorUsername = normalizeBlank(actorUsername);
        String normalizedTargetId = normalizeBlank(targetId);

        PageRequest pageable = PageRequest.of(page, size, AuditLogRepository.stableAuditSort());
        Page<AuditLog> resultPage = auditLogRepository.searchAuditLogs(
                normalizedKeyword,
                actorId,
                normalizedActorUsername,
                actionType,
                targetType,
                normalizedTargetId,
                resultStatus,
                parsedFrom,
                parsedTo,
                pageable);

        List<AuditLogResponse> content = resultPage.getContent().stream()
                .map(AuditLogResponse::fromEntity)
                .toList();

        return PageResponse.<AuditLogResponse>builder()
                .content(content)
                .pageNumber(resultPage.getNumber())
                .pageSize(resultPage.getSize())
                .totalElements(resultPage.getTotalElements())
                .totalPages(resultPage.getTotalPages())
                .last(resultPage.isLast())
                .build();
    }

    @Override
    public AuditLogDetailResponse getAuditLogById(Long logId) {
        AuditLog entity = auditLogRepository.findById(logId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy nhật ký kiểm toán với ID: " + logId));

        String maskedBefore = safeMaskSnapshot(entity.getBeforeDataJson());
        String maskedAfter = safeMaskSnapshot(entity.getAfterDataJson());
        return AuditLogDetailResponse.fromEntity(entity, maskedBefore, maskedAfter);
    }

    @Override
    public List<String> getActionTypes() {
        return Arrays.stream(AuditActionType.values())
                .filter(a -> a.getPolicy() == AuditPolicy.STRICT)
                .map(Enum::name)
                .toList();
    }

    private String safeMaskSnapshot(String rawJson) {
        if (rawJson == null || rawJson.isBlank()) {
            return null;
        }
        try {
            return dataMaskingUtil.maskJsonString(rawJson);
        } catch (IllegalArgumentException ex) {
            return DataMaskingUtil.MASKED_VALUE;
        }
    }

    private String normalizeBlank(String input) {
        if (input == null) {
            return null;
        }
        String trimmed = input.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }

    private LocalDateTime parseDateBoundary(String raw, boolean startOfDay) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        String trimmed = raw.trim();
        try {
            return LocalDateTime.parse(trimmed);
        } catch (DateTimeParseException ignored) {
            try {
                LocalDate date = LocalDate.parse(trimmed);
                return startOfDay ? date.atStartOfDay() : date.atTime(LocalTime.MAX);
            } catch (DateTimeParseException ex) {
                throw new BadRequestException("Định dạng thời gian không hợp lệ: " + trimmed);
            }
        }
    }
}

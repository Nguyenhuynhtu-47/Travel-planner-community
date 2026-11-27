package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.audit.AuditCommand;
import Travel_Planner.Travel_Planner.dto.audit.ItineraryAuditSnapshot;
import Travel_Planner.Travel_Planner.dto.request.ModerateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.AdminItineraryService;
import Travel_Planner.Travel_Planner.service.AuditLogService;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;

@Service
public class AdminItineraryServiceImpl implements AdminItineraryService {

    private final ItineraryRepository itineraryRepository;
    private final ItineraryDayRepository itineraryDayRepository;
    private final ActivityRepository activityRepository;
    private final PostReportRepository postReportRepository;
    private final UserRepository userRepository;
    private final AuditLogService auditLogService;
    private final SocialNotificationService socialNotifications;

    public AdminItineraryServiceImpl(
            ItineraryRepository itineraryRepository,
            ItineraryDayRepository itineraryDayRepository,
            ActivityRepository activityRepository,
            PostReportRepository postReportRepository,
            UserRepository userRepository,
            AuditLogService auditLogService,
            SocialNotificationService socialNotifications) {
        this.itineraryRepository = itineraryRepository;
        this.itineraryDayRepository = itineraryDayRepository;
        this.activityRepository = activityRepository;
        this.postReportRepository = postReportRepository;
        this.userRepository = userRepository;
        this.auditLogService = auditLogService;
        this.socialNotifications = socialNotifications;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ItineraryAdminResponse> getAdminItineraries(
            String keyword,
            ItineraryStatus status,
            Visibility visibility,
            int page,
            int size,
            String sort) {
        if (page < 0 || size < 1) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ.");
        }
        if (visibility == Visibility.PRIVATE) {
            throw new AccessDeniedException("Không được phép duyệt danh sách tự do đối với lịch trình PRIVATE.");
        }

        int cappedSize = Math.min(size, 50);
        Pageable pageable = PageRequest.of(page, cappedSize, resolveSort(sort));

        Specification<Itinerary> spec = (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("visibility"), Visibility.PUBLIC));

            if (status != null) {
                predicates.add(cb.equal(root.get("status"), status));
            } else {
                predicates.add(root.get("status").in(ItineraryStatus.ACTIVE, ItineraryStatus.HIDDEN));
            }

            if (keyword != null && !keyword.trim().isEmpty()) {
                String escaped = escapeLike(keyword.trim().toLowerCase(Locale.ROOT));
                String pattern = "%" + escaped + "%";
                Join<Itinerary, User> creatorJoin = root.join("user", JoinType.LEFT);
                Predicate byTitle = cb.like(cb.lower(root.get("title")), pattern, '!');
                Predicate byLocation = cb.like(cb.lower(root.get("location")), pattern, '!');
                Predicate byTheme = cb.like(cb.lower(cb.coalesce(root.get("theme"), "")), pattern, '!');
                Predicate byUsername = cb.like(cb.lower(cb.coalesce(creatorJoin.get("username"), "")), pattern, '!');
                Predicate byHandle = cb.like(cb.lower(cb.coalesce(creatorJoin.get("handle"), "")), pattern, '!');
                Predicate byFullName = cb.like(cb.lower(cb.coalesce(creatorJoin.get("fullName"), "")), pattern, '!');
                predicates.add(cb.or(byTitle, byLocation, byTheme, byUsername, byHandle, byFullName));
            }

            return cb.and(predicates.toArray(new Predicate[0]));
        };

        Page<ItineraryAdminResponse> mapped = itineraryRepository.findAll(spec, pageable)
                .map(ItineraryAdminResponse::from);
        return PageResponse.from(mapped);
    }

    /**
     * Read-only inspector for both PUBLIC and reported PRIVATE itineraries.
     * Note: intentionally NOT marked readOnly = true because inspecting a PRIVATE itinerary
     * MUST persist a mandatory Strict Audit record in the same transaction before returning payload.
     */
    @Override
    @Transactional(propagation = Propagation.REQUIRED, isolation = Isolation.READ_COMMITTED, readOnly = false)
    public ItineraryAdminDetailResponse getAdminItineraryById(
            Integer itineraryId,
            Long reportId,
            String inspectionReason,
            String actorUsername) {
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ.");
        }

        User actor = reloadAndVerifyActiveAdmin(actorUsername);
        Itinerary itinerary = itineraryRepository.findByIdWithUser(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình."));

        boolean isPrivateInspection = itinerary.getVisibility() == Visibility.PRIVATE;
        if (isPrivateInspection) {
            validatePrivateInspectionContext(itinerary, reportId, inspectionReason);

            ItineraryAuditSnapshot snapshot = ItineraryAuditSnapshot.from(itinerary);
            Map<String, Object> inspectContext = new LinkedHashMap<>();
            inspectContext.put("itinerary", snapshot);
            inspectContext.put("reportId", reportId);
            inspectContext.put("visibility", Visibility.PRIVATE.name());

            auditLogService.logStrictAction(AuditCommand.builder()
                    .actionType(AuditActionType.ITINERARY_PRIVATE_INSPECT)
                    .targetType(AuditTargetType.ITINERARY)
                    .targetId(String.valueOf(itineraryId))
                    .reason(inspectionReason.trim())
                    .beforeSnapshot(snapshot)
                    .afterSnapshot(inspectContext)
                    .resultStatus(AuditResultStatus.SUCCESS)
                    .expectedActorUsername(actor.getUsername())
                    .build());
        }

        return buildReadOnlyDetailResponse(itinerary, isPrivateInspection, isPrivateInspection ? reportId : null);
    }

    @Override
    @Transactional(propagation = Propagation.REQUIRED, isolation = Isolation.READ_COMMITTED, readOnly = false)
    public ItineraryAdminResponse moderateItinerary(
            Integer itineraryId,
            ModerateItineraryRequest request,
            String actorUsername) {
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ.");
        }
        if (request == null || (request.getStatus() != ItineraryStatus.ACTIVE && request.getStatus() != ItineraryStatus.HIDDEN)) {
            throw new BadRequestException("Trạng thái kiểm duyệt hợp lệ chỉ có thể là ACTIVE hoặc HIDDEN.");
        }
        String trimmedReason = request.getReason() != null ? request.getReason().trim() : "";
        if (trimmedReason.length() < 3 || trimmedReason.length() > 255) {
            throw new BadRequestException("Lý do kiểm duyệt phải từ 3 đến 255 ký tự.");
        }

        User actor = reloadAndVerifyActiveAdmin(actorUsername);
        Itinerary itinerary = itineraryRepository.findByIdWithUser(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lịch trình."));

        if (itinerary.getStatus() == ItineraryStatus.DELETED) {
            throw new BadRequestException("Không thể kiểm duyệt lịch trình đã bị xóa bởi người dùng.");
        }
        if (itinerary.getStatus() == request.getStatus()) {
            throw new BadRequestException("Lịch trình hiện đã ở trạng thái " + request.getStatus().name() + ".");
        }

        ItineraryStatus previousStatus = itinerary.getStatus();
        ItineraryAuditSnapshot beforeSnapshot = ItineraryAuditSnapshot.from(itinerary);

        itinerary.setStatus(request.getStatus());
        itinerary = itineraryRepository.saveAndFlush(itinerary);

        ItineraryAuditSnapshot afterSnapshot = ItineraryAuditSnapshot.from(itinerary);

        auditLogService.logStrictAction(AuditCommand.builder()
                .actionType(AuditActionType.ITINERARY_MODERATE)
                .targetType(AuditTargetType.ITINERARY)
                .targetId(String.valueOf(itineraryId))
                .reason(trimmedReason)
                .beforeSnapshot(beforeSnapshot)
                .afterSnapshot(afterSnapshot)
                .resultStatus(AuditResultStatus.SUCCESS)
                .expectedActorUsername(actor.getUsername())
                .build());

        socialNotifications.itineraryModerationTransition(
                itinerary, actor, previousStatus, itinerary.getStatus(), trimmedReason);

        return ItineraryAdminResponse.from(itinerary);
    }

    private void validatePrivateInspectionContext(Itinerary itinerary, Long reportId, String inspectionReason) {
        if (reportId == null) {
            throw new AccessDeniedException("Không thể truy cập trực tiếp lịch trình PRIVATE nếu thiếu reportId hợp lệ.");
        }
        String trimmedReason = inspectionReason != null ? inspectionReason.trim() : "";
        if (trimmedReason.length() < 10 || trimmedReason.length() > 255) {
            throw new BadRequestException("Lý do kiểm tra lịch trình PRIVATE phải từ 10 đến 255 ký tự.");
        }

        PostReport report = postReportRepository.findById(reportId)
                .orElseThrow(() -> new AccessDeniedException("Báo cáo vi phạm không tồn tại."));

        if (report.getStatus() != ReportStatus.PENDING) {
            throw new AccessDeniedException("Chỉ được phép kiểm tra lịch trình PRIVATE khi báo cáo đang ở trạng thái PENDING.");
        }

        Post reportedPost = report.getPost();
        Itinerary linkedItinerary = reportedPost != null ? reportedPost.getItinerary() : null;
        if (linkedItinerary == null || !linkedItinerary.getItineraryId().equals(itinerary.getItineraryId())) {
            throw new AccessDeniedException("Báo cáo không liên kết với lịch trình PRIVATE cần kiểm tra.");
        }
    }

    private User reloadAndVerifyActiveAdmin(String actorUsername) {
        if (actorUsername == null || actorUsername.isBlank()) {
            throw new AccessDeniedException("Không xác định được quản trị viên thực hiện thao tác.");
        }
        User actor = userRepository.findByUsername(actorUsername)
                .orElseThrow(() -> new AccessDeniedException("Tài khoản quản trị viên không tồn tại."));
        if (actor.getRole() != Role.ADMIN || actor.getStatus() != UserStatus.ACTIVE) {
            throw new AccessDeniedException("Tài khoản không còn quyền Quản trị viên đang hoạt động.");
        }
        return actor;
    }

    private ItineraryAdminDetailResponse buildReadOnlyDetailResponse(
            Itinerary itinerary,
            boolean privateInspection,
            Long inspectedReportId) {
        List<ItineraryDay> days = itineraryDayRepository
                .findByItinerary_ItineraryIdOrderByDayNumberAsc(itinerary.getItineraryId());
        List<Integer> dayIds = days.stream().map(ItineraryDay::getDayId).toList();

        Map<Integer, List<Activity>> activityMap = new HashMap<>();
        if (!dayIds.isEmpty()) {
            List<Activity> activities = activityRepository.findByItineraryDay_DayIdInOrderByDisplayOrderAsc(dayIds);
            for (Activity activity : activities) {
                activityMap.computeIfAbsent(activity.getItineraryDay().getDayId(), k -> new ArrayList<>())
                        .add(activity);
            }
        }

        List<ItineraryDayResponse> dayResponses = days.stream()
                .map(day -> {
                    List<Activity> dayActivities = activityMap.getOrDefault(day.getDayId(), Collections.emptyList());
                    List<ActivityResponse> activityResponses = dayActivities.stream()
                            .map(this::mapActivityReadOnly)
                            .toList();
                    return ItineraryDayResponse.builder()
                            .dayId(day.getDayId())
                            .dayNumber(day.getDayNumber())
                            .title(day.getTitle())
                            .date(day.getDate())
                            .activities(activityResponses)
                            .build();
                })
                .toList();

        CreatorSummaryResponse creatorDto = null;
        User owner = itinerary.getUser();
        if (owner != null) {
            creatorDto = CreatorSummaryResponse.builder()
                    .userId(owner.getUserId())
                    .username(owner.getUsername())
                    .handle(owner.getHandle())
                    .fullName(owner.getFullName())
                    .avatar(owner.getAvatar())
                    .build();
        }

        return ItineraryAdminDetailResponse.builder()
                .itineraryId(itinerary.getItineraryId())
                .title(itinerary.getTitle())
                .description(itinerary.getDescription())
                .location(itinerary.getLocation())
                .coverImage(itinerary.getCoverImage())
                .totalDays(itinerary.getTotalDays())
                .budget(itinerary.getBudget())
                .theme(itinerary.getTheme())
                .visibility(itinerary.getVisibility() != null ? itinerary.getVisibility().name() : null)
                .status(itinerary.getStatus() != null ? itinerary.getStatus().name() : null)
                .viewCount(itinerary.getViewCount())
                .favoriteCount(itinerary.getFavoriteCount())
                .ratingCount(itinerary.getRatingCount())
                .commentCount(itinerary.getCommentCount())
                .reuseCount(itinerary.getReuseCount())
                .createdAt(itinerary.getCreatedAt())
                .updatedAt(itinerary.getUpdatedAt())
                .creator(creatorDto)
                .days(dayResponses)
                .privateInspection(privateInspection)
                .inspectedReportId(inspectedReportId)
                .build();
    }

    private ActivityResponse mapActivityReadOnly(Activity activity) {
        Long canonicalPlaceId = null;
        PlaceResponse placeResponse = null;
        if (activity.getPlace() != null) {
            Place p = activity.getPlace();
            canonicalPlaceId = p.getPlaceId();
            placeResponse = PlaceResponse.builder()
                    .placeId(p.getPlaceId())
                    .name(p.getName())
                    .address(p.getAddress())
                    .description(p.getDescription())
                    .imageUrl(p.getImageUrl())
                    .latitude(p.getLatitude())
                    .longitude(p.getLongitude())
                    .category(p.getCategory())
                    .status(p.getStatus())
                    .build();
        }

        String effectiveName = activity.getLocationName() != null
                ? activity.getLocationName()
                : activity.getCustomLocationName();
        String effectiveAddress = activity.getLocationAddress() != null
                ? activity.getLocationAddress()
                : activity.getCustomAddress();

        return ActivityResponse.builder()
                .activityId(activity.getActivityId())
                .name(activity.getName())
                .description(activity.getDescription())
                .startTime(activity.getStartTime())
                .endTime(activity.getEndTime())
                .cost(activity.getCost())
                .displayOrder(activity.getDisplayOrder())
                .commentCount(null)
                .visited(false)
                .canonicalPlaceId(canonicalPlaceId)
                .place(placeResponse)
                .locationName(effectiveName)
                .locationAddress(effectiveAddress)
                .customLocationName(effectiveName)
                .customAddress(effectiveAddress)
                .latitude(activity.getLatitude())
                .longitude(activity.getLongitude())
                .placeId(activity.getPlaceId())
                .locationProvider(activity.getLocationProvider())
                .imageUrl(activity.getImageUrl())
                .build();
    }

    private Sort resolveSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
        }
        String[] parts = sort.split(",");
        String property = parts[0].trim();
        Sort.Direction direction = Sort.Direction.DESC;
        if (parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim())) {
            direction = Sort.Direction.ASC;
        }
        return switch (property) {
            case "totalDays" -> Sort.by(direction, "totalDays").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
            case "viewCount" -> Sort.by(direction, "viewCount").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
            case "favoriteCount" -> Sort.by(direction, "favoriteCount").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
            default -> Sort.by(direction, "createdAt").and(Sort.by(direction, "itineraryId"));
        };
    }

    private String escapeLike(String input) {
        return input
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
    }
}

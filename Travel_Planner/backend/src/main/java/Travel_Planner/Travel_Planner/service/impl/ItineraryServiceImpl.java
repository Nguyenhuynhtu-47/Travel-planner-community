package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.repository.specification.ItinerarySpecification;
import Travel_Planner.Travel_Planner.service.ItineraryService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;

@Service
public class ItineraryServiceImpl implements ItineraryService {

    private final ItineraryRepository itineraryRepository;
    private final RatingRepository ratingRepository;
    private final ItineraryDayRepository itineraryDayRepository;
    private final ActivityRepository activityRepository;
    private final UserRepository userRepository;
    private final DestinationRepository destinationRepository;

    public ItineraryServiceImpl(
            ItineraryRepository itineraryRepository,
            RatingRepository ratingRepository,
            ItineraryDayRepository itineraryDayRepository,
            ActivityRepository activityRepository,
            UserRepository userRepository,
            DestinationRepository destinationRepository
    ) {
        this.itineraryRepository = itineraryRepository;
        this.ratingRepository = ratingRepository;
        this.itineraryDayRepository = itineraryDayRepository;
        this.activityRepository = activityRepository;
        this.userRepository = userRepository;
        this.destinationRepository = destinationRepository;
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getPublicItineraries(
            String keyword,
            String location,
            String theme,
            BigDecimal minBudget,
            BigDecimal maxBudget,
            Integer minDays,
            Integer maxDays,
            Double minRating,
            int page,
            int size,
            String sort
    ) {
        validateFilters(minBudget, maxBudget, minDays, maxDays, minRating);

        int normalizedPage = Math.max(page, 0);
        int normalizedSize = (size <= 0) ? 10 : Math.min(size, 50);

        Sort sortObj = parseSort(sort);
        Pageable pageable = PageRequest.of(normalizedPage, normalizedSize, sortObj);

        Specification<Itinerary> spec = ItinerarySpecification.filter(
                keyword, location, theme, minBudget, maxBudget, minDays, maxDays, minRating
        );

        Page<Itinerary> itineraryPage = itineraryRepository.findAll(spec, pageable);

        List<Integer> ids = itineraryPage.getContent().stream()
                .map(Itinerary::getItineraryId)
                .toList();

        Map<Integer, Double> ratingMap = fetchAverageRatings(ids);

        List<ItinerarySummaryResponse> content = itineraryPage.getContent().stream()
                .map(item -> mapToSummaryResponse(item, ratingMap.getOrDefault(item.getItineraryId(), 0.0)))
                .toList();

        return PageResponse.<ItinerarySummaryResponse>builder()
                .content(content)
                .pageNumber(itineraryPage.getNumber())
                .pageSize(itineraryPage.getSize())
                .totalElements(itineraryPage.getTotalElements())
                .totalPages(itineraryPage.getTotalPages())
                .last(itineraryPage.isLast())
                .build();
    }

    private void validateFilters(BigDecimal minBudget, BigDecimal maxBudget, Integer minDays, Integer maxDays, Double minRating) {
        if (minBudget != null && minBudget.compareTo(BigDecimal.ZERO) < 0) {
            throw new BadRequestException("Ngân sách tối thiểu không được nhỏ hơn 0");
        }
        if (maxBudget != null && maxBudget.compareTo(BigDecimal.ZERO) < 0) {
            throw new BadRequestException("Ngân sách tối đa không được nhỏ hơn 0");
        }
        if (minBudget != null && maxBudget != null && minBudget.compareTo(maxBudget) > 0) {
            throw new BadRequestException("Ngân sách tối đa phải lớn hơn hoặc bằng ngân sách tối thiểu");
        }
        if (minDays != null && minDays < 1) {
            throw new BadRequestException("Số ngày tối thiểu phải lớn hơn hoặc bằng 1");
        }
        if (maxDays != null && maxDays < 1) {
            throw new BadRequestException("Số ngày tối đa phải lớn hơn hoặc bằng 1");
        }
        if (minDays != null && maxDays != null && minDays > maxDays) {
            throw new BadRequestException("Số ngày tối đa phải lớn hơn hoặc bằng số ngày tối thiểu");
        }
        if (minRating != null && (minRating < 1.0 || minRating > 5.0)) {
            throw new BadRequestException("Điểm đánh giá tối thiểu phải từ 1.0 đến 5.0");
        }
    }

    private Sort parseSort(String sort) {
        if (sort == null || sort.isBlank()) {
            return Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
        }

        String[] parts = sort.split(",");
        String property = parts[0].trim();
        Sort.Direction direction = Sort.Direction.DESC;

        if (parts.length > 1 && parts[1].trim().equalsIgnoreCase("asc")) {
            direction = Sort.Direction.ASC;
        }

        return switch (property) {
            case "createdAt" -> Sort.by(direction, "createdAt").and(Sort.by(direction, "itineraryId"));
            case "budget" -> Sort.by(direction, "budget").and(Sort.by(Sort.Direction.DESC, "createdAt")).and(Sort.by(direction, "itineraryId"));
            case "totalDays" -> Sort.by(direction, "totalDays").and(Sort.by(Sort.Direction.DESC, "createdAt")).and(Sort.by(direction, "itineraryId"));
            case "viewCount" -> Sort.by(direction, "viewCount").and(Sort.by(Sort.Direction.DESC, "createdAt")).and(Sort.by(direction, "itineraryId"));
            case "favoriteCount" -> Sort.by(direction, "favoriteCount").and(Sort.by(Sort.Direction.DESC, "createdAt")).and(Sort.by(direction, "itineraryId"));
            case "rating", "ratingCount" -> Sort.by(direction, "ratingCount").and(Sort.by(Sort.Direction.DESC, "createdAt")).and(Sort.by(direction, "itineraryId"));
            default -> Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
        };
    }

    private Map<Integer, Double> fetchAverageRatings(List<Integer> itineraryIds) {
        Map<Integer, Double> ratingMap = new HashMap<>();
        if (itineraryIds == null || itineraryIds.isEmpty()) {
            return ratingMap;
        }

        List<Object[]> rows = ratingRepository.findAverageRatingsByItineraryIds(itineraryIds);
        for (Object[] row : rows) {
            if (row != null && row.length >= 2 && row[0] != null && row[1] != null) {
                Integer id = (Integer) row[0];
                double avg = ((Number) row[1]).doubleValue();
                double rounded = Math.round(avg * 10.0) / 10.0;
                ratingMap.put(id, rounded);
            }
        }
        return ratingMap;
    }

    private ItinerarySummaryResponse mapToSummaryResponse(Itinerary item, Double averageRating) {
        CreatorSummaryResponse creator = null;
        if (item.getUser() != null) {
            creator = CreatorSummaryResponse.builder()
                    .userId(item.getUser().getUserId())
                    .username(item.getUser().getUsername())
                    .fullName(item.getUser().getFullName())
                    .avatar(item.getUser().getAvatar())
                    .build();
        }

        return ItinerarySummaryResponse.builder()
                .itineraryId(item.getItineraryId())
                .title(item.getTitle())
                .description(item.getDescription())
                .location(item.getLocation())
                .coverImage(item.getCoverImage())
                .totalDays(item.getTotalDays())
                .budget(item.getBudget())
                .theme(item.getTheme())
                .visibility(item.getVisibility() != null ? item.getVisibility().name() : "PUBLIC")
                .status(item.getStatus() != null ? item.getStatus().name() : "ACTIVE")
                .viewCount(item.getViewCount())
                .favoriteCount(item.getFavoriteCount())
                .ratingCount(item.getRatingCount())
                .averageRating(averageRating)
                .createdAt(item.getCreatedAt())
                .creator(creator)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public ItineraryDetailResponse getItineraryDetail(Integer id, String currentUsername) {
        if (id == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }

        Itinerary itinerary = itineraryRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));

        if (itinerary.getStatus() == ItineraryStatus.DELETED || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        boolean isOwner = currentUsername != null && currentUsername.equals(itinerary.getUser().getUsername());

        if (itinerary.getStatus() != ItineraryStatus.ACTIVE && !isOwner) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        if (itinerary.getVisibility() != Visibility.PUBLIC && !isOwner) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        Map<Integer, Double> ratingMap = fetchAverageRatings(List.of(itinerary.getItineraryId()));
        Double avgRating = ratingMap.getOrDefault(itinerary.getItineraryId(), 0.0);

        List<ItineraryDay> days = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(id);
        List<Integer> dayIds = days.stream().map(ItineraryDay::getDayId).toList();

        Map<Integer, List<Activity>> activityMap = new HashMap<>();
        if (!dayIds.isEmpty()) {
            List<Activity> activities = activityRepository.findByItineraryDay_DayIdInOrderByDisplayOrderAsc(dayIds);
            for (Activity activity : activities) {
                activityMap.computeIfAbsent(activity.getItineraryDay().getDayId(), k -> new ArrayList<>()).add(activity);
            }
        }

        List<ItineraryDayResponse> dayResponses = days.stream().map(day -> {
            List<Activity> dayActivities = activityMap.getOrDefault(day.getDayId(), Collections.emptyList());
            List<ActivityResponse> activityResponses = dayActivities.stream().map(this::mapToActivityResponse).toList();
            return ItineraryDayResponse.builder()
                    .dayId(day.getDayId())
                    .dayNumber(day.getDayNumber())
                    .title(day.getTitle())
                    .date(day.getDate())
                    .activities(activityResponses)
                    .build();
        }).toList();

        CreatorSummaryResponse creator = null;
        if (itinerary.getUser() != null) {
            creator = CreatorSummaryResponse.builder()
                    .userId(itinerary.getUser().getUserId())
                    .username(itinerary.getUser().getUsername())
                    .fullName(itinerary.getUser().getFullName())
                    .avatar(itinerary.getUser().getAvatar())
                    .build();
        }

        return ItineraryDetailResponse.builder()
                .itineraryId(itinerary.getItineraryId())
                .title(itinerary.getTitle())
                .description(itinerary.getDescription())
                .location(itinerary.getLocation())
                .coverImage(itinerary.getCoverImage())
                .totalDays(itinerary.getTotalDays())
                .budget(itinerary.getBudget())
                .theme(itinerary.getTheme())
                .visibility(itinerary.getVisibility().name())
                .status(itinerary.getStatus() != null ? itinerary.getStatus().name() : "ACTIVE")
                .viewCount(itinerary.getViewCount())
                .favoriteCount(itinerary.getFavoriteCount())
                .ratingCount(itinerary.getRatingCount())
                .commentCount(itinerary.getCommentCount())
                .reuseCount(itinerary.getReuseCount())
                .averageRating(avgRating)
                .createdAt(itinerary.getCreatedAt())
                .updatedAt(itinerary.getUpdatedAt())
                .creator(creator)
                .days(dayResponses)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getMyItineraries(
            String currentUsername,
            String status,
            String visibility,
            int page,
            int size,
            String sort
    ) {
        if (currentUsername == null || currentUsername.isBlank()) {
            throw new UnauthorizedException("Vui lòng đăng nhập để xem danh sách lịch trình");
        }

        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Người dùng không tồn tại"));

        int normalizedPage = Math.max(page, 0);
        int normalizedSize = (size <= 0) ? 10 : Math.min(size, 50);
        Sort sortObj = parseSort(sort);
        Pageable pageable = PageRequest.of(normalizedPage, normalizedSize, sortObj);

        Specification<Itinerary> spec = (root, query, cb) -> {
            List<jakarta.persistence.criteria.Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("user").get("userId"), user.getUserId()));

            if (status != null && !status.isBlank() && !"ALL".equalsIgnoreCase(status)) {
                try {
                    ItineraryStatus st = ItineraryStatus.valueOf(status.toUpperCase());
                    predicates.add(cb.equal(root.get("status"), st));
                } catch (IllegalArgumentException e) {
                    throw new BadRequestException("Trạng thái không hợp lệ: " + status);
                }
            } else {
                // By default, exclude DELETED itineraries
                predicates.add(cb.notEqual(root.get("status"), ItineraryStatus.DELETED));
            }

            if (visibility != null && !visibility.isBlank() && !"ALL".equalsIgnoreCase(visibility)) {
                try {
                    Visibility vis = Visibility.valueOf(visibility.toUpperCase());
                    predicates.add(cb.equal(root.get("visibility"), vis));
                } catch (IllegalArgumentException e) {
                    throw new BadRequestException("Quyền riêng tư không hợp lệ: " + visibility);
                }
            }

            return cb.and(predicates.toArray(new jakarta.persistence.criteria.Predicate[0]));
        };

        Page<Itinerary> itineraryPage = itineraryRepository.findAll(spec, pageable);
        List<Integer> ids = itineraryPage.getContent().stream().map(Itinerary::getItineraryId).toList();
        Map<Integer, Double> ratingMap = fetchAverageRatings(ids);

        List<ItinerarySummaryResponse> content = itineraryPage.getContent().stream()
                .map(item -> mapToSummaryResponse(item, ratingMap.getOrDefault(item.getItineraryId(), 0.0)))
                .toList();

        return PageResponse.<ItinerarySummaryResponse>builder()
                .content(content)
                .pageNumber(itineraryPage.getNumber())
                .pageSize(itineraryPage.getSize())
                .totalElements(itineraryPage.getTotalElements())
                .totalPages(itineraryPage.getTotalPages())
                .last(itineraryPage.isLast())
                .build();
    }

    @Override
    @Transactional
    public ItineraryDetailResponse createItinerary(CreateItineraryRequest request, String currentUsername) {
        if (currentUsername == null || currentUsername.isBlank()) {
            throw new UnauthorizedException("Vui lòng đăng nhập để tạo lịch trình");
        }

        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Người dùng không tồn tại"));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đã bị khóa hoặc không hoạt động");
        }

        Visibility visibility = request.getVisibility() != null ? request.getVisibility() : Visibility.PRIVATE;

        Itinerary itinerary = Itinerary.builder()
                .user(user)
                .title(request.getTitle().trim())
                .description(request.getDescription() != null ? request.getDescription().trim() : null)
                .location(request.getLocation().trim())
                .coverImage(request.getCoverImage() != null && !request.getCoverImage().isBlank() ? request.getCoverImage().trim() : null)
                .totalDays(request.getTotalDays())
                .budget(request.getBudget())
                .theme(request.getTheme() != null ? request.getTheme().trim() : null)
                .visibility(visibility)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(0)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .build();

        itinerary = itineraryRepository.save(itinerary);

        List<ItineraryDay> days = new ArrayList<>();
        for (int i = 1; i <= request.getTotalDays(); i++) {
            ItineraryDay day = ItineraryDay.builder()
                    .itinerary(itinerary)
                    .dayNumber(i)
                    .title("Ngày " + i)
                    .date(null)
                    .build();
            days.add(itineraryDayRepository.save(day));
        }

        List<ItineraryDayResponse> dayResponses = days.stream()
                .map(day -> ItineraryDayResponse.builder()
                        .dayId(day.getDayId())
                        .dayNumber(day.getDayNumber())
                        .title(day.getTitle())
                        .date(day.getDate())
                        .activities(Collections.emptyList())
                        .build())
                .toList();

        CreatorSummaryResponse creator = CreatorSummaryResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .fullName(user.getFullName())
                .avatar(user.getAvatar())
                .build();

        return ItineraryDetailResponse.builder()
                .itineraryId(itinerary.getItineraryId())
                .title(itinerary.getTitle())
                .description(itinerary.getDescription())
                .location(itinerary.getLocation())
                .coverImage(itinerary.getCoverImage())
                .totalDays(itinerary.getTotalDays())
                .budget(itinerary.getBudget())
                .theme(itinerary.getTheme())
                .visibility(itinerary.getVisibility().name())
                .viewCount(0)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .averageRating(0.0)
                .createdAt(itinerary.getCreatedAt())
                .updatedAt(itinerary.getUpdatedAt())
                .creator(creator)
                .days(dayResponses)
                .build();
    }

    @Override
    @Transactional
    public ItineraryDetailResponse updateItinerary(Integer id, UpdateItineraryRequest request, String currentUsername) {
        if (id == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }
        Itinerary itinerary = findOwnedItinerary(id, currentUsername, "chỉnh sửa");

        itinerary.setTitle(request.getTitle().trim());
        itinerary.setDescription(request.getDescription() != null ? request.getDescription().trim() : null);
        itinerary.setLocation(request.getLocation().trim());
        itinerary.setCoverImage(request.getCoverImage() != null && !request.getCoverImage().isBlank() ? request.getCoverImage().trim() : null);
        itinerary.setBudget(request.getBudget());
        itinerary.setTheme(request.getTheme() != null ? request.getTheme().trim() : null);
        if (request.getVisibility() != null) {
            itinerary.setVisibility(request.getVisibility());
        }

        itineraryRepository.save(itinerary);
        return getItineraryDetail(id, currentUsername);
    }

    @Override
    @Transactional
    public void deleteItinerary(Integer id, String currentUsername) {
        if (id == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }
        Itinerary itinerary = findOwnedItinerary(id, currentUsername, "xóa");
        itinerary.setStatus(ItineraryStatus.DELETED);
        itineraryRepository.save(itinerary);
    }

    @Override
    @Transactional
    public ItineraryDayResponse addDay(Integer itineraryId, CreateDayRequest request, String currentUsername) {
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }
        Itinerary itinerary = findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        List<ItineraryDay> existingDays = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(itineraryId);
        int nextDayNumber = existingDays.isEmpty() ? 1 : existingDays.get(existingDays.size() - 1).getDayNumber() + 1;

        String title = (request != null && request.getTitle() != null && !request.getTitle().isBlank())
                ? request.getTitle().trim()
                : "Ngày " + nextDayNumber;
        LocalDate date = request != null ? request.getDate() : null;

        ItineraryDay newDay = ItineraryDay.builder()
                .itinerary(itinerary)
                .dayNumber(nextDayNumber)
                .title(title)
                .date(date)
                .build();
        newDay = itineraryDayRepository.save(newDay);

        itinerary.setTotalDays(itinerary.getTotalDays() + 1);
        itineraryRepository.save(itinerary);

        return ItineraryDayResponse.builder()
                .dayId(newDay.getDayId())
                .dayNumber(newDay.getDayNumber())
                .title(newDay.getTitle())
                .date(newDay.getDate())
                .activities(Collections.emptyList())
                .build();
    }

    @Override
    @Transactional
    public ItineraryDayResponse updateDay(Integer itineraryId, Integer dayId, UpdateDayRequest request, String currentUsername) {
        if (itineraryId == null || dayId == null) {
            throw new BadRequestException("Mã lịch trình hoặc mã ngày không hợp lệ");
        }
        findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        ItineraryDay day = itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        if (request != null) {
            if (request.getTitle() != null) {
                day.setTitle(request.getTitle().trim());
            }
            day.setDate(request.getDate());
        }
        day = itineraryDayRepository.save(day);

        List<Activity> activities = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);
        List<ActivityResponse> activityResponses = activities.stream().map(this::mapToActivityResponse).toList();

        return ItineraryDayResponse.builder()
                .dayId(day.getDayId())
                .dayNumber(day.getDayNumber())
                .title(day.getTitle())
                .date(day.getDate())
                .activities(activityResponses)
                .build();
    }

    @Override
    @Transactional
    public void deleteDay(Integer itineraryId, Integer dayId, String currentUsername) {
        if (itineraryId == null || dayId == null) {
            throw new BadRequestException("Mã lịch trình hoặc mã ngày không hợp lệ");
        }
        Itinerary itinerary = findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        ItineraryDay dayToDelete = itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        if (itinerary.getTotalDays() <= 1) {
            throw new BadRequestException("Lịch trình phải có ít nhất 1 ngày. Không thể xóa ngày cuối cùng");
        }

        int deletedDayNumber = dayToDelete.getDayNumber();

        // 1. Delete all activities belonging to this day first to respect foreign key constraint
        activityRepository.deleteByItineraryDay_DayId(dayId);

        // 2. Delete the day itself
        itineraryDayRepository.delete(dayToDelete);
        itineraryDayRepository.flush();

        // 3. Renumber subsequent days (dayNumber > deletedDayNumber)
        List<ItineraryDay> subsequentDays = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(itineraryId);
        for (ItineraryDay day : subsequentDays) {
            if (day.getDayNumber() > deletedDayNumber) {
                day.setDayNumber(day.getDayNumber() - 1);
                itineraryDayRepository.save(day);
            }
        }
        itineraryDayRepository.flush();

        // 4. Update itinerary totalDays
        itinerary.setTotalDays(itinerary.getTotalDays() - 1);
        itineraryRepository.save(itinerary);
    }

    @Override
    @Transactional
    public ActivityResponse addActivity(Integer itineraryId, Integer dayId, CreateActivityRequest request, String currentUsername) {
        if (itineraryId == null || dayId == null) {
            throw new BadRequestException("Mã lịch trình hoặc mã ngày không hợp lệ");
        }
        findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        ItineraryDay day = itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        validateTimes(request.getStartTime(), request.getEndTime());

        Destination destination = null;
        if (request.getDestinationId() != null) {
            destination = destinationRepository.findById(request.getDestinationId())
                    .orElseThrow(() -> new ResourceNotFoundException("Địa điểm không tồn tại"));
            if (destination.getStatus() != DestinationStatus.ACTIVE) {
                throw new BadRequestException("Địa điểm này hiện không khả dụng");
            }
        }

        List<Activity> existing = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);
        int nextOrder = existing.isEmpty() ? 1 : existing.get(existing.size() - 1).getDisplayOrder() + 1;

        Activity activity = Activity.builder()
                .itineraryDay(day)
                .destination(destination)
                .name(request.getName().trim())
                .description(request.getDescription() != null ? request.getDescription().trim() : null)
                .startTime(request.getStartTime())
                .endTime(request.getEndTime())
                .cost(request.getCost() != null ? request.getCost() : BigDecimal.ZERO)
                .displayOrder(nextOrder)
                .build();

        activity = activityRepository.save(activity);
        return mapToActivityResponse(activity);
    }

    @Override
    @Transactional
    public ActivityResponse updateActivity(Integer itineraryId, Integer dayId, Integer activityId, UpdateActivityRequest request, String currentUsername) {
        if (itineraryId == null || dayId == null || activityId == null) {
            throw new BadRequestException("Mã lịch trình, ngày hoặc hoạt động không hợp lệ");
        }
        findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        Activity activity = activityRepository.findByActivityIdAndItineraryDay_DayId(activityId, dayId)
                .orElseThrow(() -> new ResourceNotFoundException("Hoạt động không tồn tại hoặc không thuộc ngày này"));

        validateTimes(request.getStartTime(), request.getEndTime());

        Destination destination = null;
        if (request.getDestinationId() != null) {
            destination = destinationRepository.findById(request.getDestinationId())
                    .orElseThrow(() -> new ResourceNotFoundException("Địa điểm không tồn tại"));
            if (destination.getStatus() != DestinationStatus.ACTIVE) {
                throw new BadRequestException("Địa điểm này hiện không khả dụng");
            }
        }

        activity.setName(request.getName().trim());
        activity.setDescription(request.getDescription() != null ? request.getDescription().trim() : null);
        activity.setDestination(destination);
        activity.setStartTime(request.getStartTime());
        activity.setEndTime(request.getEndTime());
        if (request.getCost() != null) {
            activity.setCost(request.getCost());
        }

        activity = activityRepository.save(activity);
        return mapToActivityResponse(activity);
    }

    @Override
    @Transactional
    public void deleteActivity(Integer itineraryId, Integer dayId, Integer activityId, String currentUsername) {
        if (itineraryId == null || dayId == null || activityId == null) {
            throw new BadRequestException("Mã lịch trình, ngày hoặc hoạt động không hợp lệ");
        }
        findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        Activity activity = activityRepository.findByActivityIdAndItineraryDay_DayId(activityId, dayId)
                .orElseThrow(() -> new ResourceNotFoundException("Hoạt động không tồn tại hoặc không thuộc ngày này"));

        int deletedOrder = activity.getDisplayOrder();
        activityRepository.delete(activity);
        activityRepository.flush();

        List<Activity> remaining = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);
        for (Activity act : remaining) {
            if (act.getDisplayOrder() > deletedOrder) {
                act.setDisplayOrder(act.getDisplayOrder() - 1);
                activityRepository.save(act);
            }
        }
        activityRepository.flush();
    }

    @Override
    @Transactional
    public List<ActivityResponse> reorderActivities(Integer itineraryId, Integer dayId, List<ReorderActivityItem> items, String currentUsername) {
        if (itineraryId == null || dayId == null) {
            throw new BadRequestException("Mã lịch trình hoặc mã ngày không hợp lệ");
        }
        if (items == null || items.isEmpty()) {
            throw new BadRequestException("Danh sách sắp xếp không được để trống");
        }
        findOwnedItinerary(itineraryId, currentUsername, "chỉnh sửa");

        itineraryDayRepository.findByDayIdAndItinerary_ItineraryId(dayId, itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Ngày không tồn tại hoặc không thuộc lịch trình này"));

        List<Activity> currentActivities = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);
        if (items.size() != currentActivities.size()) {
            throw new BadRequestException("Số lượng hoạt động sắp xếp (" + items.size() + ") không khớp với số hoạt động hiện có (" + currentActivities.size() + ")");
        }

        Map<Integer, Activity> activityMap = new HashMap<>();
        for (Activity act : currentActivities) {
            activityMap.put(act.getActivityId(), act);
        }

        Set<Integer> submittedIds = new HashSet<>();
        Set<Integer> submittedOrders = new HashSet<>();

        for (ReorderActivityItem item : items) {
            if (!activityMap.containsKey(item.getActivityId())) {
                throw new BadRequestException("Hoạt động ID " + item.getActivityId() + " không thuộc ngày này");
            }
            if (!submittedIds.add(item.getActivityId())) {
                throw new BadRequestException("Mã hoạt động bị trùng lặp: " + item.getActivityId());
            }
            if (item.getDisplayOrder() < 1 || item.getDisplayOrder() > currentActivities.size()) {
                throw new BadRequestException("Thứ tự hiển thị không hợp lệ: " + item.getDisplayOrder());
            }
            if (!submittedOrders.add(item.getDisplayOrder())) {
                throw new BadRequestException("Thứ tự hiển thị bị trùng lặp: " + item.getDisplayOrder());
            }
        }

        // Two-pass update to avoid unique constraint collisions on uk_activity_day_order (day_id, display_order)
        // Pass 1: Set temporary negative order values and flush
        for (ReorderActivityItem item : items) {
            Activity act = activityMap.get(item.getActivityId());
            act.setDisplayOrder(-1 * item.getDisplayOrder());
            activityRepository.save(act);
        }
        activityRepository.flush();

        // Pass 2: Set final positive order values and flush
        for (ReorderActivityItem item : items) {
            Activity act = activityMap.get(item.getActivityId());
            act.setDisplayOrder(item.getDisplayOrder());
            activityRepository.save(act);
        }
        activityRepository.flush();

        List<Activity> updated = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(dayId);
        return updated.stream().map(this::mapToActivityResponse).toList();
    }

    private Itinerary findOwnedItinerary(Integer itineraryId, String currentUsername, String action) {
        if (currentUsername == null || currentUsername.isBlank()) {
            throw new UnauthorizedException("Vui lòng đăng nhập để thực hiện hành động này");
        }

        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));

        if (itinerary.getStatus() == ItineraryStatus.DELETED) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        boolean isOwner = itinerary.getUser() != null && currentUsername.equals(itinerary.getUser().getUsername());
        if (!isOwner) {
            throw new ForbiddenException("Bạn không có quyền " + action + " lịch trình này");
        }

        return itinerary;
    }

    private void validateTimes(LocalTime startTime, LocalTime endTime) {
        if (startTime != null && endTime != null && endTime.isBefore(startTime)) {
            throw new BadRequestException("Thời gian kết thúc không thể trước thời gian bắt đầu");
        }
    }

    private ActivityResponse mapToActivityResponse(Activity activity) {
        DestinationResponse destinationResponse = null;
        if (activity.getDestination() != null) {
            Destination dest = activity.getDestination();
            destinationResponse = DestinationResponse.builder()
                    .destinationId(dest.getDestinationId())
                    .name(dest.getName())
                    .address(dest.getAddress())
                    .description(dest.getDescription())
                    .imageUrl(dest.getImageUrl())
                    .latitude(dest.getLatitude())
                    .longitude(dest.getLongitude())
                    .build();
        }

        return ActivityResponse.builder()
                .activityId(activity.getActivityId())
                .name(activity.getName())
                .description(activity.getDescription())
                .startTime(activity.getStartTime())
                .endTime(activity.getEndTime())
                .cost(activity.getCost())
                .displayOrder(activity.getDisplayOrder())
                .destination(destinationResponse)
                .build();
    }
}

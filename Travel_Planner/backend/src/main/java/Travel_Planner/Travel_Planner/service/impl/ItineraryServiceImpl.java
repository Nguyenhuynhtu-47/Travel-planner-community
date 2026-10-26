package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ActivityRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryDayRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
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
import java.util.*;

@Service
public class ItineraryServiceImpl implements ItineraryService {

    private final ItineraryRepository itineraryRepository;
    private final RatingRepository ratingRepository;
    private final ItineraryDayRepository itineraryDayRepository;
    private final ActivityRepository activityRepository;

    public ItineraryServiceImpl(
            ItineraryRepository itineraryRepository,
            RatingRepository ratingRepository,
            ItineraryDayRepository itineraryDayRepository,
            ActivityRepository activityRepository
    ) {
        this.itineraryRepository = itineraryRepository;
        this.ratingRepository = ratingRepository;
        this.itineraryDayRepository = itineraryDayRepository;
        this.activityRepository = activityRepository;
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

        int normalizedPage = Math.max(0, page);
        int normalizedSize = normalizePageSize(size);
        Sort parsedSort = parseSort(sort);

        Pageable pageable = PageRequest.of(normalizedPage, normalizedSize, parsedSort);
        Specification<Itinerary> spec = ItinerarySpecification.filter(
                keyword, location, theme, minBudget, maxBudget, minDays, maxDays, minRating
        );

        Page<Itinerary> itineraryPage = itineraryRepository.findAll(spec, pageable);

        if (itineraryPage.isEmpty()) {
            return PageResponse.<ItinerarySummaryResponse>builder()
                    .content(Collections.emptyList())
                    .pageNumber(itineraryPage.getNumber())
                    .pageSize(itineraryPage.getSize())
                    .totalElements(itineraryPage.getTotalElements())
                    .totalPages(itineraryPage.getTotalPages())
                    .last(itineraryPage.isLast())
                    .build();
        }

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

    private int normalizePageSize(int size) {
        if (size <= 0) {
            return 10;
        }
        return Math.min(size, 50);
    }

    private Sort parseSort(String sortParam) {
        if (sortParam == null || sortParam.isBlank()) {
            return Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "itineraryId"));
        }

        String[] parts = sortParam.split(",");
        String field = parts[0].trim();
        Sort.Direction direction = Sort.Direction.DESC;
        if (parts.length > 1 && "asc".equalsIgnoreCase(parts[1].trim())) {
            direction = Sort.Direction.ASC;
        }

        return switch (field) {
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

        if (itinerary.getStatus() != ItineraryStatus.ACTIVE || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }

        if (itinerary.getVisibility() != Visibility.PUBLIC) {
            boolean isOwner = currentUsername != null && currentUsername.equals(itinerary.getUser().getUsername());
            if (!isOwner) {
                throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
            }
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

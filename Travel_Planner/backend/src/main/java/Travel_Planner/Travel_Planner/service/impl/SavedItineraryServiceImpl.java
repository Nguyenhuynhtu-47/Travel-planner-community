package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.CreatorSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.SavedItineraryResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.SavedItinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.SavedItineraryRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.SavedItineraryService;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.util.*;

@Service
public class SavedItineraryServiceImpl implements SavedItineraryService {

    private final SavedItineraryRepository savedItineraryRepository;
    private final ItineraryRepository itineraryRepository;
    private final RatingRepository ratingRepository;
    private final UserRepository userRepository;
    private final TransactionTemplate transactionTemplate;

    public SavedItineraryServiceImpl(SavedItineraryRepository savedItineraryRepository,
                                     ItineraryRepository itineraryRepository,
                                     RatingRepository ratingRepository,
                                     UserRepository userRepository,
                                     PlatformTransactionManager transactionManager) {
        this.savedItineraryRepository = savedItineraryRepository;
        this.itineraryRepository = itineraryRepository;
        this.ratingRepository = ratingRepository;
        this.userRepository = userRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    @Override
    public SavedItineraryResponse saveItinerary(Integer itineraryId, String currentUsername) {
        if (currentUsername == null) {
            throw new UnauthorizedException("Phiên đăng nhập không hợp lệ");
        }

        try {
            return transactionTemplate.execute(status -> {
                User user = getAuthenticatedUser(currentUsername);
                Itinerary itinerary = validateAndGetItineraryForSave(itineraryId, user);

                Optional<SavedItinerary> existingOpt = savedItineraryRepository.findByUser_UserIdAndItinerary_ItineraryId(
                        user.getUserId(), itineraryId);

                if (existingOpt.isPresent()) {
                    SavedItinerary existing = existingOpt.get();
                    return SavedItineraryResponse.builder()
                            .saveId(existing.getSaveId())
                            .itineraryId(itineraryId)
                            .saved(true)
                            .savedAt(existing.getCreatedAt())
                            .newlyCreated(false)
                            .build();
                }

                SavedItinerary savedItinerary = SavedItinerary.builder()
                        .user(user)
                        .itinerary(itinerary)
                        .createdAt(LocalDateTime.now())
                        .build();

                SavedItinerary created = savedItineraryRepository.saveAndFlush(savedItinerary);

                return SavedItineraryResponse.builder()
                        .saveId(created.getSaveId())
                        .itineraryId(itineraryId)
                        .saved(true)
                        .savedAt(created.getCreatedAt())
                        .newlyCreated(true)
                        .build();
            });
        } catch (DataIntegrityViolationException dive) {
            // Concurrent duplicate insertion: return existing record
            return transactionTemplate.execute(status -> {
                User user = getAuthenticatedUser(currentUsername);
                SavedItinerary existing = savedItineraryRepository.findByUser_UserIdAndItinerary_ItineraryId(
                        user.getUserId(), itineraryId)
                        .orElseThrow(() -> dive);

                return SavedItineraryResponse.builder()
                        .saveId(existing.getSaveId())
                        .itineraryId(itineraryId)
                        .saved(true)
                        .savedAt(existing.getCreatedAt())
                        .newlyCreated(false)
                        .build();
            });
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public SavedItineraryResponse removeSavedItinerary(Integer itineraryId, String currentUsername) {
        User user = getAuthenticatedUser(currentUsername);
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }

        Optional<SavedItinerary> savedOpt = savedItineraryRepository.findByUser_UserIdAndItinerary_ItineraryId(
                user.getUserId(), itineraryId);

        if (savedOpt.isPresent()) {
            savedItineraryRepository.delete(savedOpt.get());
            savedItineraryRepository.flush();
        }

        return SavedItineraryResponse.builder()
                .saveId(null)
                .itineraryId(itineraryId)
                .saved(false)
                .savedAt(null)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getUserSavedItineraries(String currentUsername, int page, int size) {
        User user = getAuthenticatedUser(currentUsername);
        int safePage = Math.max(0, page);
        int safeSize = Math.min(Math.max(1, size), 50);
        Pageable pageable = PageRequest.of(safePage, safeSize);

        Page<Itinerary> itineraryPage = savedItineraryRepository.findActivePublicSavedItineraries(user.getUserId(), pageable);

        List<Integer> itineraryIds = itineraryPage.getContent().stream()
                .map(Itinerary::getItineraryId)
                .toList();

        Map<Integer, Double> ratingMap = fetchAverageRatings(itineraryIds);

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

    private Itinerary validateAndGetItineraryForSave(Integer itineraryId, User user) {
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));

        boolean isAuthor = itinerary.getUser() != null && itinerary.getUser().getUserId().equals(user.getUserId());

        if (isAuthor) {
            if (itinerary.getStatus() != ItineraryStatus.ACTIVE || itinerary.getVisibility() != Visibility.PUBLIC) {
                throw new BadRequestException("Chỉ có thể lưu các lịch trình đang ở trạng thái công khai (PUBLIC). Vui lòng công khai lịch trình trước khi lưu vào Bộ sưu tập.");
            }
        } else {
            if (itinerary.getStatus() != ItineraryStatus.ACTIVE
                    || itinerary.getVisibility() != Visibility.PUBLIC
                    || itinerary.getUser() == null
                    || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
                throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
            }
        }

        return itinerary;
    }

    private Map<Integer, Double> fetchAverageRatings(List<Integer> itineraryIds) {
        if (itineraryIds == null || itineraryIds.isEmpty()) {
            return Collections.emptyMap();
        }
        List<Object[]> rawList = ratingRepository.findAverageRatingsByItineraryIds(itineraryIds);
        Map<Integer, Double> ratingMap = new HashMap<>();
        for (Object[] row : rawList) {
            Integer id = (Integer) row[0];
            Double avg = (Double) row[1];
            ratingMap.put(id, avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0);
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

    private User getAuthenticatedUser(String currentUsername) {
        if (currentUsername == null) {
            throw new UnauthorizedException("Phiên đăng nhập không hợp lệ");
        }
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() == UserStatus.BANNED) {
            throw new ForbiddenException("Tài khoản của bạn đã bị khóa");
        }
        if (user.getStatus() == UserStatus.INACTIVE) {
            throw new ForbiddenException("Tài khoản chưa được kích hoạt");
        }
        return user;
    }
}

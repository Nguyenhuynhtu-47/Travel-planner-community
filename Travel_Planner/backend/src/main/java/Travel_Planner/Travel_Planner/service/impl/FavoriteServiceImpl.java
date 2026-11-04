package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.CreatorSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.FavoriteResponse;
import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.Favorite;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.FavoriteRepository;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.FavoriteService;
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
import java.util.stream.Collectors;

@Service
public class FavoriteServiceImpl implements FavoriteService {

    private final FavoriteRepository favoriteRepository;
    private final ItineraryRepository itineraryRepository;
    private final RatingRepository ratingRepository;
    private final UserRepository userRepository;
    private final TransactionTemplate transactionTemplate;

    public FavoriteServiceImpl(FavoriteRepository favoriteRepository,
                               ItineraryRepository itineraryRepository,
                               RatingRepository ratingRepository,
                               UserRepository userRepository,
                               PlatformTransactionManager transactionManager) {
        this.favoriteRepository = favoriteRepository;
        this.itineraryRepository = itineraryRepository;
        this.ratingRepository = ratingRepository;
        this.userRepository = userRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    @Override
    public FavoriteResponse addFavorite(Integer itineraryId, String currentUsername) {
        if (currentUsername == null) {
            throw new UnauthorizedException("Phiên đăng nhập không hợp lệ");
        }

        try {
            return transactionTemplate.execute(status -> {
                User user = getAuthenticatedUser(currentUsername);
                Itinerary itinerary = getPublicActiveItinerary(itineraryId);

                if (itinerary.getUser().getUserId().equals(user.getUserId())) {
                    throw new BadRequestException("Bạn không thể tự thêm lịch trình của mình vào danh sách yêu thích");
                }

                boolean alreadyFavorited = favoriteRepository.existsByUser_UserIdAndItinerary_ItineraryId(
                        user.getUserId(), itineraryId);

                if (alreadyFavorited) {
                    int count = itinerary.getFavoriteCount() != null ? itinerary.getFavoriteCount() : 0;
                    return FavoriteResponse.builder()
                            .itineraryId(itineraryId)
                            .favorited(true)
                            .favoriteCount(count)
                            .newlyCreated(false)
                            .build();
                }

                Favorite favorite = Favorite.builder()
                        .user(user)
                        .itinerary(itinerary)
                        .createdAt(LocalDateTime.now())
                        .build();

                favoriteRepository.saveAndFlush(favorite);
                itineraryRepository.incrementFavoriteCount(itineraryId);

                int count = (itinerary.getFavoriteCount() != null ? itinerary.getFavoriteCount() : 0) + 1;
                return FavoriteResponse.builder()
                        .itineraryId(itineraryId)
                        .favorited(true)
                        .favoriteCount(count)
                        .newlyCreated(true)
                        .build();
            });
        } catch (DataIntegrityViolationException dive) {
            // Concurrent duplicate insertion: return existing state without incrementing
            return transactionTemplate.execute(status -> {
                Itinerary itinerary = getPublicActiveItinerary(itineraryId);
                int count = itinerary.getFavoriteCount() != null ? itinerary.getFavoriteCount() : 0;
                return FavoriteResponse.builder()
                        .itineraryId(itineraryId)
                        .favorited(true)
                        .favoriteCount(count)
                        .newlyCreated(false)
                        .build();
            });
        }
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public FavoriteResponse removeFavorite(Integer itineraryId, String currentUsername) {
        User user = getAuthenticatedUser(currentUsername);
        Itinerary itinerary = getPublicActiveItinerary(itineraryId);

        Optional<Favorite> favOpt = favoriteRepository.findByUser_UserIdAndItinerary_ItineraryId(
                user.getUserId(), itineraryId);

        if (favOpt.isPresent()) {
            favoriteRepository.delete(favOpt.get());
            favoriteRepository.flush();

            itineraryRepository.decrementFavoriteCount(itineraryId);

            int currentCount = itinerary.getFavoriteCount() != null ? itinerary.getFavoriteCount() : 0;
            int newCount = Math.max(0, currentCount - 1);

            return FavoriteResponse.builder()
                    .itineraryId(itineraryId)
                    .favorited(false)
                    .favoriteCount(newCount)
                    .build();
        } else {
            // Idempotent: already not favorited
            int count = itinerary.getFavoriteCount() != null ? itinerary.getFavoriteCount() : 0;
            return FavoriteResponse.builder()
                    .itineraryId(itineraryId)
                    .favorited(false)
                    .favoriteCount(count)
                    .build();
        }
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getUserFavorites(String currentUsername, int page, int size) {
        User user = getAuthenticatedUser(currentUsername);
        int safePage = Math.max(0, page);
        int safeSize = Math.min(Math.max(1, size), 50);
        Pageable pageable = PageRequest.of(safePage, safeSize);

        Page<Itinerary> itineraryPage = favoriteRepository.findActivePublicFavoritedItineraries(user.getUserId(), pageable);

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

    private Itinerary getPublicActiveItinerary(Integer itineraryId) {
        if (itineraryId == null) {
            throw new BadRequestException("Mã lịch trình không hợp lệ");
        }
        Itinerary itinerary = itineraryRepository.findById(itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa"));
        if (itinerary.getStatus() != ItineraryStatus.ACTIVE
                || itinerary.getVisibility() != Visibility.PUBLIC
                || itinerary.getUser() == null
                || itinerary.getUser().getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Lịch trình không tồn tại hoặc đã bị xóa");
        }
        return itinerary;
    }
}

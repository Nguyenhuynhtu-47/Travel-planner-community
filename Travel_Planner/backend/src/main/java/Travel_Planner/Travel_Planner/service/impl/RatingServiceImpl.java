package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.RateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.DeleteRatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.UserRatingStatusResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.Itinerary;
import Travel_Planner.Travel_Planner.model.Rating;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.repository.ItineraryRepository;
import Travel_Planner.Travel_Planner.repository.RatingRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.RatingService;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
public class RatingServiceImpl implements RatingService {

    private final RatingRepository ratingRepository;
    private final ItineraryRepository itineraryRepository;
    private final UserRepository userRepository;
    private final TransactionTemplate transactionTemplate;

    public RatingServiceImpl(RatingRepository ratingRepository,
                             ItineraryRepository itineraryRepository,
                             UserRepository userRepository,
                             PlatformTransactionManager transactionManager) {
        this.ratingRepository = ratingRepository;
        this.itineraryRepository = itineraryRepository;
        this.userRepository = userRepository;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    @Override
    public RatingResponse rateItinerary(Integer itineraryId, RateItineraryRequest request, String currentUsername) {
        if (currentUsername == null) {
            throw new UnauthorizedException("Phiên đăng nhập không hợp lệ");
        }
        if (request == null || request.getScore() == null) {
            throw new BadRequestException("Điểm đánh giá không được để trống");
        }
        if (request.getScore() < 1 || request.getScore() > 5) {
            throw new BadRequestException("Điểm đánh giá phải từ 1 đến 5 sao");
        }

        try {
            return transactionTemplate.execute(status -> {
                User user = getAuthenticatedUser(currentUsername);
                Itinerary itinerary = getPublicActiveItinerary(itineraryId);

                if (itinerary.getUser().getUserId().equals(user.getUserId())) {
                    throw new BadRequestException("Bạn không thể tự đánh giá lịch trình của chính mình");
                }

                Optional<Rating> existingRatingOpt = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(
                        user.getUserId(), itineraryId);

                if (existingRatingOpt.isPresent()) {
                    Rating existingRating = existingRatingOpt.get();
                    existingRating.setScore(request.getScore());
                    existingRating.setUpdatedAt(LocalDateTime.now());
                    Rating saved = ratingRepository.saveAndFlush(existingRating);

                    Double avg = ratingRepository.findAverageRatingByItineraryId(itineraryId);
                    double roundedAvg = avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0;
                    long count = ratingRepository.countByItinerary_ItineraryId(itineraryId);

                    return RatingResponse.builder()
                            .ratingId(saved.getRatingId())
                            .itineraryId(itineraryId)
                            .score(saved.getScore())
                            .averageRating(roundedAvg)
                            .ratingCount((int) count)
                            .createdAt(saved.getCreatedAt())
                            .updatedAt(saved.getUpdatedAt())
                            .newlyCreated(false)
                            .build();
                } else {
                    Rating newRating = Rating.builder()
                            .user(user)
                            .itinerary(itinerary)
                            .score(request.getScore())
                            .createdAt(LocalDateTime.now())
                            .updatedAt(LocalDateTime.now())
                            .build();

                    Rating saved = ratingRepository.saveAndFlush(newRating);
                    itineraryRepository.incrementRatingCount(itineraryId);

                    Double avg = ratingRepository.findAverageRatingByItineraryId(itineraryId);
                    double roundedAvg = avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0;
                    long count = ratingRepository.countByItinerary_ItineraryId(itineraryId);

                    return RatingResponse.builder()
                            .ratingId(saved.getRatingId())
                            .itineraryId(itineraryId)
                            .score(saved.getScore())
                            .averageRating(roundedAvg)
                            .ratingCount((int) count)
                            .createdAt(saved.getCreatedAt())
                            .updatedAt(saved.getUpdatedAt())
                            .newlyCreated(true)
                            .build();
                }
            });
        } catch (DataIntegrityViolationException dive) {
            // Concurrent duplicate insertion: the failed inner transaction rolled back cleanly.
            // Fall back to updating the score in a clean transaction without incrementing ratingCount.
            return transactionTemplate.execute(status -> {
                User user = getAuthenticatedUser(currentUsername);
                Rating existingRating = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(
                        user.getUserId(), itineraryId)
                        .orElseThrow(() -> dive);

                existingRating.setScore(request.getScore());
                existingRating.setUpdatedAt(LocalDateTime.now());
                Rating saved = ratingRepository.saveAndFlush(existingRating);

                Double avg = ratingRepository.findAverageRatingByItineraryId(itineraryId);
                double roundedAvg = avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0;
                long count = ratingRepository.countByItinerary_ItineraryId(itineraryId);

                return RatingResponse.builder()
                        .ratingId(saved.getRatingId())
                        .itineraryId(itineraryId)
                        .score(saved.getScore())
                        .averageRating(roundedAvg)
                        .ratingCount((int) count)
                        .createdAt(saved.getCreatedAt())
                        .updatedAt(saved.getUpdatedAt())
                        .newlyCreated(false)
                        .build();
            });
        }
    }

    @Override
    @Transactional(readOnly = true)
    public UserRatingStatusResponse getUserRating(Integer itineraryId, String currentUsername) {
        User user = getAuthenticatedUser(currentUsername);
        getPublicActiveItinerary(itineraryId);

        Optional<Rating> ratingOpt = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(
                user.getUserId(), itineraryId);

        if (ratingOpt.isPresent()) {
            Rating rating = ratingOpt.get();
            return UserRatingStatusResponse.builder()
                    .itineraryId(itineraryId)
                    .rated(true)
                    .score(rating.getScore())
                    .ratingId(rating.getRatingId())
                    .updatedAt(rating.getUpdatedAt())
                    .build();
        } else {
            return UserRatingStatusResponse.builder()
                    .itineraryId(itineraryId)
                    .rated(false)
                    .score(null)
                    .ratingId(null)
                    .updatedAt(null)
                    .build();
        }
    }

    @Override
    @Transactional(readOnly = true)
    public RatingSummaryResponse getRatingSummary(Integer itineraryId) {
        getPublicActiveItinerary(itineraryId);

        Double avg = ratingRepository.findAverageRatingByItineraryId(itineraryId);
        double roundedAvg = avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0;
        long totalRatings = ratingRepository.countByItinerary_ItineraryId(itineraryId);

        Map<Integer, Long> starCounts = new LinkedHashMap<>();
        for (int i = 5; i >= 1; i--) {
            starCounts.put(i, 0L);
        }

        List<Object[]> distribution = ratingRepository.countStarDistributionByItineraryId(itineraryId);
        if (distribution != null) {
            for (Object[] row : distribution) {
                Integer score = (Integer) row[0];
                Long count = (Long) row[1];
                if (score != null) {
                    starCounts.put(score, count != null ? count : 0L);
                }
            }
        }

        return RatingSummaryResponse.builder()
                .itineraryId(itineraryId)
                .averageRating(roundedAvg)
                .ratingCount((int) totalRatings)
                .starCounts(starCounts)
                .build();
    }

    @Override
    @Transactional(rollbackFor = Exception.class)
    public DeleteRatingResponse deleteRating(Integer itineraryId, String currentUsername) {
        User user = getAuthenticatedUser(currentUsername);
        getPublicActiveItinerary(itineraryId);

        Rating rating = ratingRepository.findByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), itineraryId)
                .orElseThrow(() -> new ResourceNotFoundException("Bạn chưa đánh giá lịch trình này"));

        ratingRepository.delete(rating);
        ratingRepository.flush();

        itineraryRepository.decrementRatingCount(itineraryId);

        Double avg = ratingRepository.findAverageRatingByItineraryId(itineraryId);
        double roundedAvg = avg != null ? Math.round(avg * 100.0) / 100.0 : 0.0;
        long totalRatings = ratingRepository.countByItinerary_ItineraryId(itineraryId);

        return DeleteRatingResponse.builder()
                .message("Đã xóa đánh giá thành công")
                .itineraryId(itineraryId)
                .averageRating(roundedAvg)
                .ratingCount((int) totalRatings)
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


package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.PublicUserService;
import java.util.*;
import java.util.stream.Collectors;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PublicUserServiceImpl implements PublicUserService {
    private final UserRepository users;
    private final FollowRepository follows;
    private final ItineraryRepository itineraries;
    private final RatingRepository ratings;
    public PublicUserServiceImpl(UserRepository users, FollowRepository follows,
            ItineraryRepository itineraries, RatingRepository ratings) {
        this.users = users; this.follows = follows; this.itineraries = itineraries; this.ratings = ratings;
    }

    @Override @Transactional(readOnly = true)
    public PublicProfileResponse getProfile(Integer userId, String viewerUsername) {
        User target = activeTarget(userId);
        User viewer = viewerUsername == null ? null : users.findByUsername(viewerUsername).orElse(null);
        boolean own = viewer != null && viewer.getUserId().equals(target.getUserId());
        boolean following = viewer != null && !own && follows.existsByFollower_UserIdAndFollowing_UserId(viewer.getUserId(), target.getUserId());
        return PublicProfileResponse.builder().userId(target.getUserId()).username(target.getUsername())
                .fullName(target.getFullName()).avatar(target.getAvatar()).bio(target.getBio())
                .createdAt(target.getCreatedAt()).followerCount(follows.countByFollowing_UserId(userId))
                .followingCount(follows.countByFollower_UserId(userId)).isFollowing(following).isOwnProfile(own).build();
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getItineraries(Integer userId, int page, int size) {
        activeTarget(userId);
        Page<Itinerary> result = itineraries.findByUser_UserIdAndVisibilityAndStatusAndUser_StatusOrderByCreatedAtDesc(
                userId, Visibility.PUBLIC, ItineraryStatus.ACTIVE, UserStatus.ACTIVE, itineraryPage(page, size));
        List<Integer> ids = result.getContent().stream().map(Itinerary::getItineraryId).toList();
        Map<Integer, Double> avg = new HashMap<>();
        if (!ids.isEmpty()) ratings.findAverageRatingsByItineraryIds(ids).forEach(row -> avg.put((Integer) row[0], ((Number) row[1]).doubleValue()));
        return PageResponse.from(result.map(item -> ItinerarySummaryResponse.builder()
                .itineraryId(item.getItineraryId()).title(item.getTitle()).description(item.getDescription())
                .location(item.getLocation()).coverImage(item.getCoverImage()).totalDays(item.getTotalDays())
                .budget(item.getBudget()).theme(item.getTheme()).visibility(item.getVisibility().name())
                .status(item.getStatus().name()).viewCount(item.getViewCount()).favoriteCount(item.getFavoriteCount())
                .ratingCount(item.getRatingCount()).averageRating(avg.getOrDefault(item.getItineraryId(), 0.0))
                .createdAt(item.getCreatedAt()).creator(creator(item.getUser())).build()));
    }

    @Override @Transactional
    public void follow(Integer targetId, String username) {
        User actor = activeViewer(username);
        if (actor.getUserId().equals(targetId)) throw new BadRequestException("Bạn không thể theo dõi chính mình");
        User target = users.findByUserIdForUpdate(targetId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));
        if (target.getStatus() != UserStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        if (!follows.existsByFollower_UserIdAndFollowing_UserId(actor.getUserId(), targetId)) {
            try { follows.save(Follow.builder().follower(actor).following(target).build()); }
            catch (DataIntegrityViolationException duplicate) { /* idempotent duplicate request; unique key is final guard */ }
        }
    }

    @Override @Transactional
    public void unfollow(Integer targetId, String username) {
        User actor = activeViewer(username);
        if (actor.getUserId().equals(targetId)) throw new BadRequestException("Bạn không thể bỏ theo dõi chính mình");
        activeTarget(targetId);
        follows.findByFollower_UserIdAndFollowing_UserId(actor.getUserId(), targetId).ifPresent(follows::delete);
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> getFollowers(Integer userId, int page, int size) {
        activeTarget(userId);
        return PageResponse.from(follows.findByFollowing_UserIdAndFollower_StatusOrderByCreatedAtDesc(
                userId, UserStatus.ACTIVE, followPage(page, size)).map(f -> userSummary(f.getFollower())));
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> getFollowing(Integer userId, int page, int size) {
        activeTarget(userId);
        return PageResponse.from(follows.findByFollower_UserIdAndFollowing_StatusOrderByCreatedAtDesc(
                userId, UserStatus.ACTIVE, followPage(page, size)).map(f -> userSummary(f.getFollowing())));
    }

    private User activeTarget(Integer id) {
        User user = users.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ công khai"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        return user;
    }
    private User activeViewer(String username) {
        if (username == null || username.isBlank()) throw new UnauthorizedException("Bạn cần đăng nhập");
        User user = users.findByUsername(username).orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new UnauthorizedException("Tài khoản không hoạt động");
        return user;
    }
    private int safePage(int page) { return Math.max(0, page); }
    private int safeSize(int size) { return size <= 0 ? 20 : Math.min(size, 50); }
    private Pageable itineraryPage(int page, int size) { return PageRequest.of(safePage(page), safeSize(size), Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "itineraryId"))); }
    private Pageable followPage(int page, int size) { return PageRequest.of(safePage(page), safeSize(size), Sort.by(Sort.Direction.DESC, "createdAt").and(Sort.by(Sort.Direction.DESC, "followId"))); }
    private CreatorSummaryResponse creator(User user) { return CreatorSummaryResponse.builder().userId(user.getUserId()).username(user.getUsername()).fullName(user.getFullName()).avatar(user.getAvatar()).build(); }
    private PublicUserSummaryResponse userSummary(User user) { return PublicUserSummaryResponse.builder().userId(user.getUserId()).username(user.getUsername()).fullName(user.getFullName()).avatar(user.getAvatar()).build(); }
}

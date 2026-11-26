package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.PublicUserService;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import Travel_Planner.Travel_Planner.service.SocialNotificationService;
import org.springframework.beans.factory.annotation.Autowired;
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
    private final FriendshipService friendships;
    private final ConversationRepository conversations;
    private final SocialNotificationService socialNotifications;

    @Autowired
    public PublicUserServiceImpl(UserRepository users, FollowRepository follows, ItineraryRepository itineraries,
            RatingRepository ratings, FriendshipService friendships, ConversationRepository conversations,
            SocialNotificationService socialNotifications) {
        this.users = users;
        this.follows = follows;
        this.itineraries = itineraries;
        this.ratings = ratings;
        this.friendships = friendships;
        this.conversations = conversations;
        this.socialNotifications = socialNotifications;
    }

    public PublicUserServiceImpl(UserRepository users, FollowRepository follows, ItineraryRepository itineraries,
            RatingRepository ratings, FriendshipService friendships, ConversationRepository conversations) {
        this(users, follows, itineraries, ratings, friendships, conversations, null);
    }

    public PublicUserServiceImpl(UserRepository users, FollowRepository follows, ItineraryRepository itineraries,
            RatingRepository ratings, FriendshipService friendships) {
        this(users, follows, itineraries, ratings, friendships, null, null);
    }

    public PublicUserServiceImpl(UserRepository users, FollowRepository follows, ItineraryRepository itineraries,
            RatingRepository ratings) {
        this(users, follows, itineraries, ratings, null, null, null);
    }
    @Override @Transactional(readOnly = true)
    public PublicProfileResponse getProfile(Integer userId, String viewerUsername) {
        User target = activeTarget(userId);
        User viewer = viewerUsername == null ? null : users.findByUsername(viewerUsername).orElse(null);
        requireVisible(viewer, target);
        boolean own = viewer != null && viewer.getUserId().equals(target.getUserId());
        boolean following = viewer != null && !own && follows.existsByFollower_UserIdAndFollowing_UserId(viewer.getUserId(), target.getUserId());
        Travel_Planner.Travel_Planner.dto.response.RelationshipContextResponse context = context(target, viewer);
        return PublicProfileResponse.builder().userId(target.getUserId()).handle(target.getHandle())
                .fullName(target.getFullName()).avatar(target.getAvatar()).bio(target.getBio())
                .createdAt(target.getCreatedAt()).followerCount(follows.countByFollowing_UserId(userId))
                .followingCount(follows.countByFollower_UserId(userId)).isFollowing(following).isOwnProfile(own)
                .friendshipStatus(context.getFriendshipStatus()).friendRequestDirection(context.getFriendRequestDirection())
                .canMessage(context.isCanMessage())
                .canContinueConversation(hasAcceptedConversation(viewer, target, context))
                .canSendFriendRequest(context.isCanSendFriendRequest()).build();
    }
    @Override @Transactional(readOnly = true)
    public PublicProfileResponse getProfileByHandle(String handle, String viewerUsername) {
        if (handle == null || handle.isBlank()) {
            throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        }
        String normalized = handle.trim().toLowerCase();
        if (normalized.startsWith("@")) {
            normalized = normalized.substring(1);
        }
        User target = users.findByHandle(normalized)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ công khai"));
        if (target.getStatus() != UserStatus.ACTIVE) {
            throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        }
        return getProfile(target.getUserId(), viewerUsername);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<UserSearchResultResponse> searchUsers(String query, int page, int size, String viewerUsername) {
        User viewer = activeViewer(viewerUsername);
        if (query == null || query.trim().length() < 2 || query.trim().length() > 50) {
            throw new BadRequestException("Từ khóa tìm kiếm cần từ 2 đến 50 ký tự");
        }
        if (page < 0 || size < 1) throw new BadRequestException("Thông tin phân trang không hợp lệ");
        String normalized = query.trim().replaceFirst("^@", "").toLowerCase(Locale.ROOT);
        if (normalized.length() < 2) throw new BadRequestException("Từ khóa tìm kiếm cần từ 2 đến 50 ký tự");
        String escaped = normalized.replace("!", "!!").replace("%", "!%").replace("_", "!_");
        Pageable pageable = PageRequest.of(page, Math.min(size, 50));
        Page<User> result = viewer == null
                ? users.searchActiveUsers(escaped + "%", normalized, pageable)
                : users.searchActiveUsersVisibleTo(escaped + "%", normalized, viewer.getUserId(), pageable);
        return toUserSearchPage(result, viewer);
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<UserSearchResultResponse> getSuggestions(int size, String viewerUsername) {
        User viewer = activeViewer(viewerUsername);
        int clampedSize = Math.max(1, Math.min(size, 20));
        Pageable pageable = PageRequest.of(0, clampedSize);
        Page<User> result = viewer == null
                ? users.searchActiveUsers("%", "", pageable)
                : users.searchActiveUsersVisibleTo("%", "", viewer.getUserId(), pageable);
        return toUserSearchPage(result, viewer);
    }

    private PageResponse<UserSearchResultResponse> toUserSearchPage(Page<User> result, User viewer) {
        List<Integer> peerIds = viewer == null
                ? List.of()
                : result.getContent().stream().map(User::getUserId)
                        .filter(id -> !id.equals(viewer.getUserId())).toList();
        Map<Integer, RelationshipContextResponse> contexts = viewer == null || friendships == null || peerIds.isEmpty()
                ? Map.of() : friendships.relationshipContexts(viewer.getUserId(), peerIds);
        Set<Integer> acceptedPeers = new HashSet<>();
        if (viewer != null && conversations != null && !peerIds.isEmpty()) {
            acceptedPeers.addAll(conversations.findAcceptedPeerIds(viewer.getUserId(), peerIds,
                    ConversationStatus.ACCEPTED));
        }
        Map<Integer, Boolean> canContinue = viewer == null || friendships == null || acceptedPeers.isEmpty()
                ? Map.of() : friendships.canContinueConversationForPeers(viewer.getUserId(), List.copyOf(acceptedPeers));
        List<UserSearchResultResponse> content = result.getContent().stream().map(user -> {
            boolean self = viewer != null && viewer.getUserId().equals(user.getUserId());
            RelationshipContextResponse context = contexts.get(user.getUserId());
            return UserSearchResultResponse.builder().userId(user.getUserId()).handle(user.getHandle())
                    .fullName(user.getFullName()).avatar(user.getAvatar()).isSelf(self)
                    .friendshipId(context == null ? null : context.getFriendshipId())
                    .friendshipStatus(self ? "SELF" : context == null ? null : context.getFriendshipStatus())
                    .friendRequestDirection(context == null ? null : context.getFriendRequestDirection())
                    .canMessage(!self && context != null && context.isCanMessage())
                    .canContinueConversation(!self && acceptedPeers.contains(user.getUserId())
                            && canContinue.getOrDefault(user.getUserId(), false))
                    .canSendFriendRequest(!self && context != null && context.isCanSendFriendRequest()).build();
        }).toList();
        return PageResponse.<UserSearchResultResponse>builder().content(content).pageNumber(result.getNumber())
                .pageSize(result.getSize()).totalElements(result.getTotalElements()).totalPages(result.getTotalPages())
                .last(result.isLast()).build();
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<ItinerarySummaryResponse> getItineraries(Integer userId, int page, int size, String viewerUsername) {
        User target = activeTarget(userId);
        requireVisible(viewerUsername == null ? null : users.findByUsername(viewerUsername).orElse(null), target);
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
        requireVisible(actor, target);
        if (!follows.existsByFollower_UserIdAndFollowing_UserId(actor.getUserId(), targetId)) {
            Follow follow;
            try {
                follow = follows.save(Follow.builder().follower(actor).following(target).build());
            }
            catch (DataIntegrityViolationException duplicate) {
                // A concurrent follow already won the unique follower/following key.
                return;
            }
            if (socialNotifications != null) socialNotifications.followed(follow);
        }
    }

    @Override @Transactional
    public void unfollow(Integer targetId, String username) {
        User actor = activeViewer(username);
        if (actor.getUserId().equals(targetId)) throw new BadRequestException("Bạn không thể bỏ theo dõi chính mình");
        activeTarget(targetId);
        User target = users.findById(targetId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ công khai"));
        requireVisible(actor, target);
        follows.findByFollower_UserIdAndFollowing_UserId(actor.getUserId(), targetId).ifPresent(follows::delete);
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> getFollowers(Integer userId, int page, int size, String viewerUsername) {
        User target = activeTarget(userId);
        requireVisible(viewerUsername == null ? null : users.findByUsername(viewerUsername).orElse(null), target);
        return PageResponse.from(follows.findByFollowing_UserIdAndFollower_StatusOrderByCreatedAtDesc(
                userId, UserStatus.ACTIVE, followPage(page, size)).map(f -> userSummary(f.getFollower())));
    }

    @Override @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> getFollowing(Integer userId, int page, int size, String viewerUsername) {
        User target = activeTarget(userId);
        requireVisible(viewerUsername == null ? null : users.findByUsername(viewerUsername).orElse(null), target);
        return PageResponse.from(follows.findByFollower_UserIdAndFollowing_StatusOrderByCreatedAtDesc(
                userId, UserStatus.ACTIVE, followPage(page, size)).map(f -> userSummary(f.getFollowing())));
    }

    private Travel_Planner.Travel_Planner.dto.response.RelationshipContextResponse context(User target, User viewer) {
        if (friendships == null || viewer == null) {
            return Travel_Planner.Travel_Planner.dto.response.RelationshipContextResponse.builder()
                    .canMessage(false).canSendFriendRequest(false).build();
        }
        return friendships.relationshipContext(viewer.getUserId(), target.getUserId());
    }
    private boolean hasAcceptedConversation(User viewer, User target, RelationshipContextResponse context) {
        return viewer != null && !viewer.getUserId().equals(target.getUserId())
                && conversations != null
                && conversations.findAcceptedPeerIds(viewer.getUserId(), List.of(target.getUserId()),
                        ConversationStatus.ACCEPTED).contains(target.getUserId())
                && friendships != null
                && friendships.canContinueConversation(viewer.getUserId(), target.getUserId());
    }
    private User activeTarget(Integer id) {
        User user = users.findById(id).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy hồ sơ công khai"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        return user;
    }
    private void requireVisible(User viewer, User target) {
        if (viewer != null && !viewer.getUserId().equals(target.getUserId())
                && friendships != null && friendships.isBlockedBetween(viewer.getUserId(), target.getUserId())) {
            throw new ResourceNotFoundException("Không tìm thấy hồ sơ công khai");
        }
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
    private CreatorSummaryResponse creator(User user) { return CreatorSummaryResponse.builder().userId(user.getUserId()).username(user.getUsername()).handle(user.getHandle()).fullName(user.getFullName()).avatar(user.getAvatar()).build(); }
    private PublicUserSummaryResponse userSummary(User user) { return PublicUserSummaryResponse.builder().userId(user.getUserId()).username(user.getUsername()).handle(user.getHandle()).fullName(user.getFullName()).avatar(user.getAvatar()).build(); }
}

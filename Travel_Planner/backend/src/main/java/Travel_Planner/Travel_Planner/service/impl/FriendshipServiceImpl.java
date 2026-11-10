package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.FriendshipStatus;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import org.springframework.data.domain.Page;
import java.util.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FriendshipServiceImpl implements FriendshipService {
    private final UserRepository users;
    private final FriendshipRepository friendships;
    private final UserBlockRepository blocks;
    private final UserMessagingSettingsRepository settings;

    public FriendshipServiceImpl(UserRepository users, FriendshipRepository friendships,
            UserBlockRepository blocks, UserMessagingSettingsRepository settings) {
        this.users = users;
        this.friendships = friendships;
        this.blocks = blocks;
        this.settings = settings;
    }

    @Override
    @Transactional
    public FriendRequestResponse sendRequest(Integer targetUserId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(actorLookup.getUserId(), targetUserId);
        User actor = pair.user(actorLookup.getUserId());
        User target = pair.user(targetUserId);
        if (actor.equals(target)) throw new BadRequestException("Bạn không thể kết bạn với chính mình");
        ensureNotBlocked(actor.getUserId(), target.getUserId());

        Friendship relation = find(pair);
        if (relation == null) {
            relation = new Friendship();
            relation.setUserLow(pair.low);
            relation.setUserHigh(pair.high);
            relation.setRequestedByUser(actor);
            relation.setStatus(FriendshipStatus.PENDING);
            relation = friendships.save(relation);
        } else if (relation.getStatus() == FriendshipStatus.ACCEPTED) {
            throw new ConflictException("Hai người dùng đã là bạn bè");
        } else if (relation.getStatus() == FriendshipStatus.PENDING) {
            if (relation.getRequestedByUser().getUserId().equals(actor.getUserId())) return requestResponse(relation, actor.getUserId(), "sent");
            throw new ConflictException("Bạn đang có lời mời kết bạn từ người dùng này. Hãy chấp nhận hoặc từ chối lời mời.");
        } else {
            relation.setRequestedByUser(actor);
            relation.setStatus(FriendshipStatus.PENDING);
        }
        return requestResponse(relation, actor.getUserId(), "sent");
    }

    @Override
    @Transactional
    public FriendRequestResponse accept(Long friendshipId, String actorUsername) {
        Friendship first = friendships.findById(friendshipId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lời mời kết bạn"));
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(first.getUserLow().getUserId(), first.getUserHigh().getUserId());
        User actor = pair.user(actorLookup.getUserId());
        Friendship relation = friendships.findByIdForUpdate(friendshipId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lời mời kết bạn"));
        ensureNotBlocked(pair.low.getUserId(), pair.high.getUserId());
        if (!relation.includes(actor.getUserId())) throw new ResourceNotFoundException("Không tìm thấy lời mời kết bạn");
        if (relation.getStatus() == FriendshipStatus.ACCEPTED) return requestResponse(relation, actor.getUserId(), "friends");
        if (relation.getStatus() != FriendshipStatus.PENDING || relation.getRequestedByUser().getUserId().equals(actor.getUserId())) {
            throw new ForbiddenException("Bạn không thể chấp nhận lời mời này");
        }
        relation.setStatus(FriendshipStatus.ACCEPTED);
        return requestResponse(relation, actor.getUserId(), "friends");
    }

    @Override
    @Transactional
    public FriendRequestResponse decline(Long friendshipId, String actorUsername) {
        Friendship first = friendships.findById(friendshipId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lời mời kết bạn"));
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(first.getUserLow().getUserId(), first.getUserHigh().getUserId());
        User actor = pair.user(actorLookup.getUserId());
        Friendship relation = friendships.findByIdForUpdate(friendshipId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lời mời kết bạn"));
        if (!relation.includes(actor.getUserId())) throw new ResourceNotFoundException("Không tìm thấy lời mời kết bạn");
        if (relation.getStatus() == FriendshipStatus.REJECTED) return requestResponse(relation, actor.getUserId(), "received");
        if (relation.getStatus() != FriendshipStatus.PENDING || relation.getRequestedByUser().getUserId().equals(actor.getUserId())) {
            throw new ForbiddenException("Bạn không thể từ chối lời mời này");
        }
        relation.setStatus(FriendshipStatus.REJECTED);
        return requestResponse(relation, actor.getUserId(), "received");
    }

    @Override
    @Transactional
    public void cancel(Long friendshipId, String actorUsername) {
        Friendship first = friendships.findById(friendshipId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy lời mời kết bạn"));
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(first.getUserLow().getUserId(), first.getUserHigh().getUserId());
        User actor = pair.user(actorLookup.getUserId());
        Friendship relation = friendships.findByIdForUpdate(friendshipId).orElse(null);
        if (relation == null) return;
        if (!relation.getRequestedByUser().getUserId().equals(actor.getUserId()) || relation.getStatus() != FriendshipStatus.PENDING) {
            throw new ForbiddenException("Bạn không thể hủy lời mời này");
        }
        friendships.delete(relation);
    }

    @Override
    @Transactional
    public void unfriend(Integer targetUserId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(actorLookup.getUserId(), targetUserId);
        User actor = pair.user(actorLookup.getUserId());
        if (actor.getUserId().equals(targetUserId)) throw new BadRequestException("Không thể hủy kết bạn với chính mình");
        Friendship relation = find(pair);
        if (relation != null && relation.getStatus() == FriendshipStatus.ACCEPTED) friendships.delete(relation);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<FriendRequestResponse> requests(String direction, int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        Pageable pageable = pageRequest(page, size);
        Page<Friendship> result;
        if ("received".equalsIgnoreCase(direction)) result = friendships.findReceived(actor.getUserId(), FriendshipStatus.PENDING, pageable);
        else if ("sent".equalsIgnoreCase(direction)) result = friendships.findSent(actor.getUserId(), FriendshipStatus.PENDING, pageable);
        else throw new BadRequestException("direction phải là received hoặc sent");
        String selectedDirection = direction.toLowerCase();
        return PageResponse.from(result.map(item -> requestResponse(item, actor.getUserId(), selectedDirection)));
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> friends(int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        Page<Friendship> result = friendships.findByUserAndStatus(actor.getUserId(), FriendshipStatus.ACCEPTED, pageRequest(page, size));
        return PageResponse.from(result.map(item -> userSummary(item.otherUser(actor.getUserId()))));
    }

    @Override
    @Transactional
    public void block(Integer targetUserId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(actorLookup.getUserId(), targetUserId);
        User actor = pair.user(actorLookup.getUserId());
        User target = pair.user(targetUserId);
        if (actor.equals(target)) throw new BadRequestException("Bạn không thể chặn chính mình");
        if (!blocks.existsByBlocker_UserIdAndBlockedUser_UserId(actor.getUserId(), target.getUserId())) {
            UserBlock block = new UserBlock();
            block.setBlocker(actor);
            block.setBlockedUser(target);
            blocks.save(block);
        }
        Friendship relation = find(pair);
        if (relation != null) friendships.delete(relation);
    }

    @Override
    @Transactional
    public void unblock(Integer targetUserId, String actorUsername) {
        User actorLookup = activeUser(actorUsername);
        Pair pair = lockPair(actorLookup.getUserId(), targetUserId);
        User actor = pair.user(actorLookup.getUserId());
        if (actor.getUserId().equals(targetUserId)) throw new BadRequestException("Không thể bỏ chặn chính mình");
        blocks.findForUpdate(actor.getUserId(), targetUserId).ifPresent(blocks::delete);
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<PublicUserSummaryResponse> blocks(int page, int size, String actorUsername) {
        User actor = activeUser(actorUsername);
        Page<UserBlock> result = blocks.findByBlocker_UserIdOrderByCreatedAtDesc(actor.getUserId(), pageRequest(page, size));
        return PageResponse.from(result.map(item -> userSummary(item.getBlockedUser())));
    }

    @Override
    @Transactional(readOnly = true)
    public RelationshipContextResponse relationshipContext(Integer viewerId, Integer targetId) {
        if (viewerId == null || targetId == null || viewerId.equals(targetId)) {
            return RelationshipContextResponse.builder().canMessage(false).canSendFriendRequest(false).build();
        }
        User target = users.findById(targetId).orElse(null);
        User viewer = users.findById(viewerId).orElse(null);
        if (target == null || viewer == null || target.getStatus() != UserStatus.ACTIVE || viewer.getStatus() != UserStatus.ACTIVE) {
            return RelationshipContextResponse.builder().canMessage(false).canSendFriendRequest(false).build();
        }
        Pair pair = Pair.canonical(viewer, target);
        Friendship relation = find(pair);
        boolean blocked = blocks.existsBetween(viewerId, targetId);
        boolean friends = relation != null && relation.getStatus() == FriendshipStatus.ACCEPTED;
        String direction = null;
        if (relation != null && relation.getStatus() == FriendshipStatus.PENDING) {
            direction = relation.getRequestedByUser().getUserId().equals(viewerId) ? "sent" : "received";
        }
        InboundMessagePolicy policy = settings.findById(targetId).map(UserMessagingSettings::getInboundPolicy).orElse(InboundMessagePolicy.FRIENDS_ONLY);
        boolean canMessage = !blocked && (policy == InboundMessagePolicy.EVERYONE || (policy == InboundMessagePolicy.FRIENDS_ONLY && friends));
        boolean canRequest = !blocked && (relation == null || relation.getStatus() == FriendshipStatus.REJECTED);
        return RelationshipContextResponse.builder()
                .friendshipStatus(relation == null ? null : relation.getStatus().name())
                .friendRequestDirection(direction)
                .canMessage(canMessage)
                .canSendFriendRequest(canRequest)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public boolean canMessage(Integer senderId, Integer recipientId) {
        if (senderId == null || recipientId == null || senderId.equals(recipientId) || blocks.existsBetween(senderId, recipientId)) return false;
        User recipient = users.findById(recipientId).orElse(null);
        if (recipient == null || recipient.getStatus() != UserStatus.ACTIVE) return false;
        InboundMessagePolicy policy = settings.findById(recipientId).map(UserMessagingSettings::getInboundPolicy).orElse(InboundMessagePolicy.FRIENDS_ONLY);
        if (policy == InboundMessagePolicy.EVERYONE) return true;
        if (policy == InboundMessagePolicy.NOBODY) return false;
        return friendships.findByUserLow_UserIdAndUserHigh_UserId(Math.min(senderId, recipientId), Math.max(senderId, recipientId))
                .map(f -> f.getStatus() == FriendshipStatus.ACCEPTED).orElse(false);
    }

    @Override
    @Transactional(readOnly = true)
    public java.util.Map<Integer, Boolean> canMessageForPeers(Integer senderId, java.util.List<Integer> recipientIds) {
        java.util.Map<Integer, Boolean> result = new java.util.HashMap<>();
        if (recipientIds == null || recipientIds.isEmpty()) return result;
        User sender = users.findById(senderId).orElse(null);
        if (sender == null || sender.getStatus() != UserStatus.ACTIVE) return result;
        java.util.Set<Integer> blocked = new java.util.HashSet<>();
        for (Object[] row : blocks.findPairsForUser(senderId, recipientIds)) {
            Integer low = (Integer) row[0]; Integer high = (Integer) row[1];
            blocked.add(low.equals(senderId) ? high : low);
        }
        java.util.Set<Integer> friends = new java.util.HashSet<>();
        for (Object[] row : friendships.findPairsByUserAndStatus(senderId, recipientIds, FriendshipStatus.ACCEPTED)) {
            Integer low = (Integer) row[0]; Integer high = (Integer) row[1];
            friends.add(low.equals(senderId) ? high : low);
        }
        java.util.Map<Integer, InboundMessagePolicy> policies = new java.util.HashMap<>();
        for (UserMessagingSettings setting : settings.findByUser_UserIdIn(recipientIds)) {
            policies.put(setting.getUserId(), setting.getInboundPolicy());
        }
        java.util.Map<Integer, UserStatus> statuses = new java.util.HashMap<>();
        users.findAllById(recipientIds).forEach(user -> statuses.put(user.getUserId(), user.getStatus()));
        for (Integer recipientId : recipientIds) {
            InboundMessagePolicy policy = policies.getOrDefault(recipientId, InboundMessagePolicy.FRIENDS_ONLY);
            boolean allowed = !senderId.equals(recipientId) && !blocked.contains(recipientId)
                    && statuses.get(recipientId) == UserStatus.ACTIVE
                    && (policy == InboundMessagePolicy.EVERYONE
                        || (policy == InboundMessagePolicy.FRIENDS_ONLY && friends.contains(recipientId)));
            result.put(recipientId, allowed);
        }
        return result;
    }
    private void ensureNotBlocked(Integer first, Integer second) {
        if (blocks.existsBetween(first, second)) throw new ForbiddenException("Không thể thực hiện thao tác với người dùng này");
    }

    private Friendship find(Pair pair) {
        return friendships.findByUserLow_UserIdAndUserHigh_UserId(pair.low.getUserId(), pair.high.getUserId()).orElse(null);
    }

    private Pair lockPair(Integer firstId, Integer secondId) {
        if (firstId == null || secondId == null) throw new ResourceNotFoundException("Không tìm thấy người dùng");
        Integer lowId = Math.min(firstId, secondId);
        Integer highId = Math.max(firstId, secondId);
        User low = users.findByUserIdForUpdate(lowId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));
        User high = users.findByUserIdForUpdate(highId).orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người dùng"));
        if (low.getStatus() != UserStatus.ACTIVE || high.getStatus() != UserStatus.ACTIVE) throw new ResourceNotFoundException("Không tìm thấy người dùng");
        return new Pair(low, high);
    }

    private User activeUser(String username) {
        if (username == null || username.isBlank()) throw new UnauthorizedException("Bạn cần đăng nhập");
        User user = users.findByUsername(username).orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new UnauthorizedException("Tài khoản không hoạt động");
        return user;
    }

    private PageRequest pageRequest(int page, int size) {
        if (page < 0 || size < 1) throw new BadRequestException("Thông tin phân trang không hợp lệ");
        return PageRequest.of(page, Math.min(size, 50));
    }

    private FriendRequestResponse requestResponse(Friendship item, Integer viewerId, String direction) {
        return FriendRequestResponse.builder().friendshipId(item.getFriendshipId()).status(item.getStatus())
                .direction(direction).otherUser(userSummary(item.otherUser(viewerId))).createdAt(item.getCreatedAt()).build();
    }

    private PublicUserSummaryResponse userSummary(User user) {
        return PublicUserSummaryResponse.builder().userId(user.getUserId()).handle(user.getHandle())
                .username(user.getUsername()).fullName(user.getFullName()).avatar(user.getAvatar()).build();
    }

    private record Pair(User low, User high) {
        private static Pair canonical(User first, User second) {
            return first.getUserId() < second.getUserId() ? new Pair(first, second) : new Pair(second, first);
        }
        private User user(Integer id) {
            if (low.getUserId().equals(id)) return low;
            if (high.getUserId().equals(id)) return high;
            throw new ResourceNotFoundException("Không tìm thấy người dùng");
        }
    }
}


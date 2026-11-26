package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.NotificationPageResponse;
import Travel_Planner.Travel_Planner.dto.response.NotificationResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.NotificationLikeActor;
import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.repository.NotificationRepository;
import Travel_Planner.Travel_Planner.repository.NotificationLikeActorRepository;
import Travel_Planner.Travel_Planner.repository.SystemAnnouncementRepository;
import Travel_Planner.Travel_Planner.repository.AnnouncementReadRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.NotificationService;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeParseException;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class NotificationServiceImpl implements NotificationService {
    private static final int MAX_PAGE_SIZE = 50;
    private static final int MAX_CURSOR_LENGTH = 128;

    private final NotificationRepository notificationRepository;
    private final NotificationLikeActorRepository likeActors;
    private final UserRepository userRepository;
    private final SystemAnnouncementRepository announcementRepository;
    private final AnnouncementReadRepository announcementReadRepository;

    public NotificationServiceImpl(NotificationRepository notificationRepository,
            NotificationLikeActorRepository likeActors, UserRepository userRepository,
            SystemAnnouncementRepository announcementRepository, AnnouncementReadRepository announcementReadRepository) {
        this.notificationRepository = notificationRepository;
        this.likeActors = likeActors;
        this.userRepository = userRepository;
        this.announcementRepository = announcementRepository;
        this.announcementReadRepository = announcementReadRepository;
    }

    @Override
    @Transactional
    public Optional<Notification> create(Integer recipientUserId, Integer actorUserId,
            NotificationType type, String title, String body,
            NotificationTargetType targetType, String targetId, String sourceEventKey) {
        return createInternal(recipientUserId, actorUserId, type, null, title, body,
                targetType, targetId, sourceEventKey, true);
    }

    @Override
    @Transactional
    public Optional<Notification> createAdminAction(Integer recipientUserId, Integer adminUserId,
            NotificationActionType actionType, String title, String body,
            NotificationTargetType targetType, String targetId, String sourceEventKey) {
        if (actionType == null) {
            throw new BadRequestException("Hành động quản trị thông báo là bắt buộc");
        }
        return createInternal(recipientUserId, adminUserId, NotificationType.SYSTEM, actionType,
                title, body, targetType, targetId, sourceEventKey, false);
    }

    private Optional<Notification> createInternal(Integer recipientUserId, Integer actorUserId,
            NotificationType type, NotificationActionType actionType, String title, String body,
            NotificationTargetType targetType, String targetId, String sourceEventKey,
            boolean suppressSelfNotification) {
        validateCreateRequest(recipientUserId, type, title, body, targetId, sourceEventKey);

        User recipient = userRepository.findByUserIdForUpdate(recipientUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người nhận thông báo"));
        if (suppressSelfNotification && actorUserId != null && actorUserId.equals(recipientUserId)) {
            return Optional.empty();
        }

        String normalizedEventKey = normalizeOptional(sourceEventKey);
        if (normalizedEventKey != null) {
            Optional<Notification> existing = notificationRepository.findByRecipient_UserIdAndSourceEventKey(
                    recipientUserId, normalizedEventKey);
            if (existing.isPresent()) {
                return existing;
            }
        }

        User actor = actorUserId == null ? null : userRepository.findById(actorUserId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người tạo thông báo"));
        Notification notification = Notification.builder()
                .recipient(recipient)
                .actor(actor)
                .type(type)
                .actionType(actionType)
                .title(title.trim())
                .body(normalizeOptional(body))
                .targetType(targetType)
                .targetId(normalizeOptional(targetId))
                .sourceEventKey(normalizedEventKey)
                .build();
        return Optional.of(notificationRepository.save(notification));
    }

    @Override
    @Transactional
    public Optional<Notification> recordPostLike(User recipientInput, User actorInput, Post post) {
        if (recipientInput == null || actorInput == null || post == null
                || post.getPostId() == null || recipientInput.getUserId() == null || actorInput.getUserId() == null) {
            return Optional.empty();
        }
        User recipient = userRepository.findByUserIdForUpdate(recipientInput.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người nhận thông báo"));
        if (recipient.getStatus() != UserStatus.ACTIVE || recipient.getUserId().equals(actorInput.getUserId())) {
            return Optional.empty();
        }
        User actor = userRepository.findById(actorInput.getUserId())
                .filter(user -> user.getStatus() == UserStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người tạo thông báo"));

        String postId = post.getPostId().toString();
        LocalDate utcDay = LocalDate.now(ZoneOffset.UTC);
        String eventPrefix = "post-like-group:" + postId + ":" + utcDay + ":";
        Notification notification = notificationRepository.findUnreadLikeGroups(recipient.getUserId(), postId,
                eventPrefix, NotificationType.POST_LIKE, PageRequest.of(0, 1)).stream().findFirst().orElse(null);
        if (notification == null) {
            notification = Notification.builder()
                    .recipient(recipient)
                    .type(NotificationType.POST_LIKE)
                    .targetType(NotificationTargetType.POST)
                    .targetId(postId)
                    .sourceEventKey(eventPrefix + UUID.randomUUID())
                    .title("Bài viết có lượt thích mới")
                    .build();
            notification = notificationRepository.saveAndFlush(notification);
        }

        boolean alreadyMember = likeActors.existsByNotification_NotificationIdAndActor_UserId(
                notification.getNotificationId(), actor.getUserId());
        if (!alreadyMember) {
            NotificationLikeActor membership = new NotificationLikeActor();
            membership.setNotification(notification);
            membership.setActor(actor);
            likeActors.save(membership);
        }
        updateLikeGroupSummary(notification, actor, false);
        return Optional.of(notification);
    }

    @Override
    @Transactional
    public void removePostLikeFromUnreadGroup(User recipientInput, User actorInput, Post post) {
        if (recipientInput == null || actorInput == null || post == null
                || post.getPostId() == null || recipientInput.getUserId() == null || actorInput.getUserId() == null
                || recipientInput.getUserId().equals(actorInput.getUserId())) return;
        User recipient = userRepository.findByUserIdForUpdate(recipientInput.getUserId())
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy người nhận thông báo"));
        if (recipient.getStatus() != UserStatus.ACTIVE) return;
        List<NotificationLikeActor> memberships = likeActors.findUnreadMemberships(recipient.getUserId(),
                post.getPostId().toString(), actorInput.getUserId(), NotificationType.POST_LIKE);
        for (NotificationLikeActor membership : memberships) {
            Notification notification = membership.getNotification();
            likeActors.delete(membership);
            likeActors.flush();
            long count = likeActors.countByNotification_NotificationId(notification.getNotificationId());
            if (count == 0) {
                notificationRepository.delete(notification);
            } else {
                NotificationLikeActor latest = likeActors
                        .findFirstByNotification_NotificationIdOrderByCreatedAtDescNotificationLikeActorIdDesc(
                                notification.getNotificationId());
                updateLikeGroupSummary(notification, latest.getActor(), true);
            }
        }
    }

    private void updateLikeGroupSummary(Notification notification, User latestActor, boolean flush) {
        long count = likeActors.countByNotification_NotificationId(notification.getNotificationId());
        String displayName = latestActor.getFullName();
        if (displayName == null || displayName.isBlank()) displayName = latestActor.getHandle();
        if (displayName == null || displayName.isBlank()) displayName = "Một người";
        notification.setActor(latestActor);
        notification.setTitle(count == 1
                ? displayName + " đã thích bài viết của bạn"
                : displayName + " và " + (count - 1) + " người khác đã thích bài viết của bạn");
        notification.setBody(count == 1 ? null : "Tổng cộng " + count + " lượt thích mới.");
        if (flush) notificationRepository.saveAndFlush(notification);
        else notificationRepository.save(notification);
    }

    @Override
    @Transactional(readOnly = true)
    public NotificationPageResponse getFeed(String username, String cursor, int size,
            boolean unreadOnly, NotificationType type) {
        Integer recipientId = findUserId(username);
        if (size < 1 || size > MAX_PAGE_SIZE) {
            throw new BadRequestException("Kích thước trang phải từ 1 đến " + MAX_PAGE_SIZE);
        }
        CursorPosition position = decodeCursor(cursor);
        List<Notification> personal = notificationRepository.findFeed(recipientId, unreadOnly, type,
                position == null ? null : position.createdAt(),
                position == null ? null : position.id(), PageRequest.of(0, size + 1));
        LocalDateTime now = LocalDateTime.now();
        List<Travel_Planner.Travel_Planner.model.SystemAnnouncement> announcements = type != null ? List.of()
                : (position == null
                    ? (unreadOnly ? announcementRepository.findUnreadActive(recipientId, now, PageRequest.of(0, size + 1))
                            : announcementRepository.findActive(now, PageRequest.of(0, size + 1)))
                    : unreadOnly
                        ? announcementRepository.findUnreadActiveBefore(recipientId, now, position.createdAt(), position.id(), position.source(), PageRequest.of(0, size + 1))
                        : announcementRepository.findActiveBefore(now, position.createdAt(), position.id(), position.source(), PageRequest.of(0, size + 1)));
        List<Long> announcementIds = announcements.stream().map(Travel_Planner.Travel_Planner.model.SystemAnnouncement::getAnnouncementId).toList();
        var readById = announcementIds.isEmpty() ? java.util.Map.<Long, LocalDateTime>of()
                : announcementReadRepository.findForUserAndAnnouncements(recipientId, announcementIds).stream()
                    .collect(java.util.stream.Collectors.toMap(r -> r.getAnnouncement().getAnnouncementId(), Travel_Planner.Travel_Planner.model.AnnouncementRead::getReadAt));
        record FeedEntry(LocalDateTime createdAt, Long id, String source, Travel_Planner.Travel_Planner.dto.response.NotificationResponse response) {}
        List<FeedEntry> combined = new java.util.ArrayList<>();
        personal.forEach(n -> combined.add(new FeedEntry(n.getCreatedAt(), n.getNotificationId(), "N", Travel_Planner.Travel_Planner.dto.response.NotificationResponse.from(n))));
        announcements.forEach(a -> combined.add(new FeedEntry(a.getPublishedAt(), a.getAnnouncementId(), "A", Travel_Planner.Travel_Planner.dto.response.NotificationResponse.fromAnnouncement(a, readById.get(a.getAnnouncementId())))));
        combined.sort(java.util.Comparator.comparing(FeedEntry::createdAt).reversed()
                .thenComparing(FeedEntry::id, java.util.Comparator.reverseOrder())
                .thenComparing(FeedEntry::source, java.util.Comparator.reverseOrder()));
        boolean hasMore = combined.size() > size;
        List<FeedEntry> page = hasMore ? combined.subList(0, size) : combined;
        String nextCursor = hasMore && !page.isEmpty() ? encodeCursor(page.get(page.size() - 1).createdAt(), page.get(page.size() - 1).id(), page.get(page.size() - 1).source()) : null;
        return NotificationPageResponse.builder()
                .content(page.stream().map(FeedEntry::response).toList())
                .nextCursor(nextCursor)
                .hasMore(hasMore)
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public long getUnreadCount(String username) {
        Integer userId = findUserId(username);
        return notificationRepository.countByRecipient_UserIdAndReadAtIsNull(userId)
                + announcementReadRepository.countUnreadActive(userId, LocalDateTime.now());
    }

    @Override
    @Transactional(readOnly = true)
    public long getPersonalUnreadCount(String username) {
        return notificationRepository.countByRecipient_UserIdAndReadAtIsNull(findUserId(username));
    }

    @Override
    @Transactional(readOnly = true)
    public long getAnnouncementUnreadCount(String username) {
        return announcementReadRepository.countUnreadActive(findUserId(username), LocalDateTime.now());
    }

    @Override
    @Transactional
    public void markRead(String username, Long notificationId) {
        if (notificationId == null || notificationId < 1) {
            throw new BadRequestException("Mã thông báo không hợp lệ");
        }
        Integer recipientId = userRepository.findByUsernameForUpdate(username)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"))
                .getUserId();
        int updated = notificationRepository.markRead(notificationId, recipientId, LocalDateTime.now());
        if (updated == 0 && !notificationRepository.existsForRecipient(notificationId, recipientId)) {
            throw new ResourceNotFoundException("Không tìm thấy thông báo");
        }
    }

    @Override
    @Transactional
    public int markAllRead(String username) {
        // The same row lock is taken by create(), so inserts for this recipient
        // cannot slip into the read-all snapshot between its watermark and update.
        Integer recipientId = userRepository.findByUsernameForUpdate(username)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"))
                .getUserId();
        Long watermark = notificationRepository.findLatestIdForRecipient(recipientId);
        if (watermark == null) {
            return 0;
        }
        return notificationRepository.markAllReadThrough(recipientId, watermark, LocalDateTime.now());
    }

    private Integer findUserId(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"))
                .getUserId();
    }

    private static void validateCreateRequest(Integer recipientUserId, NotificationType type,
            String title, String body, String targetId, String sourceEventKey) {
        if (recipientUserId == null || recipientUserId < 1 || type == null) {
            throw new BadRequestException("Người nhận và loại thông báo là bắt buộc");
        }
        if (title == null || title.isBlank() || title.trim().length() > 160) {
            throw new BadRequestException("Tiêu đề thông báo phải có tối đa 160 ký tự");
        }
        if (body != null && body.trim().length() > 500) {
            throw new BadRequestException("Nội dung thông báo phải có tối đa 500 ký tự");
        }
        if (targetId != null && targetId.trim().length() > 100) {
            throw new BadRequestException("Mã đích thông báo không hợp lệ");
        }
        if (sourceEventKey != null && sourceEventKey.trim().length() > 191) {
            throw new BadRequestException("Mã sự kiện thông báo không hợp lệ");
        }
    }

    private static String normalizeOptional(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    @Transactional
    public void markAnnouncementRead(String username, Long announcementId) {
        Integer userId = findUserId(username);
        Travel_Planner.Travel_Planner.model.SystemAnnouncement announcement = announcementRepository.findById(announcementId)
                .filter(a -> a.getStatus() == Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus.PUBLISHED
                        && (a.getExpiresAt() == null || a.getExpiresAt().isAfter(LocalDateTime.now())))
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy thông báo hệ thống"));
        announcementReadRepository.insertIfAbsent(announcement.getAnnouncementId(), userId, LocalDateTime.now());
    }

    @Override
    @Transactional(readOnly = true)
    public PageResponse<NotificationResponse> getAdminActionHistory(NotificationTargetType targetType,
            String targetId, int page, int size) {
        if (page < 0 || size < 1 || size > MAX_PAGE_SIZE) {
            throw new BadRequestException("Thông tin phân trang không hợp lệ");
        }
        String normalizedTargetId = normalizeOptional(targetId);
        if (normalizedTargetId != null && normalizedTargetId.length() > 100) {
            throw new BadRequestException("Mã đối tượng không hợp lệ");
        }
        var actions = notificationRepository.findAdminActionHistory(targetType, normalizedTargetId,
                PageRequest.of(page, size, Sort.unsorted()));
        return PageResponse.from(actions.map(NotificationResponse::from));
    }

    private static String encodeCursor(LocalDateTime createdAt, Long id, String source) {
        String value = createdAt + "|" + id + "|" + source;
        return Base64.getUrlEncoder().withoutPadding().encodeToString(value.getBytes(StandardCharsets.UTF_8));
    }

    private static CursorPosition decodeCursor(String encoded) {
        if (encoded == null || encoded.isBlank()) {
            return null;
        }
        if (encoded.length() > MAX_CURSOR_LENGTH) {
            throw new BadRequestException("Cursor thông báo không hợp lệ");
        }
        try {
            String decoded = new String(Base64.getUrlDecoder().decode(encoded), StandardCharsets.UTF_8);
            String[] parts = decoded.split("\\|", -1);
            if (parts.length != 3 || parts[0].isBlank() || parts[1].isBlank()
                    || !(parts[2].equals("N") || parts[2].equals("A"))) {
                throw new IllegalArgumentException("Invalid cursor shape");
            }
            LocalDateTime createdAt = LocalDateTime.parse(parts[0]);
            long id = Long.parseLong(parts[1]);
            if (id < 1) {
                throw new IllegalArgumentException("Invalid cursor id");
            }
            return new CursorPosition(createdAt, id, parts[2]);
        } catch (IllegalArgumentException | DateTimeParseException exception) {
            throw new BadRequestException("Cursor thông báo không hợp lệ");
        }
    }

    private record CursorPosition(LocalDateTime createdAt, Long id, String source) { }
}

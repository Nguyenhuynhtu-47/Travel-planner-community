package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.Notification;
import Travel_Planner.Travel_Planner.model.Post;
import Travel_Planner.Travel_Planner.model.SystemAnnouncement;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import Travel_Planner.Travel_Planner.model.enums.NotificationType;
import Travel_Planner.Travel_Planner.model.enums.NotificationActionType;
import Travel_Planner.Travel_Planner.model.enums.NotificationTargetType;
import Travel_Planner.Travel_Planner.repository.NotificationRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.SystemAnnouncementRepository;
import Travel_Planner.Travel_Planner.service.NotificationService;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.context.WebApplicationContext;

import java.util.UUID;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.user;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
class NotificationDatabaseIntegrationTest {
    @Autowired private NotificationService notificationService;
    @Autowired private NotificationRepository notificationRepository;
    @Autowired private UserRepository userRepository;
    @Autowired private SystemAnnouncementRepository announcementRepository;
    @Autowired private JdbcTemplate jdbcTemplate;
    @Autowired private WebApplicationContext context;
    private MockMvc mockMvc;
    private final Set<Integer> fixtureUserIds = ConcurrentHashMap.newKeySet();
    private final Set<Long> fixtureAnnouncementIds = ConcurrentHashMap.newKeySet();

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(context).apply(springSecurity()).build();
    }

    @AfterEach
    void cleanFixtures() {
        if (!fixtureAnnouncementIds.isEmpty()) {
            String announcementPlaceholders = String.join(",", java.util.Collections.nCopies(fixtureAnnouncementIds.size(), "?"));
            jdbcTemplate.update("delete from audit_logs where target_type='SYSTEM_ANNOUNCEMENT' and target_id in (" + announcementPlaceholders + ")",
                    java.util.Arrays.stream(fixtureAnnouncementIds.toArray()).map(String::valueOf).toArray());
            jdbcTemplate.update("delete from announcement_reads where announcement_id in (" + announcementPlaceholders + ")", fixtureAnnouncementIds.toArray());
            announcementRepository.deleteAllById(fixtureAnnouncementIds);
            fixtureAnnouncementIds.clear();
        }
        if (fixtureUserIds.isEmpty()) return;
        String placeholders = String.join(",", java.util.Collections.nCopies(fixtureUserIds.size(), "?"));
        Object[] ids = fixtureUserIds.toArray();
        jdbcTemplate.update("delete from notification_like_actors where actor_user_id in (" + placeholders
                + ") or notification_id in (select notification_id from notifications where recipient_user_id in ("
                + placeholders + ") or actor_user_id in (" + placeholders + "))", concat(ids, ids, ids));
        jdbcTemplate.update("delete from notifications where recipient_user_id in (" + placeholders
                + ") or actor_user_id in (" + placeholders + ")", concat(ids, ids));
        jdbcTemplate.update("delete from users where user_id in (" + placeholders + ")", ids);
    }

    @Test
    void activeAnnouncementIsVisibleToFutureUsersAndOnlyExplicitOpenCreatesReceipt() {
        User publisher = createUser();
        SystemAnnouncement announcement = announcementRepository.saveAndFlush(SystemAnnouncement.builder()
                .createdBy(publisher).title("Test announcement").body("Shared body")
                .type("SYSTEM").status(AnnouncementStatus.PUBLISHED)
                .publishedAt(java.time.LocalDateTime.now().minusMinutes(1))
                .expiresAt(java.time.LocalDateTime.now().plusDays(1)).build());
        fixtureAnnouncementIds.add(announcement.getAnnouncementId());

        User existingUser = createUser();
        var page = notificationService.getFeed(existingUser.getUsername(), null, 10, false, null);
        assertEquals(1, page.getContent().size());
        assertTrue(page.getContent().getFirst().isAnnouncement());
        assertEquals(1, notificationService.getUnreadCount(existingUser.getUsername()));

        User futureUser = createUser();
        assertEquals(1, notificationService.getFeed(futureUser.getUsername(), null, 10, false, null).getContent().size());
        assertEquals(1, notificationService.getUnreadCount(futureUser.getUsername()));

        notificationService.markAnnouncementRead(existingUser.getUsername(), announcement.getAnnouncementId());
        assertEquals(0, notificationService.getUnreadCount(existingUser.getUsername()));
        assertEquals(1, notificationService.getUnreadCount(futureUser.getUsername()));
    }

    @Test
    void cancelledAndExpiredAnnouncementsAreExcludedFromFeedAndUnreadCount() {
        User reader = createUser();
        var now = java.time.LocalDateTime.now();
        var cancelled = announcementRepository.saveAndFlush(SystemAnnouncement.builder().title("Cancelled").body("x")
                .type("SYSTEM").status(AnnouncementStatus.CANCELLED).publishedAt(now.minusDays(1)).build());
        var expired = announcementRepository.saveAndFlush(SystemAnnouncement.builder().title("Expired").body("x")
                .type("SYSTEM").status(AnnouncementStatus.PUBLISHED).publishedAt(now.minusDays(2)).expiresAt(now.minusMinutes(1)).build());
        fixtureAnnouncementIds.add(cancelled.getAnnouncementId());
        fixtureAnnouncementIds.add(expired.getAnnouncementId());

        assertTrue(notificationService.getFeed(reader.getUsername(), null, 10, false, null).getContent().isEmpty());
        assertEquals(0, notificationService.getUnreadCount(reader.getUsername()));
    }

    @Test
    void adminActionNotificationPersistsActionActorTargetAndPublicReason() {
        User recipient = createUser();
        User admin = createUser();
        String eventKey = "admin-post-hidden:" + UUID.randomUUID();

        var created = notificationService.createAdminAction(recipient.getUserId(), admin.getUserId(),
                NotificationActionType.POST_HIDDEN, "Cập nhật về bài viết",
                "Bài viết của bạn đã bị ẩn. Lý do: Nội dung vi phạm quy định.",
                NotificationTargetType.POST, "987", eventKey).orElseThrow();
        var persisted = notificationRepository.findByRecipient_UserIdAndSourceEventKey(
                recipient.getUserId(), eventKey).orElseThrow();

        assertEquals(NotificationType.SYSTEM, persisted.getType());
        assertEquals(NotificationActionType.POST_HIDDEN, persisted.getActionType());
        assertEquals(admin.getUserId(), persisted.getActor().getUserId());
        assertEquals(NotificationTargetType.POST, persisted.getTargetType());
        assertEquals("987", persisted.getTargetId());
        assertTrue(persisted.getBody().contains("Nội dung vi phạm quy định"));
        assertNull(persisted.getReadAt());
        assertEquals(created.getNotificationId(), persisted.getNotificationId());
    }

    @Test
    void systemFilterAndApiNormalizeLegacyModerationRows() {
        User recipient = createUser();
        notificationService.create(recipient.getUserId(), null, NotificationType.MODERATION_UPDATE,
                "Thông báo cũ", "Nội dung", NotificationTargetType.USER,
                recipient.getUserId().toString(), "legacy-system:" + UUID.randomUUID());

        var page = notificationService.getFeed(recipient.getUsername(), null, 10, false, NotificationType.SYSTEM);

        assertEquals(1, page.getContent().size());
        assertEquals("SYSTEM", page.getContent().getFirst().getType());
    }

    @Test
    void adminOnlyActionHistoryQueryReturnsMatchingActionRows() throws Exception {
        User recipient = createUser();
        User admin = createUser();
        admin.setRole(Travel_Planner.Travel_Planner.model.enums.Role.ADMIN);
        userRepository.saveAndFlush(admin);
        notificationService.createAdminAction(recipient.getUserId(), admin.getUserId(),
                NotificationActionType.POST_HIDDEN, "Cập nhật về bài viết", "Bài viết đã bị ẩn.",
                NotificationTargetType.POST, "54321", "admin-history:" + UUID.randomUUID());

        mockMvc.perform(get("/api/admin/notification-actions")
                        .param("targetType", "POST").param("targetId", "54321")
                        .with(user(principal(recipient.getUsername()))))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/admin/notification-actions")
                        .param("targetType", "POST").param("targetId", "54321")
                        .with(user(org.springframework.security.core.userdetails.User.withUsername(admin.getUsername())
                                .password("unused").roles("ADMIN").build())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].actionType").value("POST_HIDDEN"))
                .andExpect(jsonPath("$.content[0].targetId").value("54321"));
    }

    @Test
    void announcementReadApiRequiresAuthenticationAndAdminMutationIsRoleProtected() throws Exception {
        User reader = createUser();
        mockMvc.perform(post("/api/admin/announcements")
                        .with(user(principal(reader.getUsername()))).with(csrf())
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"x\",\"body\":\"x\"}"))
                .andExpect(status().isForbidden());
        mockMvc.perform(post("/api/announcements/999999/read"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void adminCanCreatePublishAndCancelAnnouncementWithAuditedLifecycle() throws Exception {
        User admin = createUser();
        admin.setRole(Travel_Planner.Travel_Planner.model.enums.Role.ADMIN);
        userRepository.saveAndFlush(admin);
        var created = mockMvc.perform(post("/api/admin/announcements")
                        .with(user(org.springframework.security.core.userdetails.User.withUsername(admin.getUsername()).password("unused").roles("ADMIN").build()))
                        .with(csrf()).contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Maintenance\",\"body\":\"Scheduled update\",\"expiresAt\":null}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("DRAFT"))
                .andReturn();
        long announcementId = new com.fasterxml.jackson.databind.ObjectMapper()
                .readTree(created.getResponse().getContentAsString()).get("id").asLong();
        fixtureAnnouncementIds.add(announcementId);

        mockMvc.perform(post("/api/admin/announcements/{id}/publish", announcementId)
                        .with(user(org.springframework.security.core.userdetails.User.withUsername(admin.getUsername()).password("unused").roles("ADMIN").build()))
                        .with(csrf()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("PUBLISHED"));
        mockMvc.perform(post("/api/admin/announcements/{id}/cancel", announcementId)
                        .with(user(org.springframework.security.core.userdetails.User.withUsername(admin.getUsername()).password("unused").roles("ADMIN").build()))
                        .with(csrf()))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("CANCELLED"));
        assertEquals(3, jdbcTemplate.queryForObject(
                "select count(*) from audit_logs where target_type='SYSTEM_ANNOUNCEMENT' and target_id=?",
                Integer.class, String.valueOf(announcementId)));
    }

    @Test
    void mysqlSchemaSupportsCreateIdempotentFeedAndReadOperations() {
        User recipient = createUser();
        User actor = createUser();
        String eventKey = "follow:" + actor.getUserId() + ":" + recipient.getUserId();

        var first = notificationService.create(recipient.getUserId(), actor.getUserId(),
                NotificationType.NEW_FOLLOWER, "Có người theo dõi bạn", "Travel Planner",
                NotificationTargetType.USER, actor.getUserId().toString(), eventKey).orElseThrow();
        var repeated = notificationService.create(recipient.getUserId(), actor.getUserId(),
                NotificationType.NEW_FOLLOWER, "Có người theo dõi bạn", "Travel Planner",
                NotificationTargetType.USER, actor.getUserId().toString(), eventKey).orElseThrow();

        assertEquals(first.getNotificationId(), repeated.getNotificationId());
        assertEquals(1, notificationRepository.countByRecipient_UserIdAndReadAtIsNull(recipient.getUserId()));
        var page = notificationService.getFeed(recipient.getUsername(), null, 10, false, null);
        assertEquals(1, page.getContent().size());
        assertEquals(actor.getUsername(), page.getContent().getFirst().getActor().getUsername());

        notificationService.markRead(recipient.getUsername(), first.getNotificationId());
        assertEquals(0, notificationService.getUnreadCount(recipient.getUsername()));
        assertThrows(ResourceNotFoundException.class,
                () -> notificationService.markRead(actor.getUsername(), first.getNotificationId()));
    }

    @Test
    void postLikesGroupByUtcDayAndUnlikeOnlyChangesUnreadGroups() {
        User owner = createUser();
        User firstActor = createUser();
        User latestActor = createUser();
        Post post = Post.builder().postId(987654321L).author(owner).build();

        Notification first = notificationService.recordPostLike(owner, firstActor, post).orElseThrow();
        Notification grouped = notificationService.recordPostLike(owner, latestActor, post).orElseThrow();
        assertEquals(first.getNotificationId(), grouped.getNotificationId());
        assertEquals(latestActor.getUserId(), grouped.getActor().getUserId());
        assertEquals("Tổng cộng 2 lượt thích mới.", grouped.getBody());
        assertEquals(2, jdbcTemplate.queryForObject(
                "select count(*) from notification_like_actors where notification_id = ?", Integer.class,
                grouped.getNotificationId()));

        notificationService.removePostLikeFromUnreadGroup(owner, firstActor, post);
        Notification remaining = notificationRepository.findById(grouped.getNotificationId()).orElseThrow();
        assertEquals(latestActor.getUserId(), remaining.getActor().getUserId());
        assertNull(remaining.getBody());

        notificationService.markRead(owner.getUsername(), remaining.getNotificationId());
        String readTitle = notificationRepository.findById(remaining.getNotificationId()).orElseThrow().getTitle();
        notificationService.removePostLikeFromUnreadGroup(owner, latestActor, post);
        Notification historical = notificationRepository.findById(remaining.getNotificationId()).orElseThrow();
        assertNotNull(historical.getReadAt());
        assertEquals(readTitle, historical.getTitle());
        assertEquals(1, jdbcTemplate.queryForObject(
                "select count(*) from notification_like_actors where notification_id = ?", Integer.class,
                historical.getNotificationId()));

        Notification newUnreadGroup = notificationService.recordPostLike(owner, latestActor, post).orElseThrow();
        assertNotEquals(historical.getNotificationId(), newUnreadGroup.getNotificationId());
        assertNull(newUnreadGroup.getReadAt());
        assertEquals(1, jdbcTemplate.queryForObject(
                "select count(*) from notification_like_actors where notification_id = ?", Integer.class,
                newUnreadGroup.getNotificationId()));
    }

    @Test
    void unlikingFinalActorDeletesOnlyTheUnreadLikeGroup() {
        User owner = createUser();
        User actor = createUser();
        Post post = Post.builder().postId(987654322L).author(owner).build();
        Notification group = notificationService.recordPostLike(owner, actor, post).orElseThrow();

        notificationService.removePostLikeFromUnreadGroup(owner, actor, post);

        assertFalse(notificationRepository.existsById(group.getNotificationId()));
        assertEquals(0, notificationService.getPersonalUnreadCount(owner.getUsername()));
    }

    @Test
    void readAllMarksOnlyRowsOwnedByTheCurrentUser() {
        User recipient = createUser();
        User other = createUser();
        notificationService.create(recipient.getUserId(), null, NotificationType.SYSTEM,
                "Thông báo", null, null, null, "moderation:" + UUID.randomUUID());
        notificationService.create(other.getUserId(), null, NotificationType.SYSTEM,
                "Thông báo", null, null, null, "moderation:" + UUID.randomUUID());

        assertEquals(1, notificationService.markAllRead(recipient.getUsername()));
        assertEquals(0, notificationService.getUnreadCount(recipient.getUsername()));
        assertEquals(1, notificationService.getUnreadCount(other.getUsername()));
    }

    @Test
    void cursorPagesAreStableAndTypeFilterIsAppliedInDatabase() {
        User recipient = createUser();
        for (int index = 0; index < 3; index++) {
            NotificationType type = index == 1 ? NotificationType.SYSTEM : NotificationType.NEW_FOLLOWER;
            notificationService.create(recipient.getUserId(), null, type,
                    "Thông báo " + index, null, null, null, "paging:" + UUID.randomUUID());
        }

        var firstPage = notificationService.getFeed(recipient.getUsername(), null, 2, false, null);
        var secondPage = notificationService.getFeed(recipient.getUsername(), firstPage.getNextCursor(), 2, false, null);
        var filtered = notificationService.getFeed(recipient.getUsername(), null, 10, false,
                NotificationType.SYSTEM);

        var allIds = java.util.stream.Stream.concat(firstPage.getContent().stream(), secondPage.getContent().stream())
                .map(item -> item.getId()).collect(Collectors.toSet());
        assertEquals(3, allIds.size());
        assertTrue(firstPage.isHasMore());
        assertFalse(secondPage.isHasMore());
        assertEquals(1, filtered.getContent().size());
        assertEquals("SYSTEM", filtered.getContent().getFirst().getType());
    }

    @Test
    void concurrentRetriesForSameRecipientAndEventCreateOneRow() throws Exception {
        User recipient = createUser();
        String eventKey = "concurrent:" + UUID.randomUUID();
        int workerCount = 6;
        var pool = Executors.newFixedThreadPool(workerCount);
        var start = new CountDownLatch(1);
        try {
            var results = IntStream.range(0, workerCount).mapToObj(index -> pool.submit(() -> {
                assertTrue(start.await(5, TimeUnit.SECONDS));
                return notificationService.create(recipient.getUserId(), null,
                        NotificationType.SYSTEM, "Concurrent event", null, null, null, eventKey)
                        .orElseThrow().getNotificationId();
            })).toList();
            start.countDown();
            var ids = results.stream().map(future -> {
                try {
                    return future.get(10, TimeUnit.SECONDS);
                } catch (Exception exception) {
                    throw new AssertionError("Concurrent create failed", exception);
                }
            }).collect(Collectors.toSet());
            assertEquals(1, ids.size());
            assertEquals(1, notificationRepository.countByRecipient_UserIdAndReadAtIsNull(recipient.getUserId()));
        } finally {
            pool.shutdownNow();
        }
    }

    @Test
    void httpApiRequiresAuthenticationAndScopesReadOperationsToPrincipal() throws Exception {
        User recipient = createUser();
        User other = createUser();
        var notification = notificationService.create(recipient.getUserId(), null,
                NotificationType.SYSTEM, "Cập nhật quản trị", null, null, null,
                "http:" + UUID.randomUUID()).orElseThrow();

        mockMvc.perform(get("/api/notifications"))
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/notifications")
                        .with(user(principal(recipient.getUsername()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content[0].id").value(notification.getNotificationId()));
        mockMvc.perform(post("/api/notifications/{id}/read", notification.getNotificationId())
                        .with(user(principal(other.getUsername()))).with(csrf()))
                .andExpect(status().isNotFound());
        mockMvc.perform(post("/api/notifications/{id}/read", notification.getNotificationId())
                        .with(user(principal(recipient.getUsername()))).with(csrf()))
                .andExpect(status().isNoContent());
    }

    private User createUser() {
        String suffix = UUID.randomUUID().toString().replace("-", "");
        User user = userRepository.saveAndFlush(User.builder()
                .username("notify_" + suffix.substring(0, 20))
                .handle("n_" + suffix.substring(0, 20))
                .password("test-only-password")
                .email("notify_" + suffix + "@example.test")
                .fullName("Notification test")
                .build());
        fixtureUserIds.add(user.getUserId());
        return user;
    }

    private static Object[] concat(Object[] first, Object[] second) {
        Object[] combined = java.util.Arrays.copyOf(first, first.length + second.length);
        System.arraycopy(second, 0, combined, first.length, second.length);
        return combined;
    }

    private static Object[] concat(Object[] first, Object[] second, Object[] third) {
        return concat(concat(first, second), third);
    }

    private static UserDetails principal(String username) {
        return org.springframework.security.core.userdetails.User.withUsername(username)
                .password("unused").roles("USER").build();
    }
}

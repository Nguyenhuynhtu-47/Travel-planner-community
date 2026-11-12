package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.ItineraryService;
import Travel_Planner.Travel_Planner.service.impl.ItineraryServiceImpl;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Verification Test Suite for:
 * Phase 5.1 — Atomic reuse_count Increment & Concurrency Hardening (Zero Lost Update)
 * Phase 5.2 — Clone Transaction Rollback Verification (Atomic All-or-Nothing Guarantee)
 */
@SpringBootTest
class CloneConcurrencyAndRollbackTest {

    @Autowired
    private ItineraryService itineraryService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private ItineraryPlaceRepository itineraryPlaceRepository;

    @Autowired
    private RatingRepository ratingRepository;

    @Autowired
    private FavoriteRepository favoriteRepository;

    @Autowired
    private SavedItineraryRepository savedItineraryRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    private User sourceOwner;
    private Place canonicalPlace1;
    private Place canonicalPlace2;
    private Itinerary sourceItinerary;
    private ItineraryDay day1;
    private ItineraryDay day2;
    private Activity activity1;
    private Activity activity2;

    @BeforeEach
    void setUp() {
        cleanupDatabase();

        // 1. Create source owner
        sourceOwner = userRepository.save(User.builder()
                .username("concurrency_owner")
                .email("concurrency_owner@example.com")
                .password(passwordEncoder.encode("Password123!"))
                .fullName("Chủ Lịch Trình Nguồn")
                .handle("concurrency_owner")
                .status(UserStatus.ACTIVE)
                .role(Role.USER)
                .build());

        // 2. Create canonical places
        canonicalPlace1 = placeRepository.save(Place.builder()
                .name("Nhà thờ Đức Bà Sài Gòn")
                .normalizedName("nha tho duc ba sai gon")
                .address("01 Công xã Paris, Bến Nghé, Quận 1")
                .latitude(new BigDecimal("10.7798000"))
                .longitude(new BigDecimal("106.6990000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build());

        canonicalPlace2 = placeRepository.save(Place.builder()
                .name("Chợ Bến Thành")
                .normalizedName("cho ben thanh")
                .address("Đường Lê Lợi, Bến Thành, Quận 1")
                .latitude(new BigDecimal("10.7725000"))
                .longitude(new BigDecimal("106.6980000"))
                .category(PlaceCategory.SHOPPING)
                .status(PlaceStatus.ACTIVE)
                .build());

        // 3. Create rich source itinerary
        sourceItinerary = itineraryRepository.save(Itinerary.builder()
                .user(sourceOwner)
                .title("Hành Trình Gốc Kiểm Thử Concurrency & Rollback")
                .description("Mô tả chi tiết hành trình gốc với nhiều ngày và hoạt động")
                .location("TP. Hồ Chí Minh")
                .coverImage("https://example.com/cover.jpg")
                .totalDays(2)
                .budget(new BigDecimal("3000000.00"))
                .theme("Văn hóa & Lịch sử")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(50)
                .favoriteCount(25)
                .ratingCount(10)
                .commentCount(5)
                .reuseCount(0)
                .build());

        // 4. Create Days
        day1 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(sourceItinerary)
                .dayNumber(1)
                .title("Ngày 1: Trung tâm Quận 1")
                .date(LocalDate.of(2026, 12, 10))
                .build());

        day2 = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(sourceItinerary)
                .dayNumber(2)
                .title("Ngày 2: Mua sắm và Ẩm thực")
                .date(LocalDate.of(2026, 12, 11))
                .build());

        // 5. Create Activities
        activity1 = activityRepository.save(Activity.builder()
                .itineraryDay(day1)
                .place(canonicalPlace1)
                .name("Tham quan Nhà thờ Đức Bà")
                .description("Chụp ảnh kiến trúc cổ điển")
                .locationName("Nhà thờ Đức Bà")
                .locationAddress("01 Công xã Paris, Quận 1")
                .customLocationName("Nhà thờ Đức Bà")
                .customAddress("01 Công xã Paris, Quận 1")
                .latitude(new BigDecimal("10.7798000"))
                .longitude(new BigDecimal("106.6990000"))
                .placeId("place-ndb-01")
                .locationProvider("LOCATION_IQ")
                .startTime(LocalTime.of(9, 0))
                .endTime(LocalTime.of(11, 0))
                .cost(BigDecimal.ZERO)
                .displayOrder(1)
                .build());

        activity2 = activityRepository.save(Activity.builder()
                .itineraryDay(day2)
                .place(canonicalPlace2)
                .name("Khám phá Chợ Bến Thành")
                .description("Mua sắm quà lưu niệm")
                .locationName("Chợ Bến Thành")
                .locationAddress("Lê Lợi, Quận 1")
                .customLocationName("Chợ Bến Thành")
                .customAddress("Lê Lợi, Quận 1")
                .latitude(new BigDecimal("10.7725000"))
                .longitude(new BigDecimal("106.6980000"))
                .placeId("place-cbt-02")
                .locationProvider("LOCATION_IQ")
                .startTime(LocalTime.of(14, 0))
                .endTime(LocalTime.of(16, 30))
                .cost(new BigDecimal("500000.00"))
                .displayOrder(1)
                .build());

        // 6. Create ItineraryPlaces
        itineraryPlaceRepository.save(ItineraryPlace.builder()
                .itinerary(sourceItinerary)
                .place(canonicalPlace1)
                .build());

        itineraryPlaceRepository.save(ItineraryPlace.builder()
                .itinerary(sourceItinerary)
                .place(canonicalPlace2)
                .build());
    }

    @AfterEach
    void tearDown() {
        ItineraryServiceImpl.clearTestFaultInjector();
        cleanupDatabase();
    }

    private void cleanupDatabase() {
        itineraryPlaceRepository.deleteAll();
        activityRepository.deleteAll();
        itineraryDayRepository.deleteAll();
        ratingRepository.deleteAll();
        favoriteRepository.deleteAll();
        savedItineraryRepository.deleteAll();
        itineraryRepository.deleteAll();
        placeRepository.deleteAll();
        userRepository.deleteAll();
    }

    // =========================================================================
    // PHASE 5.1: CONCURRENCY & ATOMIC REUSE COUNT INCREMENT TESTS
    // =========================================================================

    @Test
    @DisplayName("Phase 5.1 — 10 concurrent clone requests increment reuse_count atomically to exactly 10 without Lost Update")
    void testConcurrentClone_TenSimultaneousRequests_IncrementsReuseCountExactlyTen() throws Exception {
        int threadCount = 10;
        List<User> cloners = new ArrayList<>();

        // Create 10 distinct active cloner users
        for (int i = 1; i <= threadCount; i++) {
            User cloner = userRepository.save(User.builder()
                    .username("cloner_concurrent_" + i)
                    .email("cloner_concurrent_" + i + "@example.com")
                    .password(passwordEncoder.encode("Password123!"))
                    .fullName("Người Dùng Đồng Thời " + i)
                    .handle("cloner_concurrent_" + i)
                    .status(UserStatus.ACTIVE)
                    .role(Role.USER)
                    .build());
            cloners.add(cloner);
        }

        // Verify initial state
        Itinerary initialSource = itineraryRepository.findById(sourceItinerary.getItineraryId()).orElseThrow();
        assertEquals(0, initialSource.getReuseCount(), "Initial reuse_count must be 0");
        long initialTotalItineraries = itineraryRepository.count();

        // Concurrency synchronization primitives
        ExecutorService executor = Executors.newFixedThreadPool(threadCount);
        CountDownLatch readyLatch = new CountDownLatch(threadCount);
        CountDownLatch startLatch = new CountDownLatch(1);
        CountDownLatch doneLatch = new CountDownLatch(threadCount);

        List<Throwable> errors = Collections.synchronizedList(new ArrayList<>());
        AtomicInteger successCount = new AtomicInteger(0);
        List<Integer> createdClonedIds = Collections.synchronizedList(new ArrayList<>());

        for (int i = 0; i < threadCount; i++) {
            final User cloner = cloners.get(i);
            executor.submit(() -> {
                readyLatch.countDown();
                try {
                    // Await the firing signal to maximize simultaneous race condition
                    startLatch.await();

                    var response = itineraryService.cloneItinerary(sourceItinerary.getItineraryId(), cloner.getUsername());
                    assertNotNull(response);
                    assertNotNull(response.getItineraryId());
                    createdClonedIds.add(response.getItineraryId());
                    successCount.incrementAndGet();
                } catch (Throwable t) {
                    errors.add(t);
                } finally {
                    doneLatch.countDown();
                }
            });
        }

        // Wait until all threads are initialized and waiting
        assertTrue(readyLatch.await(10, TimeUnit.SECONDS), "All threads should be ready within 10s");

        // Fire all threads simultaneously!
        long startTime = System.currentTimeMillis();
        startLatch.countDown();

        // Wait for all threads to complete
        assertTrue(doneLatch.await(30, TimeUnit.SECONDS), "All 10 concurrent clone operations must complete within 30s");
        long duration = System.currentTimeMillis() - startTime;
        executor.shutdown();

        // Verify all 10 operations succeeded without error
        assertTrue(errors.isEmpty(), "Zero errors expected during concurrent cloning, but got: " + errors);
        assertEquals(threadCount, successCount.get(), "All 10 requests must succeed");
        assertEquals(threadCount, createdClonedIds.size(), "Exactly 10 cloned itinerary IDs must be returned");

        // CRITICAL CONCURRENCY INVARIANT: reuse_count must be exactly 10 (Zero Lost Update)
        Itinerary updatedSource = itineraryRepository.findById(sourceItinerary.getItineraryId()).orElseThrow();
        assertEquals(10, updatedSource.getReuseCount(),
                "CRITICAL: reuse_count must be exactly 10 after 10 concurrent clones. Lost update detected if < 10!");

        // Total itineraries in DB must be baseline (1) + 10 = 11
        assertEquals(initialTotalItineraries + 10, itineraryRepository.count(), "Exactly 10 new itineraries in DB");

        // Verify each clone is independent and links to the source itinerary
        for (Integer cloneId : createdClonedIds) {
            Itinerary cloneEntity = itineraryRepository.findById(cloneId).orElseThrow();
            assertEquals(sourceItinerary.getItineraryId(), cloneEntity.getOriginalItinerary().getItineraryId(),
                    "Each clone must link to the original ancestor");
            assertEquals(Visibility.PRIVATE, cloneEntity.getVisibility(), "Clones default to PRIVATE");
            assertEquals(0, cloneEntity.getReuseCount(), "Clones have reuse_count initialized to 0");

            // Verify each clone has its own independent days and activities
            List<ItineraryDay> cloneDays = itineraryDayRepository.findByItinerary_ItineraryIdOrderByDayNumberAsc(cloneId);
            assertEquals(2, cloneDays.size(), "Each clone must have 2 copied days");
            for (ItineraryDay cd : cloneDays) {
                List<Activity> cloneActivities = activityRepository.findByItineraryDay_DayIdOrderByDisplayOrderAsc(cd.getDayId());
                assertEquals(1, cloneActivities.size(), "Each cloned day must have 1 activity");
            }

            // Verify cloned saved places
            List<ItineraryPlace> clonePlaces = itineraryPlaceRepository.findAllByItineraryIdWithPlace(cloneId);
            assertEquals(2, clonePlaces.size(), "Each clone must have 2 cloned itinerary_places");
        }

        // Verify source itinerary metadata was not corrupted
        assertEquals("Hành Trình Gốc Kiểm Thử Concurrency & Rollback", updatedSource.getTitle());
        assertEquals(sourceOwner.getUserId(), updatedSource.getUser().getUserId());

        System.out.println(">>> Phase 5.1 Concurrency Verification PASSED: 10 concurrent clones completed in "
                + duration + "ms with reuse_count = " + updatedSource.getReuseCount());
    }

    // =========================================================================
    // PHASE 5.2: TRANSACTION ROLLBACK VERIFICATION TESTS
    // =========================================================================

    @Test
    @DisplayName("Phase 5.2 — Transaction Rollback: mid-clone RuntimeException rolls back all clone data, counter and preserves baseline")
    void testCloneRollback_FailureMidWay_RollsBackAllDataAndPreservesBaseline() {
        // 1. Create a cloner user
        User cloner = userRepository.save(User.builder()
                .username("rollback_cloner")
                .email("rollback_cloner@example.com")
                .password(passwordEncoder.encode("Password123!"))
                .fullName("Người Dùng Kiểm Thử Rollback")
                .handle("rollback_cloner")
                .status(UserStatus.ACTIVE)
                .role(Role.USER)
                .build());

        // 2. Record database baseline before clone attempt
        long baselineItinerariesCount = itineraryRepository.count();
        long baselineDaysCount = itineraryDayRepository.count();
        long baselineActivitiesCount = activityRepository.count();
        long baselineItineraryPlacesCount = itineraryPlaceRepository.count();
        long baselinePlacesCount = placeRepository.count();
        long baselineUsersCount = userRepository.count();

        Itinerary sourceBefore = itineraryRepository.findById(sourceItinerary.getItineraryId()).orElseThrow();
        int baselineReuseCount = sourceBefore.getReuseCount() != null ? sourceBefore.getReuseCount() : 0;
        assertEquals(0, baselineReuseCount, "Baseline reuse_count must be 0");

        // 3. Configure ThreadLocal fault injector to trigger mid-way after Day 1 and Activity 1 have been saved
        AtomicInteger hookInvocations = new AtomicInteger(0);
        try {
            ItineraryServiceImpl.setTestFaultInjector(() -> {
                hookInvocations.incrementAndGet();
                throw new RuntimeException("FAULT_INJECTION: Giả lập sự cố database giữa chừng trong quá trình nhân bản!");
            });

            // 4. Execute clone and verify the exception is propagated out
            RuntimeException exception = assertThrows(RuntimeException.class, () -> {
                itineraryService.cloneItinerary(sourceItinerary.getItineraryId(), cloner.getUsername());
            });

            assertTrue(exception.getMessage().contains("FAULT_INJECTION"),
                    "Exception message must match injected fault");
            assertEquals(1, hookInvocations.get(), "Fault hook must have been executed exactly once");
        } finally {
            ItineraryServiceImpl.clearTestFaultInjector();
        }

        // 5. CRITICAL VERIFICATION: Query real database AFTER rollback and compare with baseline
        long afterItinerariesCount = itineraryRepository.count();
        long afterDaysCount = itineraryDayRepository.count();
        long afterActivitiesCount = activityRepository.count();
        long afterItineraryPlacesCount = itineraryPlaceRepository.count();
        long afterPlacesCount = placeRepository.count();
        long afterUsersCount = userRepository.count();

        assertEquals(baselineItinerariesCount, afterItinerariesCount,
                "ROLLBACK INVARIANT: Total itineraries must match baseline. Cloned itinerary was not rolled back if greater!");
        assertEquals(baselineDaysCount, afterDaysCount,
                "ROLLBACK INVARIANT: Total days must match baseline. Cloned days were not rolled back if greater!");
        assertEquals(baselineActivitiesCount, afterActivitiesCount,
                "ROLLBACK INVARIANT: Total activities must match baseline. Cloned activities were not rolled back if greater!");
        assertEquals(baselineItineraryPlacesCount, afterItineraryPlacesCount,
                "ROLLBACK INVARIANT: Total itinerary_places must match baseline. Cloned places were not rolled back if greater!");
        assertEquals(baselinePlacesCount, afterPlacesCount,
                "ROLLBACK INVARIANT: Places count must remain completely unchanged");
        assertEquals(baselineUsersCount, afterUsersCount,
                "ROLLBACK INVARIANT: Users count must remain completely unchanged");

        // 6. Verify source itinerary reuse_count and data remained intact
        Itinerary sourceAfter = itineraryRepository.findById(sourceItinerary.getItineraryId()).orElseThrow();
        assertEquals(0, sourceAfter.getReuseCount(),
                "ROLLBACK INVARIANT: Source reuse_count must remain 0. Counter increment was not rolled back if > 0!");
        assertEquals("Hành Trình Gốc Kiểm Thử Concurrency & Rollback", sourceAfter.getTitle(),
                "Source title must be intact");
        assertEquals("TP. Hồ Chí Minh", sourceAfter.getLocation(),
                "Source location must be intact");
        assertEquals(new BigDecimal("3000000.00"), sourceAfter.getBudget(),
                "Source budget must be intact");

        // 7. Verify NO orphan cloned itineraries exist in the entire database
        List<Itinerary> clonedDescendants = itineraryRepository.findAll().stream()
                .filter(i -> i.getOriginalItinerary() != null && sourceItinerary.getItineraryId().equals(i.getOriginalItinerary().getItineraryId()))
                .toList();
        assertTrue(clonedDescendants.isEmpty(),
                "ROLLBACK INVARIANT: No descendants must exist for the source itinerary after failed clone");

        System.out.println(">>> Phase 5.2 Transaction Rollback Verification PASSED: All partial clone records, days, activities, and counter cleanly rolled back to pristine baseline.");
    }
}

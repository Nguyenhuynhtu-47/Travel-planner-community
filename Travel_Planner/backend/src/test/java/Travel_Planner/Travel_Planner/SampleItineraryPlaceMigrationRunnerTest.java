package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.config.SampleItineraryPlaceMigrationRunner;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.boot.test.context.SpringBootTest;

import javax.sql.DataSource;
import java.math.BigDecimal;
import java.sql.Connection;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
public class SampleItineraryPlaceMigrationRunnerTest {

    @Autowired
    private DataSource dataSource;

    @Autowired
    private SampleItineraryPlaceMigrationRunner runner;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private PlaceRepository placeRepository;

    @Autowired
    private ItineraryRepository itineraryRepository;

    @Autowired
    private ItineraryDayRepository itineraryDayRepository;

    @Autowired
    private ActivityRepository activityRepository;

    @Autowired
    private ItineraryPlaceRepository itineraryPlaceRepository;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    private User testUser;
    private Place testPlace1;
    private Place testPlace2;
    private Itinerary testItinerary;

    @BeforeEach
    void setUp() {
        cleanData();

        testUser = userRepository.save(User.builder()
                .username("sample_migration_user")
                .password("Password123!")
                .email("sample_migration@example.com")
                .fullName("Migration Test User")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(true)
                .build());

        testPlace1 = placeRepository.save(Place.builder()
                .name("Chùa Một Cột Migration")
                .address("Đội Cấn, Ba Đình, Hà Nội")
                .category(PlaceCategory.ATTRACTION)
                .latitude(new BigDecimal("21.0358"))
                .longitude(new BigDecimal("105.8335"))
                .status(PlaceStatus.ACTIVE)
                .build());

        testPlace2 = placeRepository.save(Place.builder()
                .name("Nhà hát Lớn Hà Nội Migration")
                .address("Số 1 Tràng Tiền, Hoàn Kiếm, Hà Nội")
                .category(PlaceCategory.ATTRACTION)
                .latitude(new BigDecimal("21.0244"))
                .longitude(new BigDecimal("105.8576"))
                .status(PlaceStatus.ACTIVE)
                .build());

        testItinerary = itineraryRepository.save(Itinerary.builder()
                .title("Lịch trình mẫu kiểm tra migration")
                .description("Mô tả lịch trình mẫu")
                .location("Hà Nội")
                .user(testUser)
                .status(ItineraryStatus.ACTIVE)
                .visibility(Visibility.PUBLIC)
                .totalDays(1)
                .build());

        ItineraryDay day = itineraryDayRepository.save(ItineraryDay.builder()
                .itinerary(testItinerary)
                .dayNumber(1)
                .date(LocalDate.now())
                .build());

        // Create 2 activities with canonical places
        activityRepository.save(Activity.builder()
                .itineraryDay(day)
                .place(testPlace1)
                .name("Thăm Chùa Một Cột")
                .startTime(LocalTime.of(8, 0))
                .endTime(LocalTime.of(10, 0))
                .cost(BigDecimal.ZERO)
                .displayOrder(1)
                .build());

        activityRepository.save(Activity.builder()
                .itineraryDay(day)
                .place(testPlace2)
                .name("Thăm Nhà hát Lớn")
                .startTime(LocalTime.of(10, 30))
                .endTime(LocalTime.of(12, 0))
                .cost(BigDecimal.ZERO)
                .displayOrder(2)
                .build());
    }

    @AfterEach
    void tearDown() {
        cleanData();
    }

    private void cleanData() {
        if (jdbcTemplate != null) {
            jdbcTemplate.update("DELETE FROM itinerary_places WHERE itinerary_id IN (SELECT itinerary_id FROM itineraries WHERE title = 'Lịch trình mẫu kiểm tra migration')");
            jdbcTemplate.update("DELETE FROM activities WHERE day_id IN (SELECT day_id FROM itinerary_days WHERE itinerary_id IN (SELECT itinerary_id FROM itineraries WHERE title = 'Lịch trình mẫu kiểm tra migration'))");
            jdbcTemplate.update("DELETE FROM itinerary_days WHERE itinerary_id IN (SELECT itinerary_id FROM itineraries WHERE title = 'Lịch trình mẫu kiểm tra migration')");
            jdbcTemplate.update("DELETE FROM itineraries WHERE title = 'Lịch trình mẫu kiểm tra migration'");
            jdbcTemplate.update("DELETE FROM places WHERE name IN ('Chùa Một Cột Migration', 'Nhà hát Lớn Hà Nội Migration')");
            jdbcTemplate.update("DELETE FROM users WHERE username = 'sample_migration_user' OR email = 'sample_migration@example.com'");
        }
    }

    @Test
    @DisplayName("SampleItineraryPlaceMigrationRunner should backfill missing places into itinerary_places and be idempotent")
    void testBackfillSampleItineraryPlaces_SuccessAndIdempotency() {
        // Initially, itinerary_places has no entries for testItinerary
        List<ItineraryPlace> initialPlaces = itineraryPlaceRepository.findAllByItineraryIdWithPlace(testItinerary.getItineraryId());
        assertTrue(initialPlaces.isEmpty(), "Ban đầu itinerary_places chưa có bản ghi nào");

        // Run migration runner
        int backfilled = runner.backfillSampleItineraryPlaces();
        assertTrue(backfilled >= 2, "Phải backfill ít nhất 2 địa điểm cho test itinerary, actual: " + backfilled);

        // Verify both places now linked in itinerary_places
        List<ItineraryPlace> placesAfter = itineraryPlaceRepository.findAllByItineraryIdWithPlace(testItinerary.getItineraryId());
        assertEquals(2, placesAfter.size(), "Sau backfill phải có chính xác 2 địa điểm");
        assertTrue(placesAfter.stream().anyMatch(ip -> ip.getPlace().getPlaceId().equals(testPlace1.getPlaceId())));
        assertTrue(placesAfter.stream().anyMatch(ip -> ip.getPlace().getPlaceId().equals(testPlace2.getPlaceId())));

        // Run second time to verify idempotency (no duplicates created)
        int secondRunBackfilled = runner.backfillSampleItineraryPlaces();
        assertEquals(0, secondRunBackfilled, "Lần chạy thứ 2 không được chèn thêm bản ghi nào");

        List<ItineraryPlace> placesAfterSecondRun = itineraryPlaceRepository.findAllByItineraryIdWithPlace(testItinerary.getItineraryId());
        assertEquals(2, placesAfterSecondRun.size(), "Số lượng địa điểm vẫn là 2, không bị trùng lặp");
    }

    @Test
    @DisplayName("Migration runner run(ApplicationArguments) executes without error")
    void testRun_ApplicationArguments() {
        assertDoesNotThrow(() -> runner.run(new DefaultApplicationArguments()));
    }
}

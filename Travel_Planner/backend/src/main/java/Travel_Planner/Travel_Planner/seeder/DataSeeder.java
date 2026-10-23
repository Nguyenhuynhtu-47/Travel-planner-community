package Travel_Planner.Travel_Planner.seeder;

import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.repository.*;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.*;

import org.springframework.beans.factory.annotation.Value;

@Component
public class DataSeeder implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(DataSeeder.class);
    private static final String DEFAULT_DEV_PASSWORD = "Password123!";

    @Value("${app.seed.enabled:false}")
    private boolean seedEnabled;


    private final PasswordEncoder passwordEncoder;
    private final UserRepository userRepository;
    private final DestinationRepository destinationRepository;
    private final ItineraryRepository itineraryRepository;
    private final ItineraryDayRepository itineraryDayRepository;
    private final ActivityRepository activityRepository;
    private final RatingRepository ratingRepository;
    private final CommentRepository commentRepository;
    private final FavoriteRepository favoriteRepository;
    private final SavedItineraryRepository savedItineraryRepository;
    private final FollowRepository followRepository;
    private final ItineraryShareRepository itineraryShareRepository;
    private final OfflineDownloadRepository offlineDownloadRepository;

    public DataSeeder(PasswordEncoder passwordEncoder,
                      UserRepository userRepository,
                      DestinationRepository destinationRepository,
                      ItineraryRepository itineraryRepository,
                      ItineraryDayRepository itineraryDayRepository,
                      ActivityRepository activityRepository,
                      RatingRepository ratingRepository,
                      CommentRepository commentRepository,
                      FavoriteRepository favoriteRepository,
                      SavedItineraryRepository savedItineraryRepository,
                      FollowRepository followRepository,
                      ItineraryShareRepository itineraryShareRepository,
                      OfflineDownloadRepository offlineDownloadRepository) {
        this.passwordEncoder = passwordEncoder;
        this.userRepository = userRepository;
        this.destinationRepository = destinationRepository;
        this.itineraryRepository = itineraryRepository;
        this.itineraryDayRepository = itineraryDayRepository;
        this.activityRepository = activityRepository;
        this.ratingRepository = ratingRepository;
        this.commentRepository = commentRepository;
        this.favoriteRepository = favoriteRepository;
        this.savedItineraryRepository = savedItineraryRepository;
        this.followRepository = followRepository;
        this.itineraryShareRepository = itineraryShareRepository;
        this.offlineDownloadRepository = offlineDownloadRepository;
    }

    @Override
    @Transactional
    public void run(String... args) {
        if (!seedEnabled) {
            log.info("--- [DataSeeder] Automatic startup seeding is disabled (app.seed.enabled=false). Skipping. ---");
            return;
        }
        log.info("--- [DataSeeder] Initializing realistic development seed data ---");
        SeedResult result = seedData();
        log.info("--- [DataSeeder] Completed successfully. Summary: {} ---", result);
    }


    @Transactional
    public SeedResult seedData() {
        Map<String, User> userMap = seedUsers();
        Map<String, Destination> destinationMap = seedDestinations();
        Map<String, Itinerary> itineraryMap = seedItineraries(userMap);
        seedDaysAndActivities(itineraryMap, destinationMap);
        seedSocialInteractions(userMap, itineraryMap);
        synchronizeItineraryCounters(itineraryMap);

        return SeedResult.builder()
                .usersCount(userRepository.count())
                .destinationsCount(destinationRepository.count())
                .itinerariesCount(itineraryRepository.count())
                .daysCount(itineraryDayRepository.count())
                .activitiesCount(activityRepository.count())
                .commentsCount(commentRepository.count())
                .ratingsCount(ratingRepository.count())
                .favoritesCount(favoriteRepository.count())
                .savedItinerariesCount(savedItineraryRepository.count())
                .followsCount(followRepository.count())
                .sharesCount(itineraryShareRepository.count())
                .downloadsCount(offlineDownloadRepository.count())
                .newlySeeded(true)
                .build();
    }

    private Map<String, User> seedUsers() {
        String encodedPassword = passwordEncoder.encode(DEFAULT_DEV_PASSWORD);
        Map<String, User> map = new LinkedHashMap<>();

        List<User> userDefinitions = List.of(
                User.builder()
                        .username("admin_master")
                        .password(encodedPassword)
                        .email("admin@travelplanner.local")
                        .role(Role.ADMIN)
                        .status(UserStatus.ACTIVE)
                        .fullName("Nguyễn Hoàng Nam (Admin)")
                        .phone("0901234567")
                        .address("Quận 1, TP. Hồ Chí Minh")
                        .avatar("https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&q=80")
                        .bio("Quản trị viên hệ thống Travel Planner. Đảm bảo chất lượng nội dung và an toàn cộng đồng.")
                        .build(),
                User.builder()
                        .username("traveler_viet")
                        .password(encodedPassword)
                        .email("viet.nguyen@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Nguyễn Quốc Việt")
                        .phone("0912345678")
                        .address("Cầu Giấy, Hà Nội")
                        .avatar("https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80")
                        .bio("Travel blogger & trekker. Đam mê săn mây Tây Bắc và ghi lại hành trình văn hóa Việt Nam.")
                        .build(),
                User.builder()
                        .username("wanderer_linh")
                        .password(encodedPassword)
                        .email("linh.dan@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Đặng Thùy Linh")
                        .phone("0923456789")
                        .address("Hải Châu, Đà Nẵng")
                        .avatar("https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&q=80")
                        .bio("Nhiếp ảnh gia tự do. Chuyên săn ảnh phố cổ Hội An, lăng tẩm Huế và biển đảo miền Trung.")
                        .build(),
                User.builder()
                        .username("foodie_khoa")
                        .password(encodedPassword)
                        .email("khoa.tran@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Trần Đăng Khoa")
                        .phone("0934567890")
                        .address("Bình Thạnh, TP. Hồ Chí Minh")
                        .avatar("https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80")
                        .bio("Food reviewer Sài Gòn. Tin rằng cách tốt nhất để hiểu một vùng đất là thưởng thức ẩm thực bản địa.")
                        .build(),
                User.builder()
                        .username("nature_an")
                        .password(encodedPassword)
                        .email("an.le@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Lê Hoài An")
                        .phone("0945678901")
                        .address("Đà Lạt, Lâm Đồng")
                        .avatar("https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=400&q=80")
                        .bio("Yêu thiên nhiên, đồi thông Đà Lạt và suối ngàn. Thích cắm trại, chèo SUP và du lịch bền vững.")
                        .build(),
                User.builder()
                        .username("hiker_duy")
                        .password(encodedPassword)
                        .email("duy.pham@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Phạm Đức Duy")
                        .phone("0956789012")
                        .address("Đống Đa, Hà Nội")
                        .avatar("https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=400&q=80")
                        .bio("Chinh phục các đỉnh núi Việt Nam: Fansipan, Bạch Mộc Lương Tử, Tà Xùa, Lảo Thẩn.")
                        .build(),
                User.builder()
                        .username("island_mai")
                        .password(encodedPassword)
                        .email("mai.huynh@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Huỳnh Ngọc Mai")
                        .phone("0967890123")
                        .address("Dương Đông, Phú Quốc")
                        .avatar("https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400&q=80")
                        .bio("Thợ lặn PADI. Yêu biển xanh, rạn san hô Nam Đảo Phú Quốc và văn hóa làng chài ven biển.")
                        .build(),
                User.builder()
                        .username("backpacker_tuan")
                        .password(encodedPassword)
                        .email("tuan.vu@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.ACTIVE)
                        .fullName("Vũ Minh Tuấn")
                        .phone("0978901234")
                        .address("Ninh Kiều, Cần Thơ")
                        .avatar("https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=400&q=80")
                        .bio("Phượt thủ xe máy xuyên Việt, thích ngao du các cung đường đèo và chợ nổi miền Tây.")
                        .build(),
                User.builder()
                        .username("inactive_user")
                        .password(encodedPassword)
                        .email("inactive@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.INACTIVE)
                        .fullName("Trần Thị Thanh (Chưa kích hoạt)")
                        .phone("0989012345")
                        .address("Ba Đình, Hà Nội")
                        .avatar("https://images.unsplash.com/photo-1517841905240-472988babdf9?w=400&q=80")
                        .bio("Tài khoản đang tạm dừng hoặc chưa xác thực email.")
                        .build(),
                User.builder()
                        .username("banned_spammer")
                        .password(encodedPassword)
                        .email("spammer@travelplanner.local")
                        .role(Role.USER)
                        .status(UserStatus.BANNED)
                        .fullName("Nguyễn Vi Phạm (Bị khóa)")
                        .phone("0990123456")
                        .address("Việt Nam")
                        .avatar("https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80")
                        .bio("Tài khoản đã bị cấm do vi phạm chính sách cộng đồng.")
                        .build()
        );

        for (User def : userDefinitions) {
            User existing = userRepository.findByUsername(def.getUsername())
                    .orElseGet(() -> userRepository.findByEmail(def.getEmail())
                            .orElse(null));
            if (existing != null) {
                map.put(def.getUsername(), existing);
            } else {
                User saved = userRepository.save(def);
                map.put(def.getUsername(), saved);
            }
        }

        // Also index existing user if present in local DB (e.g. minhdanh)
        userRepository.findByUsername("minhdanh").ifPresent(u -> map.put("minhdanh", u));

        return map;
    }

    private Map<String, Destination> seedDestinations() {
        Map<String, Destination> map = new LinkedHashMap<>();

        List<Destination> list = List.of(
                Destination.builder()
                        .name("Hồ Hoàn Kiếm & Phố Cổ Hà Nội")
                        .address("Hoàn Kiếm, Hà Nội")
                        .description("Trái tim của thủ đô nghìn năm văn hiến, nổi tiếng với Tháp Rùa, Cầu Thê Húc, Đền Ngọc Sơn và 36 phố phường nhộn nhịp.")
                        .imageUrl("https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&q=80")
                        .latitude(new BigDecimal("21.0285110"))
                        .longitude(new BigDecimal("105.8544441"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Văn Miếu - Quốc Tử Giám")
                        .address("58 Quốc Tử Giám, Đống Đa, Hà Nội")
                        .description("Trường đại học đầu tiên của Việt Nam, biểu tượng của tinh hoa Nho học và truyền thống hiếu học ngàn đời.")
                        .imageUrl("https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800&q=80")
                        .latitude(new BigDecimal("21.0293500"))
                        .longitude(new BigDecimal("105.8360500"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Vịnh Hạ Long")
                        .address("TP. Hạ Long, Quảng Ninh")
                        .description("Di sản thiên nhiên thế giới UNESCO với hàng nghìn hòn đảo đá vôi kỳ vĩ nhô lên giữa làn nước xanh ngọc bích.")
                        .imageUrl("https://images.unsplash.com/photo-1528127269322-539801943592?w=800&q=80")
                        .latitude(new BigDecimal("20.9100500"))
                        .longitude(new BigDecimal("107.1839000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Đỉnh Fansipan - Nóc Nhà Đông Dương")
                        .address("Sa Pa, Lào Cai")
                        .description("Đỉnh núi cao nhất bán đảo Đông Dương ở độ cao 3.143m, điểm đến trekking và săn mây huyền thoại.")
                        .imageUrl("https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=800&q=80")
                        .latitude(new BigDecimal("22.3033990"))
                        .longitude(new BigDecimal("103.7751050"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Bản Cát Cát")
                        .address("San Sả Hồ, Sa Pa, Lào Cai")
                        .description("Bản làng cổ của người H'Mông với cối xay nước, suối Mường Hoa thơ mộng và trang phục thổ cẩm rực rỡ.")
                        .imageUrl("https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80")
                        .latitude(new BigDecimal("22.3312000"))
                        .longitude(new BigDecimal("103.8329000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Quần thể danh thắng Tràng An")
                        .address("Hoa Lư, Ninh Bình")
                        .description("Di sản hỗn hợp văn hóa và thiên nhiên thế giới, nổi bật với hệ thống hang động xuyên thủy và thung lũng đá vôi ngập nước.")
                        .imageUrl("https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&q=80")
                        .latitude(new BigDecimal("20.2589000"))
                        .longitude(new BigDecimal("105.9083000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Đại Nội Huế (Hoàng Thành)")
                        .address("Thuận Thành, TP. Huế, Thừa Thiên Huế")
                        .description("Kinh đô cuối cùng của các triều đại phong kiến Việt Nam dưới triều Nguyễn, lưu giữ kiến trúc cung đình tinh xảo.")
                        .imageUrl("https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&q=80")
                        .latitude(new BigDecimal("16.4699500"))
                        .longitude(new BigDecimal("107.5794800"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Chùa Thiên Mụ")
                        .address("Đồi Hà Khê, Kim Long, TP. Huế")
                        .description("Ngôi chùa cổ kính hơn 400 năm tuổi soi bóng bên dòng sông Hương êm đềm, biểu tượng tâm linh xứ Huế.")
                        .imageUrl("https://images.unsplash.com/photo-1599707367072-cd6ada2bc375?w=800&q=80")
                        .latitude(new BigDecimal("16.4528000"))
                        .longitude(new BigDecimal("107.5452000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Phố Cổ Hội An")
                        .address("Minh An, TP. Hội An, Quảng Nam")
                        .description("Đô thị cổ thương cảng quốc tế sầm uất thế kỷ 16-17, lung linh trong ánh đèn lồng rực rỡ và những mái ngói rêu phong.")
                        .imageUrl("https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&q=80")
                        .latitude(new BigDecimal("15.8800580"))
                        .longitude(new BigDecimal("108.3380470"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Rừng Dừa Bảy Mẫu")
                        .address("Cẩm Thanh, Hội An, Quảng Nam")
                        .description("Vùng sinh thái sông nước độc đáo với trải nghiệm chèo thuyền thúng xoay điệu nghệ giữa bạt ngàn dừa nước.")
                        .imageUrl("https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80")
                        .latitude(new BigDecimal("15.8672000"))
                        .longitude(new BigDecimal("108.3719000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Bà Nà Hills & Cầu Vàng")
                        .address("Hòa Ninh, Hòa Vang, TP. Đà Nẵng")
                        .description("Khu du lịch trên đỉnh núi Chúa nổi tiếng toàn cầu với Cầu Vàng được đôi bàn tay khổng lồ rêu phong nâng đỡ.")
                        .imageUrl("https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800&q=80")
                        .latitude(new BigDecimal("15.9988500"))
                        .longitude(new BigDecimal("107.9961600"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Bán Đảo Sơn Trà & Chùa Linh Ứng")
                        .address("Hoàng Sa, Thọ Quang, Sơn Trà, TP. Đà Nẵng")
                        .description("Lá phổi xanh của Đà Nẵng nơi có tượng Phật Bà Quan Âm cao 67m hướng ra biển Đông và loài voọc chà vá chân nâu quý hiếm.")
                        .imageUrl("https://images.unsplash.com/photo-1570789210967-2cac24afeb00?w=800&q=80")
                        .latitude(new BigDecimal("16.1001000"))
                        .longitude(new BigDecimal("108.2778000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Hồ Xuân Hương & Quảng Trường Lâm Viên")
                        .address("Phường 1, TP. Đà Lạt, Lâm Đồng")
                        .description("Biểu tượng của thành phố ngàn hoa với khối nụ hoa Atiso và đóa hoa dã quỳ khổng lồ bằng kính màu rực rỡ.")
                        .imageUrl("https://images.unsplash.com/photo-1513415564515-763d91423bdd?w=800&q=80")
                        .latitude(new BigDecimal("11.9398800"))
                        .longitude(new BigDecimal("108.4449800"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Đồi Chè Cầu Đất")
                        .address("Thôn Cầu Đất, Xuân Trường, TP. Đà Lạt")
                        .description("Đồi chè trăm tuổi xanh mướt ngút ngàn, điểm săn mây bình minh tuyệt đẹp cùng các tuabin gió khổng lồ.")
                        .imageUrl("https://images.unsplash.com/photo-1544644181-1484b3fdfc62?w=800&q=80")
                        .latitude(new BigDecimal("11.9056000"))
                        .longitude(new BigDecimal("108.5442000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Chợ Bến Thành & Phố Đi Bộ Nguyễn Huệ")
                        .address("Quận 1, TP. Hồ Chí Minh")
                        .description("Trung tâm văn hóa ẩm thực và thương mại sầm uất bậc nhất Sài Gòn, nơi hội tụ nhịp sống hiện đại và di sản lịch sử.")
                        .imageUrl("https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&q=80")
                        .latitude(new BigDecimal("10.7725300"))
                        .longitude(new BigDecimal("106.6980400"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Bưu Điện Trung Tâm Sài Gòn")
                        .address("02 Công xã Paris, Bến Nghé, Quận 1, TP. Hồ Chí Minh")
                        .description("Công trình kiến trúc Pháp cổ kính xây dựng cuối thế kỷ 19, điểm check-in lịch sử và gửi bưu thiếp lưu niệm.")
                        .imageUrl("https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=800&q=80")
                        .latitude(new BigDecimal("10.7797800"))
                        .longitude(new BigDecimal("106.6999600"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Bãi Sao Phú Quốc")
                        .address("Ấp Bãi Sao, An Thới, TP. Phú Quốc, Kiên Giang")
                        .description("Một trong những bãi biển đẹp nhất Phú Quốc với bờ cát trắng mịn như kem và hàng dừa nghiêng soi bóng nước trong vắt.")
                        .imageUrl("https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80")
                        .latitude(new BigDecimal("10.0543000"))
                        .longitude(new BigDecimal("104.0322000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Quần đảo An Thới & Cáp treo Hòn Thơm")
                        .address("An Thới, TP. Phú Quốc, Kiên Giang")
                        .description("Cáp treo ba dây vượt biển dài nhất thế giới nối sang đảo Hòn Thơm và cụm đảo hoang sơ lặn ngắm san hô tự nhiên.")
                        .imageUrl("https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=800&q=80")
                        .latitude(new BigDecimal("9.9998000"))
                        .longitude(new BigDecimal("104.0189000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Chợ Nổi Cái Răng")
                        .address("Sông Cần Thơ, Cái Răng, TP. Cần Thơ")
                        .description("Chợ nổi đặc trưng của miền Tây Nam Bộ với hàng trăm ghe xuồng buôn bán nông sản, bún riêu trên sông buổi sáng sớm.")
                        .imageUrl("https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800&q=80")
                        .latitude(new BigDecimal("10.0035000"))
                        .longitude(new BigDecimal("105.7483000"))
                        .status(DestinationStatus.ACTIVE)
                        .build(),
                Destination.builder()
                        .name("Khu bảo tồn thiên nhiên Đang Cải Tạo (Tạm Đóng)")
                        .address("Phong Nha, Bố Trạch, Quảng Bình")
                        .description("Khu vực đang tạm thời bảo tồn và cải tạo sinh thái, không mở cửa cho du khách tự do thăm quan.")
                        .imageUrl("https://images.unsplash.com/photo-1448375240586-882707db888b?w=800&q=80")
                        .latitude(new BigDecimal("17.5890000"))
                        .longitude(new BigDecimal("106.2830000"))
                        .status(DestinationStatus.HIDDEN)
                        .build()
        );

        for (Destination d : list) {
            Destination existing = destinationRepository.findByName(d.getName()).orElse(null);
            if (existing != null) {
                map.put(d.getName(), existing);
            } else {
                Destination saved = destinationRepository.save(d);
                map.put(d.getName(), saved);
            }
        }

        return map;
    }

    private Map<String, Itinerary> seedItineraries(Map<String, User> userMap) {
        Map<String, Itinerary> map = new LinkedHashMap<>();

        User viet = userMap.get("traveler_viet");
        User linh = userMap.get("wanderer_linh");
        User khoa = userMap.get("foodie_khoa");
        User an = userMap.get("nature_an");
        User duy = userMap.get("hiker_duy");
        User mai = userMap.get("island_mai");
        User tuan = userMap.get("backpacker_tuan");
        User spammer = userMap.get("banned_spammer");

        // Base parent itinerary: Sa Pa Trekking by hiker_duy
        Itinerary saPaBase = saveOrGetItinerary(Itinerary.builder()
                .user(duy)
                .title("Trekking Sa Pa - Chinh Phục Đỉnh Fansipan 3N2Đ")
                .description("Hành trình leo núi Fansipan bằng đường bộ, băng qua rừng đỗ quyên cổ thụ và cắm trại ngắm dải ngân hà ở trạm 2800m.")
                .location("Sa Pa, Lào Cai")
                .coverImage("https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("4800000.00"))
                .theme("Phiêu lưu")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1240)
                .favoriteCount(85)
                .ratingCount(12)
                .commentCount(8)
                .reuseCount(5)
                .build());
        map.put("sa_pa_trekking", saPaBase);

        // Derived personalized itinerary from saPaBase by foodie_khoa
        Itinerary saPaPersonalized = saveOrGetItinerary(Itinerary.builder()
                .user(khoa)
                .originalItinerary(saPaBase)
                .title("Fansipan & Săn Mây Sa Pa Cá Nhân Hóa (Bản nhẹ nhàng)")
                .description("Bản tái sử dụng từ lịch trình trekking của bạn Duy, điều chỉnh sang đi cáp treo Fansipan và dành thời gian thưởng thức lẩu cá tầm bản địa.")
                .location("Sa Pa, Lào Cai")
                .coverImage("https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("5200000.00"))
                .theme("Ẩm thực")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(580)
                .favoriteCount(32)
                .ratingCount(6)
                .commentCount(4)
                .reuseCount(0)
                .build());
        map.put("sa_pa_derived", saPaPersonalized);

        // Itinerary 1: Ha Noi Food & Heritage by viet
        map.put("hanoi_food", saveOrGetItinerary(Itinerary.builder()
                .user(viet)
                .title("Khám phá 36 Phố Phường Hà Nội & Ẩm thực Thủ Đô 2N1Đ")
                .description("Lịch trình dạo quanh Hồ Hoàn Kiếm, ngắm hoàng hôn Hồ Tây, thưởng thức phở Bát Đàn, bún chả Hàng Quạt và cà phê trứng Giảng trứ danh.")
                .location("Hà Nội")
                .coverImage("https://images.unsplash.com/photo-1509042239860-f550ce710b93?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("2500000.00"))
                .theme("Ẩm thực")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(2100)
                .favoriteCount(145)
                .ratingCount(24)
                .commentCount(15)
                .reuseCount(18)
                .build()));

        // Itinerary 2: Da Nang - Hoi An by linh
        map.put("danang_hoian", saveOrGetItinerary(Itinerary.builder()
                .user(linh)
                .title("Hành Trình Di Sản Miền Trung: Đà Nẵng - Hội An 4N3Đ")
                .description("Check-in Cầu Vàng Bà Nà Hills, lặn ngắm san hô Cù Lao Chàm, dạo phố cổ Hội An đêm rằm lung linh hoa đăng.")
                .location("Đà Nẵng")
                .coverImage("https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=800&q=80")
                .totalDays(4)
                .budget(new BigDecimal("6500000.00"))
                .theme("Văn hóa")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(3450)
                .favoriteCount(230)
                .ratingCount(35)
                .commentCount(22)
                .reuseCount(28)
                .build()));

        // Itinerary 3: Da Lat Cloud Hunting by an
        map.put("dalat_clouds", saveOrGetItinerary(Itinerary.builder()
                .user(an)
                .title("Đà Lạt Mộng Mơ: Săn Mây, Cà Phê & Đồi Chè 3N2Đ")
                .description("Thức dậy sớm đón bình minh biển mây Cầu Đất, dạo quanh Hồ Xuân Hương thơ mộng và thưởng thức bánh tráng nướng đêm lạnh.")
                .location("Đà Lạt, Lâm Đồng")
                .coverImage("https://images.unsplash.com/photo-1513415564515-763d91423bdd?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("3800000.00"))
                .theme("Khám phá")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(4120)
                .favoriteCount(310)
                .ratingCount(42)
                .commentCount(29)
                .reuseCount(35)
                .build()));

        // Itinerary 4: Phu Quoc Resort by mai
        map.put("phuquoc_resort", saveOrGetItinerary(Itinerary.builder()
                .user(mai)
                .title("Nghỉ Dưỡng Thiên Đường Biển Đảo Phú Quốc 4N3Đ")
                .description("Trải nghiệm cáp treo Hòn Thơm vượt biển, tắm biển Bãi Sao cát trắng, ngắm hoàng hôn Sunset Sanato và hải sản Hàm Ninh tươi ngon.")
                .location("Phú Quốc, Kiên Giang")
                .coverImage("https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80")
                .totalDays(4)
                .budget(new BigDecimal("12000000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(2890)
                .favoriteCount(190)
                .ratingCount(28)
                .commentCount(16)
                .reuseCount(14)
                .build()));

        // Itinerary 5: Ninh Binh Trang An by tuan
        map.put("ninhbinh_trangan", saveOrGetItinerary(Itinerary.builder()
                .user(tuan)
                .title("Hà Nội - Ninh Bình - Tràng An Non Nước Hữu Tình 2N1Đ")
                .description("Ngồi thuyền nan xuôi dòng Sào Khê khám phá các hang động Tràng An, leo đỉnh Hang Múa ngắm toàn cảnh thung lũng Tam Cốc mùa lúa chín.")
                .location("Ninh Bình")
                .coverImage("https://images.unsplash.com/photo-1578632767115-351597cf2477?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("2200000.00"))
                .theme("Sinh thái")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1670)
                .favoriteCount(115)
                .ratingCount(18)
                .commentCount(9)
                .reuseCount(11)
                .build()));

        // Itinerary 6: Hue Imperial Heritage by linh
        map.put("hue_heritage", saveOrGetItinerary(Itinerary.builder()
                .user(linh)
                .title("Hành Trình Di Sản Cố Đô Huế: Lăng Tẩm & Ẩm Thực Cung Đình 2N2Đ")
                .description("Thăm Đại Nội uy nghiêm, lắng nghe nhã nhạc cung đình Huế trên thuyền rồng sông Hương, thưởng thức bún bò mụ Rơi và bánh bèo nậm lọc.")
                .location("Huế, Thừa Thiên Huế")
                .coverImage("https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("3200000.00"))
                .theme("Văn hóa")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1520)
                .favoriteCount(98)
                .ratingCount(16)
                .commentCount(11)
                .reuseCount(8)
                .build()));

        // Itinerary 7: Ha Long Bay Cruise by an
        map.put("halong_cruise", saveOrGetItinerary(Itinerary.builder()
                .user(an)
                .title("Du Thuyền Vịnh Hạ Long & Ngắm Hoàng Hôn 2N1Đ")
                .description("Nghỉ dưỡng trên du thuyền 5 sao vịnh Hạ Long, chèo thuyền kayak hang Luồn, tắm biển đảo Ti Tốp và câu mực đêm giữa kỳ quan thế giới.")
                .location("Hạ Long, Quảng Ninh")
                .coverImage("https://images.unsplash.com/photo-1528127269322-539801943592?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("4500000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(2340)
                .favoriteCount(165)
                .ratingCount(22)
                .commentCount(14)
                .reuseCount(12)
                .build()));

        // Itinerary 8: Sai Gon 1 Day by khoa
        map.put("saigon_oneday", saveOrGetItinerary(Itinerary.builder()
                .user(khoa)
                .title("Sài Gòn Sôi Động: Lịch Sử Kiến Trúc & Cà Phê Bệt 1 Ngày")
                .description("Check-in Nhà Thờ Đức Bà, Bưu Điện Thành Phố, dạo chợ Bến Thành, ăn cơm tấm Ba Ghiền và ngắm hoàng hôn Landmark 81 ven sông Sài Gòn.")
                .location("TP. Hồ Chí Minh")
                .coverImage("https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=800&q=80")
                .totalDays(1)
                .budget(new BigDecimal("1200000.00"))
                .theme("Ẩm thực")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(980)
                .favoriteCount(68)
                .ratingCount(9)
                .commentCount(6)
                .reuseCount(7)
                .build()));

        // Itinerary 9: Can Tho Floating Market by viet
        map.put("cantho_market", saveOrGetItinerary(Itinerary.builder()
                .user(viet)
                .title("Miền Tây Sông Nước: Chợ Nổi Cái Răng & Vườn Trái Cây Cần Thơ 2N1Đ")
                .description("Hòa mình vào nếp sống chợ nổi lúc rạng sáng, thưởng thức hủ tiếu gõ nóng hổi trên ghe, đạp xe dưới rặng dừa vườn du lịch Phong Điền.")
                .location("Cần Thơ")
                .coverImage("https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("2800000.00"))
                .theme("Sinh thái")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1380)
                .favoriteCount(82)
                .ratingCount(14)
                .commentCount(8)
                .reuseCount(6)
                .build()));

        // Itinerary 10: Phu Quoc Diving by mai
        map.put("phuquoc_diving", saveOrGetItinerary(Itinerary.builder()
                .user(mai)
                .title("Phú Quốc Lặn San Hô Quần Đảo An Thới & Sunset Sanato 3N2Đ")
                .description("Tour cano 4 đảo Nam Phú Quốc: hòn Mây Rút, hòn Gầm Ghì lặn ngắm san hô rực rỡ, câu cá biển và ngắm hoàng hôn ráng chiều tuyệt đẹp.")
                .location("Phú Quốc, Kiên Giang")
                .coverImage("https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("8500000.00"))
                .theme("Biển đảo")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1950)
                .favoriteCount(140)
                .ratingCount(20)
                .commentCount(10)
                .reuseCount(9)
                .build()));

        // Itinerary 11: Da Lat Camping by duy
        map.put("dalat_camping", saveOrGetItinerary(Itinerary.builder()
                .user(duy)
                .title("Đà Lạt Mùa Dã Quỳ: Cắm Trại Đỉnh Langbiang & Suối Vàng 2N1Đ")
                .description("Trải nghiệm ngủ lều đêm giữa rừng thông, đốt lửa trại nướng gà đồi và đón bình minh sương mù thung lũng Vàng thanh khiết.")
                .location("Đà Lạt, Lâm Đồng")
                .coverImage("https://images.unsplash.com/photo-1544644181-1484b3fdfc62?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("2600000.00"))
                .theme("Phiêu lưu")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(1120)
                .favoriteCount(76)
                .ratingCount(11)
                .commentCount(5)
                .reuseCount(4)
                .build()));

        // Itinerary 12: Private Itinerary 1 by an
        map.put("private_honeymoon", saveOrGetItinerary(Itinerary.builder()
                .user(an)
                .title("Kế hoạch trăng mật riêng tư Đà Lạt (Chuyến đi bí mật)")
                .description("Lịch trình cá nhân bí mật dành cho kỳ nghỉ trăng mật riêng tư, không công khai trên bản tin cộng đồng.")
                .location("Đà Lạt, Lâm Đồng")
                .coverImage("https://images.unsplash.com/photo-1513415564515-763d91423bdd?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("9000000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(15)
                .favoriteCount(1)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .build()));

        // Itinerary 13: Private Itinerary 2 by tuan
        map.put("private_northwest", saveOrGetItinerary(Itinerary.builder()
                .user(tuan)
                .title("Lịch trình dự thảo khám phá Tây Bắc (Chưa công bố)")
                .description("Bản nháp kế hoạch phượt độc hành cung đường Y Tý - Ô Quy Hồ - Mù Cang Chải đang được hoàn thiện.")
                .location("Sa Pa, Lào Cai")
                .coverImage("https://images.unsplash.com/photo-1570168007204-dfb528c6958f?w=800&q=80")
                .totalDays(5)
                .budget(new BigDecimal("7500000.00"))
                .theme("Phiêu lưu")
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(8)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .build()));

        // Itinerary 14: Moderated Hidden Itinerary by viet
        map.put("hidden_itinerary", saveOrGetItinerary(Itinerary.builder()
                .user(viet)
                .title("Lịch trình vi phạm quảng cáo bị quản trị viên ẩn")
                .description("Nội dung chứa liên kết thương mại trái phép, đã được hệ thống quản trị viên ẩn khỏi trang khám phá cộng đồng.")
                .location("Đà Nẵng")
                .coverImage("https://images.unsplash.com/photo-1569154941061-e231b4725ef1?w=800&q=80")
                .totalDays(2)
                .budget(new BigDecimal("3000000.00"))
                .theme("Khám phá")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.HIDDEN)
                .viewCount(120)
                .favoriteCount(2)
                .ratingCount(1)
                .commentCount(1)
                .reuseCount(0)
                .build()));

        // Itinerary 15: Soft Deleted Itinerary by khoa
        map.put("deleted_itinerary", saveOrGetItinerary(Itinerary.builder()
                .user(khoa)
                .title("Lịch trình cũ đã bị người dùng xóa")
                .description("Lịch trình này đã bị chủ sở hữu thực hiện thao tác xóa mềm.")
                .location("Hà Nội")
                .coverImage("https://images.unsplash.com/photo-1596422846543-75c6fc197f07?w=800&q=80")
                .totalDays(1)
                .budget(new BigDecimal("1500000.00"))
                .theme("Văn hóa")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.DELETED)
                .viewCount(45)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .build()));

        // Itinerary 16: Banned User Itinerary
        map.put("banned_itinerary", saveOrGetItinerary(Itinerary.builder()
                .user(spammer)
                .title("Spam quảng cáo tour lừa đảo (Tài khoản bị khóa)")
                .description("Lịch trình do tài khoản vi phạm tiêu chuẩn đăng tải, phải bị loại khỏi kết quả Explore.")
                .location("Nha Trang, Khánh Hòa")
                .coverImage("https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=800&q=80")
                .totalDays(3)
                .budget(new BigDecimal("1000000.00"))
                .theme("Nghỉ dưỡng")
                .visibility(Visibility.PUBLIC)
                .status(ItineraryStatus.ACTIVE)
                .viewCount(500)
                .favoriteCount(0)
                .ratingCount(0)
                .commentCount(0)
                .reuseCount(0)
                .build()));

        return map;
    }

    private Itinerary saveOrGetItinerary(Itinerary itin) {
        return itineraryRepository.findByTitleAndUser_UserId(itin.getTitle(), itin.getUser().getUserId())
                .orElseGet(() -> itineraryRepository.save(itin));
    }

    private void seedDaysAndActivities(Map<String, Itinerary> itineraryMap, Map<String, Destination> destinationMap) {
        Destination hanoiLake = destinationMap.get("Hồ Hoàn Kiếm & Phố Cổ Hà Nội");
        Destination vanMieu = destinationMap.get("Văn Miếu - Quốc Tử Giám");
        Destination fansipan = destinationMap.get("Đỉnh Fansipan - Nóc Nhà Đông Dương");
        Destination catCat = destinationMap.get("Bản Cát Cát");
        Destination baNa = destinationMap.get("Bà Nà Hills & Cầu Vàng");
        Destination sonTra = destinationMap.get("Bán Đảo Sơn Trà & Chùa Linh Ứng");
        Destination hoiAn = destinationMap.get("Phố Cổ Hội An");
        Destination bayMau = destinationMap.get("Rừng Dừa Bảy Mẫu");
        Destination xuanHuong = destinationMap.get("Hồ Xuân Hương & Quảng Trường Lâm Viên");
        Destination cauDat = destinationMap.get("Đồi Chè Cầu Đất");
        Destination baiSao = destinationMap.get("Bãi Sao Phú Quốc");
        Destination anThoi = destinationMap.get("Quần đảo An Thới & Cáp treo Hòn Thơm");
        Destination trangAn = destinationMap.get("Quần thể danh thắng Tràng An");
        Destination daiNoi = destinationMap.get("Đại Nội Huế (Hoàng Thành)");
        Destination thienMu = destinationMap.get("Chùa Thiên Mụ");
        Destination haLong = destinationMap.get("Vịnh Hạ Long");
        Destination benThanh = destinationMap.get("Chợ Bến Thành & Phố Đi Bộ Nguyễn Huệ");
        Destination buuDien = destinationMap.get("Bưu Điện Trung Tâm Sài Gòn");
        Destination caiRang = destinationMap.get("Chợ Nổi Cái Răng");

        // Seed details for each itinerary
        for (Itinerary itin : itineraryMap.values()) {
            int days = itin.getTotalDays();
            for (int dayNum = 1; dayNum <= days; dayNum++) {
                final int finalDayNum = dayNum;
                ItineraryDay day = itineraryDayRepository.findByItinerary_ItineraryIdAndDayNumber(itin.getItineraryId(), dayNum)
                        .orElseGet(() -> itineraryDayRepository.save(ItineraryDay.builder()
                                .itinerary(itin)
                                .dayNumber(finalDayNum)
                                .title("Ngày " + finalDayNum + ": Khám phá " + itin.getLocation())
                                .date(LocalDate.now().plusDays(finalDayNum))
                                .build()));

                // Assign activities according to location
                seedActivitiesForDay(day, itin.getLocation(), dayNum, destinationMap);
            }
        }
    }

    private void seedActivitiesForDay(ItineraryDay day, String location, int dayNum, Map<String, Destination> destinationMap) {
        // Fallback default destination if specific destination not determined
        Destination defaultDest = destinationMap.get("Hồ Hoàn Kiếm & Phố Cổ Hà Nội");

        if (location.contains("Hà Nội")) {
            saveActivityIfNotExists(day, 1, "Ăn sáng Phở Bát Đàn & cà phê Giảng",
                    "Thưởng thức bát phở bò truyền thống phố cổ và nhâm nhi ly cà phê trứng trứ danh.",
                    LocalTime.of(7, 30), LocalTime.of(9, 0), new BigDecimal("120000.00"),
                    destinationMap.getOrDefault("Hồ Hoàn Kiếm & Phố Cổ Hà Nội", defaultDest));
            saveActivityIfNotExists(day, 2, "Thăm Văn Miếu - Quốc Tử Giám",
                    "Tìm hiểu lịch sử khoa bảng Việt Nam và dạo bước trong khuôn viên rợp bóng cây cổ thụ.",
                    LocalTime.of(9, 30), LocalTime.of(11, 30), new BigDecimal("70000.00"),
                    destinationMap.getOrDefault("Văn Miếu - Quốc Tử Giám", defaultDest));
            saveActivityIfNotExists(day, 3, "Dạo quanh Hồ Gươm và Cầu Thê Húc",
                    "Ngắm Tháp Rùa lúc hoàng hôn buông xuống và trải nghiệm không gian đi bộ phố cổ.",
                    LocalTime.of(16, 0), LocalTime.of(18, 30), new BigDecimal("50000.00"),
                    destinationMap.getOrDefault("Hồ Hoàn Kiếm & Phố Cổ Hà Nội", defaultDest));
        } else if (location.contains("Sa Pa")) {
            Destination targetDest = (dayNum == 1)
                    ? destinationMap.getOrDefault("Bản Cát Cát", defaultDest)
                    : destinationMap.getOrDefault("Đỉnh Fansipan - Nóc Nhà Đông Dương", defaultDest);
            saveActivityIfNotExists(day, 1, "Thăm bản Cát Cát & check-in cối xay nước",
                    "Đi dạo bản làng người H'Mông, thuê trang phục dân tộc chụp ảnh bên suối Mường Hoa.",
                    LocalTime.of(8, 0), LocalTime.of(11, 30), new BigDecimal("150000.00"),
                    targetDest);
            saveActivityIfNotExists(day, 2, "Chinh phục đỉnh Fansipan săn biển mây",
                    "Lên nóc nhà Đông Dương ngắm toàn cảnh dãy Hoàng Liên Sơn hùng vĩ.",
                    LocalTime.of(13, 30), LocalTime.of(17, 0), new BigDecimal("850000.00"),
                    destinationMap.getOrDefault("Đỉnh Fansipan - Nóc Nhà Đông Dương", defaultDest));
        } else if (location.contains("Đà Nẵng") || location.contains("Hội An")) {
            Destination targetDest1 = destinationMap.getOrDefault("Bà Nà Hills & Cầu Vàng", defaultDest);
            Destination targetDest2 = destinationMap.getOrDefault("Phố Cổ Hội An", defaultDest);
            Destination targetDest3 = destinationMap.getOrDefault("Bán Đảo Sơn Trà & Chùa Linh Ứng", defaultDest);

            saveActivityIfNotExists(day, 1, "Khám phá Cầu Vàng và Làng Pháp Bà Nà Hills",
                    "Trải nghiệm cáp treo đạt kỷ lục thế giới và dạo bước trên Cầu Vàng mây phủ.",
                    LocalTime.of(8, 0), LocalTime.of(12, 30), new BigDecimal("950000.00"),
                    targetDest1);
            saveActivityIfNotExists(day, 2, "Viếng Chùa Linh Ứng Sơn Trà",
                    "Chiêm bái tượng Phật Bà Quan Âm cao 67m hướng nhìn trọn vịnh Đà Nẵng tuyệt mỹ.",
                    LocalTime.of(14, 0), LocalTime.of(16, 0), new BigDecimal("0.00"),
                    targetDest3);
            saveActivityIfNotExists(day, 3, "Thả đèn hoa đăng Phố Cổ Hội An",
                    "Ngồi thuyền gỗ trên sông Hoài, thả hoa đăng nguyện ước và ăn cao lầu Bà Bé.",
                    LocalTime.of(17, 30), LocalTime.of(21, 0), new BigDecimal("250000.00"),
                    targetDest2);
        } else if (location.contains("Đà Lạt")) {
            Destination xh = destinationMap.getOrDefault("Hồ Xuân Hương & Quảng Trường Lâm Viên", defaultDest);
            Destination cd = destinationMap.getOrDefault("Đồi Chè Cầu Đất", defaultDest);

            saveActivityIfNotExists(day, 1, "Săn mây bình minh Đồi Chè Cầu Đất",
                    "Thức dậy sớm từ 4h30, đón khoảnh khắc mặt trời ló rạng giữa biển mây bồng bềnh.",
                    LocalTime.of(5, 0), LocalTime.of(8, 30), new BigDecimal("100000.00"),
                    cd);
            saveActivityIfNotExists(day, 2, "Dạo Quảng trường Lâm Viên & cà phê ven Hồ Xuân Hương",
                    "Chụp ảnh khối nụ Atiso khổng lồ, đạp vịt ngắm hồ và thưởng thức cà phê nóng.",
                    LocalTime.of(14, 30), LocalTime.of(17, 0), new BigDecimal("80000.00"),
                    xh);
            saveActivityIfNotExists(day, 3, "Thưởng thức lẩu gà lá é & chợ đêm Đà Lạt",
                    "Bữa tối ấm cúng với lẩu gà lá é Tao Ngộ và ăn sữa đậu nành nóng hổi.",
                    LocalTime.of(18, 30), LocalTime.of(21, 30), new BigDecimal("200000.00"),
                    xh);
        } else if (location.contains("Phú Quốc")) {
            Destination bs = destinationMap.getOrDefault("Bãi Sao Phú Quốc", defaultDest);
            Destination at = destinationMap.getOrDefault("Quần đảo An Thới & Cáp treo Hòn Thơm", defaultDest);

            saveActivityIfNotExists(day, 1, "Đi cáp treo Hòn Thơm vượt biển Nam Phú Quốc",
                    "Ngắm toàn cảnh biển ngọc bích từ cabin cáp treo và vui chơi công viên nước Aquatopia.",
                    LocalTime.of(8, 30), LocalTime.of(13, 0), new BigDecimal("650000.00"),
                    at);
            saveActivityIfNotExists(day, 2, "Tắm biển và nghỉ ngơi tại Bãi Sao",
                    "Tận hưởng bờ cát trắng mịn như kem, chụp ảnh cây dừa nghiêng huyền thoại.",
                    LocalTime.of(14, 30), LocalTime.of(17, 30), new BigDecimal("150000.00"),
                    bs);
        } else if (location.contains("Ninh Bình")) {
            Destination ta = destinationMap.getOrDefault("Quần thể danh thắng Tràng An", defaultDest);
            saveActivityIfNotExists(day, 1, "Ngồi thuyền nan khám phá hang động Tràng An",
                    "Chuyến đò 3 tiếng qua Hang Tối, Hang Sáng, Hang Nấu Rượu và Phim trường Kong.",
                    LocalTime.of(8, 0), LocalTime.of(12, 0), new BigDecimal("250000.00"),
                    ta);
            saveActivityIfNotExists(day, 2, "Thưởng thức đặc sản dê núi Ninh Bình và cơm cháy",
                    "Bữa trưa đặc sản bản địa thơm ngon giàu hương vị truyền thống.",
                    LocalTime.of(12, 30), LocalTime.of(14, 0), new BigDecimal("200000.00"),
                    ta);
        } else if (location.contains("Huế")) {
            Destination dn = destinationMap.getOrDefault("Đại Nội Huế (Hoàng Thành)", defaultDest);
            Destination tm = destinationMap.getOrDefault("Chùa Thiên Mụ", defaultDest);
            saveActivityIfNotExists(day, 1, "Tham quan Hoàng Thành Đại Nội Huế",
                    "Chiêm ngưỡng Điện Thái Hòa, Ngọ Môn và Cung Diên Thọ.",
                    LocalTime.of(8, 0), LocalTime.of(11, 30), new BigDecimal("200000.00"),
                    dn);
            saveActivityIfNotExists(day, 2, "Viếng Chùa Thiên Mụ và ngắm hoàng hôn sông Hương",
                    "Ngắm Tháp Phước Duyên cổ kính và lắng nghe tiếng chuông chùa thanh tịnh.",
                    LocalTime.of(15, 0), LocalTime.of(17, 30), new BigDecimal("50000.00"),
                    tm);
        } else if (location.contains("Hạ Long")) {
            Destination hl = destinationMap.getOrDefault("Vịnh Hạ Long", defaultDest);
            saveActivityIfNotExists(day, 1, "Khởi hành du thuyền ngắm vịnh di sản Hạ Long",
                    "Du thuyền lướt qua Hòn Đỉnh Hương, Hòn Gà Chọi và thưởng thức bữa trưa hải sản tươi sống.",
                    LocalTime.of(9, 0), LocalTime.of(14, 0), new BigDecimal("1200000.00"),
                    hl);
            saveActivityIfNotExists(day, 2, "Chèo thuyền Kayak hang Luồn & tắm biển đảo Ti Tốp",
                    "Tự tay chèo kayak luồn qua vòm hang đá vôi và leo 400 bậc ngắm toàn cảnh vịnh từ đỉnh Ti Tốp.",
                    LocalTime.of(14, 30), LocalTime.of(17, 30), new BigDecimal("350000.00"),
                    hl);
        } else if (location.contains("TP. Hồ Chí Minh")) {
            Destination bt = destinationMap.getOrDefault("Chợ Bến Thành & Phố Đi Bộ Nguyễn Huệ", defaultDest);
            Destination bd = destinationMap.getOrDefault("Bưu Điện Trung Tâm Sài Gòn", defaultDest);
            saveActivityIfNotExists(day, 1, "Thăm Bưu Điện Trung Tâm và Nhà Thờ Đức Bà",
                    "Ngắm kiến trúc Gothic châu Âu cổ kính và gửi bưu thiếp tay lưu niệm.",
                    LocalTime.of(8, 30), LocalTime.of(11, 0), new BigDecimal("40000.00"),
                    bd);
            saveActivityIfNotExists(day, 2, "Ẩm thực Chợ Bến Thành & dạo phố đi bộ Nguyễn Huệ",
                    "Thưởng thức gỏi cuốn, bánh xèo, chè ba màu và trải nghiệm nhịp sống sôi động về đêm.",
                    LocalTime.of(15, 0), LocalTime.of(19, 0), new BigDecimal("250000.00"),
                    bt);
        } else if (location.contains("Cần Thơ")) {
            Destination cr = destinationMap.getOrDefault("Chợ Nổi Cái Răng", defaultDest);
            saveActivityIfNotExists(day, 1, "Đi thuyền sớm khám phá Chợ Nổi Cái Răng",
                    "Ăn tô bún riêu cua bốc khói nghi ngút trên ghe thuyền dập dềnh sóng nước miền Tây.",
                    LocalTime.of(5, 30), LocalTime.of(9, 0), new BigDecimal("180000.00"),
                    cr);
            saveActivityIfNotExists(day, 2, "Ghé thăm vườn trái cây Phong Điền",
                    "Tự tay hái và thưởng thức chôm chôm, măng cụt, dâu Hạ Châu chín mọng tại vườn.",
                    LocalTime.of(10, 0), LocalTime.of(13, 30), new BigDecimal("120000.00"),
                    cr);
        } else {
            saveActivityIfNotExists(day, 1, "Hoạt động tham quan buổi sáng",
                    "Khám phá cảnh quan thiên nhiên và trải nghiệm văn hóa địa phương.",
                    LocalTime.of(8, 0), LocalTime.of(11, 30), new BigDecimal("100000.00"),
                    defaultDest);
            saveActivityIfNotExists(day, 2, "Hoạt động thư giãn buổi chiều",
                    "Dạo bước ngắm cảnh, thưởng thức đặc sản và chụp ảnh kỷ niệm.",
                    LocalTime.of(14, 0), LocalTime.of(17, 30), new BigDecimal("150000.00"),
                    defaultDest);
        }
    }

    private void saveActivityIfNotExists(ItineraryDay day, int order, String name, String desc,
                                         LocalTime start, LocalTime end, BigDecimal cost, Destination destination) {
        if (!activityRepository.existsByItineraryDay_DayIdAndDisplayOrder(day.getDayId(), order)) {
            activityRepository.save(Activity.builder()
                    .itineraryDay(day)
                    .destination(destination)
                    .name(name)
                    .description(desc)
                    .startTime(start)
                    .endTime(end)
                    .cost(cost)
                    .displayOrder(order)
                    .build());
        }
    }

    private void seedSocialInteractions(Map<String, User> userMap, Map<String, Itinerary> itineraryMap) {
        User viet = userMap.get("traveler_viet");
        User linh = userMap.get("wanderer_linh");
        User khoa = userMap.get("foodie_khoa");
        User an = userMap.get("nature_an");
        User duy = userMap.get("hiker_duy");
        User mai = userMap.get("island_mai");
        User tuan = userMap.get("backpacker_tuan");

        Itinerary hanoi = itineraryMap.get("hanoi_food");
        Itinerary danang = itineraryMap.get("danang_hoian");
        Itinerary dalat = itineraryMap.get("dalat_clouds");
        Itinerary phuquoc = itineraryMap.get("phuquoc_resort");
        Itinerary sapa = itineraryMap.get("sa_pa_trekking");
        Itinerary sapaDerived = itineraryMap.get("sa_pa_derived");
        Itinerary ninhbinh = itineraryMap.get("ninhbinh_trangan");
        Itinerary hue = itineraryMap.get("hue_heritage");

        // 1. Comments
        saveCommentIfNotExists(khoa, hanoi, "Lịch trình rất chi tiết! Mình đã thử quán phở Bát Đàn đúng như gợi ý, nước dùng thanh ngọt tuyệt vời.", CommentStatus.ACTIVE);
        saveCommentIfNotExists(linh, hanoi, "Cà phê Giảng buổi sáng ngắm đường phố Hà Nội rất chill. Cảm ơn bạn Việt đã chia sẻ!", CommentStatus.ACTIVE);
        saveCommentIfNotExists(viet, danang, "Hình ảnh Cầu Vàng bạn chụp đẹp xuất sắc! Bạn đi vào khung giờ nào để vắng khách vậy?", CommentStatus.ACTIVE);
        saveCommentIfNotExists(linh, danang, "Mình lên Bà Nà chuyến cáp treo đầu tiên lúc 7h30 sáng nên chụp được góc không người rất đẹp nha bạn Việt!", CommentStatus.ACTIVE);
        saveCommentIfNotExists(duy, dalat, "Cung săn mây Cầu Đất này quá đỉnh. Đường đi sáng sớm có bị sương mù nhiều không tác giả?", CommentStatus.ACTIVE);
        saveCommentIfNotExists(an, dalat, "Tầm 5h sáng sương hơi dày bạn nhé, nên chạy xe máy chậm và bật đèn pha vàng để an toàn.", CommentStatus.ACTIVE);
        saveCommentIfNotExists(mai, phuquoc, "Bãi Sao mùa này biển êm như gương, cát mịn không tì vết. Review rất có tâm!", CommentStatus.ACTIVE);
        saveCommentIfNotExists(tuan, sapa, "Đoạn leo trạm 2800m cần thể lực tốt không anh Duy? Em dự định đi vào tháng tới.", CommentStatus.ACTIVE);
        saveCommentIfNotExists(duy, sapa, "Cần tập leo cầu thang trước 2 tuần nhé Tuấn. Mang giày leo núi có độ bám tốt là đi ổn!", CommentStatus.ACTIVE);
        saveCommentIfNotExists(an, ninhbinh, "Mùa lúa chín Tràng An - Tam Cốc vàng rực rỡ, nhìn từ Hang Múa xuống như bức tranh thủy mặc.", CommentStatus.ACTIVE);
        saveCommentIfNotExists(khoa, hue, "Bún bò Huế ở mụ Rơi chuẩn vị đậm đà thơm mùi sả ruốc. Lịch trình rất hợp lý cho 2 ngày.", CommentStatus.ACTIVE);
        saveCommentIfNotExists(viet, sapaDerived, "Bản tùy biến này rất phù hợp với gia đình có người lớn tuổi hoặc bạn nào không quen trekking nặng. Vote 5 sao!", CommentStatus.ACTIVE);

        // Moderation test comments: HIDDEN and DELETED
        saveCommentIfNotExists(khoa, dalat, "Bình luận chứa nội dung quảng cáo spam đã được admin ẩn", CommentStatus.HIDDEN);
        saveCommentIfNotExists(duy, danang, "Bình luận cũ đã bị người dùng xóa", CommentStatus.DELETED);

        // 2. Ratings (Scores: 1..5 stars)
        // High rated trips (>= 4.5 average with multiple ratings) trigger the "Yêu thích" badge!
        saveRatingIfNotExists(khoa, hanoi, 5);
        saveRatingIfNotExists(linh, hanoi, 5);
        saveRatingIfNotExists(an, hanoi, 4);
        saveRatingIfNotExists(duy, hanoi, 5);

        saveRatingIfNotExists(viet, danang, 5);
        saveRatingIfNotExists(khoa, danang, 5);
        saveRatingIfNotExists(an, danang, 5);
        saveRatingIfNotExists(mai, danang, 4);

        saveRatingIfNotExists(viet, dalat, 5);
        saveRatingIfNotExists(linh, dalat, 5);
        saveRatingIfNotExists(duy, dalat, 5);
        saveRatingIfNotExists(mai, dalat, 4);

        saveRatingIfNotExists(viet, phuquoc, 5);
        saveRatingIfNotExists(linh, phuquoc, 5);
        saveRatingIfNotExists(khoa, phuquoc, 4);

        saveRatingIfNotExists(viet, sapa, 5);
        saveRatingIfNotExists(khoa, sapa, 5);
        saveRatingIfNotExists(tuan, sapa, 4);

        saveRatingIfNotExists(duy, sapaDerived, 5);
        saveRatingIfNotExists(viet, sapaDerived, 4);

        saveRatingIfNotExists(an, ninhbinh, 5);
        saveRatingIfNotExists(mai, ninhbinh, 4);

        saveRatingIfNotExists(khoa, hue, 5);
        saveRatingIfNotExists(viet, hue, 4);

        // 3. Favorites
        saveFavoriteIfNotExists(khoa, hanoi);
        saveFavoriteIfNotExists(linh, hanoi);
        saveFavoriteIfNotExists(an, hanoi);
        saveFavoriteIfNotExists(duy, hanoi);

        saveFavoriteIfNotExists(viet, danang);
        saveFavoriteIfNotExists(khoa, danang);
        saveFavoriteIfNotExists(an, danang);

        saveFavoriteIfNotExists(viet, dalat);
        saveFavoriteIfNotExists(linh, dalat);
        saveFavoriteIfNotExists(mai, dalat);

        saveFavoriteIfNotExists(viet, phuquoc);
        saveFavoriteIfNotExists(khoa, phuquoc);

        saveFavoriteIfNotExists(tuan, sapa);
        saveFavoriteIfNotExists(khoa, sapa);

        // 4. Saved Itineraries (Bookmarks)
        saveSavedItineraryIfNotExists(khoa, hanoi);
        saveSavedItineraryIfNotExists(an, hanoi);
        saveSavedItineraryIfNotExists(viet, danang);
        saveSavedItineraryIfNotExists(tuan, danang);
        saveSavedItineraryIfNotExists(linh, dalat);
        saveSavedItineraryIfNotExists(duy, dalat);
        saveSavedItineraryIfNotExists(viet, phuquoc);
        saveSavedItineraryIfNotExists(khoa, sapa);
        saveSavedItineraryIfNotExists(tuan, sapaDerived);

        // 5. Follows (Social Network, no self follows)
        saveFollowIfNotExists(khoa, viet);
        saveFollowIfNotExists(linh, viet);
        saveFollowIfNotExists(an, viet);
        saveFollowIfNotExists(viet, linh);
        saveFollowIfNotExists(khoa, linh);
        saveFollowIfNotExists(duy, an);
        saveFollowIfNotExists(mai, an);
        saveFollowIfNotExists(tuan, duy);
        saveFollowIfNotExists(khoa, duy);
        saveFollowIfNotExists(linh, mai);
        saveFollowIfNotExists(viet, tuan);

        // 6. Itinerary Shares (Valid & expired share tokens)
        saveShareIfNotExists(hanoi, "share-token-hanoi-spring-2026-abc12345", LocalDateTime.now().plusDays(30));
        saveShareIfNotExists(danang, "share-token-danang-heritage-2026-def67890", LocalDateTime.now().plusDays(30));
        saveShareIfNotExists(dalat, "share-token-dalat-clouds-2026-ghi11223", LocalDateTime.now().plusDays(30));
        saveShareIfNotExists(phuquoc, "share-token-phuquoc-resort-2026-jkl44556", LocalDateTime.now().plusDays(30));
        saveShareIfNotExists(sapa, "share-token-sapa-expired-2025-expired999", LocalDateTime.now().minusDays(10)); // expired token for testing

        // 7. Offline Downloads
        saveOfflineDownloadIfNotExists(khoa, hanoi);
        saveOfflineDownloadIfNotExists(linh, hanoi);
        saveOfflineDownloadIfNotExists(viet, danang);
        saveOfflineDownloadIfNotExists(duy, dalat);
        saveOfflineDownloadIfNotExists(tuan, sapa);
        saveOfflineDownloadIfNotExists(mai, phuquoc);
        saveOfflineDownloadIfNotExists(an, ninhbinh);
    }

    private void saveCommentIfNotExists(User user, Itinerary itinerary, String content, CommentStatus status) {
        boolean exists = commentRepository.findByItinerary_ItineraryIdOrderByCreatedAtDesc(itinerary.getItineraryId())
                .stream()
                .anyMatch(c -> c.getUser().getUserId().equals(user.getUserId()) && c.getContent().equals(content));
        if (!exists) {
            commentRepository.save(Comment.builder()
                    .user(user)
                    .itinerary(itinerary)
                    .content(content)
                    .status(status)
                    .build());
        }
    }

    private void saveRatingIfNotExists(User user, Itinerary itinerary, int score) {
        if (!ratingRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), itinerary.getItineraryId())) {
            ratingRepository.save(Rating.builder()
                    .user(user)
                    .itinerary(itinerary)
                    .score(score)
                    .build());
        }
    }

    private void saveFavoriteIfNotExists(User user, Itinerary itinerary) {
        if (!favoriteRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), itinerary.getItineraryId())) {
            favoriteRepository.save(Favorite.builder()
                    .user(user)
                    .itinerary(itinerary)
                    .build());
        }
    }

    private void saveSavedItineraryIfNotExists(User user, Itinerary itinerary) {
        if (!savedItineraryRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), itinerary.getItineraryId())) {
            savedItineraryRepository.save(SavedItinerary.builder()
                    .user(user)
                    .itinerary(itinerary)
                    .build());
        }
    }

    private void saveFollowIfNotExists(User follower, User following) {
        if (!follower.getUserId().equals(following.getUserId())
                && !followRepository.existsByFollower_UserIdAndFollowing_UserId(follower.getUserId(), following.getUserId())) {
            followRepository.save(Follow.builder()
                    .follower(follower)
                    .following(following)
                    .build());
        }
    }

    private void saveShareIfNotExists(Itinerary itinerary, String shareToken, LocalDateTime expiresAt) {
        if (!itineraryShareRepository.existsByShareToken(shareToken)) {
            itineraryShareRepository.save(ItineraryShare.builder()
                    .itinerary(itinerary)
                    .shareToken(shareToken)
                    .expiresAt(expiresAt)
                    .build());
        }
    }

    private void saveOfflineDownloadIfNotExists(User user, Itinerary itinerary) {
        if (!offlineDownloadRepository.existsByUser_UserIdAndItinerary_ItineraryId(user.getUserId(), itinerary.getItineraryId())) {
            offlineDownloadRepository.save(OfflineDownload.builder()
                    .user(user)
                    .itinerary(itinerary)
                    .downloadedAt(LocalDateTime.now())
                    .build());
        }
    }

    private void synchronizeItineraryCounters(Map<String, Itinerary> itineraryMap) {
        for (Itinerary itin : itineraryMap.values()) {
            int ratingCount = (int) ratingRepository.findAll().stream()
                    .filter(r -> r.getItinerary().getItineraryId().equals(itin.getItineraryId()))
                    .count();
            int favoriteCount = (int) favoriteRepository.countByItinerary_ItineraryId(itin.getItineraryId());
            int commentCount = (int) commentRepository.countByItinerary_ItineraryId(itin.getItineraryId());
            int reuseCount = (int) itineraryRepository.findAll().stream()
                    .filter(i -> i.getOriginalItinerary() != null
                            && i.getOriginalItinerary().getItineraryId().equals(itin.getItineraryId()))
                    .count();

            boolean changed = false;
            if (ratingCount > itin.getRatingCount()) {
                itin.setRatingCount(ratingCount);
                changed = true;
            }
            if (favoriteCount > itin.getFavoriteCount()) {
                itin.setFavoriteCount(favoriteCount);
                changed = true;
            }
            if (commentCount > itin.getCommentCount()) {
                itin.setCommentCount(commentCount);
                changed = true;
            }
            if (reuseCount > itin.getReuseCount()) {
                itin.setReuseCount(reuseCount);
                changed = true;
            }
            if (changed) {
                itineraryRepository.save(itin);
            }
        }
    }
}

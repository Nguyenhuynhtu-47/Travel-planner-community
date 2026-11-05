package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.location.ParsedLocationQuery;
import Travel_Planner.Travel_Planner.dto.location.SearchIntent;
import Travel_Planner.Travel_Planner.service.QueryUnderstandingService;
import Travel_Planner.Travel_Planner.service.impl.QueryUnderstandingServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("Query Understanding Service Unit Tests")
class QueryUnderstandingServiceTest {

    private QueryUnderstandingService queryUnderstandingService;

    @BeforeEach
    void setUp() {
        queryUnderstandingService = new QueryUnderstandingServiceImpl();
    }

    @Test
    @DisplayName("Decomposes implicit 'Cơm tấm Long Xuyên' into food keyword and location")
    void shouldDecomposeImplicitComTamLongXuyen() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Cơm tấm Long Xuyên");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Cơm tấm");
        assertThat(parsed.getLocationQuery()).isEqualTo("Long Xuyên");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes prepositional 'cơm tấm ở Long Xuyên' into food keyword and location")
    void shouldDecomposePrepositionalComTamOLongXuyen() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("cơm tấm ở Long Xuyên");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("cơm tấm");
        assertThat(parsed.getLocationQuery()).isEqualTo("Long Xuyên");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes unaccented 'com tam long xuyen' into keyword and location")
    void shouldDecomposeUnaccentedComTamLongXuyen() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("com tam long xuyen");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword().toLowerCase()).isEqualTo("com tam");
        assertThat(parsed.getLocationQuery().toLowerCase()).isEqualTo("long xuyen");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes 'Cafe Đà Lạt' into CAFE category and location")
    void shouldDecomposeCafeDaLat() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Cafe Đà Lạt");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Cafe");
        assertThat(parsed.getLocationQuery()).isEqualTo("Đà Lạt");
        assertThat(parsed.getPlaceCategory()).isEqualTo("CAFE");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes 'Khách sạn Vũng Tàu' into STAY category and location")
    void shouldDecomposeKhachSanVungTau() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Khách sạn Vũng Tàu");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Khách sạn");
        assertThat(parsed.getLocationQuery()).isEqualTo("Vũng Tàu");
        assertThat(parsed.getPlaceCategory()).isEqualTo("STAY");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes 'Nhà hàng Quận 1' into FOOD category and district location")
    void shouldDecomposeNhaHangQuan1() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Nhà hàng Quận 1");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Nhà hàng");
        assertThat(parsed.getLocationQuery()).isEqualTo("Quận 1");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Decomposes 'Tiệm bánh gần Hồ Gươm' into BAKERY category and landmark location")
    void shouldDecomposeTiemBanhGanHoGuom() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Tiệm bánh gần Hồ Gươm");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Tiệm bánh");
        assertThat(parsed.getLocationQuery()).isEqualTo("Hồ Gươm");
        assertThat(parsed.getPlaceCategory()).isEqualTo("BAKERY");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Protects compound dish 'bún bò Huế' as generic food POI without target location")
    void shouldProtectCompoundDishBunBoHue() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("bún bò Huế");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.GENERIC_POI);
        assertThat(parsed.getSearchKeyword()).isEqualTo("bún bò Huế");
        assertThat(parsed.getLocationQuery()).isNull();
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isFalse();
    }

    @Test
    @DisplayName("Decomposes 'bún bò Huế ở Sài Gòn' into dish keyword and distinct target location")
    void shouldDecomposeBunBoHueWithExplicitLocation() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("bún bò Huế ở Sài Gòn");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("bún bò Huế");
        assertThat(parsed.getLocationQuery()).isEqualTo("Sài Gòn");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @ParameterizedTest
    @ValueSource(strings = {"phở Hà Nội", "nem nướng Nha Trang", "bánh khọt Vũng Tàu", "mì Quảng"})
    @DisplayName("Protects lexicalized regional dishes from being incorrectly split into location queries")
    void shouldProtectLexicalizedDishes(String dish) {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery(dish);

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.GENERIC_POI);
        assertThat(parsed.hasExplicitLocation()).isFalse();
        assertThat(parsed.getLocationQuery()).isNull();
    }

    @Test
    @DisplayName("Classifies generic query 'Cơm tấm' as GENERIC_POI without explicit location")
    void shouldClassifyGenericComTam() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Cơm tấm");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.GENERIC_POI);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Cơm tấm");
        assertThat(parsed.getLocationQuery()).isNull();
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isFalse();
    }

    @ParameterizedTest
    @ValueSource(strings = {"Vũng Tàu", "Đà Lạt", "Long Xuyên", "Hà Nội", "Thành phố Long Xuyên", "Quận 1", "Lâm Đồng", "Tỉnh Lâm Đồng"})
    @DisplayName("Classifies standalone localities as LOCALITY intent")
    void shouldClassifyStandaloneLocalities(String locality) {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery(locality);

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.LOCALITY);
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }

    @Test
    @DisplayName("Classifies 'Lâm Đồng, An Giang' as LOCALITY intent rather than POI in location")
    void shouldClassifyLamDongAnGiangAsLocality() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("Lâm Đồng, An Giang");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.LOCALITY);
        assertThat(parsed.getSearchKeyword()).isEqualTo("Lâm Đồng");
    }

    @Test
    @DisplayName("Classifies 'bánh mì' as GENERIC_POI intent")
    void shouldClassifyBanhMiAsGenericPoi() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("bánh mì");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.GENERIC_POI);
        assertThat(parsed.getSearchKeyword()).isEqualTo("bánh mì");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isFalse();
    }

    @Test
    @DisplayName("Decomposes 'bánh mì Đà Lạt' into POI_IN_LOCATION intent")
    void shouldDecomposeBanhMiDaLat() {
        ParsedLocationQuery parsed = queryUnderstandingService.parseQuery("bánh mì Đà Lạt");

        assertThat(parsed.getSearchIntent()).isEqualTo(SearchIntent.POI_IN_LOCATION);
        assertThat(parsed.getSearchKeyword()).isEqualTo("bánh mì");
        assertThat(parsed.getLocationQuery()).isEqualTo("Đà Lạt");
        assertThat(parsed.getPlaceCategory()).isEqualTo("FOOD");
        assertThat(parsed.hasExplicitLocation()).isTrue();
    }
}


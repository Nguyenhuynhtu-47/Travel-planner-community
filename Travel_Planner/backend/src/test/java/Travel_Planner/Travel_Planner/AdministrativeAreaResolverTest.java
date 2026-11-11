package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.model.enums.ConfidenceClassification;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.resolver.impl.AdministrativeAreaResolverImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AdministrativeAreaResolverTest {

    @Mock
    private AdministrativeAreaRepository areaRepository;

    private AdministrativeAreaResolverImpl resolver;

    private AdministrativeArea hanoiProvince;
    private AdministrativeArea hoanKiemWard;
    private AdministrativeArea trangBomWard;
    private AdministrativeArea secondaryCommune;

    @BeforeEach
    void setUp() {
        resolver = new AdministrativeAreaResolverImpl(areaRepository);

        hanoiProvince = AdministrativeArea.builder()
                .areaId(1L)
                .code("01")
                .name("Thành phố Hà Nội")
                .normalizedName("thanh pho ha noi")
                .areaType(AdministrativeAreaType.CENTRAL_CITY)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        hoanKiemWard = AdministrativeArea.builder()
                .areaId(70L)
                .code("00070")
                .name("Phường Hoàn Kiếm")
                .normalizedName("phuong hoan kiem")
                .areaType(AdministrativeAreaType.WARD)
                .parent(hanoiProvince)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        AdministrativeArea dongNai = AdministrativeArea.builder()
                .areaId(75L)
                .code("75")
                .name("Thành phố Đồng Nai")
                .normalizedName("thanh pho dong nai")
                .areaType(AdministrativeAreaType.CENTRAL_CITY)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        trangBomWard = AdministrativeArea.builder()
                .areaId(26248L)
                .code("26248")
                .name("Phường Trảng Bom")
                .normalizedName("phuong trang bom")
                .areaType(AdministrativeAreaType.WARD)
                .parent(dongNai)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        secondaryCommune = AdministrativeArea.builder()
                .areaId(100L)
                .code("12345")
                .name("Xã Mẫu Sơn")
                .normalizedName("xa mau son")
                .areaType(AdministrativeAreaType.COMMUNE)
                .parent(hanoiProvince)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_WITH_LIMITATIONS)
                .build();
    }

    @Test
    @DisplayName("Should resolve exact verified administrative code with HIGH_CONFIDENCE")
    void testResolve_ExactVerifiedCode() {
        when(areaRepository.findByCodeWithParent("26248")).thenReturn(Optional.of(trangBomWard));

        PlaceResolutionResultResponse result = resolver.resolve(
                1L, "Trảng Bom Center", "Trảng Bom, Đồng Nai", 10.95, 107.01, "26248"
        );

        assertNotNull(result);
        assertEquals(ConfidenceClassification.HIGH_CONFIDENCE, result.getConfidence());
        assertTrue(result.isEligibleForAutoLink());
        assertNotNull(result.getResolvedArea());
        assertEquals("26248", result.getResolvedArea().getCode());
        assertEquals("Phường Trảng Bom", result.getResolvedArea().getName());
    }

    @Test
    @DisplayName("Should resolve secondary verified administrative code with MEDIUM_CONFIDENCE")
    void testResolve_SecondaryVerifiedCode() {
        when(areaRepository.findByCodeWithParent("12345")).thenReturn(Optional.of(secondaryCommune));

        PlaceResolutionResultResponse result = resolver.resolve(
                2L, "Mẫu Sơn Site", "Mẫu Sơn, Hà Nội", 21.0, 105.8, "12345"
        );

        assertNotNull(result);
        assertEquals(ConfidenceClassification.MEDIUM_CONFIDENCE, result.getConfidence());
        assertTrue(result.isEligibleForAutoLink());
        assertNotNull(result.getResolvedArea());
        assertEquals("12345", result.getResolvedArea().getCode());
    }

    @Test
    @DisplayName("CRITICAL: All 12 quarantined Bắc Ninh codes must be REJECTED with UNVERIFIED and resolvedArea=null")
    void testResolve_AllTwelveQuarantinedBacNinhCodes_MustBeRejected() {
        List<String> quarantinedCodes = List.of(
                "07294", "07375", "07399", "07444", "07840", "09193",
                "09292", "09313", "09319", "09454", "09475", "09496"
        );

        for (String qCode : quarantinedCodes) {
            PlaceResolutionResultResponse result = resolver.resolve(
                    99L, "Test Bắc Ninh Place", "Bắc Ninh, Việt Nam", 21.18, 106.07, qCode
            );

            assertNotNull(result, "Result should not be null for code " + qCode);
            assertEquals(ConfidenceClassification.UNVERIFIED, result.getConfidence(), "Code " + qCode + " must be UNVERIFIED");
            assertNull(result.getResolvedArea(), "Resolved area must be NULL for quarantined code " + qCode);
            assertFalse(result.isEligibleForAutoLink(), "Quarantined code " + qCode + " must NEVER be eligible for auto-link");
            assertTrue(result.getExplanation().contains("cách ly"), "Explanation must mention quarantine for code " + qCode);
        }
    }

    @Test
    @DisplayName("Should resolve place with structured address matching Hoàn Kiếm, Hà Nội")
    void testResolve_StructuredAddress_HoanKiemHanoi() {
        when(areaRepository.findByParent_CodeAndStatusOrderByCodeAsc(eq("01"), eq(AdministrativeAreaStatus.ACTIVE)))
                .thenReturn(List.of(hoanKiemWard));

        Place place = Place.builder()
                .placeId(1L)
                .name("Hồ Hoàn Kiếm")
                .address("Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0285110"))
                .longitude(new BigDecimal("105.8544441"))
                .build();

        PlaceResolutionResultResponse result = resolver.resolve(place);

        assertNotNull(result);
        assertEquals(ConfidenceClassification.HIGH_CONFIDENCE, result.getConfidence());
        assertTrue(result.isEligibleForAutoLink());
        assertNotNull(result.getResolvedArea());
        assertEquals("00070", result.getResolvedArea().getCode());
    }

    @Test
    @DisplayName("Should return NO_MATCH when place address and coordinates are missing")
    void testResolve_MissingAddressAndCoordinates() {
        PlaceResolutionResultResponse result = resolver.resolve(
                5L, "", "", null, null, null
        );

        assertEquals(ConfidenceClassification.NO_MATCH, result.getConfidence());
        assertNull(result.getResolvedArea());
        assertFalse(result.isEligibleForAutoLink());
    }

    @Test
    @DisplayName("Should flag coordinates outside Vietnam territory")
    void testResolve_CoordinatesOutsideVietnam() {
        PlaceResolutionResultResponse result = resolver.resolve(
                6L, "Paris Landmark", "Eiffel Tower, Paris", 48.8584, 2.2945, null
        );

        assertEquals(ConfidenceClassification.NO_MATCH, result.getConfidence());
        assertFalse(result.getWarnings().isEmpty());
        assertTrue(result.getWarnings().get(0).contains("ngoài khung lãnh thổ Việt Nam"));
    }

    @Test
    @DisplayName("Should fallback to PROVINCE level when commune cannot be uniquely identified")
    void testResolve_ProvinceLevelFallback() {
        when(areaRepository.findByParent_CodeAndStatusOrderByCodeAsc(eq("01"), eq(AdministrativeAreaStatus.ACTIVE)))
                .thenReturn(Collections.emptyList());
        when(areaRepository.findByCodeWithParent("01")).thenReturn(Optional.of(hanoiProvince));

        PlaceResolutionResultResponse result = resolver.resolve(
                7L, "Hà Nội Capital Sight", "Thành phố Hà Nội", 21.02, 105.84, null
        );

        assertEquals(ConfidenceClassification.MEDIUM_CONFIDENCE, result.getConfidence());
        assertTrue(result.isEligibleForAutoLink());
        assertNotNull(result.getResolvedArea());
        assertEquals("01", result.getResolvedArea().getCode());
        assertEquals(AdministrativeAreaType.CENTRAL_CITY, result.getResolvedArea().getAreaType());
    }

    @Test
    @DisplayName("Should return AMBIGUOUS when multiple equivalent commune candidates exist")
    void testResolve_AmbiguousCandidates() {
        AdministrativeArea wardA = AdministrativeArea.builder()
                .areaId(101L)
                .code("00101")
                .name("Phường An Hải")
                .normalizedName("phuong an hai")
                .areaType(AdministrativeAreaType.WARD)
                .parent(hanoiProvince)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        AdministrativeArea wardB = AdministrativeArea.builder()
                .areaId(102L)
                .code("00102")
                .name("Phường An Hòa")
                .normalizedName("phuong an hoa")
                .areaType(AdministrativeAreaType.WARD)
                .parent(hanoiProvince)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        when(areaRepository.findByParent_CodeAndStatusOrderByCodeAsc(eq("01"), eq(AdministrativeAreaStatus.ACTIVE)))
                .thenReturn(List.of(wardA, wardB));

        PlaceResolutionResultResponse result = resolver.resolve(
                8L, "Chợ An Hải", "An Hải, An Hòa, Hà Nội", 21.02, 105.84, null
        );

        assertEquals(ConfidenceClassification.AMBIGUOUS, result.getConfidence());
        assertNull(result.getResolvedArea());
        assertFalse(result.isEligibleForAutoLink());
    }
}


package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.CreatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.PlaceProviderMapping;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.repository.PlaceProviderMappingRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.service.PlaceNormalizationService;
import Travel_Planner.Travel_Planner.service.PlaceService;
import Travel_Planner.Travel_Planner.service.impl.PlaceNormalizationServiceImpl;
import Travel_Planner.Travel_Planner.service.impl.PlaceServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class PlaceServiceTest {

    @Mock
    private PlaceRepository placeRepository;

    @Mock
    private PlaceProviderMappingRepository mappingRepository;

    private PlaceNormalizationService normalizationService;
    private PlaceService placeService;

    @BeforeEach
    void setUp() {
        normalizationService = new PlaceNormalizationServiceImpl();
        placeService = new PlaceServiceImpl(placeRepository, mappingRepository, normalizationService);
    }

    @Test
    @DisplayName("Search canonical places by keyword maps results and filters active places")
    void testSearchPlacesByKeyword() {
        Place place1 = Place.builder()
                .placeId(1L)
                .name("Chùa Một Cột")
                .normalizedName("chua mot cot")
                .address("Ba Đình, Hà Nội")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build();

        Pageable pageable = PageRequest.of(0, 10);
        when(placeRepository.searchPlaces(eq("Chùa"), anyString(), isNull(), eq(PlaceStatus.ACTIVE), eq(pageable)))
                .thenReturn(new PageImpl<>(List.of(place1), pageable, 1));

        Page<PlaceResponse> result = placeService.searchPlaces("Chùa", null, null, null, null, pageable);

        assertNotNull(result);
        assertEquals(1, result.getTotalElements());
        assertEquals("Chùa Một Cột", result.getContent().get(0).getName());
    }

    @Test
    @DisplayName("Search places by spatial radius uses Haversine distance and sorts by proximity")
    void testSearchPlacesByRadius() {
        Place placeNear = Place.builder()
                .placeId(1L)
                .name("Hồ Hoàn Kiếm")
                .address("Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0285110"))
                .longitude(new BigDecimal("105.8544441"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build();

        Place placeFar = Place.builder()
                .placeId(2L)
                .name("Vịnh Hạ Long")
                .address("Quảng Ninh")
                .latitude(new BigDecimal("20.9100500"))
                .longitude(new BigDecimal("107.1839000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build();

        when(placeRepository.findInBoundingBox(any(), any(), any(), any()))
                .thenReturn(List.of(placeNear, placeFar));

        Pageable pageable = PageRequest.of(0, 10);
        // Search center in Hanoi (21.0285, 105.8542) with radius 5.0 km
        Page<PlaceResponse> result = placeService.searchPlaces(null, null, 21.0285, 105.8542, 5.0, pageable);

        assertNotNull(result);
        assertEquals(1, result.getTotalElements(), "Only placeNear is within 5km, Ha Long (>100km) must be filtered out");
        assertEquals("Hồ Hoàn Kiếm", result.getContent().get(0).getName());
        assertNotNull(result.getContent().get(0).getDistanceKm());
    }

    @Test
    @DisplayName("Get public place by ID returns active place detail, throws 404 for HIDDEN place")
    void testGetPublicPlaceById() {
        Place activePlace = Place.builder()
                .placeId(5L)
                .name("Văn Miếu")
                .address("Đống Đa, Hà Nội")
                .latitude(new BigDecimal("21.0293500"))
                .longitude(new BigDecimal("105.8360500"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .build();

        when(placeRepository.findByPlaceIdAndStatus(5L, PlaceStatus.ACTIVE)).thenReturn(Optional.of(activePlace));
        when(placeRepository.findByPlaceIdAndStatus(6L, PlaceStatus.ACTIVE)).thenReturn(Optional.empty());

        PlaceDetailResponse found = placeService.getPublicPlaceById(5L);
        assertNotNull(found);
        assertEquals("Văn Miếu", found.getName());

        assertThrows(ResourceNotFoundException.class, () -> placeService.getPublicPlaceById(6L));
    }

    @Test
    @DisplayName("Admin create place validates coordinates, creates place and initial provider mapping")
    void testCreatePlaceSuccess() {
        CreatePlaceRequest request = CreatePlaceRequest.builder()
                .name("Cà Phê Trứng Giảng")
                .address("39 Nguyễn Hữu Huân, Hoàn Kiếm, TP. Hà Nội")
                .description("Quán cà phê trứng lâu đời nhất Hà Nội")
                .latitude(new BigDecimal("21.0345000"))
                .longitude(new BigDecimal("105.8530000"))
                .category(PlaceCategory.CAFE)
                .provider("MANUAL")
                .providerPlaceId("manual_giang_39")
                .build();

        when(mappingRepository.existsByProviderAndProviderPlaceId("MANUAL", "manual_giang_39")).thenReturn(false);
        when(placeRepository.findInBoundingBox(any(), any(), any(), any())).thenReturn(List.of());

        when(placeRepository.save(any(Place.class))).thenAnswer(invocation -> {
            Place p = invocation.getArgument(0);
            p.setPlaceId(101L);
            return p;
        });

        PlaceDetailResponse response = placeService.createPlace(request);

        assertNotNull(response);
        assertEquals(101L, response.getPlaceId());
        assertEquals("Cà Phê Trứng Giảng", response.getName());
        assertEquals(PlaceCategory.CAFE, response.getCategory());
        assertEquals(PlaceStatus.ACTIVE, response.getStatus());

        ArgumentCaptor<Place> captor = ArgumentCaptor.forClass(Place.class);
        verify(placeRepository).save(captor.capture());
        Place saved = captor.getValue();
        assertEquals(1, saved.getProviderMappings().size());
        assertEquals("manual_giang_39", saved.getProviderMappings().get(0).getProviderPlaceId());
    }

    @Test
    @DisplayName("Admin create place throws BadRequestException if candidate duplicates existing place with >= 85% confidence")
    void testCreatePlaceDuplicatePrevention() {
        Place existing = Place.builder()
                .placeId(200L)
                .name("Cà Phê Giảng")
                .normalizedName("ca phe giang")
                .address("39 Nguyễn Hữu Huân, Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0345000"))
                .longitude(new BigDecimal("105.8530000"))
                .category(PlaceCategory.CAFE)
                .status(PlaceStatus.ACTIVE)
                .build();

        when(placeRepository.findInBoundingBox(any(), any(), any(), any())).thenReturn(List.of(existing));

        CreatePlaceRequest duplicateRequest = CreatePlaceRequest.builder()
                .name("Cà Phê Trứng Giảng")
                .address("39 Nguyễn Hữu Huân, Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0345100")) // ~1 meter apart
                .longitude(new BigDecimal("105.8530100"))
                .category(PlaceCategory.CAFE)
                .build();

        BadRequestException ex = assertThrows(BadRequestException.class, () -> placeService.createPlace(duplicateRequest));
        assertTrue(ex.getMessage().contains("trùng khớp với địa điểm đã có trong catalog"));
    }

    @Test
    @DisplayName("Admin update place updates fields, recalculates normalizedName, and preserves mappings")
    void testUpdatePlaceSuccess() {
        Place existing = Place.builder()
                .placeId(15L)
                .name("Tên Cũ")
                .normalizedName("ten cu")
                .address("Địa Chỉ Cũ")
                .latitude(new BigDecimal("21.0000000"))
                .longitude(new BigDecimal("105.0000000"))
                .category(PlaceCategory.OTHER)
                .status(PlaceStatus.ACTIVE)
                .build();

        when(placeRepository.findById(15L)).thenReturn(Optional.of(existing));
        when(placeRepository.save(any(Place.class))).thenAnswer(i -> i.getArgument(0));

        UpdatePlaceRequest request = UpdatePlaceRequest.builder()
                .name("Tên Mới Cập Nhật")
                .address("100 Phố Mới, Q.1, TP.HCM")
                .latitude(new BigDecimal("10.7700000"))
                .longitude(new BigDecimal("106.6900000"))
                .category(PlaceCategory.RESTAURANT)
                .status(PlaceStatus.ACTIVE)
                .build();

        PlaceDetailResponse response = placeService.updatePlace(15L, request);

        assertEquals("Tên Mới Cập Nhật", response.getName());
        assertEquals(PlaceCategory.RESTAURANT, response.getCategory());
        assertEquals(new BigDecimal("10.7700000"), response.getLatitude());
    }

    @Test
    @DisplayName("Admin delete place soft-deletes by setting status to HIDDEN")
    void testDeletePlaceSoftDeletes() {
        Place existing = Place.builder()
                .placeId(25L)
                .name("Địa Điểm Tạm Ẩn")
                .status(PlaceStatus.ACTIVE)
                .build();

        when(placeRepository.findById(25L)).thenReturn(Optional.of(existing));

        placeService.deletePlace(25L);

        assertEquals(PlaceStatus.HIDDEN, existing.getStatus());
        verify(placeRepository).save(existing);
    }

    @Test
    @DisplayName("Resolve or persist: Direct provider mapping match returns existing place immediately")
    void testResolveOrPersistExistingProviderMapping() {
        Place place = Place.builder()
                .placeId(50L)
                .name("Khách Sạn Mường Thanh")
                .status(PlaceStatus.ACTIVE)
                .build();

        PlaceProviderMapping mapping = PlaceProviderMapping.builder()
                .mappingId(1L)
                .place(place)
                .provider("LOCATION_IQ")
                .providerPlaceId("liq_12345")
                .lastSyncedAt(LocalDateTime.now().minusDays(1))
                .build();

        when(mappingRepository.findByProviderAndProviderPlaceId("LOCATION_IQ", "liq_12345"))
                .thenReturn(Optional.of(mapping));

        PlaceDetailResponse resp = placeService.resolveOrPersistPlace(
                "LOCATION_IQ", "liq_12345", "Khách Sạn Mường Thanh", "Đà Nẵng",
                new BigDecimal("16.0544000"), new BigDecimal("108.2022000"),
                "tourism", "hotel", null
        );

        assertNotNull(resp);
        assertEquals(50L, resp.getPlaceId());
        verify(placeRepository, never()).save(any());
        verify(mappingRepository).save(mapping);
    }

    @Test
    @DisplayName("Resolve or persist: Multi-signal deduplication attaches new provider mapping to existing matched place")
    void testResolveOrPersistAttachesToExistingMatchedPlace() {
        Place existing = Place.builder()
                .placeId(70L)
                .name("Chùa Một Cột")
                .normalizedName("chua mot cot")
                .address("Ba Đình, Hà Nội")
                .latitude(new BigDecimal("21.0358000"))
                .longitude(new BigDecimal("105.8335000"))
                .category(PlaceCategory.ATTRACTION)
                .status(PlaceStatus.ACTIVE)
                .providerMappings(new ArrayList<>())
                .build();

        when(mappingRepository.findByProviderAndProviderPlaceId("HERE", "here_99999"))
                .thenReturn(Optional.empty());
        when(placeRepository.findInBoundingBox(any(), any(), any(), any()))
                .thenReturn(List.of(existing));

        PlaceDetailResponse resp = placeService.resolveOrPersistPlace(
                "HERE", "here_99999", "Chùa Một Cột", "Ba Đình, Hà Nội",
                new BigDecimal("21.0358050"), new BigDecimal("105.8335020"), // ~0.5 meter apart
                "tourism", "attraction", null
        );

        assertNotNull(resp);
        assertEquals(70L, resp.getPlaceId(), "Must link to existing place 70L");
        verify(mappingRepository).save(any(PlaceProviderMapping.class));
        verify(placeRepository, never()).save(any());
    }

    @Test
    @DisplayName("Resolve or persist: Unmatched candidate creates a new canonical Place with initial mapping")
    void testResolveOrPersistCreatesNewPlace() {
        when(mappingRepository.findByProviderAndProviderPlaceId("TOMTOM", "tt_88888"))
                .thenReturn(Optional.empty());
        when(placeRepository.findInBoundingBox(any(), any(), any(), any()))
                .thenReturn(List.of());

        when(placeRepository.save(any(Place.class))).thenAnswer(i -> {
            Place p = i.getArgument(0);
            p.setPlaceId(300L);
            return p;
        });

        PlaceDetailResponse resp = placeService.resolveOrPersistPlace(
                "TOMTOM", "tt_88888", "Địa Điểm Hoàn Toàn Mới", "Sa Pa, Lào Cai",
                new BigDecimal("22.3300000"), new BigDecimal("103.8400000"),
                "tourism", "attraction", null
        );

        assertNotNull(resp);
        assertEquals(300L, resp.getPlaceId());
        assertEquals("Địa Điểm Hoàn Toàn Mới", resp.getName());
        verify(placeRepository).save(any(Place.class));
    }
}


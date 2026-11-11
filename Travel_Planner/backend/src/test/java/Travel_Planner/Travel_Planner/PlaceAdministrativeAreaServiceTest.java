package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.request.ManualLinkAdministrativeAreaRequest;
import Travel_Planner.Travel_Planner.dto.response.AdministrativeAreaSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.BatchLinkingReportResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaStatus;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaType;
import Travel_Planner.Travel_Planner.model.enums.ConfidenceClassification;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.resolver.AdministrativeAreaResolver;
import Travel_Planner.Travel_Planner.service.PlaceService;
import Travel_Planner.Travel_Planner.service.impl.PlaceAdministrativeAreaServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PlaceAdministrativeAreaServiceTest {

    @Mock
    private PlaceRepository placeRepository;

    @Mock
    private AdministrativeAreaRepository areaRepository;

    @Mock
    private AdministrativeAreaResolver resolver;

    @Mock
    private PlaceService placeService;

    private PlaceAdministrativeAreaServiceImpl linkingService;

    private Place samplePlace;
    private AdministrativeArea hoanKiemWard;

    @BeforeEach
    void setUp() {
        linkingService = new PlaceAdministrativeAreaServiceImpl(
                placeRepository,
                areaRepository,
                resolver,
                placeService
        );

        samplePlace = Place.builder()
                .placeId(1L)
                .name("Hồ Hoàn Kiếm")
                .address("Hoàn Kiếm, Hà Nội")
                .latitude(new BigDecimal("21.0285110"))
                .longitude(new BigDecimal("105.8544441"))
                .build();

        hoanKiemWard = AdministrativeArea.builder()
                .areaId(70L)
                .code("00070")
                .name("Phường Hoàn Kiếm")
                .areaType(AdministrativeAreaType.WARD)
                .status(AdministrativeAreaStatus.ACTIVE)
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();
    }

    @Test
    @DisplayName("previewResolution should return resolver output without saving to database")
    void testPreviewResolution() {
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));

        PlaceResolutionResultResponse expectedRes = PlaceResolutionResultResponse.builder()
                .placeId(1L)
                .confidence(ConfidenceClassification.HIGH_CONFIDENCE)
                .eligibleForAutoLink(true)
                .build();

        when(resolver.resolve(samplePlace)).thenReturn(expectedRes);

        PlaceResolutionResultResponse actual = linkingService.previewResolution(1L);

        assertEquals(ConfidenceClassification.HIGH_CONFIDENCE, actual.getConfidence());
        verify(placeRepository, never()).save(any());
    }

    @Test
    @DisplayName("resolveAndLink should persist link when resolution is eligible")
    void testResolveAndLink_Success() {
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));

        AdministrativeAreaSummaryResponse summary = AdministrativeAreaSummaryResponse.builder()
                .areaId(70L)
                .code("00070")
                .name("Phường Hoàn Kiếm")
                .trustClassification(AdministrativeAreaTrustClassification.VERIFIED_AND_TRUSTED)
                .build();

        PlaceResolutionResultResponse res = PlaceResolutionResultResponse.builder()
                .placeId(1L)
                .confidence(ConfidenceClassification.HIGH_CONFIDENCE)
                .eligibleForAutoLink(true)
                .resolvedArea(summary)
                .build();

        when(resolver.resolve(samplePlace)).thenReturn(res);
        when(areaRepository.findById(70L)).thenReturn(Optional.of(hoanKiemWard));
        when(placeRepository.save(any(Place.class))).thenReturn(samplePlace);

        PlaceResolutionResultResponse finalRes = linkingService.resolveAndLink(1L, false);

        assertTrue(finalRes.isCurrentlyLinked());
        assertNotNull(samplePlace.getAdministrativeArea());
        assertEquals("00070", samplePlace.getAdministrativeArea().getCode());
        verify(placeRepository, times(1)).save(samplePlace);
    }

    @Test
    @DisplayName("resolveAndLink should protect existing valid link when overwriteExisting is false")
    void testResolveAndLink_ProtectExistingLink() {
        samplePlace.setAdministrativeArea(hoanKiemWard);
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));

        PlaceResolutionResultResponse res = PlaceResolutionResultResponse.builder()
                .placeId(1L)
                .confidence(ConfidenceClassification.HIGH_CONFIDENCE)
                .eligibleForAutoLink(true)
                .build();
        when(resolver.resolve(samplePlace)).thenReturn(res);

        PlaceResolutionResultResponse finalRes = linkingService.resolveAndLink(1L, false);

        assertFalse(finalRes.isEligibleForAutoLink());
        assertTrue(finalRes.getExplanation().contains("đã được liên kết"));
        verify(placeRepository, never()).save(any());
    }

    @Test
    @DisplayName("CRITICAL: resolveAndLink must NEVER link to a quarantined Bắc Ninh code")
    void testResolveAndLink_QuarantinedCode_MustNeverLink() {
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));

        AdministrativeAreaSummaryResponse quarantinedSummary = AdministrativeAreaSummaryResponse.builder()
                .areaId(7294L)
                .code("07294")
                .name("Phường Bố Hạ")
                .trustClassification(AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED)
                .build();

        PlaceResolutionResultResponse res = PlaceResolutionResultResponse.builder()
                .placeId(1L)
                .confidence(ConfidenceClassification.UNVERIFIED)
                .eligibleForAutoLink(true) // even if resolver mistakenly flagged true
                .resolvedArea(quarantinedSummary)
                .build();

        when(resolver.resolve(samplePlace)).thenReturn(res);

        PlaceResolutionResultResponse finalRes = linkingService.resolveAndLink(1L, false);

        assertFalse(finalRes.isEligibleForAutoLink());
        assertNull(finalRes.getResolvedArea());
        assertEquals(ConfidenceClassification.UNVERIFIED, finalRes.getConfidence());
        assertNull(samplePlace.getAdministrativeArea());
        verify(placeRepository, never()).save(any());
    }

    @Test
    @DisplayName("CRITICAL: linkManually must throw BadRequestException for any of the 12 quarantined Bắc Ninh codes")
    void testLinkManually_QuarantinedCode_ThrowsBadRequestException() {
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));

        List<String> quarantinedCodes = List.of(
                "07294", "07375", "07399", "07444", "07840", "09193",
                "09292", "09313", "09319", "09454", "09475", "09496"
        );

        for (String qCode : quarantinedCodes) {
            ManualLinkAdministrativeAreaRequest req = ManualLinkAdministrativeAreaRequest.builder()
                    .administrativeAreaCode(qCode)
                    .reason("Manual test link")
                    .build();

            BadRequestException ex = assertThrows(BadRequestException.class, () ->
                    linkingService.linkManually(1L, req)
            );
            assertTrue(ex.getMessage().contains("cách ly pháp lý"));
        }

        verify(placeRepository, never()).save(any());
    }

    @Test
    @DisplayName("linkManually should successfully link verified code")
    void testLinkManually_Success() {
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));
        when(areaRepository.findByCodeWithParent("00070")).thenReturn(Optional.of(hoanKiemWard));
        when(placeRepository.save(any(Place.class))).thenReturn(samplePlace);
        when(placeService.getAdminPlaceById(1L)).thenReturn(PlaceDetailResponse.builder().placeId(1L).build());

        ManualLinkAdministrativeAreaRequest req = ManualLinkAdministrativeAreaRequest.builder()
                .administrativeAreaCode("00070")
                .reason("Admin manual verification")
                .build();

        PlaceDetailResponse resp = linkingService.linkManually(1L, req);

        assertNotNull(resp);
        assertEquals(hoanKiemWard, samplePlace.getAdministrativeArea());
        verify(placeRepository, times(1)).save(samplePlace);
    }

    @Test
    @DisplayName("unlink should remove administrativeArea and persist place")
    void testUnlink() {
        samplePlace.setAdministrativeArea(hoanKiemWard);
        when(placeRepository.findById(1L)).thenReturn(Optional.of(samplePlace));
        when(placeRepository.save(any(Place.class))).thenReturn(samplePlace);
        when(placeService.getAdminPlaceById(1L)).thenReturn(PlaceDetailResponse.builder().placeId(1L).build());

        PlaceDetailResponse resp = linkingService.unlink(1L);

        assertNotNull(resp);
        assertNull(samplePlace.getAdministrativeArea());
        verify(placeRepository, times(1)).save(samplePlace);
    }

    @Test
    @DisplayName("batchResolveAndLink should respect dryRun and calculate report counts")
    void testBatchResolveAndLink_DryRun() {
        when(placeRepository.findAll()).thenReturn(List.of(samplePlace));

        PlaceResolutionResultResponse previewRes = PlaceResolutionResultResponse.builder()
                .placeId(1L)
                .confidence(ConfidenceClassification.HIGH_CONFIDENCE)
                .eligibleForAutoLink(true)
                .build();

        when(resolver.resolve(samplePlace)).thenReturn(previewRes);

        BatchResolvePlacesRequest req = BatchResolvePlacesRequest.builder()
                .dryRun(true)
                .build();

        BatchLinkingReportResponse report = linkingService.batchResolveAndLink(req);

        assertNotNull(report);
        assertEquals(1, report.getTotalPlacesExamined());
        assertEquals(1, report.getLinkedCount());
        assertTrue(report.isDryRun());
        verify(placeRepository, never()).save(any());
    }
}


package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.request.ManualLinkAdministrativeAreaRequest;
import Travel_Planner.Travel_Planner.dto.response.BatchLinkingReportResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.AdministrativeArea;
import Travel_Planner.Travel_Planner.model.Place;
import Travel_Planner.Travel_Planner.model.enums.AdministrativeAreaTrustClassification;
import Travel_Planner.Travel_Planner.model.enums.ConfidenceClassification;
import Travel_Planner.Travel_Planner.repository.AdministrativeAreaRepository;
import Travel_Planner.Travel_Planner.repository.PlaceRepository;
import Travel_Planner.Travel_Planner.resolver.AdministrativeAreaResolver;
import Travel_Planner.Travel_Planner.resolver.impl.AdministrativeAreaResolverImpl;
import Travel_Planner.Travel_Planner.service.PlaceAdministrativeAreaService;
import Travel_Planner.Travel_Planner.service.PlaceService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;

@Service
@Transactional
public class PlaceAdministrativeAreaServiceImpl implements PlaceAdministrativeAreaService {

    private static final Logger log = LoggerFactory.getLogger(PlaceAdministrativeAreaServiceImpl.class);

    private final PlaceRepository placeRepository;
    private final AdministrativeAreaRepository areaRepository;
    private final AdministrativeAreaResolver resolver;
    private final PlaceService placeService;

    public PlaceAdministrativeAreaServiceImpl(
            PlaceRepository placeRepository,
            AdministrativeAreaRepository areaRepository,
            AdministrativeAreaResolver resolver,
            PlaceService placeService
    ) {
        this.placeRepository = placeRepository;
        this.areaRepository = areaRepository;
        this.resolver = resolver;
        this.placeService = placeService;
    }

    @Override
    @Transactional(readOnly = true)
    public PlaceResolutionResultResponse previewResolution(Long placeId) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + placeId));
        return resolver.resolve(place);
    }

    @Override
    public PlaceResolutionResultResponse resolveAndLink(Long placeId, boolean overwriteExisting) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + placeId));

        if (place.getAdministrativeArea() != null && !overwriteExisting) {
            PlaceResolutionResultResponse res = resolver.resolve(place);
            res.setEligibleForAutoLink(false);
            res.setExplanation("Địa điểm đã được liên kết với đơn vị hành chính: " +
                    place.getAdministrativeArea().getName() + " (" + place.getAdministrativeArea().getCode() + ")");
            return res;
        }

        PlaceResolutionResultResponse result = resolver.resolve(place);

        if (result.isEligibleForAutoLink() && result.getResolvedArea() != null) {
            String code = result.getResolvedArea().getCode();

            // Strict quarantine check
            if (AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES.contains(code)) {
                log.warn("[QUARANTINE_GUARD] Refusing to link placeId={} to quarantined code {}", placeId, code);
                result.setEligibleForAutoLink(false);
                result.setResolvedArea(null);
                result.setConfidence(ConfidenceClassification.UNVERIFIED);
                return result;
            }

            AdministrativeArea area = areaRepository.findById(result.getResolvedArea().getAreaId())
                    .orElseThrow(() -> new IllegalStateException("Đơn vị hành chính đã phân giải không tồn tại: " + result.getResolvedArea().getAreaId()));

            if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
                log.warn("[QUARANTINE_GUARD] Area entity {} is marked UNVERIFIED_AND_QUARANTINED. Linking blocked.", area.getCode());
                result.setEligibleForAutoLink(false);
                result.setResolvedArea(null);
                result.setConfidence(ConfidenceClassification.UNVERIFIED);
                return result;
            }

            place.setAdministrativeArea(area);
            placeRepository.save(place);
            result.setCurrentlyLinked(true);

            log.info("Successfully linked Place {} ({}) -> AdministrativeArea {} ({}) [confidence={}]",
                    place.getPlaceId(), place.getName(), area.getCode(), area.getName(), result.getConfidence());
        }

        return result;
    }

    @Override
    public PlaceDetailResponse linkManually(Long placeId, ManualLinkAdministrativeAreaRequest request) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + placeId));

        String code = request.getAdministrativeAreaCode().trim();

        if (AdministrativeAreaResolverImpl.QUARANTINED_BAC_NINH_CODES.contains(code)) {
            log.warn("[QUARANTINE_GUARD] Manual linking rejected for placeId={} to quarantined code {}", placeId, code);
            throw new BadRequestException("Không thể liên kết thủ công với đơn vị hành chính đang bị cách ly pháp lý (NQ 388/NQ-UBTVQH16): " + code);
        }

        AdministrativeArea area = areaRepository.findByCodeWithParent(code)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy đơn vị hành chính với mã: " + code));

        if (area.getTrustClassification() == AdministrativeAreaTrustClassification.UNVERIFIED_AND_QUARANTINED) {
            throw new BadRequestException("Đơn vị hành chính này thuộc diện cách ly pháp lý, không được phép liên kết.");
        }

        place.setAdministrativeArea(area);
        placeRepository.save(place);

        log.info("Manually linked Place {} ({}) -> AdministrativeArea {} ({})",
                place.getPlaceId(), place.getName(), area.getCode(), area.getName());

        return placeService.getAdminPlaceById(placeId);
    }

    @Override
    public PlaceDetailResponse unlink(Long placeId) {
        Place place = placeRepository.findById(placeId)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy địa điểm với ID: " + placeId));

        place.setAdministrativeArea(null);
        placeRepository.save(place);

        log.info("Unlinked AdministrativeArea from Place {} ({})", place.getPlaceId(), place.getName());
        return placeService.getAdminPlaceById(placeId);
    }

    @Override
    public BatchLinkingReportResponse batchResolveAndLink(BatchResolvePlacesRequest request) {
        List<Place> targetPlaces;
        if (request.getPlaceIds() != null && !request.getPlaceIds().isEmpty()) {
            targetPlaces = placeRepository.findAllById(request.getPlaceIds());
        } else {
            targetPlaces = placeRepository.findAll();
        }

        int total = targetPlaces.size();
        int linked = 0;
        int skipped = 0;
        int quarantined = 0;
        int ambiguous = 0;
        int noMatch = 0;

        List<PlaceResolutionResultResponse> results = new ArrayList<>();

        for (Place p : targetPlaces) {
            PlaceResolutionResultResponse res;
            if (request.isDryRun()) {
                res = resolver.resolve(p);
            } else {
                res = resolveAndLink(p.getPlaceId(), request.isOverwriteExisting());
            }

            results.add(res);

            if (res.isCurrentlyLinked() || res.isEligibleForAutoLink()) {
                linked++;
            } else if (res.getConfidence() == ConfidenceClassification.UNVERIFIED) {
                quarantined++;
            } else if (res.getConfidence() == ConfidenceClassification.AMBIGUOUS) {
                ambiguous++;
            } else if (res.getConfidence() == ConfidenceClassification.NO_MATCH) {
                noMatch++;
            } else {
                skipped++;
            }
        }

        return BatchLinkingReportResponse.builder()
                .totalPlacesExamined(total)
                .linkedCount(linked)
                .skippedCount(skipped)
                .quarantinedCount(quarantined)
                .ambiguousCount(ambiguous)
                .noMatchCount(noMatch)
                .dryRun(request.isDryRun())
                .results(results)
                .build();
    }
}

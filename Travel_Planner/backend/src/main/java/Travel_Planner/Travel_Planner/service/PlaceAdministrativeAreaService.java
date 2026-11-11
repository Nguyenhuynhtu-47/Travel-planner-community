package Travel_Planner.Travel_Planner.service;

import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.request.ManualLinkAdministrativeAreaRequest;
import Travel_Planner.Travel_Planner.dto.response.BatchLinkingReportResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;

/**
 * Service managing Place-to-AdministrativeArea linking lifecycle.
 */
public interface PlaceAdministrativeAreaService {

    /**
     * Preview resolution without modifying database state.
     */
    PlaceResolutionResultResponse previewResolution(Long placeId);

    /**
     * Resolve and automatically link Place if resolution meets confidence threshold.
     */
    PlaceResolutionResultResponse resolveAndLink(Long placeId, boolean overwriteExisting);

    /**
     * Manually link Place to an AdministrativeArea code with strict quarantine validation.
     */
    PlaceDetailResponse linkManually(Long placeId, ManualLinkAdministrativeAreaRequest request);

    /**
     * Unlink AdministrativeArea from a Place.
     */
    PlaceDetailResponse unlink(Long placeId);

    /**
     * Batch resolve and link multiple places.
     */
    BatchLinkingReportResponse batchResolveAndLink(BatchResolvePlacesRequest request);
}


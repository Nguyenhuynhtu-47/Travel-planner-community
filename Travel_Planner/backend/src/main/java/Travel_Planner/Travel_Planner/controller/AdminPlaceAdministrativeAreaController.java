package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.BatchResolvePlacesRequest;
import Travel_Planner.Travel_Planner.dto.request.ManualLinkAdministrativeAreaRequest;
import Travel_Planner.Travel_Planner.dto.response.BatchLinkingReportResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResolutionResultResponse;
import Travel_Planner.Travel_Planner.service.PlaceAdministrativeAreaService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * Admin Controller for Place - Administrative Area Linking and Resolution.
 */
@RestController
@RequestMapping("/api/admin/places")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPlaceAdministrativeAreaController {

    private final PlaceAdministrativeAreaService linkingService;

    public AdminPlaceAdministrativeAreaController(PlaceAdministrativeAreaService linkingService) {
        this.linkingService = linkingService;
    }

    /**
     * Preview administrative area resolution for a place without persisting changes.
     */
    @PostMapping("/{id}/administrative-area/preview")
    public ResponseEntity<PlaceResolutionResultResponse> previewResolution(@PathVariable Long id) {
        return ResponseEntity.ok(linkingService.previewResolution(id));
    }

    /**
     * Resolve and link a place if resolution confidence meets the auto-link threshold.
     */
    @PostMapping("/{id}/administrative-area/resolve")
    public ResponseEntity<PlaceResolutionResultResponse> resolveAndLink(
            @PathVariable Long id,
            @RequestParam(defaultValue = "false") boolean overwriteExisting
    ) {
        return ResponseEntity.ok(linkingService.resolveAndLink(id, overwriteExisting));
    }

    /**
     * Manually link a place to an administrative area code (with strict quarantine validation).
     */
    @PostMapping("/{id}/administrative-area/link")
    public ResponseEntity<PlaceDetailResponse> linkManually(
            @PathVariable Long id,
            @Valid @RequestBody ManualLinkAdministrativeAreaRequest request
    ) {
        return ResponseEntity.ok(linkingService.linkManually(id, request));
    }

    /**
     * Unlink administrative area from a place.
     */
    @DeleteMapping("/{id}/administrative-area")
    public ResponseEntity<PlaceDetailResponse> unlink(@PathVariable Long id) {
        return ResponseEntity.ok(linkingService.unlink(id));
    }

    /**
     * Batch resolve and link multiple places.
     */
    @PostMapping("/administrative-area/batch-resolve")
    public ResponseEntity<BatchLinkingReportResponse> batchResolve(
            @RequestBody(required = false) BatchResolvePlacesRequest request
    ) {
        if (request == null) {
            request = BatchResolvePlacesRequest.builder().build();
        }
        return ResponseEntity.ok(linkingService.batchResolveAndLink(request));
    }
}


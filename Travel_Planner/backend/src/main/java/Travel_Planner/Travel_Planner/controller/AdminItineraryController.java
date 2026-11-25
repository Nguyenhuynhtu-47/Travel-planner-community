package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.ModerateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.ItineraryAdminDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.ItineraryAdminResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.model.enums.ItineraryStatus;
import Travel_Planner.Travel_Planner.model.enums.Visibility;
import Travel_Planner.Travel_Planner.service.AdminItineraryService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@Validated
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/itineraries")
public class AdminItineraryController {

    private final AdminItineraryService adminItineraryService;

    public AdminItineraryController(AdminItineraryService adminItineraryService) {
        this.adminItineraryService = adminItineraryService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<ItineraryAdminResponse>> getItineraries(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) ItineraryStatus status,
            @RequestParam(required = false) Visibility visibility,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(required = false) String sort) {
        return ResponseEntity.ok(adminItineraryService.getAdminItineraries(keyword, status, visibility, page, size, sort));
    }

    @GetMapping("/{id}")
    public ResponseEntity<ItineraryAdminDetailResponse> getItineraryDetail(
            @PathVariable("id") Integer id,
            @RequestParam(required = false) Long reportId,
            @RequestParam(required = false) String inspectionReason,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(adminItineraryService.getAdminItineraryById(id, reportId, inspectionReason, actorUsername));
    }

    @PatchMapping("/{id}/moderate")
    public ResponseEntity<ItineraryAdminResponse> moderateItinerary(
            @PathVariable("id") Integer id,
            @Valid @RequestBody ModerateItineraryRequest request,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(adminItineraryService.moderateItinerary(id, request, actorUsername));
    }
}

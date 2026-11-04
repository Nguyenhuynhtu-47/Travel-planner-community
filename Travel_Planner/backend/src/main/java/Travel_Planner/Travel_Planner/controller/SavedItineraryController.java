package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.SavedItineraryResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.SavedItineraryService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
public class SavedItineraryController {

    private final SavedItineraryService savedItineraryService;

    public SavedItineraryController(SavedItineraryService savedItineraryService) {
        this.savedItineraryService = savedItineraryService;
    }

    @PostMapping("/api/itineraries/{itineraryId}/save")
    public ResponseEntity<SavedItineraryResponse> saveItinerary(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        SavedItineraryResponse response = savedItineraryService.saveItinerary(itineraryId, userDetails.getUsername());
        if (response.isNewlyCreated()) {
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } else {
            return ResponseEntity.ok(response);
        }
    }

    @DeleteMapping("/api/itineraries/{itineraryId}/save")
    public ResponseEntity<SavedItineraryResponse> removeSavedItinerary(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        SavedItineraryResponse response = savedItineraryService.removeSavedItinerary(itineraryId, userDetails.getUsername());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/user/saved-itineraries")
    public ResponseEntity<PageResponse<ItinerarySummaryResponse>> getUserSavedItineraries(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        PageResponse<ItinerarySummaryResponse> response = savedItineraryService.getUserSavedItineraries(
                userDetails.getUsername(), page, size);
        return ResponseEntity.ok(response);
    }
}


package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.RouteResponse;
import Travel_Planner.Travel_Planner.service.RouteService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

/**
 * REST controller for per-day itinerary route calculation.
 */
@RestController
@RequestMapping("/api/itineraries/{itineraryId}/days/{dayId}/route")
public class RouteController {

    private final RouteService routeService;

    public RouteController(RouteService routeService) {
        this.routeService = routeService;
    }

    @GetMapping
    public ResponseEntity<RouteResponse> getDayRoute(
            @PathVariable Integer itineraryId,
            @PathVariable Integer dayId,
            @RequestParam(value = "mode", defaultValue = "driving") String mode,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        RouteResponse response = routeService.calculateDayRoute(itineraryId, dayId, mode, currentUsername);
        return ResponseEntity.ok(response);
    }
}


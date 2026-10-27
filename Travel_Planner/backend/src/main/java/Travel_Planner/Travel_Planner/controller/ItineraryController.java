package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.service.ItineraryService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/itineraries")
public class ItineraryController {

    private final ItineraryService itineraryService;

    public ItineraryController(ItineraryService itineraryService) {
        this.itineraryService = itineraryService;
    }

    @GetMapping
    public ResponseEntity<PageResponse<ItinerarySummaryResponse>> getPublicItineraries(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) String location,
            @RequestParam(required = false) String theme,
            @RequestParam(required = false) BigDecimal minBudget,
            @RequestParam(required = false) BigDecimal maxBudget,
            @RequestParam(required = false) Integer minDays,
            @RequestParam(required = false) Integer maxDays,
            @RequestParam(required = false) Double minRating,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt,desc") String sort
    ) {
        PageResponse<ItinerarySummaryResponse> response = itineraryService.getPublicItineraries(
                keyword, location, theme, minBudget, maxBudget, minDays, maxDays, minRating, page, size, sort
        );
        return ResponseEntity.ok(response);
    }

    @GetMapping("/{id}")
    public ResponseEntity<ItineraryDetailResponse> getItineraryDetail(
            @PathVariable Integer id,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryDetailResponse response = itineraryService.getItineraryDetail(id, currentUsername);
        return ResponseEntity.ok(response);
    }

    @PostMapping
    public ResponseEntity<ItineraryDetailResponse> createItinerary(
            @Valid @RequestBody CreateItineraryRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryDetailResponse response = itineraryService.createItinerary(request, currentUsername);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<ItineraryDetailResponse> updateItinerary(
            @PathVariable Integer id,
            @Valid @RequestBody UpdateItineraryRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryDetailResponse response = itineraryService.updateItinerary(id, request, currentUsername);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, String>> deleteItinerary(
            @PathVariable Integer id,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        itineraryService.deleteItinerary(id, currentUsername);
        return ResponseEntity.ok(Map.of("message", "Đã xóa lịch trình thành công"));
    }

    @PostMapping("/{id}/days")
    public ResponseEntity<ItineraryDayResponse> addDay(
            @PathVariable Integer id,
            @Valid @RequestBody(required = false) CreateDayRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryDayResponse response = itineraryService.addDay(id, request, currentUsername);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}/days/{dayId}")
    public ResponseEntity<ItineraryDayResponse> updateDay(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @Valid @RequestBody UpdateDayRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryDayResponse response = itineraryService.updateDay(id, dayId, request, currentUsername);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}/days/{dayId}")
    public ResponseEntity<Map<String, String>> deleteDay(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        itineraryService.deleteDay(id, dayId, currentUsername);
        return ResponseEntity.ok(Map.of("message", "Đã xóa ngày thành công"));
    }

    @PostMapping("/{id}/days/{dayId}/activities")
    public ResponseEntity<ActivityResponse> addActivity(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @Valid @RequestBody CreateActivityRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ActivityResponse response = itineraryService.addActivity(id, dayId, request, currentUsername);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}/days/{dayId}/activities/{activityId}")
    public ResponseEntity<ActivityResponse> updateActivity(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @PathVariable Integer activityId,
            @Valid @RequestBody UpdateActivityRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ActivityResponse response = itineraryService.updateActivity(id, dayId, activityId, request, currentUsername);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}/days/{dayId}/activities/{activityId}")
    public ResponseEntity<Map<String, String>> deleteActivity(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @PathVariable Integer activityId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        itineraryService.deleteActivity(id, dayId, activityId, currentUsername);
        return ResponseEntity.ok(Map.of("message", "Đã xóa hoạt động thành công"));
    }

    @PutMapping("/{id}/days/{dayId}/activities/reorder")
    public ResponseEntity<List<ActivityResponse>> reorderActivities(
            @PathVariable Integer id,
            @PathVariable Integer dayId,
            @RequestBody List<@Valid ReorderActivityItem> items,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        List<ActivityResponse> response = itineraryService.reorderActivities(id, dayId, items, currentUsername);
        return ResponseEntity.ok(response);
    }
}

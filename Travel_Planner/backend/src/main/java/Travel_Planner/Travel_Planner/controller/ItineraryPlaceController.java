package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.SavePlaceToItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.ItineraryPlaceResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.service.ItineraryPlaceService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/itineraries/{itineraryId}/places")
public class ItineraryPlaceController {

    private final ItineraryPlaceService itineraryPlaceService;

    public ItineraryPlaceController(ItineraryPlaceService itineraryPlaceService) {
        this.itineraryPlaceService = itineraryPlaceService;
    }

    @PostMapping
    public ResponseEntity<ItineraryPlaceResponse> savePlace(
            @PathVariable Integer itineraryId,
            @Valid @RequestBody SavePlaceToItineraryRequest request,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        ItineraryPlaceResponse response = itineraryPlaceService.savePlaceToItinerary(itineraryId, request, currentUsername);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @GetMapping
    public ResponseEntity<PageResponse<ItineraryPlaceResponse>> getSavedPlaces(
            @PathVariable Integer itineraryId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "savedAt,desc") String sort,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        Sort sortObj = parseSort(sort);
        Pageable pageable = PageRequest.of(page, size, sortObj);
        Page<ItineraryPlaceResponse> pageResult = itineraryPlaceService.getSavedPlaces(itineraryId, pageable, currentUsername);
        return ResponseEntity.ok(PageResponse.from(pageResult));
    }

    @GetMapping("/all")
    public ResponseEntity<List<ItineraryPlaceResponse>> getAllSavedPlaces(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        List<ItineraryPlaceResponse> list = itineraryPlaceService.getAllSavedPlaces(itineraryId, currentUsername);
        return ResponseEntity.ok(list);
    }

    @DeleteMapping("/{placeId}")
    public ResponseEntity<Void> removePlace(
            @PathVariable Integer itineraryId,
            @PathVariable Long placeId,
            @AuthenticationPrincipal UserDetails userDetails
    ) {
        String currentUsername = userDetails != null ? userDetails.getUsername() : null;
        itineraryPlaceService.removePlaceFromItinerary(itineraryId, placeId, currentUsername);
        return ResponseEntity.ok().build();
    }

    private Sort parseSort(String sortParam) {
        if (sortParam == null || sortParam.isBlank()) {
            return Sort.by(Sort.Direction.DESC, "savedAt");
        }
        String[] parts = sortParam.split(",");
        String property = parts[0].trim();
        Sort.Direction direction = (parts.length > 1 && parts[1].trim().equalsIgnoreCase("asc"))
                ? Sort.Direction.ASC
                : Sort.Direction.DESC;
        return Sort.by(direction, property);
    }
}


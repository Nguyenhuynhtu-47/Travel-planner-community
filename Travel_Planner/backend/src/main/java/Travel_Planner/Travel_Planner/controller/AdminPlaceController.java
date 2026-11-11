package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.CreatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdatePlaceRequest;
import Travel_Planner.Travel_Planner.dto.response.PlaceDetailResponse;
import Travel_Planner.Travel_Planner.dto.response.PlaceResponse;
import Travel_Planner.Travel_Planner.model.enums.PlaceCategory;
import Travel_Planner.Travel_Planner.model.enums.PlaceStatus;
import Travel_Planner.Travel_Planner.service.PlaceService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/places")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPlaceController {

    private final PlaceService placeService;

    public AdminPlaceController(PlaceService placeService) {
        this.placeService = placeService;
    }

    @GetMapping
    public ResponseEntity<Page<PlaceResponse>> getAdminPlaces(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) PlaceCategory category,
            @RequestParam(required = false) PlaceStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt,desc") String sort
    ) {
        String[] sortParts = sort.split(",");
        String sortProp = sortParts[0];
        Sort.Direction direction = (sortParts.length > 1 && "asc".equalsIgnoreCase(sortParts[1]))
                ? Sort.Direction.ASC
                : Sort.Direction.DESC;

        Pageable pageable = PageRequest.of(Math.max(0, page), Math.min(50, Math.max(1, size)), Sort.by(direction, sortProp));
        Page<PlaceResponse> results = placeService.getAdminPlaces(keyword, category, status, pageable);
        return ResponseEntity.ok(results);
    }

    @GetMapping("/{id}")
    public ResponseEntity<PlaceDetailResponse> getAdminPlaceById(@PathVariable Long id) {
        return ResponseEntity.ok(placeService.getAdminPlaceById(id));
    }

    @PostMapping
    public ResponseEntity<PlaceDetailResponse> createPlace(@Valid @RequestBody CreatePlaceRequest request) {
        PlaceDetailResponse response = placeService.createPlace(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<PlaceDetailResponse> updatePlace(
            @PathVariable Long id,
            @Valid @RequestBody UpdatePlaceRequest request
    ) {
        PlaceDetailResponse response = placeService.updatePlace(id, request);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deletePlace(@PathVariable Long id) {
        placeService.deletePlace(id);
        return ResponseEntity.noContent().build();
    }
}


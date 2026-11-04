package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.CreateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.request.UpdateDestinationRequest;
import Travel_Planner.Travel_Planner.dto.response.DestinationResponse;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.service.DestinationService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/destinations")
@PreAuthorize("hasRole('ADMIN')")
public class AdminDestinationController {

    private final DestinationService destinationService;

    public AdminDestinationController(DestinationService destinationService) {
        this.destinationService = destinationService;
    }

    @GetMapping
    public ResponseEntity<List<DestinationResponse>> getDestinations(
            @RequestParam(required = false) String keyword,
            @RequestParam(required = false) DestinationStatus status
    ) {
        return ResponseEntity.ok(destinationService.getAdminDestinations(keyword, status));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DestinationResponse> getDestinationById(@PathVariable Integer id) {
        return ResponseEntity.ok(destinationService.getAdminDestinationById(id));
    }

    @PostMapping
    public ResponseEntity<DestinationResponse> createDestination(
            @Valid @RequestBody CreateDestinationRequest request
    ) {
        DestinationResponse response = destinationService.createDestination(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PutMapping("/{id}")
    public ResponseEntity<DestinationResponse> updateDestination(
            @PathVariable Integer id,
            @Valid @RequestBody UpdateDestinationRequest request
    ) {
        DestinationResponse response = destinationService.updateDestination(id, request);
        return ResponseEntity.ok(response);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteDestination(@PathVariable Integer id) {
        destinationService.deleteDestination(id);
        return ResponseEntity.noContent().build();
    }
}


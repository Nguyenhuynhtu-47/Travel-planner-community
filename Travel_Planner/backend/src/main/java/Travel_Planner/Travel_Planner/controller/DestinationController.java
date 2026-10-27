package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.DestinationResponse;
import Travel_Planner.Travel_Planner.model.Destination;
import Travel_Planner.Travel_Planner.model.enums.DestinationStatus;
import Travel_Planner.Travel_Planner.repository.DestinationRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/destinations")
public class DestinationController {

    private final DestinationRepository destinationRepository;

    public DestinationController(DestinationRepository destinationRepository) {
        this.destinationRepository = destinationRepository;
    }

    @GetMapping
    public ResponseEntity<List<DestinationResponse>> getDestinations(
            @RequestParam(required = false) String keyword
    ) {
        List<Destination> destinations;
        if (keyword != null && !keyword.trim().isEmpty()) {
            destinations = destinationRepository.findByNameContainingIgnoreCaseAndStatus(
                    keyword.trim(), DestinationStatus.ACTIVE);
        } else {
            destinations = destinationRepository.findByStatus(DestinationStatus.ACTIVE);
        }

        List<DestinationResponse> responses = destinations.stream()
                .map(this::toResponse)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    @GetMapping("/{id}")
    public ResponseEntity<DestinationResponse> getDestinationById(@PathVariable Integer id) {
        return destinationRepository.findById(id)
                .filter(d -> d.getStatus() == DestinationStatus.ACTIVE)
                .map(this::toResponse)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    private DestinationResponse toResponse(Destination destination) {
        return DestinationResponse.builder()
                .destinationId(destination.getDestinationId())
                .name(destination.getName())
                .address(destination.getAddress())
                .description(destination.getDescription())
                .imageUrl(destination.getImageUrl())
                .latitude(destination.getLatitude())
                .longitude(destination.getLongitude())
                .build();
    }
}

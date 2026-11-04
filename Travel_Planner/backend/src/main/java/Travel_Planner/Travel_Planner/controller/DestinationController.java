package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.DestinationResponse;
import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.service.DestinationService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/destinations")
public class DestinationController {

    private final DestinationService destinationService;

    public DestinationController(DestinationService destinationService) {
        this.destinationService = destinationService;
    }

    @GetMapping
    public ResponseEntity<List<DestinationResponse>> getDestinations(
            @RequestParam(required = false) String keyword
    ) {
        return ResponseEntity.ok(destinationService.getPublicDestinations(keyword));
    }

    @GetMapping("/{id}")
    public ResponseEntity<DestinationResponse> getDestinationById(@PathVariable Integer id) {
        try {
            return ResponseEntity.ok(destinationService.getPublicDestinationById(id));
        } catch (ResourceNotFoundException ex) {
            return ResponseEntity.notFound().build();
        }
    }
}

package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.RateItineraryRequest;
import Travel_Planner.Travel_Planner.dto.response.DeleteRatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingResponse;
import Travel_Planner.Travel_Planner.dto.response.RatingSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.UserRatingStatusResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.RatingService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/itineraries/{itineraryId}/ratings")
public class RatingController {

    private final RatingService ratingService;

    public RatingController(RatingService ratingService) {
        this.ratingService = ratingService;
    }

    @PostMapping
    public ResponseEntity<RatingResponse> rateItinerary(
            @PathVariable Integer itineraryId,
            @Valid @RequestBody RateItineraryRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        RatingResponse response = ratingService.rateItinerary(itineraryId, request, userDetails.getUsername());
        if (response.isNewlyCreated()) {
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } else {
            return ResponseEntity.ok(response);
        }
    }

    @GetMapping
    public ResponseEntity<RatingSummaryResponse> getRatingSummary(@PathVariable Integer itineraryId) {
        RatingSummaryResponse response = ratingService.getRatingSummary(itineraryId);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    public ResponseEntity<UserRatingStatusResponse> getUserRating(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        UserRatingStatusResponse response = ratingService.getUserRating(itineraryId, userDetails.getUsername());
        return ResponseEntity.ok(response);
    }

    @DeleteMapping
    public ResponseEntity<DeleteRatingResponse> deleteRating(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        DeleteRatingResponse response = ratingService.deleteRating(itineraryId, userDetails.getUsername());
        return ResponseEntity.ok(response);
    }
}


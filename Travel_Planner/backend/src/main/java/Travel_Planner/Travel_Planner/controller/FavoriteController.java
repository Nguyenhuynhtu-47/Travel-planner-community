package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.FavoriteResponse;
import Travel_Planner.Travel_Planner.dto.response.ItinerarySummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.FavoriteService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
public class FavoriteController {

    private final FavoriteService favoriteService;

    public FavoriteController(FavoriteService favoriteService) {
        this.favoriteService = favoriteService;
    }

    @PostMapping("/api/itineraries/{itineraryId}/favorites")
    public ResponseEntity<FavoriteResponse> addFavorite(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        FavoriteResponse response = favoriteService.addFavorite(itineraryId, userDetails.getUsername());
        if (response.isNewlyCreated()) {
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } else {
            return ResponseEntity.ok(response);
        }
    }

    @DeleteMapping("/api/itineraries/{itineraryId}/favorites")
    public ResponseEntity<FavoriteResponse> removeFavorite(
            @PathVariable Integer itineraryId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        FavoriteResponse response = favoriteService.removeFavorite(itineraryId, userDetails.getUsername());
        return ResponseEntity.ok(response);
    }

    @GetMapping("/api/user/favorites")
    public ResponseEntity<PageResponse<ItinerarySummaryResponse>> getUserFavorites(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userDetails == null) {
            throw new UnauthorizedException("Bạn cần đăng nhập để thực hiện thao tác này");
        }
        PageResponse<ItinerarySummaryResponse> response = favoriteService.getUserFavorites(
                userDetails.getUsername(), page, size);
        return ResponseEntity.ok(response);
    }
}


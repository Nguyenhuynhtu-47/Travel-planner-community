package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.service.PublicUserService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/{userId}")
public class PublicUserController {
    private final PublicUserService users;
    public PublicUserController(PublicUserService users) { this.users = users; }
    @GetMapping("/public-profile")
    public ResponseEntity<PublicProfileResponse> profile(@PathVariable Integer userId,
            @AuthenticationPrincipal UserDetails viewer) {
        return ResponseEntity.ok(users.getProfile(userId, viewer == null ? null : viewer.getUsername()));
    }
    @GetMapping("/itineraries")
    public ResponseEntity<PageResponse<ItinerarySummaryResponse>> itineraries(@PathVariable Integer userId,
            @RequestParam(defaultValue="0") int page, @RequestParam(defaultValue="10") int size) {
        return ResponseEntity.ok(users.getItineraries(userId, page, size));
    }
    @PostMapping("/follow")
    public ResponseEntity<Void> follow(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails viewer) {
        users.follow(userId, viewer == null ? null : viewer.getUsername()); return ResponseEntity.noContent().build();
    }
    @DeleteMapping("/follow")
    public ResponseEntity<Void> unfollow(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails viewer) {
        users.unfollow(userId, viewer == null ? null : viewer.getUsername()); return ResponseEntity.noContent().build();
    }
    @GetMapping("/followers")
    public ResponseEntity<PageResponse<PublicUserSummaryResponse>> followers(@PathVariable Integer userId,
            @RequestParam(defaultValue="0") int page, @RequestParam(defaultValue="20") int size) {
        return ResponseEntity.ok(users.getFollowers(userId, page, size));
    }
    @GetMapping("/following")
    public ResponseEntity<PageResponse<PublicUserSummaryResponse>> following(@PathVariable Integer userId,
            @RequestParam(defaultValue="0") int page, @RequestParam(defaultValue="20") int size) {
        return ResponseEntity.ok(users.getFollowing(userId, page, size));
    }
}

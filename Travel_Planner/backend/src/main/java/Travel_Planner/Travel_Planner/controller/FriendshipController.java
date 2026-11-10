package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.FriendRequestResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.PublicUserSummaryResponse;
import Travel_Planner.Travel_Planner.service.FriendshipService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class FriendshipController {
    private final FriendshipService friendships;
    public FriendshipController(FriendshipService friendships) { this.friendships = friendships; }

    @PostMapping("/users/{userId}/friend-requests")
    public ResponseEntity<FriendRequestResponse> send(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.status(HttpStatus.CREATED).body(friendships.sendRequest(userId, actorName(actor)));
    }

    @GetMapping("/users/me/friend-requests")
    public ResponseEntity<PageResponse<FriendRequestResponse>> requests(
            @RequestParam String direction, @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(friendships.requests(direction, page, size, actorName(actor)));
    }

    @PostMapping("/friend-requests/{friendshipId}/accept")
    public ResponseEntity<FriendRequestResponse> accept(@PathVariable Long friendshipId, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(friendships.accept(friendshipId, actorName(actor)));
    }

    @PostMapping("/friend-requests/{friendshipId}/decline")
    public ResponseEntity<FriendRequestResponse> decline(@PathVariable Long friendshipId, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(friendships.decline(friendshipId, actorName(actor)));
    }

    @DeleteMapping("/friend-requests/{friendshipId}")
    public ResponseEntity<Void> cancel(@PathVariable Long friendshipId, @AuthenticationPrincipal UserDetails actor) {
        friendships.cancel(friendshipId, actorName(actor));
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/users/me/friends")
    public ResponseEntity<PageResponse<PublicUserSummaryResponse>> friends(
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(friendships.friends(page, size, actorName(actor)));
    }

    @DeleteMapping("/users/me/friends/{userId}")
    public ResponseEntity<Void> unfriend(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails actor) {
        friendships.unfriend(userId, actorName(actor));
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/users/{userId}/block")
    public ResponseEntity<Void> block(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails actor) {
        friendships.block(userId, actorName(actor));
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/users/{userId}/block")
    public ResponseEntity<Void> unblock(@PathVariable Integer userId, @AuthenticationPrincipal UserDetails actor) {
        friendships.unblock(userId, actorName(actor));
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/users/me/blocks")
    public ResponseEntity<PageResponse<PublicUserSummaryResponse>> blocks(
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(friendships.blocks(page, size, actorName(actor)));
    }

    private String actorName(UserDetails actor) { return actor == null ? null : actor.getUsername(); }
}

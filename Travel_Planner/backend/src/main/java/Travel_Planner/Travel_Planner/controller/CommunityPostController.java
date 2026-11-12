package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.*;
import Travel_Planner.Travel_Planner.dto.response.*;
import Travel_Planner.Travel_Planner.service.PostService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@Validated
@RequestMapping("/api/community")
public class CommunityPostController {

    private final PostService postService;

    public CommunityPostController(PostService postService) {
        this.postService = postService;
    }

    @GetMapping("/feed")
    public ResponseEntity<PageResponse<PostResponse>> getPublicFeed(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails viewer) {
        String username = viewer != null ? viewer.getUsername() : null;
        return ResponseEntity.ok(postService.getPublicFeed(page, size, username));
    }

    @GetMapping("/feed/following")
    public ResponseEntity<PageResponse<PostResponse>> getFollowingFeed(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @AuthenticationPrincipal UserDetails viewer) {
        String username = viewer != null ? viewer.getUsername() : null;
        return ResponseEntity.ok(postService.getFollowingFeed(page, size, username));
    }

    @PostMapping("/posts")
    public ResponseEntity<PostResponse> createPost(
            @Valid @RequestBody CreatePostRequest request,
            @AuthenticationPrincipal UserDetails author) {
        String username = author != null ? author.getUsername() : null;
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.createPost(request, username));
    }

    @GetMapping("/posts/{id}")
    public ResponseEntity<PostResponse> getPostById(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails viewer) {
        String username = viewer != null ? viewer.getUsername() : null;
        return ResponseEntity.ok(postService.getPostById(id, username));
    }

    @PatchMapping("/posts/{id}")
    public ResponseEntity<PostResponse> updatePost(
            @PathVariable("id") Long id,
            @Valid @RequestBody UpdatePostRequest request,
            @AuthenticationPrincipal UserDetails author) {
        String username = author != null ? author.getUsername() : null;
        return ResponseEntity.ok(postService.updatePost(id, request, username));
    }

    @DeleteMapping("/posts/{id}")
    public ResponseEntity<Void> deletePost(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails actor) {
        String username = actor != null ? actor.getUsername() : null;
        postService.deletePost(id, username);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/posts/{id}/likes")
    public ResponseEntity<Void> likePost(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails actor) {
        String username = actor != null ? actor.getUsername() : null;
        postService.likePost(id, username);
        return ResponseEntity.ok().build();
    }

    @DeleteMapping("/posts/{id}/likes")
    public ResponseEntity<Void> unlikePost(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails actor) {
        String username = actor != null ? actor.getUsername() : null;
        postService.unlikePost(id, username);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/posts/{id}/comments")
    public ResponseEntity<PageResponse<PostCommentResponse>> getComments(
            @PathVariable("id") Long id,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails viewer) {
        String username = viewer != null ? viewer.getUsername() : null;
        return ResponseEntity.ok(postService.getComments(id, page, size, username));
    }

    @PostMapping("/posts/{id}/comments")
    public ResponseEntity<PostCommentResponse> addComment(
            @PathVariable("id") Long id,
            @Valid @RequestBody CreatePostCommentRequest request,
            @AuthenticationPrincipal UserDetails author) {
        String username = author != null ? author.getUsername() : null;
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.addComment(id, request, username));
    }

    @PatchMapping("/posts/{id}/comments/{commentId}")
    public ResponseEntity<PostCommentResponse> updateComment(
            @PathVariable("id") Long id,
            @PathVariable("commentId") Long commentId,
            @Valid @RequestBody UpdatePostCommentRequest request,
            @AuthenticationPrincipal UserDetails author) {
        String username = author != null ? author.getUsername() : null;
        return ResponseEntity.ok(postService.updateComment(id, commentId, request, username));
    }

    @DeleteMapping("/posts/{id}/comments/{commentId}")
    public ResponseEntity<Void> deleteComment(
            @PathVariable("id") Long id,
            @PathVariable("commentId") Long commentId,
            @AuthenticationPrincipal UserDetails actor) {
        String username = actor != null ? actor.getUsername() : null;
        postService.deleteComment(id, commentId, username);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/posts/{id}/report")
    public ResponseEntity<PostReportResponse> reportPost(
            @PathVariable("id") Long id,
            @Valid @RequestBody CreatePostReportRequest request,
            @AuthenticationPrincipal UserDetails reporter) {
        String username = reporter != null ? reporter.getUsername() : null;
        return ResponseEntity.status(HttpStatus.CREATED).body(postService.reportPost(id, request, username));
    }
}


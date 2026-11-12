package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.ModeratePostRequest;
import Travel_Planner.Travel_Planner.dto.response.MediaAssetResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.dto.response.PostReportResponse;
import Travel_Planner.Travel_Planner.dto.response.PostResponse;
import Travel_Planner.Travel_Planner.model.enums.MediaAssetStatus;
import Travel_Planner.Travel_Planner.model.enums.PostStatus;
import Travel_Planner.Travel_Planner.model.enums.ReportStatus;
import Travel_Planner.Travel_Planner.service.PostService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@Validated
@RequestMapping("/api/admin")
public class AdminCommunityController {

    private final PostService postService;

    public AdminCommunityController(PostService postService) {
        this.postService = postService;
    }

    @GetMapping("/community/posts")
    public ResponseEntity<PageResponse<PostResponse>> getPosts(
            @RequestParam(required = false) PostStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(postService.getAdminPosts(status, page, size));
    }

    @PatchMapping("/community/posts/{id}/moderate")
    public ResponseEntity<PostResponse> moderatePost(
            @PathVariable("id") Long id,
            @Valid @RequestBody ModeratePostRequest request,
            @AuthenticationPrincipal UserDetails admin) {
        String username = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(postService.moderatePost(id, request, username));
    }

    @DeleteMapping("/community/posts/{id}/purge")
    public ResponseEntity<Void> purgePost(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails admin) {
        String username = admin != null ? admin.getUsername() : null;
        postService.purgePost(id, username);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/community/reports")
    public ResponseEntity<PageResponse<PostReportResponse>> getReports(
            @RequestParam(required = false) ReportStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(postService.getAdminReports(status, page, size));
    }

    @PatchMapping("/community/reports/{id}/resolve")
    public ResponseEntity<PostReportResponse> resolveReport(
            @PathVariable("id") Long id,
            @RequestParam ReportStatus resolution,
            @AuthenticationPrincipal UserDetails admin) {
        String username = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(postService.resolveReport(id, resolution, username));
    }

    @GetMapping("/media-assets")
    public ResponseEntity<PageResponse<MediaAssetResponse>> getMediaAssets(
            @RequestParam(required = false) MediaAssetStatus status,
            @RequestParam(defaultValue = "false") boolean deadLetterOnly,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(postService.getAdminMediaAssets(status, deadLetterOnly, page, size));
    }

    @PostMapping("/media-assets/{id}/retry")
    public ResponseEntity<Void> retryMediaAsset(
            @PathVariable("id") Long id,
            @AuthenticationPrincipal UserDetails admin) {
        String username = admin != null ? admin.getUsername() : null;
        postService.retryMediaAsset(id, username);
        return ResponseEntity.ok().build();
    }
}


package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.service.CommentService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/activities/{activityId}/comments")
public class ActivityCommentController {
    private final CommentService comments;
    public ActivityCommentController(CommentService comments) { this.comments = comments; }

    @GetMapping
    public ResponseEntity<PageResponse<CommentResponse>> get(@PathVariable Integer activityId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(comments.getActivityComments(activityId, page, size));
    }

    @PostMapping
    public ResponseEntity<CommentResponse> create(@PathVariable Integer activityId,
            @Valid @RequestBody CreateCommentRequest request, @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(comments.createActivityComment(activityId, request,
                user == null ? null : user.getUsername()));
    }
}

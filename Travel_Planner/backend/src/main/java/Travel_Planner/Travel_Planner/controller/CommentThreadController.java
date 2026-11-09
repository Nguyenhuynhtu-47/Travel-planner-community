package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.CreateCommentRequest;
import Travel_Planner.Travel_Planner.dto.response.CommentResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.service.CommentService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/comments")
public class CommentThreadController {
    private final CommentService comments;
    public CommentThreadController(CommentService comments) { this.comments = comments; }

    @GetMapping("/{commentId}/replies")
    public ResponseEntity<PageResponse<CommentResponse>> getReplies(@PathVariable Integer commentId,
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "10") int size) {
        return ResponseEntity.ok(comments.getReplies(commentId, page, size));
    }

    @PostMapping("/{commentId}/replies")
    public ResponseEntity<CommentResponse> createReply(@PathVariable Integer commentId,
            @Valid @RequestBody CreateCommentRequest request, @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.status(HttpStatus.CREATED).body(comments.createReply(commentId, request,
                user == null ? null : user.getUsername()));
    }

    @PutMapping("/{commentId}")
    public ResponseEntity<CommentResponse> update(@PathVariable Integer commentId,
            @Valid @RequestBody CreateCommentRequest request, @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(comments.updateComment(commentId, request, user == null ? null : user.getUsername()));
    }

    @DeleteMapping("/{commentId}")
    public ResponseEntity<Map<String, String>> delete(@PathVariable Integer commentId,
            @AuthenticationPrincipal UserDetails user) {
        comments.deleteComment(commentId, user == null ? null : user.getUsername());
        return ResponseEntity.ok(Map.of("message", "Đã xóa bình luận"));
    }
}

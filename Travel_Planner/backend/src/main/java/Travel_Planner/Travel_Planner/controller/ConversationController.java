package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.MarkConversationReadRequest;
import Travel_Planner.Travel_Planner.dto.request.OpenConversationRequest;
import Travel_Planner.Travel_Planner.dto.request.SendMessageRequest;
import Travel_Planner.Travel_Planner.dto.response.ConversationSummaryResponse;
import Travel_Planner.Travel_Planner.dto.response.MessagePageResponse;
import Travel_Planner.Travel_Planner.dto.response.MessageResponse;
import Travel_Planner.Travel_Planner.dto.response.PageResponse;
import Travel_Planner.Travel_Planner.service.MessagingService;
import Travel_Planner.Travel_Planner.dto.response.TotalUnreadResponse;
import jakarta.validation.Valid;
import jakarta.validation.constraints.PositiveOrZero;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

@RestController
@Validated
@RequestMapping("/api/conversations")
public class ConversationController {
    private final MessagingService messaging;
    public ConversationController(MessagingService messaging) { this.messaging = messaging; }

    @PostMapping("/direct")
    public ResponseEntity<ConversationSummaryResponse> openDirect(@Valid @RequestBody OpenConversationRequest request,
            @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.status(HttpStatus.CREATED).body(messaging.openDirect(request.getRecipientUserId(), actorName(actor)));
    }

    @GetMapping("/unread-total")
    public ResponseEntity<TotalUnreadResponse> totalUnread(@AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(new TotalUnreadResponse(messaging.totalUnread(actorName(actor))));
    }

    @GetMapping
    public ResponseEntity<PageResponse<ConversationSummaryResponse>> list(
            @RequestParam(defaultValue = "0") int page, @RequestParam(defaultValue = "20") int size,
            @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(messaging.conversations(page, size, actorName(actor)));
    }

    @GetMapping("/{conversationId}/messages")
    public ResponseEntity<MessagePageResponse> messages(@PathVariable Long conversationId,
            @RequestParam(required = false) @PositiveOrZero Long beforeSequence,
            @RequestParam(required = false) @PositiveOrZero Long afterSequence,
            @RequestParam(defaultValue = "30") int size, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(messaging.messages(conversationId, beforeSequence, afterSequence, size, actorName(actor)));
    }

    @PostMapping("/{conversationId}/messages")
    public ResponseEntity<MessageResponse> send(@PathVariable Long conversationId,
            @Valid @RequestBody SendMessageRequest request, @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.status(HttpStatus.CREATED).body(messaging.send(conversationId, request, actorName(actor)));
    }

    @PostMapping("/{conversationId}/read")
    public ResponseEntity<Void> markRead(@PathVariable Long conversationId,
            @Valid @RequestBody MarkConversationReadRequest request, @AuthenticationPrincipal UserDetails actor) {
        messaging.markRead(conversationId, request.getLastReadSequence(), actorName(actor));
        return ResponseEntity.noContent().build();
    }

    private String actorName(UserDetails actor) { return actor == null ? null : actor.getUsername(); }
}

package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.UpdateMessagingSettingsRequest;
import Travel_Planner.Travel_Planner.dto.response.MessagingSettingsResponse;
import Travel_Planner.Travel_Planner.service.MessagingSettingsService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/users/me/messaging-settings")
public class MessagingSettingsController {
    private final MessagingSettingsService service;
    public MessagingSettingsController(MessagingSettingsService service) { this.service = service; }

    @GetMapping
    public ResponseEntity<MessagingSettingsResponse> get(@AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(service.get(actor == null ? null : actor.getUsername()));
    }

    @PutMapping
    public ResponseEntity<MessagingSettingsResponse> update(@Valid @RequestBody UpdateMessagingSettingsRequest request,
            @AuthenticationPrincipal UserDetails actor) {
        return ResponseEntity.ok(service.update(request.getInboundPolicy(), actor == null ? null : actor.getUsername()));
    }
}

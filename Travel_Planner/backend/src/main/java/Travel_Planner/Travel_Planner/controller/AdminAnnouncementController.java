package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.SaveAnnouncementRequest;
import Travel_Planner.Travel_Planner.dto.response.AdminAnnouncementResponse;
import Travel_Planner.Travel_Planner.model.enums.AnnouncementStatus;
import Travel_Planner.Travel_Planner.service.AdminAnnouncementService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/announcements")
public class AdminAnnouncementController {
    private final AdminAnnouncementService service;
    public AdminAnnouncementController(AdminAnnouncementService service) { this.service = service; }

    @GetMapping public Page<AdminAnnouncementResponse> list(@RequestParam(required = false) AnnouncementStatus status,
            @RequestParam(required = false) String type, @RequestParam(required = false) String query,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) { return service.list(status, type, query, page, size); }
    @GetMapping("/summary") public Map<String, Long> summary() { return service.summary(); }
    @GetMapping("/{id}") public AdminAnnouncementResponse get(@PathVariable Long id) { return service.get(id); }
    @PostMapping public ResponseEntity<AdminAnnouncementResponse> create(@Valid @RequestBody SaveAnnouncementRequest request,
            @AuthenticationPrincipal UserDetails admin) { return ResponseEntity.status(HttpStatus.CREATED).body(service.create(request, admin.getUsername())); }
    @PutMapping("/{id}") public AdminAnnouncementResponse update(@PathVariable Long id,
            @Valid @RequestBody SaveAnnouncementRequest request, @AuthenticationPrincipal UserDetails admin) { return service.update(id, request, admin.getUsername()); }
    @PostMapping("/{id}/publish") public AdminAnnouncementResponse publish(@PathVariable Long id,
            @AuthenticationPrincipal UserDetails admin) { return service.publish(id, admin.getUsername()); }
    @PostMapping("/{id}/cancel") public AdminAnnouncementResponse cancel(@PathVariable Long id,
            @AuthenticationPrincipal UserDetails admin) { return service.cancel(id, admin.getUsername()); }
}

package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.UpdateSystemSettingRequest;
import Travel_Planner.Travel_Planner.dto.response.SystemSettingResponse;
import Travel_Planner.Travel_Planner.service.SystemSettingService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@PreAuthorize("hasRole('ADMIN')")
@RequestMapping("/api/admin/settings")
public class AdminSettingsController {

    private final SystemSettingService systemSettingService;

    public AdminSettingsController(SystemSettingService systemSettingService) {
        this.systemSettingService = systemSettingService;
    }

    @GetMapping
    public ResponseEntity<List<SystemSettingResponse>> getSettings() {
        return ResponseEntity.ok(systemSettingService.getSettings());
    }

    @PutMapping("/{key}")
    public ResponseEntity<SystemSettingResponse> updateSetting(
            @PathVariable("key") String key,
            @Valid @RequestBody UpdateSystemSettingRequest request,
            @AuthenticationPrincipal UserDetails admin) {
        String actorUsername = admin != null ? admin.getUsername() : null;
        return ResponseEntity.ok(systemSettingService.updateSetting(key, request, actorUsername));
    }
}

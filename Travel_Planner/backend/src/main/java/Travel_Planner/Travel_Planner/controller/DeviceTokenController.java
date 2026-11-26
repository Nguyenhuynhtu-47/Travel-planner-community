package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.UpsertDeviceTokenRequest;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.service.DeviceTokenService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users/me/devices/fcm-token")
public class DeviceTokenController {
    private final DeviceTokenService deviceTokens;

    public DeviceTokenController(DeviceTokenService deviceTokens) {
        this.deviceTokens = deviceTokens;
    }

    @PutMapping
    public ResponseEntity<Void> upsert(@Valid @RequestBody UpsertDeviceTokenRequest request,
            @AuthenticationPrincipal UserDetails principal) {
        deviceTokens.upsert(requireUsername(principal), request.getToken(), request.getPlatform());
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> unregister(@Valid @RequestBody UpsertDeviceTokenRequest request,
            @AuthenticationPrincipal UserDetails principal) {
        deviceTokens.unregister(requireUsername(principal), request.getToken());
        return ResponseEntity.noContent().build();
    }

    private static String requireUsername(UserDetails principal) {
        if (principal == null) throw new UnauthorizedException("Bạn cần đăng nhập");
        return principal.getUsername();
    }
}

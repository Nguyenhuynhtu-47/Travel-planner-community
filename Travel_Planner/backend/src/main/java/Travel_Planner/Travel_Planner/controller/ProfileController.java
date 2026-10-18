package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.UpdateProfileRequest;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.service.ProfileService;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/user/profile")
public class ProfileController {

    private final ProfileService profileService;

    public ProfileController(ProfileService profileService) {
        this.profileService = profileService;
    }

    @GetMapping
    public UserResponse getProfile(@AuthenticationPrincipal UserDetails userDetails) {
        return profileService.getCurrentProfile(userDetails.getUsername());
    }

    @PutMapping
    public UserResponse updateProfile(
            @AuthenticationPrincipal UserDetails userDetails,
            @Valid @RequestBody UpdateProfileRequest request) {
        return profileService.updateCurrentProfile(userDetails.getUsername(), request);
    }
}

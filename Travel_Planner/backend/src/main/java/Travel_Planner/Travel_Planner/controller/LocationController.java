package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.response.LocationSearchResultResponse;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.service.LocationRateLimiter;
import Travel_Planner.Travel_Planner.service.LocationService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/locations")
public class LocationController {

    private final LocationService locationService;
    private final LocationRateLimiter locationRateLimiter;
    private final ClientIpResolver clientIpResolver;
    private final UserRepository userRepository;

    public LocationController(LocationService locationService,
                              LocationRateLimiter locationRateLimiter,
                              ClientIpResolver clientIpResolver,
                              UserRepository userRepository) {
        this.locationService = locationService;
        this.locationRateLimiter = locationRateLimiter;
        this.clientIpResolver = clientIpResolver;
        this.userRepository = userRepository;
    }

    @GetMapping("/search")
    public ResponseEntity<List<LocationSearchResultResponse>> search(
            @RequestParam(name = "query", required = false) String queryParam,
            @RequestParam(name = "q", required = false) String qParam,
            @RequestParam(name = "limit", required = false) Integer limit,
            @RequestParam(name = "latitude", required = false) Double latitude,
            @RequestParam(name = "lat", required = false) Double lat,
            @RequestParam(name = "longitude", required = false) Double longitude,
            @RequestParam(name = "lon", required = false) Double lon,
            @RequestParam(name = "lng", required = false) Double lng,
            HttpServletRequest request,
            Authentication authentication) {

        enforceRateLimit(request, authentication);

        String query = queryParam != null ? queryParam : qParam;
        Double effectiveLat = latitude != null ? latitude : lat;
        Double effectiveLon = longitude != null ? longitude : (lon != null ? lon : lng);

        List<LocationSearchResultResponse> results = locationService.searchLocations(query, limit, effectiveLat, effectiveLon);
        return ResponseEntity.ok(results);
    }

    @GetMapping("/reverse-geocode")
    public ResponseEntity<LocationSearchResultResponse> reverseGeocode(
            @RequestParam(name = "latitude", required = false) Double latitude,
            @RequestParam(name = "lat", required = false) Double lat,
            @RequestParam(name = "longitude", required = false) Double longitude,
            @RequestParam(name = "lon", required = false) Double lon,
            @RequestParam(name = "lng", required = false) Double lng,
            HttpServletRequest request,
            Authentication authentication) {

        enforceRateLimit(request, authentication);

        Double effectiveLat = latitude != null ? latitude : lat;
        Double effectiveLon = longitude != null ? longitude : (lon != null ? lon : lng);

        LocationSearchResultResponse result = locationService.reverseGeocode(effectiveLat, effectiveLon);
        return ResponseEntity.ok(result);
    }

    private void enforceRateLimit(HttpServletRequest request, Authentication authentication) {
        boolean isAuthenticated = authentication != null && authentication.isAuthenticated()
                && !(authentication instanceof AnonymousAuthenticationToken);

        String rateLimitKey;
        if (isAuthenticated) {
            String username = authentication.getName();
            Integer userId = userRepository.findByUsername(username)
                    .map(User::getUserId)
                    .orElse(null);
            rateLimitKey = "auth:user:" + (userId != null ? userId : username);
        } else {
            String clientIp = clientIpResolver.resolveClientIp(request);
            rateLimitKey = "ip:" + clientIp;
        }

        boolean allowed = locationRateLimiter.tryConsume(rateLimitKey, isAuthenticated);
        if (!allowed) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu vị trí. Vui lòng thử lại sau một phút.");
        }
    }
}


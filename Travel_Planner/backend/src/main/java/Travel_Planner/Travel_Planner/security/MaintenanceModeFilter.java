package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.dto.response.ErrorResponse;
import Travel_Planner.Travel_Planner.service.SystemSettingService;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Lazy;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Instant;

/**
 * Security filter enforcing global Maintenance Mode.
 * Runs strictly AFTER {@link org.springframework.web.filter.CorsFilter} and {@link JwtAuthenticationFilter}.
 * Allows essential endpoints (/api/health, /api/auth/login, OPTIONS preflight) and authenticated ROLE_ADMIN bypass.
 */
@Component
public class MaintenanceModeFilter extends OncePerRequestFilter {

    private final SystemSettingService systemSettingService;
    private final ObjectMapper objectMapper;

    public MaintenanceModeFilter(@Lazy SystemSettingService systemSettingService) {
        this.systemSettingService = systemSettingService;
        this.objectMapper = new ObjectMapper();
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain) throws ServletException, IOException {

        if (HttpMethod.OPTIONS.matches(request.getMethod())) {
            filterChain.doFilter(request, response);
            return;
        }

        if (!systemSettingService.isMaintenanceModeEnabled()) {
            filterChain.doFilter(request, response);
            return;
        }

        String path = request.getRequestURI();
        if ("/api/health".equals(path) || "/api/auth/login".equals(path)) {
            filterChain.doFilter(request, response);
            return;
        }

        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        boolean isAuthenticatedAdmin = auth != null
                && auth.isAuthenticated()
                && auth.getAuthorities().stream()
                        .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));

        if (isAuthenticatedAdmin) {
            filterChain.doFilter(request, response);
            return;
        }

        ErrorResponse error = ErrorResponse.builder()
                .timestamp(Instant.now().toString())
                .status(HttpStatus.SERVICE_UNAVAILABLE.value())
                .error(HttpStatus.SERVICE_UNAVAILABLE.getReasonPhrase())
                .message(systemSettingService.getMaintenanceMessage())
                .path(path)
                .build();

        response.setStatus(HttpStatus.SERVICE_UNAVAILABLE.value());
        response.setCharacterEncoding("UTF-8");
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        objectMapper.writeValue(response.getWriter(), error);
    }
}

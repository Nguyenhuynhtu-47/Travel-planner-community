package Travel_Planner.Travel_Planner.util;

import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.security.CorrelationIdFilter;
import Travel_Planner.Travel_Planner.security.CustomUserDetails;
import jakarta.servlet.http.HttpServletRequest;
import org.slf4j.MDC;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.UUID;

/**
 * Resolves authoritative audit actor identity from Spring SecurityContext
 * and request metadata (IP address, User-Agent, correlation ID) from the active HTTP request.
 *
 * Client-supplied actor headers (e.g. X-Actor-Id, X-User-Id) are never trusted.
 */
@Component
public class AuditContextResolver {

    private final UserRepository userRepository;
    private final ClientIpResolver clientIpResolver;

    public AuditContextResolver(UserRepository userRepository, ClientIpResolver clientIpResolver) {
        this.userRepository = userRepository;
        this.clientIpResolver = clientIpResolver;
    }

    public AuditActor resolveAuthenticatedActor(String expectedActorUsername) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {
            throw new UnauthorizedException("Không thể ghi nhật ký kiểm toán khi chưa xác thực danh tính.");
        }

        AuditActor actor = extractActorFromPrincipal(authentication.getPrincipal());

        if (expectedActorUsername != null && !expectedActorUsername.isBlank()
                && !actor.username().equalsIgnoreCase(expectedActorUsername.trim())) {
            throw new ForbiddenException("Không được phép giả mạo tác nhân thực hiện thao tác kiểm toán.");
        }

        return actor;
    }

    public AuditActor resolveTelemetryActorOrSystem() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null
                || !authentication.isAuthenticated()
                || authentication instanceof AnonymousAuthenticationToken) {
            return new AuditActor(0, "SYSTEM");
        }
        try {
            return extractActorFromPrincipal(authentication.getPrincipal());
        } catch (RuntimeException ex) {
            return new AuditActor(0, "SYSTEM");
        }
    }

    public AuditRequestMetadata resolveRequestMetadata(
            String fallbackIp,
            String fallbackUserAgent,
            String fallbackCorrelationId) {

        HttpServletRequest request = currentHttpRequest();
        String ipAddress;
        String userAgent;

        if (request != null) {
            ipAddress = clientIpResolver != null
                    ? truncate(clientIpResolver.resolveClientIp(request), 45)
                    : truncate(request.getRemoteAddr(), 45);
            userAgent = sanitizeAndTruncate(request.getHeader("User-Agent"), 255);
        } else {
            ipAddress = sanitizeAndTruncate(fallbackIp, 45);
            userAgent = sanitizeAndTruncate(fallbackUserAgent, 255);
        }

        String mdcCorrelation = MDC.get(CorrelationIdFilter.CORRELATION_ID_MDC_KEY);
        String correlationId;
        if (mdcCorrelation != null && !mdcCorrelation.isBlank()) {
            correlationId = sanitizeAndTruncate(mdcCorrelation, 64);
        } else if (request != null) {
            correlationId = CorrelationIdFilter.resolveOrGenerateCorrelationId(
                    request.getHeader(CorrelationIdFilter.CORRELATION_ID_HEADER));
        } else if (fallbackCorrelationId != null && !fallbackCorrelationId.isBlank()) {
            correlationId = sanitizeAndTruncate(fallbackCorrelationId, 64);
        } else {
            correlationId = UUID.randomUUID().toString();
        }

        return new AuditRequestMetadata(ipAddress, userAgent, correlationId);
    }

    private AuditActor extractActorFromPrincipal(Object principal) {
        if (principal instanceof CustomUserDetails customUser) {
            if (customUser.getUserId() == null || customUser.getUsername() == null || customUser.getUsername().isBlank()) {
                throw new UnauthorizedException("Thông tin xác thực tác nhân không hợp lệ.");
            }
            return new AuditActor(customUser.getUserId(), truncate(customUser.getUsername(), 50));
        }

        String username = null;
        if (principal instanceof UserDetails userDetails) {
            username = userDetails.getUsername();
        } else if (principal instanceof String s) {
            username = s;
        }

        if (username == null || username.isBlank() || "anonymousUser".equalsIgnoreCase(username)) {
            throw new UnauthorizedException("Không thể xác định danh tính tác nhân kiểm toán.");
        }

        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("Tài khoản tác nhân kiểm toán không tồn tại."));

        return new AuditActor(user.getUserId(), truncate(user.getUsername(), 50));
    }

    private HttpServletRequest currentHttpRequest() {
        RequestAttributes attrs = RequestContextHolder.getRequestAttributes();
        if (attrs instanceof ServletRequestAttributes servletAttrs) {
            return servletAttrs.getRequest();
        }
        return null;
    }

    public static String truncate(String value, int maxLen) {
        if (value == null) {
            return null;
        }
        return value.length() <= maxLen ? value : value.substring(0, maxLen);
    }

    public static String sanitizeAndTruncate(String value, int maxLen) {
        if (value == null) {
            return null;
        }
        String sanitized = value.replaceAll("[\\r\\n\\t]", " ").trim();
        if (sanitized.isEmpty()) {
            return null;
        }
        return truncate(sanitized, maxLen);
    }

    public record AuditActor(Integer userId, String username) {
    }

    public record AuditRequestMetadata(String ipAddress, String userAgent, String correlationId) {
    }
}

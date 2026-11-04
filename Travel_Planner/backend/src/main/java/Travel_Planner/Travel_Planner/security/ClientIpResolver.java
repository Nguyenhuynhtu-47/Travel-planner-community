package Travel_Planner.Travel_Planner.security;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.Set;
import java.util.stream.Collectors;

@Component
public class ClientIpResolver {

    private final Set<String> trustedProxies;

    public ClientIpResolver(@Value("${app.security.trusted-proxies:127.0.0.1,0:0:0:0:0:0:0:1,::1}") String trustedProxiesConfig) {
        this.trustedProxies = Arrays.stream(trustedProxiesConfig.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .collect(Collectors.toSet());
    }

    public String resolveClientIp(HttpServletRequest request) {
        if (request == null) {
            return "unknown";
        }

        String remoteAddr = request.getRemoteAddr();
        String normalizedRemote = cleanIp(remoteAddr);

        // Only trust forwarded headers if the direct remote address matches a configured trusted proxy
        if (isTrustedProxy(normalizedRemote)) {
            String forwardedFor = request.getHeader("X-Forwarded-For");
            if (forwardedFor != null && !forwardedFor.isBlank()) {
                String[] parts = forwardedFor.split(",");
                for (String part : parts) {
                    String candidate = cleanIp(part);
                    if (!candidate.isEmpty() && !"unknown".equalsIgnoreCase(candidate)) {
                        return candidate;
                    }
                }
            }
            String realIp = request.getHeader("X-Real-IP");
            if (realIp != null && !realIp.isBlank()) {
                String candidate = cleanIp(realIp);
                if (!candidate.isEmpty() && !"unknown".equalsIgnoreCase(candidate)) {
                    return candidate;
                }
            }
        }

        return normalizedRemote.isEmpty() ? "unknown" : normalizedRemote;
    }

    public boolean isTrustedProxy(String ip) {
        if (ip == null || ip.isBlank()) {
            return false;
        }
        String cleaned = cleanIp(ip);
        if ("::1".equals(cleaned) && (trustedProxies.contains("0:0:0:0:0:0:0:1") || trustedProxies.contains("::1"))) {
            return true;
        }
        if ("0:0:0:0:0:0:0:1".equals(cleaned) && (trustedProxies.contains("::1") || trustedProxies.contains("0:0:0:0:0:0:0:1"))) {
            return true;
        }
        return trustedProxies.contains(cleaned);
    }

    public String cleanIp(String raw) {
        if (raw == null) {
            return "";
        }
        String trimmed = raw.trim();
        // Remove surrounding quotes if present (e.g. "\"198.51.100.1\"")
        if (trimmed.startsWith("\"") && trimmed.endsWith("\"") && trimmed.length() >= 2) {
            trimmed = trimmed.substring(1, trimmed.length() - 1).trim();
        }
        // Handle IPv6 bracket notation with optional port: [2001:db8::1]:8080 -> 2001:db8::1
        if (trimmed.startsWith("[") && trimmed.contains("]")) {
            int closeBracket = trimmed.indexOf(']');
            return trimmed.substring(1, closeBracket).trim();
        }
        // Handle IPv4 with port: 198.51.100.1:8080 -> 198.51.100.1 (ensure single colon, not IPv6)
        int colonIdx = trimmed.indexOf(':');
        if (colonIdx > 0 && colonIdx == trimmed.lastIndexOf(':')) {
            return trimmed.substring(0, colonIdx).trim();
        }
        return trimmed;
    }
}

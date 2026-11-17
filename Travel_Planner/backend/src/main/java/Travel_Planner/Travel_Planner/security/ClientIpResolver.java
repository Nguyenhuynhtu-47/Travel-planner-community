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

        // If direct remote address is not a trusted proxy, it is the authoritative client socket IP.
        // Direct client-supplied forwarded headers must never be trusted.
        if (!isTrustedProxy(normalizedRemote)) {
            return isValidIp(normalizedRemote) ? normalizedRemote : "unknown";
        }

        // Direct remote address is a trusted proxy.
        // Traverse the proxy chain in X-Forwarded-For from RIGHT to LEFT to find the first untrusted IP.
        String forwardedFor = request.getHeader("X-Forwarded-For");
        if (forwardedFor != null && !forwardedFor.isBlank()) {
            String[] parts = forwardedFor.split(",");
            for (int i = parts.length - 1; i >= 0; i--) {
                String candidate = cleanIp(parts[i]);
                if (!isValidIp(candidate)) {
                    continue;
                }
                if (isTrustedProxy(candidate)) {
                    // Intermediate trusted proxy in our cluster, keep traversing left
                    continue;
                }
                // First untrusted IP encountered from right: this is the real client connecting to the proxy perimeter
                return candidate;
            }
        }

        // Fallback to X-Real-IP if set by trusted proxy
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            String candidate = cleanIp(realIp);
            if (isValidIp(candidate) && !isTrustedProxy(candidate)) {
                return candidate;
            }
        }

        return isValidIp(normalizedRemote) ? normalizedRemote : "unknown";
    }

    public boolean isValidIp(String ip) {
        if (ip == null || ip.isBlank() || "unknown".equalsIgnoreCase(ip)) {
            return false;
        }
        return isValidIpv4(ip) || isValidIpv6(ip);
    }

    private boolean isValidIpv4(String ip) {
        String[] parts = ip.split("\\.", -1);
        if (parts.length != 4) {
            return false;
        }
        for (String p : parts) {
            if (p.isEmpty() || p.length() > 3) {
                return false;
            }
            for (int i = 0; i < p.length(); i++) {
                if (!Character.isDigit(p.charAt(i))) {
                    return false;
                }
            }
            try {
                int val = Integer.parseInt(p);
                if (val < 0 || val > 255 || (p.length() > 1 && p.startsWith("0"))) {
                    return false;
                }
            } catch (NumberFormatException e) {
                return false;
            }
        }
        return true;
    }

    private boolean isValidIpv6(String ip) {
        if (!ip.contains(":")) {
            return false;
        }
        String[] parts = ip.split(":", -1);
        if (parts.length < 3 || parts.length > 8) {
            if (!ip.contains("::")) {
                return false;
            }
        }
        for (String p : parts) {
            if (p.length() > 4) {
                return false;
            }
            for (int i = 0; i < p.length(); i++) {
                char c = p.charAt(i);
                boolean isHex = (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
                if (!isHex) {
                    return false;
                }
            }
        }
        return true;
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

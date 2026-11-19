package Travel_Planner.Travel_Planner.security;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

@Component
public class DeviceInfoResolver {

    public String resolveDeviceInfo(HttpServletRequest request) {
        if (request == null) {
            return "Thiết bị không xác định";
        }

        String customDevice = request.getHeader("X-Device-Info");
        if (customDevice != null && !customDevice.trim().isEmpty()) {
            return sanitize(customDevice.trim(), 255);
        }

        String userAgent = request.getHeader("User-Agent");
        if (userAgent == null || userAgent.trim().isEmpty()) {
            return "Thiết bị không xác định";
        }

        userAgent = userAgent.trim();

        // Detect mobile or browser patterns for readable summaries
        String os = "Không xác định";
        if (userAgent.contains("Android")) {
            os = "Android";
        } else if (userAgent.contains("iPhone") || userAgent.contains("iPad") || userAgent.contains("iOS")) {
            os = "iOS";
        } else if (userAgent.contains("Windows")) {
            os = "Windows";
        } else if (userAgent.contains("Macintosh") || userAgent.contains("Mac OS")) {
            os = "macOS";
        } else if (userAgent.contains("Linux")) {
            os = "Linux";
        }

        String client = "Trình duyệt";
        if (userAgent.contains("Dart") || userAgent.contains("TravelPlanner") || userAgent.contains("MobileApp")) {
            client = "Ứng dụng Di động";
        } else if (userAgent.contains("Edg/")) {
            client = "Edge";
        } else if (userAgent.contains("Chrome/")) {
            client = "Chrome";
        } else if (userAgent.contains("Firefox/")) {
            client = "Firefox";
        } else if (userAgent.contains("Safari/") && !userAgent.contains("Chrome/")) {
            client = "Safari";
        }

        if (!"Không xác định".equals(os)) {
            return client + " (" + os + ")";
        }

        return sanitize(userAgent, 255);
    }

    private String sanitize(String input, int maxLength) {
        String clean = input.replaceAll("[\\r\\n\\t]", " ").trim();
        if (clean.length() > maxLength) {
            return clean.substring(0, maxLength);
        }
        return clean;
    }
}

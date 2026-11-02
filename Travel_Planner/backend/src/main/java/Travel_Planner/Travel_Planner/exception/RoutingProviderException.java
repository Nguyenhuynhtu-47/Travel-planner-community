package Travel_Planner.Travel_Planner.exception;

import org.springframework.http.HttpStatus;

/**
 * Exception thrown when an external routing provider (e.g. OpenRouteService)
 * fails due to timeout, rate-limit, 4xx/5xx HTTP error, or malformed payload.
 */
public class RoutingProviderException extends RuntimeException {
    private final HttpStatus status;
    private final boolean isTimeout;
    private final boolean isRateLimit;

    public RoutingProviderException(String message, HttpStatus status, boolean isTimeout, boolean isRateLimit) {
        super(message);
        this.status = status;
        this.isTimeout = isTimeout;
        this.isRateLimit = isRateLimit;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public boolean isTimeout() {
        return isTimeout;
    }

    public boolean isRateLimit() {
        return isRateLimit;
    }
}


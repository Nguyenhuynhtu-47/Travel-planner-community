package Travel_Planner.Travel_Planner.exception;

import org.springframework.http.HttpStatus;

public class RateLimitExceededException extends AppException {
    public RateLimitExceededException(String message) {
        super(message, HttpStatus.TOO_MANY_REQUESTS);
    }
}


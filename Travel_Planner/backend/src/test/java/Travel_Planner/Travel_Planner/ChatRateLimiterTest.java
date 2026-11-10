package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.service.ChatRateLimiter;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ChatRateLimiterTest {
    @Test
    void appliesConfiguredPerUserLimit() {
        ChatRateLimiter limiter = new ChatRateLimiter(2);
        assertTrue(limiter.allow(12));
        assertTrue(limiter.allow(12));
        assertFalse(limiter.allow(12));
        assertTrue(limiter.allow(13));
    }
}
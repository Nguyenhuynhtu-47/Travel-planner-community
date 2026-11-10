package Travel_Planner.Travel_Planner.service;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.time.Duration;

@Component
public class ChatRateLimiter {
    private final Cache<Integer, Bucket> buckets = Caffeine.newBuilder().expireAfterAccess(Duration.ofHours(1)).maximumSize(20_000).build();
    private final long messagesPerMinute;

    public ChatRateLimiter(@Value("${chat.rate-limit.messages-per-minute:30}") long messagesPerMinute) {
        this.messagesPerMinute = Math.max(1, messagesPerMinute);
    }

    public boolean allow(Integer userId) {
        Bucket bucket = buckets.get(userId, key -> Bucket.builder()
                .addLimit(Bandwidth.builder().capacity(messagesPerMinute).refillGreedy(messagesPerMinute, Duration.ofMinutes(1)).build())
                .build());
        return bucket.tryConsume(1);
    }
}

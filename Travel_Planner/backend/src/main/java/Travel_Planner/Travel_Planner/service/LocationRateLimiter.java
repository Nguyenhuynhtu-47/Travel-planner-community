package Travel_Planner.Travel_Planner.service;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
public class LocationRateLimiter {

    // Evict inactive rate limiting buckets after 1 hour, bounded to max 10,000 active keys
    private final Cache<String, Bucket> bucketCache = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(10_000)
            .build();

    public boolean tryConsume(String key, boolean isAuthenticated) {
        Bucket bucket = bucketCache.get(key, k -> createNewBucket(isAuthenticated));
        return bucket != null && bucket.tryConsume(1);
    }

    public long getAvailableTokens(String key, boolean isAuthenticated) {
        Bucket bucket = bucketCache.get(key, k -> createNewBucket(isAuthenticated));
        return bucket != null ? bucket.getAvailableTokens() : 0;
    }

    public void reset(String key) {
        bucketCache.invalidate(key);
    }

    public void clear() {
        bucketCache.invalidateAll();
    }

    private Bucket createNewBucket(boolean isAuthenticated) {
        long capacity = isAuthenticated ? 60 : 30;
        Bandwidth limit = Bandwidth.builder()
                .capacity(capacity)
                .refillGreedy(capacity, Duration.ofMinutes(1))
                .build();
        return Bucket.builder()
                .addLimit(limit)
                .build();
    }
}


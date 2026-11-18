package Travel_Planner.Travel_Planner.security;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.util.Locale;

@Component
public class AuthRateLimiter {

    private final boolean enabled;
    private final long loginCapacity;
    private final long loginDurationMinutes;
    private final long registerCapacity;
    private final long registerDurationMinutes;
    private final long accountCapacity;
    private final long accountDurationMinutes;
    private final long verifyCapacity;
    private final long verifyDurationMinutes;
    private final long resendCapacity;
    private final long resendDurationMinutes;
    private final long forgotCapacity;
    private final long forgotDurationMinutes;
    private final long resetPasswordCapacity;
    private final long resetPasswordDurationMinutes;
    private final long changePasswordCapacity;
    private final long changePasswordDurationMinutes;

    // Cache for IP-based login rate limiting (evict after 1 hour of inactivity, bounded to 20,000 keys)
    private final Cache<String, Bucket> loginIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account-based login rate limiting (identifier: username or email)
    private final Cache<String, Bucket> loginAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for IP-based registration rate limiting
    private final Cache<String, Bucket> registerIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for IP-based email verification rate limiting (Phase 1)
    private final Cache<String, Bucket> verifyIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account/Email-based email verification rate limiting (Phase 1)
    private final Cache<String, Bucket> verifyAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for IP-based resend verification rate limiting (Phase 1)
    private final Cache<String, Bucket> resendIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account/Email-based resend verification rate limiting (Phase 1)
    private final Cache<String, Bucket> resendAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for IP-based forgot password rate limiting (Phase 2)
    private final Cache<String, Bucket> forgotPasswordIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account/Email-based forgot password rate limiting (Phase 2)
    private final Cache<String, Bucket> forgotPasswordAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for IP-based reset password rate limiting (Phase 2)
    private final Cache<String, Bucket> resetPasswordIpBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account/Email-based reset password rate limiting (Phase 2)
    private final Cache<String, Bucket> resetPasswordAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Email change rate limiting (Phase 4)
    private final Cache<String, Bucket> emailChangeBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    // Cache for Account-based change password rate limiting (Phase 2)
    private final Cache<String, Bucket> changePasswordAccountBuckets = Caffeine.newBuilder()
            .expireAfterAccess(Duration.ofHours(1))
            .maximumSize(20_000)
            .build();

    @Autowired
    public AuthRateLimiter(
            @Value("${auth.rate-limit.enabled:true}") boolean enabled,
            @Value("${auth.rate-limit.login.capacity:5}") long loginCapacity,
            @Value("${auth.rate-limit.login.duration-minutes:1}") long loginDurationMinutes,
            @Value("${auth.rate-limit.register.capacity:3}") long registerCapacity,
            @Value("${auth.rate-limit.register.duration-minutes:10}") long registerDurationMinutes,
            @Value("${auth.rate-limit.account.capacity:5}") long accountCapacity,
            @Value("${auth.rate-limit.account.duration-minutes:1}") long accountDurationMinutes,
            @Value("${auth.rate-limit.verify.capacity:10}") long verifyCapacity,
            @Value("${auth.rate-limit.verify.duration-minutes:1}") long verifyDurationMinutes,
            @Value("${auth.rate-limit.resend.capacity:3}") long resendCapacity,
            @Value("${auth.rate-limit.resend.duration-minutes:60}") long resendDurationMinutes,
            @Value("${auth.rate-limit.forgot.capacity:3}") long forgotCapacity,
            @Value("${auth.rate-limit.forgot.duration-minutes:15}") long forgotDurationMinutes,
            @Value("${auth.rate-limit.reset.capacity:5}") long resetPasswordCapacity,
            @Value("${auth.rate-limit.reset.duration-minutes:15}") long resetPasswordDurationMinutes,
            @Value("${auth.rate-limit.change.capacity:5}") long changePasswordCapacity,
            @Value("${auth.rate-limit.change.duration-minutes:15}") long changePasswordDurationMinutes) {
        this.enabled = enabled;
        this.loginCapacity = Math.max(1, loginCapacity);
        this.loginDurationMinutes = Math.max(1, loginDurationMinutes);
        this.registerCapacity = Math.max(1, registerCapacity);
        this.registerDurationMinutes = Math.max(1, registerDurationMinutes);
        this.accountCapacity = Math.max(1, accountCapacity);
        this.accountDurationMinutes = Math.max(1, accountDurationMinutes);
        this.verifyCapacity = Math.max(1, verifyCapacity);
        this.verifyDurationMinutes = Math.max(1, verifyDurationMinutes);
        this.resendCapacity = Math.max(1, resendCapacity);
        this.resendDurationMinutes = Math.max(1, resendDurationMinutes);
        this.forgotCapacity = Math.max(1, forgotCapacity);
        this.forgotDurationMinutes = Math.max(1, forgotDurationMinutes);
        this.resetPasswordCapacity = Math.max(1, resetPasswordCapacity);
        this.resetPasswordDurationMinutes = Math.max(1, resetPasswordDurationMinutes);
        this.changePasswordCapacity = Math.max(1, changePasswordCapacity);
        this.changePasswordDurationMinutes = Math.max(1, changePasswordDurationMinutes);
    }

    public AuthRateLimiter(
            boolean enabled,
            long loginCapacity,
            long loginDurationMinutes,
            long registerCapacity,
            long registerDurationMinutes,
            long accountCapacity,
            long accountDurationMinutes) {
        this(enabled, loginCapacity, loginDurationMinutes, registerCapacity, registerDurationMinutes,
                accountCapacity, accountDurationMinutes, 10, 1, 3, 60, 3, 15, 5, 15, 5, 15);
    }

    public boolean tryConsumeLogin(String clientIp, String identifier) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = loginIpBuckets.get(safeIp, k -> createBucket(loginCapacity, loginDurationMinutes));
        if (ipBucket != null && !ipBucket.tryConsume(1)) {
            return false;
        }

        if (identifier != null && !identifier.isBlank()) {
            String safeIdentifier = identifier.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = loginAccountBuckets.get(safeIdentifier, k -> createBucket(accountCapacity, accountDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeGoogleAuth(String clientIp) {
        if (!enabled) {
            return true;
        }
        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = loginIpBuckets.get(safeIp, k -> createBucket(loginCapacity, loginDurationMinutes));
        return ipBucket == null || ipBucket.tryConsume(1);
    }

    public boolean tryConsumeRegister(String clientIp) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket bucket = registerIpBuckets.get(safeIp, k -> createBucket(registerCapacity, registerDurationMinutes));
        return bucket != null && bucket.tryConsume(1);
    }

    public boolean tryConsumeVerifyEmail(String clientIp) {
        return tryConsumeVerifyEmail(clientIp, null);
    }

    public boolean tryConsumeVerifyEmail(String clientIp, String email) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = verifyIpBuckets.get(safeIp, k -> createBucket(verifyCapacity, verifyDurationMinutes));
        if (ipBucket != null && !ipBucket.tryConsume(1)) {
            return false;
        }

        if (email != null && !email.isBlank()) {
            String safeEmail = email.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = verifyAccountBuckets.get(safeEmail, k -> createBucket(verifyCapacity, verifyDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeResendVerification(String clientIp) {
        return tryConsumeResendVerification(clientIp, null);
    }

    public boolean tryConsumeResendVerification(String clientIp, String email) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = resendIpBuckets.get(safeIp, k -> createBucket(resendCapacity, resendDurationMinutes));
        if (ipBucket != null && !ipBucket.tryConsume(1)) {
            return false;
        }

        if (email != null && !email.isBlank()) {
            String safeEmail = email.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = resendAccountBuckets.get(safeEmail, k -> createBucket(resendCapacity, resendDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeForgotPassword(String clientIp, String email) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = forgotPasswordIpBuckets.get(safeIp, k -> createBucket(forgotCapacity, forgotDurationMinutes));
        if (ipBucket != null && !ipBucket.tryConsume(1)) {
            return false;
        }

        if (email != null && !email.isBlank()) {
            String safeEmail = email.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = forgotPasswordAccountBuckets.get(safeEmail, k -> createBucket(forgotCapacity, forgotDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeResetPassword(String clientIp, String email) {
        if (!enabled) {
            return true;
        }

        String safeIp = normalizeKey(clientIp);
        Bucket ipBucket = resetPasswordIpBuckets.get(safeIp, k -> createBucket(resetPasswordCapacity, resetPasswordDurationMinutes));
        if (ipBucket != null && !ipBucket.tryConsume(1)) {
            return false;
        }

        if (email != null && !email.isBlank()) {
            String safeEmail = email.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = resetPasswordAccountBuckets.get(safeEmail, k -> createBucket(resetPasswordCapacity, resetPasswordDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeChangePassword(String identifier) {
        if (!enabled) {
            return true;
        }

        if (identifier != null && !identifier.isBlank()) {
            String safeIdentifier = identifier.trim().toLowerCase(Locale.ROOT);
            Bucket accountBucket = changePasswordAccountBuckets.get(safeIdentifier, k -> createBucket(changePasswordCapacity, changePasswordDurationMinutes));
            if (accountBucket != null && !accountBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public boolean tryConsumeEmailChange(String clientIp, String identifier) {
        if (!enabled) {
            return true;
        }

        if (clientIp != null) {
            String safeIp = normalizeKey(clientIp);
            Bucket ipBucket = emailChangeBuckets.get(safeIp, k -> createBucket(5, 15));
            if (ipBucket != null && !ipBucket.tryConsume(1)) {
                return false;
            }
        }

        if (identifier != null && !identifier.isBlank()) {
            String safeIdentifier = identifier.trim().toLowerCase(Locale.ROOT);
            Bucket userBucket = emailChangeBuckets.get("user:" + safeIdentifier, k -> createBucket(5, 15));
            if (userBucket != null && !userBucket.tryConsume(1)) {
                return false;
            }
        }

        return true;
    }

    public void reset(String clientIp) {
        if (clientIp != null) {
            String safeIp = normalizeKey(clientIp);
            loginIpBuckets.invalidate(safeIp);
            registerIpBuckets.invalidate(safeIp);
            verifyIpBuckets.invalidate(safeIp);
            resendIpBuckets.invalidate(safeIp);
            forgotPasswordIpBuckets.invalidate(safeIp);
            resetPasswordIpBuckets.invalidate(safeIp);
        }
    }

    public void resetAccount(String identifier) {
        if (identifier != null) {
            String safeKey = identifier.trim().toLowerCase(Locale.ROOT);
            loginAccountBuckets.invalidate(safeKey);
            verifyAccountBuckets.invalidate(safeKey);
            resendAccountBuckets.invalidate(safeKey);
            forgotPasswordAccountBuckets.invalidate(safeKey);
            resetPasswordAccountBuckets.invalidate(safeKey);
            changePasswordAccountBuckets.invalidate(safeKey);
        }
    }

    /**
     * Clear all rate limiting buckets. Intended exclusively for test isolation teardown.
     * Not exposed through any production API or endpoint.
     */
    public void clear() {
        loginIpBuckets.invalidateAll();
        loginAccountBuckets.invalidateAll();
        registerIpBuckets.invalidateAll();
        verifyIpBuckets.invalidateAll();
        verifyAccountBuckets.invalidateAll();
        resendIpBuckets.invalidateAll();
        resendAccountBuckets.invalidateAll();
        forgotPasswordIpBuckets.invalidateAll();
        forgotPasswordAccountBuckets.invalidateAll();
        resetPasswordIpBuckets.invalidateAll();
        resetPasswordAccountBuckets.invalidateAll();
        changePasswordAccountBuckets.invalidateAll();
        emailChangeBuckets.invalidateAll();
    }

    private Bucket createBucket(long capacity, long durationMinutes) {
        Bandwidth limit = Bandwidth.builder()
                .capacity(capacity)
                .refillGreedy(capacity, Duration.ofMinutes(durationMinutes))
                .build();
        return Bucket.builder()
                .addLimit(limit)
                .build();
    }

    private String normalizeKey(String key) {
        if (key == null || key.isBlank()) {
            return "unknown";
        }
        return key.trim().toLowerCase(Locale.ROOT);
    }
}

package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.ForgotPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyResetOtpRequest;
import Travel_Planner.Travel_Planner.dto.response.ForgotPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.ResetPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.VerifyResetOtpResponse;
import Travel_Planner.Travel_Planner.event.UserPasswordResetEvent;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.model.PasswordResetToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.UserSessionStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.PasswordResetTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.repository.UserSessionRepository;
import Travel_Planner.Travel_Planner.security.PasswordPolicyValidator;
import Travel_Planner.Travel_Planner.service.EmailService;
import Travel_Planner.Travel_Planner.service.PasswordResetService;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.core.env.Environment;
import org.springframework.scheduling.annotation.Async;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Optional;

@Service
public class PasswordResetServiceImpl implements PasswordResetService {

    private static final Logger log = LoggerFactory.getLogger(PasswordResetServiceImpl.class);

    private final PasswordResetTokenRepository tokenRepository;
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final ApplicationEventPublisher eventPublisher;
    private final EmailService emailService;
    private final UserSessionRepository userSessionRepository;
    private final SecureRandom secureRandom = new SecureRandom();
    private java.time.Clock clock = java.time.Clock.systemDefaultZone();

    public void setClock(java.time.Clock clock) {
        this.clock = clock != null ? clock : java.time.Clock.systemDefaultZone();
    }

    @Autowired(required = false)
    private Environment environment;

    @Value("${auth.password-reset.pepper:travel-planner-pwd-reset-hmac-secret-pepper-2026}")
    private String pepper;

    @Value("${auth.password-reset.expiration-minutes:15}")
    private int expirationMinutes;

    @Value("${auth.password-reset.max-attempts:5}")
    private int maxAttempts;

    @Value("${auth.password-reset.resend-cooldown-seconds:60}")
    private int resendCooldownSeconds;

    public PasswordResetServiceImpl(PasswordResetTokenRepository tokenRepository,
                                    UserRepository userRepository,
                                    PasswordEncoder passwordEncoder,
                                    ApplicationEventPublisher eventPublisher,
                                    EmailService emailService) {
        this(tokenRepository, userRepository, passwordEncoder, eventPublisher, emailService, null);
    }

    @Autowired
    public PasswordResetServiceImpl(PasswordResetTokenRepository tokenRepository,
                                    UserRepository userRepository,
                                    PasswordEncoder passwordEncoder,
                                    ApplicationEventPublisher eventPublisher,
                                    EmailService emailService,
                                    @Autowired(required = false) UserSessionRepository userSessionRepository) {
        this.tokenRepository = tokenRepository;
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.eventPublisher = eventPublisher;
        this.emailService = emailService;
        this.userSessionRepository = userSessionRepository;
    }

    @PostConstruct
    public void validatePepperForProduction() {
        if (environment != null && Arrays.asList(environment.getActiveProfiles()).contains("prod")) {
            if (pepper == null || pepper.isBlank() || "travel-planner-pwd-reset-hmac-secret-pepper-2026".equals(pepper)) {
                throw new IllegalStateException("FATAL: In 'prod' profile, auth.password-reset.pepper must be configured with a secure non-default secret via environment variables!");
            }
        }
    }

    @Override
    @Transactional
    public ForgotPasswordResponse forgotPassword(ForgotPasswordRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        Optional<User> userOpt = userRepository.findByEmail(email);

        // Anti-enumeration guarantee: If user doesn't exist, is unverified, or not active,
        // return the generic success response without disclosing account state.
        if (userOpt.isEmpty() || Boolean.FALSE.equals(userOpt.get().getEmailVerified()) || userOpt.get().getStatus() != UserStatus.ACTIVE) {
            return ForgotPasswordResponse.builder()
                    .message("Nếu địa chỉ email tồn tại trên hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.")
                    .cooldownSeconds(resendCooldownSeconds)
                    .build();
        }

        // Lock user row
        User user = userRepository.findByEmailForUpdate(email).orElse(null);
        if (user == null) {
            return ForgotPasswordResponse.builder()
                    .message("Nếu địa chỉ email tồn tại trên hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.")
                    .cooldownSeconds(resendCooldownSeconds)
                    .build();
        }

        // Enforce 60-second cooldown from latest token
        Optional<PasswordResetToken> latestTokenOpt = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId());
        if (latestTokenOpt.isPresent()) {
            PasswordResetToken latestToken = latestTokenOpt.get();
            long secondsElapsed = ChronoUnit.SECONDS.between(latestToken.getCreatedAt(), LocalDateTime.now(clock));
            if (secondsElapsed < resendCooldownSeconds) {
                long waitSeconds = resendCooldownSeconds - secondsElapsed;
                throw new RateLimitExceededException("Vui lòng đợi " + waitSeconds + " giây trước khi yêu cầu gửi lại mã đặt lại mật khẩu.", waitSeconds);
            }
        }

        log.info("--- [PasswordReset] Password reset request received for user ID: {}, email: {} ---",
                user.getUserId(), maskEmail(user.getEmail()));

        // Invalidate any existing tokens for this user
        tokenRepository.deleteByUser_UserId(user.getUserId());

        // Generate 6-digit cryptographic OTP
        String rawOtp = String.format("%06d", secureRandom.nextInt(1_000_000));
        String tokenHash = hashOtp(rawOtp, pepper);

        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime expiresAt = now.plusMinutes(expirationMinutes);
        PasswordResetToken token = PasswordResetToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .attempts(0)
                .expiresAt(expiresAt)
                .createdAt(now)
                .build();

        tokenRepository.save(token);

        log.info("--- [PasswordReset] OTP successfully persisted (expires at: {}, token type: PASSWORD_RESET) for user ID: {} ---",
                expiresAt, user.getUserId());

        // Publish event for transactional post-commit async dispatch
        eventPublisher.publishEvent(new UserPasswordResetEvent(
                this,
                user.getUserId(),
                user.getEmail(),
                user.getFullName(),
                rawOtp,
                expiresAt,
                expirationMinutes
        ));

        return ForgotPasswordResponse.builder()
                .message("Nếu địa chỉ email tồn tại trên hệ thống, hướng dẫn đặt lại mật khẩu đã được gửi đến hộp thư của bạn.")
                .cooldownSeconds(resendCooldownSeconds)
                .build();
    }

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void handlePasswordResetEvent(UserPasswordResetEvent event) {
        log.info("--- [PasswordReset] Email dispatch started for user ID: {}, recipient: {} ---",
                event.getUserId(), maskEmail(event.getEmail()));
        emailService.sendPasswordResetEmail(
                event.getEmail(),
                event.getFullName(),
                event.getOtp(),
                event.getExpirationMinutes()
        );
    }

    @Override
    @Transactional(noRollbackFor = {BadRequestException.class})
    public VerifyResetOtpResponse verifyResetOtp(VerifyResetOtpRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        User user = userRepository.findByEmailForUpdate(email)
                .orElseThrow(() -> new BadRequestException("Email hoặc mã xác thực không hợp lệ."));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new BadRequestException("Tài khoản của bạn đã bị khóa hoặc vô hiệu hóa.");
        }

        PasswordResetToken token = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId())
                .orElseThrow(() -> new BadRequestException("Mã xác thực không tồn tại hoặc đã hết hạn."));

        LocalDateTime now = LocalDateTime.now(clock);
        if (!now.isBefore(token.getExpiresAt())) {
            tokenRepository.delete(token);
            throw new BadRequestException("Mã xác thực đã hết hạn. Vui lòng gửi yêu cầu mới.");
        }

        if (token.getAttempts() >= maxAttempts) {
            tokenRepository.delete(token);
            throw new BadRequestException("Bạn đã nhập sai mã quá số lần cho phép. Vui lòng gửi yêu cầu mới.");
        }

        String inputHash = hashOtp(request.getOtp().trim(), pepper);
        if (!MessageDigest.isEqual(token.getTokenHash().getBytes(StandardCharsets.UTF_8), inputHash.getBytes(StandardCharsets.UTF_8))) {
            int newAttempts = token.getAttempts() + 1;
            token.setAttempts(newAttempts);
            tokenRepository.save(token);

            if (newAttempts >= maxAttempts) {
                tokenRepository.delete(token);
                throw new BadRequestException("Bạn đã nhập sai mã quá số lần cho phép. Vui lòng gửi yêu cầu mới.");
            }

            int remaining = maxAttempts - newAttempts;
            throw new BadRequestException("Mã xác thực không chính xác. Bạn còn " + remaining + " lần thử.");
        }

        // OTP verified successfully! Generate single-use secure reset challenge token (32 bytes = 64 hex chars)
        byte[] randomBytes = new byte[32];
        secureRandom.nextBytes(randomBytes);
        String resetToken = HexFormat.of().formatHex(randomBytes);

        // Update token record with resetToken hash, reset attempts, set 10 minutes expiry
        token.setTokenHash(hashOtp(resetToken, pepper));
        token.setAttempts(0);
        token.setExpiresAt(now.plusMinutes(10));
        tokenRepository.save(token);

        log.info("--- [PasswordReset] OTP verified successfully for user '{}'. Reset challenge token generated (10 min expiry). ---",
                user.getUsername());

        return VerifyResetOtpResponse.builder()
                .message("Mã xác thực hợp lệ.")
                .resetToken(resetToken)
                .build();
    }

    @Override
    @Transactional(noRollbackFor = {BadRequestException.class})
    public ResetPasswordResponse resetPassword(ResetPasswordRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        User user = userRepository.findByEmailForUpdate(email)
                .orElseThrow(() -> new BadRequestException("Email hoặc mã xác thực không hợp lệ."));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new BadRequestException("Tài khoản của bạn đã bị khóa hoặc vô hiệu hóa.");
        }

        PasswordResetToken token = tokenRepository.findTopByUser_UserIdOrderByCreatedAtDesc(user.getUserId())
                .orElseThrow(() -> new BadRequestException("Mã xác thực không tồn tại hoặc đã hết hạn."));

        LocalDateTime now = LocalDateTime.now(clock);
        if (!now.isBefore(token.getExpiresAt())) {
            tokenRepository.delete(token);
            throw new BadRequestException("Mã xác thực đã hết hạn. Vui lòng gửi yêu cầu mới.");
        }

        if (token.getAttempts() >= maxAttempts) {
            tokenRepository.delete(token);
            throw new BadRequestException("Bạn đã nhập sai mã quá số lần cho phép. Vui lòng gửi yêu cầu mới.");
        }

        // Support both single-use resetToken (from 3-step flow) and direct otp (backward compatibility)
        String credential = (request.getResetToken() != null && !request.getResetToken().isBlank())
                ? request.getResetToken().trim()
                : (request.getOtp() != null ? request.getOtp().trim() : "");

        if (credential.isEmpty()) {
            throw new BadRequestException("Mã xác thực hoặc token đặt lại mật khẩu không được để trống.");
        }

        String inputHash = hashOtp(credential, pepper);
        if (!MessageDigest.isEqual(token.getTokenHash().getBytes(StandardCharsets.UTF_8), inputHash.getBytes(StandardCharsets.UTF_8))) {
            int newAttempts = token.getAttempts() + 1;
            token.setAttempts(newAttempts);
            tokenRepository.save(token);

            if (newAttempts >= maxAttempts) {
                tokenRepository.delete(token);
                throw new BadRequestException("Bạn đã nhập sai mã quá số lần cho phép. Vui lòng gửi yêu cầu mới.");
            }

            int remaining = maxAttempts - newAttempts;
            throw new BadRequestException("Mã xác thực không chính xác. Bạn còn " + remaining + " lần thử.");
        }

        // Validate new password policy for Reset Password (relaxed: min 6, max 100 characters)
        PasswordPolicyValidator.validateResetPassword(request.getNewPassword());

        if (request.getConfirmPassword() != null && !request.getConfirmPassword().isBlank()
                && !request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new BadRequestException("Mật khẩu xác nhận không khớp.");
        }

        // New password cannot match old password
        if (passwordEncoder.matches(request.getNewPassword(), user.getPassword())) {
            throw new BadRequestException("Mật khẩu mới không được trùng với mật khẩu hiện tại.");
        }

        // Token consumed and deleted (guarantees single-use)
        tokenRepository.delete(token);

        // Synchronously revoke all active sessions for this user so none remain stale/active
        if (userSessionRepository != null) {
            userSessionRepository.revokeAllSessionsForUser(user.getUserId(), UserSessionStatus.ACTIVE, UserSessionStatus.REVOKED);
        }

        // Update password and increment token_version for global session revocation
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        user.setTokenVersion((user.getTokenVersion() != null ? user.getTokenVersion() : 1) + 1);
        user.setUpdatedAt(LocalDateTime.now(clock));
        userRepository.save(user);

        log.info("--- [PasswordReset] Password reset successfully for user '{}'. Token version incremented to {}. ---",
                user.getUsername(), user.getTokenVersion());

        return ResetPasswordResponse.builder()
                .message("Mật khẩu đã được đặt lại thành công. Vui lòng đăng nhập bằng mật khẩu mới.")
                .build();
    }

    public static String hashOtp(String otp, String pepper) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(pepper.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKey);
            byte[] bytes = mac.doFinal(otp.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(bytes);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to calculate HMAC-SHA256 for password reset OTP", e);
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "***";
        int atIndex = email.indexOf('@');
        if (atIndex <= 2) return "***" + email.substring(atIndex);
        return email.substring(0, 2) + "***" + email.substring(atIndex);
    }
}

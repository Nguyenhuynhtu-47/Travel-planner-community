package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.event.UserVerificationEvent;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.model.EmailVerificationToken;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.EmailVerificationTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.EmailService;
import Travel_Planner.Travel_Planner.service.EmailVerificationService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import Travel_Planner.Travel_Planner.model.UserSession;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Async;
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
import java.util.HexFormat;
import java.util.Optional;

@Service
public class EmailVerificationServiceImpl implements EmailVerificationService {

    private static final Logger log = LoggerFactory.getLogger(EmailVerificationServiceImpl.class);

    private final EmailVerificationTokenRepository tokenRepository;
    private final UserRepository userRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final ApplicationEventPublisher eventPublisher;
    private final EmailService emailService;
    private final UserSessionService userSessionService;
    private final SecureRandom secureRandom = new SecureRandom();
    private java.time.Clock clock = java.time.Clock.systemDefaultZone();

    public void setClock(java.time.Clock clock) {
        this.clock = clock != null ? clock : java.time.Clock.systemDefaultZone();
    }

    @Value("${auth.otp.pepper:travel-planner-otp-hmac-secret-pepper-2026}")
    private String pepper;

    @Value("${auth.otp.expiration-minutes:15}")
    private int expirationMinutes;

    @Value("${auth.otp.max-attempts:5}")
    private int maxAttempts;

    @Value("${auth.otp.resend-cooldown-seconds:60}")
    private int resendCooldownSeconds;

    public EmailVerificationServiceImpl(EmailVerificationTokenRepository tokenRepository,
                                        UserRepository userRepository,
                                        JwtTokenProvider jwtTokenProvider,
                                        ApplicationEventPublisher eventPublisher,
                                        EmailService emailService) {
        this(tokenRepository, userRepository, jwtTokenProvider, eventPublisher, emailService, null);
    }

    @Autowired
    public EmailVerificationServiceImpl(EmailVerificationTokenRepository tokenRepository,
                                        UserRepository userRepository,
                                        JwtTokenProvider jwtTokenProvider,
                                        ApplicationEventPublisher eventPublisher,
                                        EmailService emailService,
                                        @Autowired(required = false) UserSessionService userSessionService) {
        this.tokenRepository = tokenRepository;
        this.userRepository = userRepository;
        this.jwtTokenProvider = jwtTokenProvider;
        this.eventPublisher = eventPublisher;
        this.emailService = emailService;
        this.userSessionService = userSessionService;
    }

    @Autowired(required = false)
    private org.springframework.core.env.Environment environment;

    @jakarta.annotation.PostConstruct
    public void validatePepperForProduction() {
        if (environment != null && java.util.Arrays.asList(environment.getActiveProfiles()).contains("prod")) {
            if (pepper == null || pepper.isBlank() || "travel-planner-otp-hmac-secret-pepper-2026".equals(pepper)) {
                throw new IllegalStateException("FATAL: In 'prod' profile, auth.otp.pepper must be configured with a secure non-default secret via environment variables!");
            }
        }
    }

    @Override
    @Transactional
    public void createVerificationTokenAndDispatch(User user) {
        log.info("--- [EmailVerification] Verification request received for user ID: {}, email: {} ---",
                user.getUserId(), maskEmail(user.getEmail()));

        String rawOtp = String.format("%06d", secureRandom.nextInt(1_000_000));
        String tokenHash = hashOtp(rawOtp, pepper);

        // Delete any existing tokens for this user
        tokenRepository.deleteByUserIdAndTokenType(user.getUserId(), "EMAIL_VERIFICATION");

        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime expiresAt = now.plusMinutes(expirationMinutes);
        EmailVerificationToken token = EmailVerificationToken.builder()
                .user(user)
                .tokenHash(tokenHash)
                .tokenType("EMAIL_VERIFICATION")
                .attempts(0)
                .expiresAt(expiresAt)
                .createdAt(now)
                .build();

        tokenRepository.save(token);

        log.info("--- [EmailVerification] OTP successfully persisted (expires at: {}, token type: EMAIL_VERIFICATION) for user ID: {} ---",
                expiresAt, user.getUserId());

        // Publish event for transactional post-commit async dispatch
        eventPublisher.publishEvent(new UserVerificationEvent(
                this,
                user.getUserId(),
                user.getEmail(),
                user.getFullName(),
                rawOtp,
                expiresAt,
                expirationMinutes
        ));
    }

    @Async
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
    public void handleUserVerificationEvent(UserVerificationEvent event) {
        log.info("--- [EmailVerification] Email dispatch started for user ID: {}, recipient: {} ---",
                event.getUserId(), maskEmail(event.getEmail()));
        emailService.sendVerificationEmail(
                event.getEmail(),
                event.getFullName(),
                event.getOtp(),
                event.getExpirationMinutes()
        );
    }

    @Override
    @Transactional(noRollbackFor = {BadRequestException.class})
    public AuthResponse verifyEmail(VerifyEmailRequest request) {
        return verifyEmail(request, null, null);
    }

    @Override
    @Transactional(noRollbackFor = {BadRequestException.class})
    public AuthResponse verifyEmail(VerifyEmailRequest request, String deviceInfo, String ipAddress) {
        String email = request.getEmail().trim().toLowerCase();
        User user = userRepository.findByEmailForUpdate(email)
                .orElseThrow(() -> new BadRequestException("Email hoặc mã xác thực không hợp lệ."));

        if (Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new BadRequestException("Tài khoản đã được kích hoạt trước đó.");
        }

        EmailVerificationToken token = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION")
                .orElseThrow(() -> new BadRequestException("Mã xác thực không tồn tại hoặc đã hết hạn."));

        LocalDateTime now = LocalDateTime.now(clock);
        if (!now.isBefore(token.getExpiresAt())) {
            tokenRepository.delete(token);
            throw new BadRequestException("Mã xác thực đã hết hạn. Vui lòng yêu cầu mã mới.");
        }

        if (token.getAttempts() >= maxAttempts) {
            tokenRepository.delete(token);
            throw new BadRequestException("Bạn đã nhập sai quá số lần cho phép. Vui lòng yêu cầu mã mới.");
        }

        String inputHash = hashOtp(request.getCode().trim(), pepper);
        if (!MessageDigest.isEqual(token.getTokenHash().getBytes(StandardCharsets.UTF_8), inputHash.getBytes(StandardCharsets.UTF_8))) {
            int newAttempts = token.getAttempts() + 1;
            token.setAttempts(newAttempts);
            tokenRepository.save(token);

            if (newAttempts >= maxAttempts) {
                tokenRepository.delete(token);
                throw new BadRequestException("Bạn đã nhập sai quá số lần cho phép. Vui lòng yêu cầu mã mới.");
            }

            int remaining = maxAttempts - newAttempts;
            throw new BadRequestException("Mã xác thực không chính xác. Bạn còn " + remaining + " lần thử.");
        }

        // Successfully verified
        tokenRepository.delete(token);
        user.setEmailVerified(true);
        userRepository.save(user);

        String sessionId = null;
        if (userSessionService != null) {
            UserSession session = userSessionService.createSession(
                    user,
                    deviceInfo,
                    ipAddress,
                    jwtTokenProvider.getExpirationMs()
            );
            if (session != null) {
                sessionId = session.getSessionId();
            }
        }

        String jwt = jwtTokenProvider.generateToken(user, sessionId);
        return AuthResponse.builder()
                .token(jwt)
                .tokenType("Bearer")
                .user(mapToUserResponse(user))
                .build();
    }

    @Override
    @Transactional
    public ResendVerificationResponse resendVerification(ResendVerificationRequest request) {
        String email = request.getEmail().trim().toLowerCase();
        Optional<User> userOpt = userRepository.findByEmailForUpdate(email);

        // Anti-enumeration: if user doesn't exist or is already verified, return generic success
        if (userOpt.isEmpty() || Boolean.TRUE.equals(userOpt.get().getEmailVerified())) {
            return ResendVerificationResponse.builder()
                    .message("Nếu email tồn tại trong hệ thống, mã xác thực mới đã được gửi.")
                    .cooldownSeconds(resendCooldownSeconds)
                    .build();
        }

        User user = userOpt.get();

        // Enforce 60-second cooldown from latest token
        Optional<EmailVerificationToken> latestTokenOpt = tokenRepository.findTopByUser_UserIdAndTokenTypeOrderByCreatedAtDesc(user.getUserId(), "EMAIL_VERIFICATION");
        if (latestTokenOpt.isPresent()) {
            EmailVerificationToken latestToken = latestTokenOpt.get();
            long secondsElapsed = ChronoUnit.SECONDS.between(latestToken.getCreatedAt(), LocalDateTime.now(clock));
            if (secondsElapsed < resendCooldownSeconds) {
                long waitSeconds = resendCooldownSeconds - secondsElapsed;
                throw new RateLimitExceededException("Vui lòng đợi " + waitSeconds + " giây trước khi yêu cầu gửi lại mã xác thực.", waitSeconds);
            }
        }

        // Issue and dispatch new token
        createVerificationTokenAndDispatch(user);

        return ResendVerificationResponse.builder()
                .message("Mã xác thực mới đã được gửi vào email của bạn.")
                .cooldownSeconds(resendCooldownSeconds)
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
            throw new IllegalStateException("Failed to calculate HMAC-SHA256 for OTP", e);
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "***";
        int atIndex = email.indexOf('@');
        if (atIndex <= 2) return "***" + email.substring(atIndex);
        return email.substring(0, 2) + "***" + email.substring(atIndex);
    }

    private UserResponse mapToUserResponse(User user) {
        return UserResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .handle(user.getHandle())
                .email(user.getEmail())
                .emailVerified(user.getEmailVerified())
                .fullName(user.getFullName())
                .role(user.getRole())
                .status(user.getStatus())
                .avatar(user.getAvatar())
                .phone(user.getPhone())
                .address(user.getAddress())
                .bio(user.getBio())
                .createdAt(user.getCreatedAt())
                .build();
    }
}

package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.EmailChangeRequestDto;
import Travel_Planner.Travel_Planner.dto.request.EmailChangeVerifyDto;
import Travel_Planner.Travel_Planner.dto.request.ForgotPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.request.ResendVerificationRequest;
import Travel_Planner.Travel_Planner.dto.request.ResetPasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyEmailRequest;
import Travel_Planner.Travel_Planner.dto.request.VerifyResetOtpRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ChangePasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.EmailChangeResponse;
import Travel_Planner.Travel_Planner.dto.response.ForgotPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.dto.response.ResetPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.RevokeSessionResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.dto.response.UserSessionResponse;
import Travel_Planner.Travel_Planner.dto.response.VerifyResetOtpResponse;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.security.DeviceInfoResolver;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.AuthService;
import Travel_Planner.Travel_Planner.service.EmailChangeService;
import Travel_Planner.Travel_Planner.service.EmailVerificationService;
import Travel_Planner.Travel_Planner.service.GoogleAuthService;
import Travel_Planner.Travel_Planner.service.PasswordResetService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final EmailVerificationService emailVerificationService;
    private final PasswordResetService passwordResetService;
    private final GoogleAuthService googleAuthService;
    private final AuthRateLimiter authRateLimiter;
    private final ClientIpResolver clientIpResolver;
    private final UserSessionService userSessionService;
    private final DeviceInfoResolver deviceInfoResolver;
    private final EmailChangeService emailChangeService;
    private final JwtTokenProvider jwtTokenProvider;

    public AuthController(
            AuthService authService,
            EmailVerificationService emailVerificationService,
            PasswordResetService passwordResetService,
            GoogleAuthService googleAuthService,
            AuthRateLimiter authRateLimiter,
            ClientIpResolver clientIpResolver) {
        this(authService, emailVerificationService, passwordResetService, googleAuthService, authRateLimiter, clientIpResolver, null, null, null, null);
    }

    @org.springframework.beans.factory.annotation.Autowired
    public AuthController(
            AuthService authService,
            EmailVerificationService emailVerificationService,
            PasswordResetService passwordResetService,
            GoogleAuthService googleAuthService,
            AuthRateLimiter authRateLimiter,
            ClientIpResolver clientIpResolver,
            @org.springframework.beans.factory.annotation.Autowired(required = false) UserSessionService userSessionService,
            @org.springframework.beans.factory.annotation.Autowired(required = false) DeviceInfoResolver deviceInfoResolver,
            @org.springframework.beans.factory.annotation.Autowired(required = false) EmailChangeService emailChangeService,
            @org.springframework.beans.factory.annotation.Autowired(required = false) JwtTokenProvider jwtTokenProvider) {
        this.authService = authService;
        this.emailVerificationService = emailVerificationService;
        this.passwordResetService = passwordResetService;
        this.googleAuthService = googleAuthService;
        this.authRateLimiter = authRateLimiter;
        this.clientIpResolver = clientIpResolver;
        this.userSessionService = userSessionService;
        this.deviceInfoResolver = deviceInfoResolver;
        this.emailChangeService = emailChangeService;
        this.jwtTokenProvider = jwtTokenProvider;
    }

    @PostMapping("/register")
    public ResponseEntity<RegisterResponse> register(
            @Valid @RequestBody RegisterRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeRegister(clientIp)) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đăng ký. Vui lòng thử lại sau 10 phút.", 600);
        }
        RegisterResponse response = authService.register(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @PostMapping("/verify-email")
    public ResponseEntity<AuthResponse> verifyEmail(
            @Valid @RequestBody VerifyEmailRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeVerifyEmail(clientIp, request.getEmail())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu xác thực. Vui lòng thử lại sau 1 phút.", 60);
        }
        String deviceInfo = deviceInfoResolver != null ? deviceInfoResolver.resolveDeviceInfo(httpRequest) : null;
        AuthResponse response = emailVerificationService.verifyEmail(request, deviceInfo, clientIp);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/resend-verification")
    public ResponseEntity<ResendVerificationResponse> resendVerification(
            @Valid @RequestBody ResendVerificationRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeResendVerification(clientIp, request.getEmail())) {
            throw new RateLimitExceededException("Bạn đã vượt quá giới hạn gửi lại mã xác thực (tối đa 3 lần / giờ). Vui lòng thử lại sau.", 3600);
        }
        ResendVerificationResponse response = emailVerificationService.resendVerification(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(
            @Valid @RequestBody LoginRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeLogin(clientIp, request.getUsernameOrEmail())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đăng nhập. Vui lòng thử lại sau 1 phút.", 60);
        }
        String deviceInfo = deviceInfoResolver != null ? deviceInfoResolver.resolveDeviceInfo(httpRequest) : null;
        AuthResponse response = authService.login(request, deviceInfo, clientIp);
        authRateLimiter.resetAccount(request.getUsernameOrEmail());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/google")
    public ResponseEntity<AuthResponse> googleAuth(
            @Valid @RequestBody GoogleAuthRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeGoogleAuth(clientIp)) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đăng nhập. Vui lòng thử lại sau 1 phút.", 60);
        }
        String deviceInfo = deviceInfoResolver != null ? deviceInfoResolver.resolveDeviceInfo(httpRequest) : null;
        AuthResponse response = googleAuthService.authenticateWithGoogle(request, deviceInfo, clientIp);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/google/link")
    public ResponseEntity<GoogleLinkResponse> linkGoogle(
            @Valid @RequestBody GoogleLinkRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        GoogleLinkResponse response = googleAuthService.linkGoogleAccount(userDetails.getUsername(), request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    public ResponseEntity<UserResponse> getCurrentUser(@AuthenticationPrincipal UserDetails userDetails) {
        UserResponse response = authService.getCurrentUser(userDetails.getUsername());
        return ResponseEntity.ok(response);
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<ForgotPasswordResponse> forgotPassword(
            @Valid @RequestBody ForgotPasswordRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeForgotPassword(clientIp, request.getEmail())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đặt lại mật khẩu. Vui lòng thử lại sau 15 phút.", 900);
        }
        ForgotPasswordResponse response = passwordResetService.forgotPassword(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/verify-reset-otp")
    public ResponseEntity<VerifyResetOtpResponse> verifyResetOtp(
            @Valid @RequestBody VerifyResetOtpRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeResetPassword(clientIp, request.getEmail())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu xác thực OTP. Vui lòng thử lại sau 15 phút.", 900);
        }
        VerifyResetOtpResponse response = passwordResetService.verifyResetOtp(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/reset-password")
    public ResponseEntity<ResetPasswordResponse> resetPassword(
            @Valid @RequestBody ResetPasswordRequest request,
            HttpServletRequest httpRequest) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeResetPassword(clientIp, request.getEmail())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đặt lại mật khẩu. Vui lòng thử lại sau 15 phút.", 900);
        }
        ResetPasswordResponse response = passwordResetService.resetPassword(request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/change-password")
    public ResponseEntity<ChangePasswordResponse> changePassword(
            @Valid @RequestBody ChangePasswordRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (!authRateLimiter.tryConsumeChangePassword(userDetails.getUsername())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đổi mật khẩu. Vui lòng thử lại sau 15 phút.", 900);
        }
        ChangePasswordResponse response = authService.changePassword(userDetails.getUsername(), request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/logout")
    public ResponseEntity<Map<String, String>> logout(
            HttpServletRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        String jwt = getJwtFromRequest(request);
        if (jwt != null && jwtTokenProvider != null && userSessionService != null) {
            String sessionId = jwtTokenProvider.getSessionIdFromToken(jwt);
            if (sessionId != null) {
                userSessionService.revokeCurrentSession(sessionId);
            }
        }
        SecurityContextHolder.clearContext();
        return ResponseEntity.ok(Map.of("message", "Đăng xuất thành công"));
    }

    @GetMapping("/sessions")
    public ResponseEntity<List<UserSessionResponse>> getSessions(
            HttpServletRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        String jwt = getJwtFromRequest(request);
        String currentSessionId = (jwt != null && jwtTokenProvider != null)
                ? jwtTokenProvider.getSessionIdFromToken(jwt)
                : null;
        List<UserSessionResponse> sessions = userSessionService != null
                ? userSessionService.getUserSessions(userDetails.getUsername(), currentSessionId)
                : List.of();
        return ResponseEntity.ok(sessions);
    }

    @PostMapping("/sessions/{sessionId}/revoke")
    public ResponseEntity<RevokeSessionResponse> revokeSession(
            @PathVariable String sessionId,
            @AuthenticationPrincipal UserDetails userDetails) {
        if (userSessionService != null) {
            userSessionService.revokeSession(sessionId, userDetails.getUsername());
        }
        return ResponseEntity.ok(RevokeSessionResponse.builder()
                .message("Đã thu hồi phiên đăng nhập thành công")
                .revokedCount(1)
                .build());
    }

    @PostMapping("/sessions/revoke-others")
    public ResponseEntity<RevokeSessionResponse> revokeOtherSessions(
            HttpServletRequest request,
            @AuthenticationPrincipal UserDetails userDetails) {
        String jwt = getJwtFromRequest(request);
        String currentSessionId = (jwt != null && jwtTokenProvider != null)
                ? jwtTokenProvider.getSessionIdFromToken(jwt)
                : null;
        int count = userSessionService != null
                ? userSessionService.revokeOtherSessions(userDetails.getUsername(), currentSessionId)
                : 0;
        return ResponseEntity.ok(RevokeSessionResponse.builder()
                .message("Đã đăng xuất khỏi tất cả các thiết bị khác")
                .revokedCount(count)
                .build());
    }

    @PostMapping("/sessions/revoke-all")
    public ResponseEntity<RevokeSessionResponse> revokeAllSessions(
            @AuthenticationPrincipal UserDetails userDetails) {
        int count = userSessionService != null
                ? userSessionService.revokeAllSessions(userDetails.getUsername())
                : 0;
        SecurityContextHolder.clearContext();
        return ResponseEntity.ok(RevokeSessionResponse.builder()
                .message("Đã đăng xuất khỏi tất cả các phiên đăng nhập")
                .revokedCount(count)
                .build());
    }

    @PostMapping("/email-change/request")
    public ResponseEntity<EmailChangeResponse> requestEmailChange(
            @Valid @RequestBody EmailChangeRequestDto request,
            HttpServletRequest httpRequest,
            @AuthenticationPrincipal UserDetails userDetails) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeEmailChange(clientIp, userDetails.getUsername())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu đổi email. Vui lòng thử lại sau 15 phút.", 900);
        }
        EmailChangeResponse response = emailChangeService.requestEmailChange(userDetails.getUsername(), request);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/email-change/verify")
    public ResponseEntity<EmailChangeResponse> verifyEmailChange(
            @Valid @RequestBody EmailChangeVerifyDto request,
            HttpServletRequest httpRequest,
            @AuthenticationPrincipal UserDetails userDetails) {
        String clientIp = clientIpResolver.resolveClientIp(httpRequest);
        if (!authRateLimiter.tryConsumeEmailChange(clientIp, userDetails.getUsername())) {
            throw new RateLimitExceededException("Bạn đã gửi quá nhiều yêu cầu xác thực đổi email. Vui lòng thử lại sau 15 phút.", 900);
        }
        EmailChangeResponse response = emailChangeService.verifyEmailChange(userDetails.getUsername(), request);
        return ResponseEntity.ok(response);
    }

    private String getJwtFromRequest(HttpServletRequest request) {
        if (request == null) return null;
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}


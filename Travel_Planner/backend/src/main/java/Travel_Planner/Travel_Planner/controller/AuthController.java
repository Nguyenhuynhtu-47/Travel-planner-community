package Travel_Planner.Travel_Planner.controller;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
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
import Travel_Planner.Travel_Planner.dto.response.ForgotPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.ResendVerificationResponse;
import Travel_Planner.Travel_Planner.dto.response.ResetPasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.VerifyResetOtpResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.RateLimitExceededException;
import Travel_Planner.Travel_Planner.security.AuthRateLimiter;
import Travel_Planner.Travel_Planner.security.ClientIpResolver;
import Travel_Planner.Travel_Planner.service.AuthService;
import Travel_Planner.Travel_Planner.service.EmailVerificationService;
import Travel_Planner.Travel_Planner.service.GoogleAuthService;
import Travel_Planner.Travel_Planner.service.PasswordResetService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final EmailVerificationService emailVerificationService;
    private final PasswordResetService passwordResetService;
    private final GoogleAuthService googleAuthService;
    private final AuthRateLimiter authRateLimiter;
    private final ClientIpResolver clientIpResolver;

    public AuthController(
            AuthService authService,
            EmailVerificationService emailVerificationService,
            PasswordResetService passwordResetService,
            GoogleAuthService googleAuthService,
            AuthRateLimiter authRateLimiter,
            ClientIpResolver clientIpResolver) {
        this.authService = authService;
        this.emailVerificationService = emailVerificationService;
        this.passwordResetService = passwordResetService;
        this.googleAuthService = googleAuthService;
        this.authRateLimiter = authRateLimiter;
        this.clientIpResolver = clientIpResolver;
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
        AuthResponse response = emailVerificationService.verifyEmail(request);
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
        AuthResponse response = authService.login(request);
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
        AuthResponse response = googleAuthService.authenticateWithGoogle(request);
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
}


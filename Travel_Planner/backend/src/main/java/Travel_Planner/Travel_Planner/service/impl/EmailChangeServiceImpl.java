package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.EmailChangeRequestDto;
import Travel_Planner.Travel_Planner.dto.request.EmailChangeVerifyDto;
import Travel_Planner.Travel_Planner.dto.response.EmailChangeResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.EmailChangeRequest;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.EmailChangeStatus;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.EmailChangeRequestRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.EmailChangeService;
import Travel_Planner.Travel_Planner.service.EmailService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;

@Service
public class EmailChangeServiceImpl implements EmailChangeService {

    private static final int OTP_EXPIRATION_MINUTES = 15;
    private static final int MAX_ATTEMPTS = 5;

    private final UserRepository userRepository;
    private final EmailChangeRequestRepository emailChangeRequestRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;
    private final String pepper;
    private final SecureRandom secureRandom = new SecureRandom();

    public EmailChangeServiceImpl(
            UserRepository userRepository,
            EmailChangeRequestRepository emailChangeRequestRepository,
            PasswordEncoder passwordEncoder,
            EmailService emailService,
            @Value("${app.auth.otp.pepper:TravelPlannerDefaultOtpPepper2026SecureKey}") String pepper) {
        this.userRepository = userRepository;
        this.emailChangeRequestRepository = emailChangeRequestRepository;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
        this.pepper = pepper;
    }

    @Override
    @Transactional
    public EmailChangeResponse requestEmailChange(String currentUsername, EmailChangeRequestDto request) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị khóa hoặc vô hiệu hóa");
        }

        // Verify password if user has password set
        if (user.getPassword() != null && !user.getPassword().isBlank()) {
            if (request.getPassword() == null || request.getPassword().isBlank()) {
                throw new BadRequestException("Vui lòng nhập mật khẩu hiện tại để xác nhận quyền sở hữu tài khoản");
            }
            if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
                throw new BadCredentialsException("Mật khẩu hiện tại không chính xác");
            }
        }

        String newEmail = request.getNewEmail().trim().toLowerCase();
        if (newEmail.equalsIgnoreCase(user.getEmail())) {
            throw new BadRequestException("Email mới không được trùng với email hiện tại của tài khoản");
        }

        if (userRepository.existsByEmail(newEmail)) {
            throw new ConflictException("Email này đã được sử dụng bởi một tài khoản khác");
        }

        // Cancel previous pending requests for this user
        emailChangeRequestRepository.cancelAllPendingRequestsForUser(
                user.getUserId(),
                EmailChangeStatus.PENDING,
                EmailChangeStatus.CANCELLED
        );

        // Generate 6-digit OTP
        int otpNumber = 100000 + secureRandom.nextInt(900000);
        String otp = String.valueOf(otpNumber);
        String otpHash = hashOtp(otp);

        LocalDateTime now = LocalDateTime.now();
        EmailChangeRequest changeRequest = EmailChangeRequest.builder()
                .user(user)
                .oldEmail(user.getEmail())
                .newEmail(newEmail)
                .otpHash(otpHash)
                .attempts(0)
                .status(EmailChangeStatus.PENDING)
                .expiresAt(now.plusMinutes(OTP_EXPIRATION_MINUTES))
                .createdAt(now)
                .build();

        emailChangeRequestRepository.save(changeRequest);

        // Dispatch OTP to new email
        emailService.sendEmailChangeOtp(newEmail, user.getFullName(), otp, OTP_EXPIRATION_MINUTES);

        // Dispatch security notification to current old email
        emailService.sendEmailChangeNotice(user.getEmail(), user.getFullName(), newEmail);

        return EmailChangeResponse.builder()
                .message("Mã xác thực đã được gửi đến địa chỉ email mới. Vui lòng kiểm tra hộp thư.")
                .newEmail(newEmail)
                .build();
    }

    @Override
    @Transactional
    public EmailChangeResponse verifyEmailChange(String currentUsername, EmailChangeVerifyDto request) {
        User user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị khóa hoặc vô hiệu hóa");
        }

        String newEmail = request.getNewEmail().trim().toLowerCase();

        EmailChangeRequest changeRequest = emailChangeRequestRepository
                .findTopByUser_UserIdAndNewEmailAndStatusOrderByCreatedAtDesc(
                        user.getUserId(),
                        newEmail,
                        EmailChangeStatus.PENDING
                )
                .orElseThrow(() -> new BadRequestException("Không tìm thấy yêu cầu đổi email hợp lệ cho địa chỉ này. Vui lòng gửi lại yêu cầu."));

        if (changeRequest.isExpired()) {
            changeRequest.setStatus(EmailChangeStatus.EXPIRED);
            emailChangeRequestRepository.save(changeRequest);
            throw new BadRequestException("Mã xác thực đã hết hạn. Vui lòng gửi lại yêu cầu đổi email.");
        }

        if (changeRequest.getAttempts() >= MAX_ATTEMPTS) {
            changeRequest.setStatus(EmailChangeStatus.EXPIRED);
            emailChangeRequestRepository.save(changeRequest);
            throw new BadRequestException("Bạn đã nhập sai mã xác thực quá số lần quy định (" + MAX_ATTEMPTS + " lần). Vui lòng gửi lại yêu cầu.");
        }

        String inputHash = hashOtp(request.getOtp().trim());
        boolean matches = MessageDigest.isEqual(
                inputHash.getBytes(StandardCharsets.UTF_8),
                changeRequest.getOtpHash().getBytes(StandardCharsets.UTF_8)
        );

        if (!matches) {
            int newAttempts = changeRequest.getAttempts() + 1;
            changeRequest.setAttempts(newAttempts);
            if (newAttempts >= MAX_ATTEMPTS) {
                changeRequest.setStatus(EmailChangeStatus.EXPIRED);
            }
            emailChangeRequestRepository.save(changeRequest);

            int remaining = MAX_ATTEMPTS - newAttempts;
            if (remaining <= 0) {
                throw new BadRequestException("Mã xác thực không chính xác. Bạn đã hết số lần thử. Vui lòng gửi lại yêu cầu mới.");
            } else {
                throw new BadRequestException("Mã xác thực không chính xác. Bạn còn " + remaining + " lần thử.");
            }
        }

        // Concurrency safeguard: ensure newEmail is still available
        if (userRepository.existsByEmail(newEmail)) {
            changeRequest.setStatus(EmailChangeStatus.CANCELLED);
            emailChangeRequestRepository.save(changeRequest);
            throw new ConflictException("Email này đã được sử dụng bởi một tài khoản khác trong thời gian chờ xác thực.");
        }

        String oldEmail = user.getEmail();
        user.setEmail(newEmail);
        user.setEmailVerified(true);
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        changeRequest.setStatus(EmailChangeStatus.COMPLETED);
        emailChangeRequestRepository.save(changeRequest);

        // Send confirmation emails
        emailService.sendEmailChangeSuccessNotice(oldEmail, newEmail, user.getFullName());

        return EmailChangeResponse.builder()
                .message("Đổi địa chỉ email thành công. Địa chỉ mới của bạn là: " + newEmail)
                .newEmail(newEmail)
                .build();
    }

    private String hashOtp(String otp) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(pepper.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKey);
            byte[] hmacBytes = mac.doFinal(otp.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hmacBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Lỗi mã hóa OTP xác thực email", e);
        }
    }
}

package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.ChangePasswordRequest;
import Travel_Planner.Travel_Planner.dto.request.LoginRequest;
import Travel_Planner.Travel_Planner.dto.request.RegisterRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.ChangePasswordResponse;
import Travel_Planner.Travel_Planner.dto.response.RegisterResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.security.PasswordPolicyValidator;
import Travel_Planner.Travel_Planner.service.AuthService;
import Travel_Planner.Travel_Planner.service.EmailVerificationService;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
public class AuthServiceImpl implements AuthService {

    // Valid standard BCrypt hash (cost 10) used for constant-time evaluation on missing accounts
    private static final String DUMMY_BCRYPT_HASH = "$2a$10$wT0lV3m8T5Z2hZ8yY2hZ8uE8qY9hO0j9jF7kG4i6e3g0yX8yY2hZ8";

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final UserHandleService userHandleService;
    private final EmailVerificationService emailVerificationService;

    public AuthServiceImpl(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            UserHandleService userHandleService) {
        this(userRepository, passwordEncoder, jwtTokenProvider, userHandleService, null);
    }

    @Autowired
    public AuthServiceImpl(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider jwtTokenProvider,
            UserHandleService userHandleService,
            @Autowired(required = false) EmailVerificationService emailVerificationService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtTokenProvider = jwtTokenProvider;
        this.userHandleService = userHandleService;
        this.emailVerificationService = emailVerificationService;
    }

    @Override
    @Transactional
    public RegisterResponse register(RegisterRequest request) {
        String username = request.getUsername().trim();
        String email = request.getEmail().trim().toLowerCase();

        if (userRepository.existsByUsername(username)) {
            throw new ConflictException("Tên đăng nhập đã tồn tại");
        }

        if (userRepository.existsByEmail(email)) {
            throw new ConflictException("Email đã được sử dụng");
        }

        String handle;
        if (request.getHandle() != null && !request.getHandle().isBlank()) {
            handle = userHandleService.normalize(request.getHandle());
            if (userRepository.existsByHandle(handle)) {
                throw new ConflictException("Định danh (@handle) này đã được sử dụng");
            }
        } else {
            handle = userHandleService.generateUniqueHandle(request.getFullName(), null);
        }

        User user = User.builder()
                .username(username)
                .handle(handle)
                .email(email)
                .password(passwordEncoder.encode(request.getPassword()))
                .fullName(request.getFullName().trim())
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .emailVerified(false)
                .tokenVersion(1)
                .build();

        User savedUser = userRepository.save(user);

        if (emailVerificationService != null) {
            emailVerificationService.createVerificationTokenAndDispatch(savedUser);
        }

        return RegisterResponse.builder()
                .message("Đăng ký thành công. Vui lòng kiểm tra email để nhận mã xác thực.")
                .email(savedUser.getEmail())
                .requiresVerification(true)
                .user(mapToUserResponse(savedUser))
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        String identifier = request.getUsernameOrEmail().trim();

        User user = userRepository.findByUsernameOrEmail(identifier, identifier.toLowerCase())
                .orElse(null);

        if (user == null) {
            // Constant-time execution: evaluate dummy BCrypt hash to prevent timing attacks
            passwordEncoder.matches(request.getPassword(), DUMMY_BCRYPT_HASH);
            throw new UnauthorizedException("Tên đăng nhập hoặc mật khẩu không chính xác");
        }

        boolean passwordMatches;
        if (user.getPassword() == null) {
            // OAuth accounts without local password: run dummy hash to neutralize account enumeration
            passwordEncoder.matches(request.getPassword(), DUMMY_BCRYPT_HASH);
            passwordMatches = false;
        } else {
            passwordMatches = passwordEncoder.matches(request.getPassword(), user.getPassword());
        }

        if (!passwordMatches) {
            throw new UnauthorizedException("Tên đăng nhập hoặc mật khẩu không chính xác");
        }

        if (user.getStatus() == UserStatus.BANNED) {
            throw new ForbiddenException("Tài khoản của bạn đã bị khóa do vi phạm chính sách");
        }

        if (user.getStatus() == UserStatus.INACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa");
        }

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ForbiddenException("Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email xác thực.");
        }

        String token = jwtTokenProvider.generateToken(user);

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .user(mapToUserResponse(user))
                .build();
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getCurrentUser(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        if (user.getStatus() == UserStatus.BANNED) {
            throw new ForbiddenException("Tài khoản của bạn đã bị khóa do vi phạm chính sách");
        }

        if (user.getStatus() == UserStatus.INACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa");
        }

        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new ForbiddenException("Tài khoản chưa được kích hoạt. Vui lòng kiểm tra email xác thực.");
        }

        return mapToUserResponse(user);
    }

    @Override
    @Transactional
    public ChangePasswordResponse changePassword(String username, ChangePasswordRequest request) {
        User user = userRepository.findByUsernameForUpdate(username)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));

        if (user.getStatus() != UserStatus.ACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị khóa hoặc vô hiệu hóa");
        }

        // Verify current password
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new BadCredentialsException("Mật khẩu hiện tại không chính xác");
        }

        // Validate new password policy
        PasswordPolicyValidator.validate(request.getNewPassword());

        if (request.getConfirmPassword() != null && !request.getConfirmPassword().isBlank()
                && !request.getNewPassword().equals(request.getConfirmPassword())) {
            throw new BadRequestException("Mật khẩu xác nhận không khớp.");
        }

        // Reject new password identical to current password
        if (passwordEncoder.matches(request.getNewPassword(), user.getPassword())) {
            throw new BadRequestException("Mật khẩu mới không được trùng với mật khẩu hiện tại");
        }

        // Update password and increment token_version for global session revocation
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        user.setTokenVersion((user.getTokenVersion() != null ? user.getTokenVersion() : 1) + 1);
        user.setUpdatedAt(LocalDateTime.now());
        userRepository.save(user);

        return ChangePasswordResponse.builder()
                .message("Mật khẩu đã được thay đổi thành công. Các phiên đăng nhập trên thiết bị khác đã được đăng xuất.")
                .build();
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

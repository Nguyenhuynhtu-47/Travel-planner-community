package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.GoogleAuthRequest;
import Travel_Planner.Travel_Planner.dto.request.GoogleLinkRequest;
import Travel_Planner.Travel_Planner.dto.response.AuthResponse;
import Travel_Planner.Travel_Planner.dto.response.GoogleLinkResponse;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.AccountConflictException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.ForbiddenException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserIdentity;
import Travel_Planner.Travel_Planner.model.enums.Role;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserIdentityRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.GoogleTokenVerifier;
import Travel_Planner.Travel_Planner.security.GoogleUserInfo;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.service.GoogleAuthService;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import Travel_Planner.Travel_Planner.service.UserSessionService;
import Travel_Planner.Travel_Planner.model.UserSession;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Service
public class GoogleAuthServiceImpl implements GoogleAuthService {

    private static final String PROVIDER_GOOGLE = "GOOGLE";

    private final GoogleTokenVerifier googleTokenVerifier;
    private final UserRepository userRepository;
    private final UserIdentityRepository userIdentityRepository;
    private final JwtTokenProvider jwtTokenProvider;
    private final PasswordEncoder passwordEncoder;
    private final UserHandleService userHandleService;
    private final UserSessionService userSessionService;

    public GoogleAuthServiceImpl(
            GoogleTokenVerifier googleTokenVerifier,
            UserRepository userRepository,
            UserIdentityRepository userIdentityRepository,
            JwtTokenProvider jwtTokenProvider,
            PasswordEncoder passwordEncoder,
            UserHandleService userHandleService) {
        this(googleTokenVerifier, userRepository, userIdentityRepository, jwtTokenProvider, passwordEncoder, userHandleService, null);
    }

    @Autowired
    public GoogleAuthServiceImpl(
            GoogleTokenVerifier googleTokenVerifier,
            UserRepository userRepository,
            UserIdentityRepository userIdentityRepository,
            JwtTokenProvider jwtTokenProvider,
            PasswordEncoder passwordEncoder,
            UserHandleService userHandleService,
            @Autowired(required = false) UserSessionService userSessionService) {
        this.googleTokenVerifier = googleTokenVerifier;
        this.userRepository = userRepository;
        this.userIdentityRepository = userIdentityRepository;
        this.jwtTokenProvider = jwtTokenProvider;
        this.passwordEncoder = passwordEncoder;
        this.userHandleService = userHandleService;
        this.userSessionService = userSessionService;
    }

    @Override
    @Transactional
    public AuthResponse authenticateWithGoogle(GoogleAuthRequest request) {
        return authenticateWithGoogle(request, null, null);
    }

    @Override
    @Transactional
    public AuthResponse authenticateWithGoogle(GoogleAuthRequest request, String deviceInfo, String ipAddress) {
        // 1. Cryptographically verify Google ID Token & claims
        GoogleUserInfo userInfo = googleTokenVerifier.verify(request.getIdToken());
        String email = userInfo.getEmail().toLowerCase().trim();
        String sub = userInfo.getSub();

        // 2. Look for an existing UserIdentity for this Google subject
        Optional<UserIdentity> identityOpt = userIdentityRepository.findByProviderAndProviderSubject(PROVIDER_GOOGLE, sub);

        User user;
        if (identityOpt.isPresent()) {
            // Already linked account -> authenticate user
            user = identityOpt.get().getUser();
            checkUserStatus(user);
        } else {
            // No identity linked to this Google sub yet
            // 3. Anti-Account Hijacking check: Does a local account already exist with this email?
            Optional<User> existingUserByEmail = userRepository.findByEmail(email);
            if (existingUserByEmail.isPresent()) {
                // DO NOT AUTO-LINK: Reject with HTTP 409 Conflict instructing user to login & link
                throw new AccountConflictException(
                        "Email này đã được sử dụng bởi một tài khoản khác. " +
                        "Vui lòng đăng nhập bằng mật khẩu và liên kết tài khoản Google trong phần cài đặt."
                );
            }

            // 4. New User Provisioning via Google
            String username = generateUniqueUsername(userInfo);
            String handle = userHandleService.generateUniqueHandle(userInfo.getName(), null);
            String unusablePassword = passwordEncoder.encode(UUID.randomUUID().toString());

            User newUser = User.builder()
                    .username(username)
                    .handle(handle)
                    .email(email)
                    .password(unusablePassword)
                    .fullName(userInfo.getName() != null && !userInfo.getName().isBlank() ? userInfo.getName() : username)
                    .avatar(userInfo.getPicture())
                    .role(Role.USER)
                    .status(UserStatus.ACTIVE)
                    .emailVerified(true) // Verified by Google
                    .tokenVersion(1)
                    .build();

            user = userRepository.save(newUser);

            // 5. Persist UserIdentity
            UserIdentity newIdentity = UserIdentity.builder()
                    .user(user)
                    .provider(PROVIDER_GOOGLE)
                    .providerSubject(sub)
                    .email(email)
                    .build();
            userIdentityRepository.save(newIdentity);
        }

        // 6. Create UserSession & Issue Travel Planner JWT
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

        String token = jwtTokenProvider.generateToken(user, sessionId);

        return AuthResponse.builder()
                .token(token)
                .tokenType("Bearer")
                .user(mapToUserResponse(user))
                .build();
    }

    @Override
    @Transactional
    public GoogleLinkResponse linkGoogleAccount(String currentUsername, GoogleLinkRequest request) {
        // 1. Cryptographically verify Google ID Token & claims
        GoogleUserInfo userInfo = googleTokenVerifier.verify(request.getIdToken());
        String email = userInfo.getEmail().toLowerCase().trim();
        String sub = userInfo.getSub();

        // 2. Fetch authenticated user
        User currentUser = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy thông tin tài khoản"));
        checkUserStatus(currentUser);

        // 3. Check if this Google sub is already linked
        Optional<UserIdentity> existingSubIdentity = userIdentityRepository.findByProviderAndProviderSubject(PROVIDER_GOOGLE, sub);
        if (existingSubIdentity.isPresent()) {
            UserIdentity identity = existingSubIdentity.get();
            if (identity.getUser().getUserId().equals(currentUser.getUserId())) {
                return GoogleLinkResponse.builder()
                        .message("Tài khoản Google này đã được liên kết với tài khoản của bạn trước đó.")
                        .linkedEmail(email)
                        .provider(PROVIDER_GOOGLE)
                        .build();
            } else {
                throw new ConflictException("Tài khoản Google này đã được liên kết với một tài khoản Travel Planner khác.");
            }
        }

        // 4. Check if current user already has another Google account linked
        Optional<UserIdentity> currentUserGoogle = userIdentityRepository.findByUser_UserIdAndProvider(currentUser.getUserId(), PROVIDER_GOOGLE);
        if (currentUserGoogle.isPresent()) {
            throw new ConflictException("Tài khoản Travel Planner của bạn đã được liên kết với một tài khoản Google khác.");
        }

        // 5. Persist link
        UserIdentity newIdentity = UserIdentity.builder()
                .user(currentUser)
                .provider(PROVIDER_GOOGLE)
                .providerSubject(sub)
                .email(email)
                .build();
        userIdentityRepository.save(newIdentity);

        return GoogleLinkResponse.builder()
                .message("Liên kết tài khoản Google thành công.")
                .linkedEmail(email)
                .provider(PROVIDER_GOOGLE)
                .build();
    }

    private void checkUserStatus(User user) {
        if (user.getStatus() == UserStatus.BANNED) {
            throw new ForbiddenException("Tài khoản của bạn đã bị khóa do vi phạm chính sách");
        }
        if (user.getStatus() == UserStatus.INACTIVE) {
            throw new ForbiddenException("Tài khoản của bạn đang bị vô hiệu hóa");
        }
    }

    private String generateUniqueUsername(GoogleUserInfo userInfo) {
        String base = null;
        if (userInfo.getEmail() != null && userInfo.getEmail().contains("@")) {
            base = userInfo.getEmail().split("@")[0].replaceAll("[^a-zA-Z0-9_]", "");
        }
        if (base == null || base.trim().isEmpty()) {
            base = "user";
        }
        if (base.length() > 30) {
            base = base.substring(0, 30);
        }

        String candidate = base;
        int attempts = 0;
        while (userRepository.existsByUsername(candidate)) {
            attempts++;
            String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 6);
            int maxBaseLen = 42; // leave room for _ + suffix (7 chars)
            String safeBase = base.length() > maxBaseLen ? base.substring(0, maxBaseLen) : base;
            candidate = safeBase + "_" + suffix;
            if (attempts > 20) {
                candidate = "user_" + UUID.randomUUID().toString().replace("-", "").substring(0, 12);
                break;
            }
        }
        return candidate;
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

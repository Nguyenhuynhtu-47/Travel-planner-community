package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.request.UpdateProfileRequest;
import Travel_Planner.Travel_Planner.dto.response.UserResponse;
import Travel_Planner.Travel_Planner.exception.BadRequestException;
import Travel_Planner.Travel_Planner.exception.ConflictException;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.ProfileService;
import Travel_Planner.Travel_Planner.service.UserHandleService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProfileServiceImpl implements ProfileService {

    private final UserRepository userRepository;
    private final UserHandleService userHandleService;

    public ProfileServiceImpl(UserRepository userRepository, UserHandleService userHandleService) {
        this.userRepository = userRepository;
        this.userHandleService = userHandleService;
    }

    @Override
    @Transactional(readOnly = true)
    public UserResponse getCurrentProfile(String username) {
        return toResponse(findUser(username));
    }

    @Override
    @Transactional
    public UserResponse updateCurrentProfile(String username, UpdateProfileRequest request) {
        User user = findUser(username);

        if (request.getHandle() != null && !request.getHandle().isBlank()) {
            String normalizedHandle = userHandleService.normalize(request.getHandle());
            if (!userHandleService.isValidFormat(normalizedHandle)) {
                throw new BadRequestException("Handle không đúng định dạng. Phải từ 3-30 ký tự (chữ thường, số, dấu chấm, gạch dưới)");
            }
            if (userRepository.existsByHandleAndUserIdNot(normalizedHandle, user.getUserId())) {
                throw new ConflictException("Định danh (@handle) này đã được sử dụng");
            }
            user.setHandle(normalizedHandle);
        }

        user.setFullName(request.getFullName().trim());
        user.setAvatar(normalize(request.getAvatar()));
        user.setPhone(normalize(request.getPhone()));
        user.setAddress(normalize(request.getAddress()));
        user.setBio(normalize(request.getBio()));
        return toResponse(userRepository.save(user));
    }

    private User findUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new UnauthorizedException("Không tìm thấy tài khoản đang đăng nhập"));
    }

    private String normalize(String value) {
        return value == null || value.isBlank() ? null : value.trim();
    }

    private UserResponse toResponse(User user) {
        return UserResponse.builder()
                .userId(user.getUserId())
                .username(user.getUsername())
                .handle(user.getHandle())
                .email(user.getEmail())
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

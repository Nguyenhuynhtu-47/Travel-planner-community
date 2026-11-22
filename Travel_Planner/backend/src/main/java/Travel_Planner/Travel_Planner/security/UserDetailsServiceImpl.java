package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import java.util.Collections;

@Service
public class UserDetailsServiceImpl implements UserDetailsService {

    private final UserRepository userRepository;

    public UserDetailsServiceImpl(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public UserDetails loadUserByUsername(String usernameOrEmail) throws UsernameNotFoundException {
        User user = userRepository.findByUsernameOrEmail(usernameOrEmail, usernameOrEmail)
                .orElseThrow(() -> new UsernameNotFoundException("Không tìm thấy người dùng: " + usernameOrEmail));

        boolean isActive = user.getStatus() == UserStatus.ACTIVE;
        boolean isNotBanned = user.getStatus() != UserStatus.BANNED;
        boolean isVerified = Boolean.TRUE.equals(user.getEmailVerified());
        boolean isEnabled = isActive && isVerified;

        int effectiveTokenVersion = (user.getTokenVersion() != null && user.getTokenVersion() > 0)
                ? user.getTokenVersion()
                : 1;

        return new CustomUserDetails(
                user.getUserId(),
                user.getUsername(),
                user.getPassword(),
                user.getEmail(),
                effectiveTokenVersion,
                isEnabled,
                isNotBanned,
                Collections.singletonList(new SimpleGrantedAuthority("ROLE_" + user.getRole().name()))
        );
    }
}

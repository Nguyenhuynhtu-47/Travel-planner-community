package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.exception.ResourceNotFoundException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserDeviceToken;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserDeviceTokenRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.DeviceTokenService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

@Service
public class DeviceTokenServiceImpl implements DeviceTokenService {
    private final UserRepository users;
    private final UserDeviceTokenRepository tokens;

    public DeviceTokenServiceImpl(UserRepository users, UserDeviceTokenRepository tokens) {
        this.users = users;
        this.tokens = tokens;
    }

    @Override
    @Transactional
    public void upsert(String username, String token, String platform) {
        User user = users.findByUsernameForUpdate(username)
                .filter(candidate -> candidate.getStatus() == UserStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        String tokenHash = hash(token);
        UserDeviceToken deviceToken = tokens.findByFcmTokenHash(tokenHash).orElseGet(UserDeviceToken::new);
        deviceToken.setUser(user);
        deviceToken.setFcmToken(token);
        deviceToken.setFcmTokenHash(tokenHash);
        deviceToken.setPlatform(platform);
        deviceToken.setDisabledAt(null);
        tokens.save(deviceToken);
    }

    @Override
    @Transactional
    public void unregister(String username, String token) {
        User user = users.findByUsername(username)
                .filter(candidate -> candidate.getStatus() == UserStatus.ACTIVE)
                .orElseThrow(() -> new ResourceNotFoundException("Không tìm thấy tài khoản"));
        tokens.deleteOwnedToken(hash(token), user.getUserId());
    }

    private static String hash(String token) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}

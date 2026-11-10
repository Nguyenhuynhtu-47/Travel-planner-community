package Travel_Planner.Travel_Planner.service.impl;

import Travel_Planner.Travel_Planner.dto.response.MessagingSettingsResponse;
import Travel_Planner.Travel_Planner.exception.UnauthorizedException;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.UserMessagingSettings;
import Travel_Planner.Travel_Planner.model.enums.InboundMessagePolicy;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserMessagingSettingsRepository;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.service.MessagingSettingsService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MessagingSettingsServiceImpl implements MessagingSettingsService {
    private final UserRepository users;
    private final UserMessagingSettingsRepository settings;

    public MessagingSettingsServiceImpl(UserRepository users, UserMessagingSettingsRepository settings) {
        this.users = users;
        this.settings = settings;
    }

    @Override
    @Transactional(readOnly = true)
    public MessagingSettingsResponse get(String actorUsername) {
        User actor = activeUser(actorUsername);
        return settings.findById(actor.getUserId()).map(this::response)
                .orElseGet(() -> MessagingSettingsResponse.builder().inboundPolicy(InboundMessagePolicy.FRIENDS_ONLY).build());
    }

    @Override
    @Transactional
    public MessagingSettingsResponse update(InboundMessagePolicy policy, String actorUsername) {
        User actor = activeUser(actorUsername);
        UserMessagingSettings value = settings.findById(actor.getUserId()).orElseGet(() -> new UserMessagingSettings(actor));
        value.setInboundPolicy(policy);
        return response(settings.save(value));
    }

    private User activeUser(String username) {
        if (username == null || username.isBlank()) throw new UnauthorizedException("Bạn cần đăng nhập");
        User user = users.findByUsername(username).orElseThrow(() -> new UnauthorizedException("Phiên đăng nhập không hợp lệ"));
        if (user.getStatus() != UserStatus.ACTIVE) throw new UnauthorizedException("Tài khoản không hoạt động");
        return user;
    }

    private MessagingSettingsResponse response(UserMessagingSettings value) {
        return MessagingSettingsResponse.builder().inboundPolicy(value.getInboundPolicy()).updatedAt(value.getUpdatedAt()).build();
    }
}

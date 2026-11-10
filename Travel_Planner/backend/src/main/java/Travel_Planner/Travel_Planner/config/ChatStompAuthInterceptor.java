package Travel_Planner.Travel_Planner.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.MessageDeliveryException;
import org.springframework.messaging.simp.SimpMessageType;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;
import Travel_Planner.Travel_Planner.model.User;
import Travel_Planner.Travel_Planner.model.enums.UserStatus;
import Travel_Planner.Travel_Planner.repository.UserRepository;
import Travel_Planner.Travel_Planner.security.JwtTokenProvider;
import Travel_Planner.Travel_Planner.security.UserDetailsServiceImpl;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;
import java.time.Instant;
import java.util.Date;

@Component
public class ChatStompAuthInterceptor implements ChannelInterceptor {
    public static final String SESSION_EXPIRES_AT = "chatSessionExpiresAt";
    private final JwtTokenProvider tokens;
    private final UserDetailsServiceImpl userDetailsService;
    private final UserRepository users;
    private final ChatWebSocketSessionRegistry sessions;
    private final int maxSessionsPerUser;

    public ChatStompAuthInterceptor(JwtTokenProvider tokens, UserDetailsServiceImpl userDetailsService,
            UserRepository users, ChatWebSocketSessionRegistry sessions,
            @Value("${chat.websocket.max-sessions-per-user:5}") int maxSessionsPerUser) {
        this.tokens = tokens;
        this.userDetailsService = userDetailsService;
        this.users = users;
        this.sessions = sessions;
        this.maxSessionsPerUser = Math.max(1, maxSessionsPerUser);
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor == null) return message;
        StompCommand command = accessor.getCommand();
        if (command == StompCommand.CONNECT) {
            authenticate(accessor);
            return message;
        }
        if (command == StompCommand.DISCONNECT || (command == null && accessor.getMessageType() == SimpMessageType.HEARTBEAT)) return message;
        if (command == null) throw denied();
        if (!(accessor.getUser() instanceof Authentication authentication)) throw denied();
        if (authentication == null || !authentication.isAuthenticated()) throw denied();
        Object expires = accessor.getSessionAttributes() == null ? null : accessor.getSessionAttributes().get(SESSION_EXPIRES_AT);
        if (!(expires instanceof Long expiration) || Instant.now().toEpochMilli() >= expiration) throw denied();
        User user = users.findByUsername(authentication.getName()).orElseThrow(ChatStompAuthInterceptor::denied);
        if (user.getStatus() != UserStatus.ACTIVE) throw denied();
        if (command == StompCommand.SEND) throw denied();
        if (command == StompCommand.SUBSCRIBE) {
            if (!"/user/queue/chat-events".equals(accessor.getDestination())) throw denied();
            return message;
        }
        if (command == StompCommand.UNSUBSCRIBE || accessor.getMessageType() == SimpMessageType.UNSUBSCRIBE) return message;
        throw denied();
    }

    private void authenticate(StompHeaderAccessor accessor) {
        String authorization = accessor.getFirstNativeHeader("Authorization");
        if (authorization == null || !authorization.startsWith("Bearer ")) throw denied();
        String token = authorization.substring(7).trim();
        if (!tokens.validateToken(token)) throw denied();
        String username = tokens.getUsernameFromToken(token);
        UserDetails details;
        try { details = userDetailsService.loadUserByUsername(username); }
        catch (RuntimeException ex) { throw denied(); }
        if (!details.isEnabled() || !details.isAccountNonLocked()) throw denied();
        Date expiration = tokens.getClaimsFromToken(token).getExpiration();
        if (expiration == null || !expiration.after(new Date())) throw denied();
        String sessionId = accessor.getSessionId();
        if (sessionId == null || !sessions.register(username, sessionId, maxSessionsPerUser)) throw denied();
        Authentication authentication = new UsernamePasswordAuthenticationToken(details, null, details.getAuthorities());
        accessor.setUser(authentication);
        if (accessor.getSessionAttributes() != null) accessor.getSessionAttributes().put(SESSION_EXPIRES_AT, expiration.getTime());
    }

    @EventListener
    public void onDisconnect(SessionDisconnectEvent event) { sessions.remove(event.getSessionId()); }

    private static MessageDeliveryException denied() { return new MessageDeliveryException("WebSocket authentication or destination denied"); }
}


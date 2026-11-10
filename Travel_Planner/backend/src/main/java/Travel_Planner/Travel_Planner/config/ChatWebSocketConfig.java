package Travel_Planner.Travel_Planner.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.util.StringUtils;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketTransportRegistration;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Stream;

@Configuration
@EnableWebSocketMessageBroker
public class ChatWebSocketConfig implements WebSocketMessageBrokerConfigurer {
    private final ChatStompAuthInterceptor authInterceptor;
    private final String allowedOrigins;
    private final String allowedOriginPatterns;
    private final int maxFrameBytes;
    private final int sendBufferBytes;
    private final int sendTimeLimitMs;

    public ChatWebSocketConfig(ChatStompAuthInterceptor authInterceptor,
            @Value("${cors.allowed-origins:http://localhost:8081,http://127.0.0.1:8081}") String allowedOrigins,
            @Value("${cors.allowed-origin-patterns:http://localhost:*,http://127.0.0.1:*}") String allowedOriginPatterns,
            @Value("${chat.websocket.max-frame-bytes:65536}") int maxFrameBytes,
            @Value("${chat.websocket.send-buffer-bytes:524288}") int sendBufferBytes,
            @Value("${chat.websocket.send-time-limit-ms:15000}") int sendTimeLimitMs) {
        this.authInterceptor = authInterceptor;
        this.allowedOrigins = allowedOrigins;
        this.allowedOriginPatterns = allowedOriginPatterns;
        this.maxFrameBytes = Math.max(1024, maxFrameBytes);
        this.sendBufferBytes = Math.max(this.maxFrameBytes, sendBufferBytes);
        this.sendTimeLimitMs = Math.max(1000, sendTimeLimitMs);
    }

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        List<String> patterns = Stream.concat(parse(allowedOrigins).stream(), parse(allowedOriginPatterns).stream()).distinct().toList();
        registry.addEndpoint("/ws").setAllowedOriginPatterns(patterns.toArray(String[]::new));
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/queue");
        registry.setApplicationDestinationPrefixes("/app");
        registry.setUserDestinationPrefix("/user");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(authInterceptor);
    }

    @Override
    public void configureWebSocketTransport(WebSocketTransportRegistration registration) {
        registration.setMessageSizeLimit(maxFrameBytes).setSendBufferSizeLimit(sendBufferBytes).setSendTimeLimit(sendTimeLimitMs);
    }

    private List<String> parse(String value) {
        if (!StringUtils.hasText(value)) return List.of();
        return Arrays.stream(value.split(",")).map(String::trim).filter(StringUtils::hasText).toList();
    }
}

package Travel_Planner.Travel_Planner.config;

import org.springframework.stereotype.Component;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class ChatWebSocketSessionRegistry {
    private final ConcurrentHashMap<String, Set<String>> sessionsByUsername = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, String> usernameBySession = new ConcurrentHashMap<>();

    public boolean register(String username, String sessionId, int maximum) {
        String previous = usernameBySession.get(sessionId);
        if (previous != null) return previous.equals(username);
        Set<String> sessions = sessionsByUsername.computeIfAbsent(username, ignored -> ConcurrentHashMap.newKeySet());
        synchronized (sessions) {
            if (sessions.contains(sessionId)) return true;
            if (sessions.size() >= maximum) return false;
            sessions.add(sessionId);
            usernameBySession.put(sessionId, username);
            return true;
        }
    }

    public void remove(String sessionId) {
        String username = usernameBySession.remove(sessionId);
        if (username == null) return;
        Set<String> sessions = sessionsByUsername.get(username);
        if (sessions == null) return;
        synchronized (sessions) {
            sessions.remove(sessionId);
            if (sessions.isEmpty()) sessionsByUsername.remove(username, sessions);
        }
    }
}

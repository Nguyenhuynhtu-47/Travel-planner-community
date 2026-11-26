package Travel_Planner.Travel_Planner.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.util.List;

@Configuration
public class FirebaseMessagingConfiguration {
    @Bean
    @ConditionalOnProperty(name = "app.firebase.messaging.enabled", havingValue = "true")
    FirebaseApp notificationFirebaseApp(@Value("${app.firebase.messaging.project-id}") String projectId)
            throws IOException {
        return FirebaseApp.getApps().stream().filter(app -> app.getName().equals("travelPlannerMessaging"))
                .findFirst().orElseGet(() -> {
                    try {
                        FirebaseOptions options = FirebaseOptions.builder()
                                .setCredentials(GoogleCredentials.getApplicationDefault())
                                .setProjectId(projectId)
                                .build();
                        return FirebaseApp.initializeApp(options, "travelPlannerMessaging");
                    } catch (IOException exception) {
                        throw new FirebaseInitializationException(exception);
                    }
                });
    }

    static final class FirebaseInitializationException extends RuntimeException {
        FirebaseInitializationException(IOException cause) { super(cause); }
    }
}

package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.exception.BadRequestException;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdToken;
import com.google.api.client.googleapis.auth.oauth2.GoogleIdTokenVerifier;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.gson.GsonFactory;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.stream.Collectors;

@Component
public class GoogleTokenVerifierImpl implements GoogleTokenVerifier {

    private static final Logger log = LoggerFactory.getLogger(GoogleTokenVerifierImpl.class);

    private final GoogleIdTokenVerifier verifier;
    private final List<String> configuredAudiences;

    @org.springframework.beans.factory.annotation.Autowired
    public GoogleTokenVerifierImpl(
            @Value("${app.google.client-ids:}") String clientIds,
            @Value("${app.google.android-client-id:}") String androidClientId,
            @Value("${app.google.server-client-id:}") String serverClientId) {

        List<String> audiences = new ArrayList<>();
        if (clientIds != null && !clientIds.isBlank()) {
            audiences.addAll(Arrays.stream(clientIds.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList());
        }
        if (androidClientId != null && !androidClientId.isBlank()) {
            audiences.add(androidClientId.trim());
        }
        if (serverClientId != null && !serverClientId.isBlank()) {
            audiences.add(serverClientId.trim());
        }

        this.configuredAudiences = Collections.unmodifiableList(audiences.stream().distinct().collect(Collectors.toList()));

        GoogleIdTokenVerifier.Builder builder = new GoogleIdTokenVerifier.Builder(
                new NetHttpTransport(),
                GsonFactory.getDefaultInstance()
        );

        if (!this.configuredAudiences.isEmpty()) {
            builder.setAudience(this.configuredAudiences);
            log.info("--- [GoogleTokenVerifier] Initialized with accepted audiences: {} ---", this.configuredAudiences);
        } else {
            log.warn("--- [GoogleTokenVerifier] No Google OAuth client IDs configured in app.google.*. Any valid Google ID token will be accepted for dev/testing. Configure GOOGLE_CLIENT_IDS in production! ---");
        }

        this.verifier = builder.build();
    }

    // Constructor for testing with mock verifier
    public GoogleTokenVerifierImpl(GoogleIdTokenVerifier customVerifier, List<String> configuredAudiences) {
        this.verifier = customVerifier;
        this.configuredAudiences = configuredAudiences != null ? configuredAudiences : Collections.emptyList();
    }

    @Override
    public GoogleUserInfo verify(String idTokenString) {
        if (idTokenString == null || idTokenString.trim().isEmpty()) {
            throw new BadRequestException("Mã xác thực Google (ID Token) không được để trống.");
        }

        GoogleIdToken idToken;
        try {
            idToken = verifier.verify(idTokenString.trim());
        } catch (GeneralSecurityException | IOException e) {
            log.error("--- [GoogleTokenVerifier] Verification failure: {} ---", e.getMessage());
            throw new BadRequestException("Không thể xác thực mã Google ID Token: " + e.getMessage());
        }

        if (idToken == null) {
            log.warn("--- [GoogleTokenVerifier] Google ID Token rejected (signature/expiry/issuer/audience mismatch) ---");
            throw new BadRequestException("Mã xác thực Google không hợp lệ hoặc đã hết hạn.");
        }

        GoogleIdToken.Payload payload = idToken.getPayload();
        if (payload == null) {
            throw new BadRequestException("Thông tin định danh từ Google không hợp lệ.");
        }

        String sub = payload.getSubject();
        if (sub == null || sub.trim().isEmpty()) {
            throw new BadRequestException("Mã định danh người dùng (sub) từ Google không tồn tại.");
        }

        String email = payload.getEmail();
        if (email == null || email.trim().isEmpty()) {
            throw new BadRequestException("Không tìm thấy địa chỉ email trong thông tin Google.");
        }

        Boolean emailVerified = payload.getEmailVerified();
        if (!Boolean.TRUE.equals(emailVerified)) {
            throw new BadRequestException("Email tài khoản Google này chưa được xác thực bởi Google.");
        }

        String name = (String) payload.get("name");
        String picture = (String) payload.get("picture");

        return GoogleUserInfo.builder()
                .sub(sub.trim())
                .email(email.trim().toLowerCase())
                .emailVerified(true)
                .name(name)
                .picture(picture)
                .build();
    }
}

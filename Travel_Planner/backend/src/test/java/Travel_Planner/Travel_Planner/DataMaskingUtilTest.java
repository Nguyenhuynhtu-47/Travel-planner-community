package Travel_Planner.Travel_Planner;

import Travel_Planner.Travel_Planner.dto.audit.*;
import Travel_Planner.Travel_Planner.model.*;
import Travel_Planner.Travel_Planner.model.enums.*;
import Travel_Planner.Travel_Planner.util.DataMaskingUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

class DataMaskingUtilTest {

    private final DataMaskingUtil dataMaskingUtil = new DataMaskingUtil();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    @DisplayName("Allowlist UserAuditSnapshot excludes password/tokenVersion and masks email")
    void userAuditSnapshot_excludesSecretsAndMasksEmail() throws Exception {
        User user = User.builder()
                .userId(42)
                .username("traveler_one")
                .handle("traveler_one")
                .password("$2a$10$superSecretBcryptHash")
                .email("traveler.one@example.com")
                .role(Role.USER)
                .status(UserStatus.ACTIVE)
                .tokenVersion(99)
                .phone("0901234567")
                .address("123 Secret Home Street")
                .bio("Private bio")
                .build();

        UserAuditSnapshot snapshot = UserAuditSnapshot.from(user);
        String json = dataMaskingUtil.toMaskedJson(snapshot);
        assertNotNull(json);

        assertFalse(json.contains("superSecretBcryptHash"));
        assertFalse(json.contains("password"));
        assertFalse(json.contains("tokenVersion"));
        assertFalse(json.contains("0901234567"));
        assertFalse(json.contains("123 Secret Home Street"));

        JsonNode node = objectMapper.readTree(json);
        assertEquals(42, node.get("userId").asInt());
        assertEquals("traveler_one", node.get("username").asText());
        assertEquals("t***@example.com", node.get("email").asText());
        assertEquals("USER", node.get("role").asText());
        assertEquals("ACTIVE", node.get("status").asText());
    }

    @Test
    @DisplayName("Allowlist snapshots for Itinerary, Place, Post, Report contain only safe fields")
    void allowlistSnapshots_otherEntities_safeFieldsOnly() throws Exception {
        Itinerary itinerary = Itinerary.builder()
                .itineraryId(10)
                .title("Da Nang 3N2D")
                .totalDays(3)
                .visibility(Visibility.PRIVATE)
                .status(ItineraryStatus.ACTIVE)
                .description("Sensitive private trip notes should not leak")
                .build();

        String itineraryJson = dataMaskingUtil.toMaskedJson(ItineraryAuditSnapshot.from(itinerary));
        assertFalse(itineraryJson.contains("Sensitive private trip notes"));
        assertTrue(itineraryJson.contains("Da Nang 3N2D"));

        AdministrativeArea area = AdministrativeArea.builder().code("79").name("TP.HCM").build();
        Place place = Place.builder()
                .placeId(5L)
                .name("Ben Thanh Market")
                .category(PlaceCategory.SHOPPING)
                .address("Le Loi, Q1")
                .status(PlaceStatus.ACTIVE)
                .administrativeArea(area)
                .latitude(new BigDecimal("10.7720"))
                .longitude(new BigDecimal("106.6980"))
                .build();

        JsonNode placeNode = objectMapper.readTree(dataMaskingUtil.toMaskedJson(PlaceAuditSnapshot.from(place)));
        assertEquals("79", placeNode.get("administrativeCode").asText());
        assertEquals("Ben Thanh Market", placeNode.get("name").asText());
    }

    @Test
    @DisplayName("Direct JPA Entity or Entity nested inside Map/List is strictly rejected")
    void directJpaEntitySerialization_throwsIllegalArgumentException() {
        User entity = User.builder().userId(1).username("u1").password("secret").email("u1@test.com").build();

        assertThrows(IllegalArgumentException.class, () -> dataMaskingUtil.toMaskedJson(entity));

        Map<String, Object> wrappedInMap = Map.of("nested", Map.of("targetUser", entity));
        assertThrows(IllegalArgumentException.class, () -> dataMaskingUtil.toMaskedJson(wrappedInMap));

        List<Object> wrappedInList = List.of(entity);
        assertThrows(IllegalArgumentException.class, () -> dataMaskingUtil.toMaskedJson(wrappedInList));
    }

    @Test
    @DisplayName("Recursive denylist masks credentials, JWTs, Bearer tokens, and PII in nested objects and collections")
    void recursiveMasking_nestedObjectsAndCollections_masksAllSensitiveData() throws Exception {
        Map<String, Object> nestedCredentials = new LinkedHashMap<>();
        nestedCredentials.put("password", "MySecretPass!123");
        nestedCredentials.put("api_key", "sk_live_123456");
        nestedCredentials.put("authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.signature123");
        nestedCredentials.put("contactEmail", "alice.admin@travelplanner.io");
        nestedCredentials.put("phoneNumber", "0909888777");

        Map<String, Object> item1 = Map.of(
                "clientSecret", "top-secret-abc",
                "otpCode", "123456",
                "safeLabel", "Audit Check"
        );
        Map<String, Object> item2 = Map.of(
                "notes", "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiI5OTkifQ.sig999",
                "rawJwt", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxIn0.abcd1234"
        );

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("operation", "SECURITY_TEST");
        payload.put("nested", nestedCredentials);
        payload.put("tokens", List.of("tok_1", "tok_2"));
        payload.put("items", List.of(item1, item2));

        String maskedJson = dataMaskingUtil.toMaskedJson(payload);
        assertNotNull(maskedJson);

        assertFalse(maskedJson.contains("MySecretPass!123"));
        assertFalse(maskedJson.contains("sk_live_123456"));
        assertFalse(maskedJson.contains("top-secret-abc"));
        assertFalse(maskedJson.contains("eyJhbGciOiJIUzI1NiJ9"));
        assertFalse(maskedJson.contains("tok_1"));
        assertFalse(maskedJson.contains("tok_2"));
        assertFalse(maskedJson.contains("alice.admin@travelplanner.io"));
        assertFalse(maskedJson.contains("0909888777"));

        JsonNode root = objectMapper.readTree(maskedJson);
        assertEquals("SECURITY_TEST", root.get("operation").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/nested/password").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/nested/api_key").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/nested/authorization").asText());
        assertEquals("a***@travelplanner.io", root.at("/nested/contactEmail").asText());
        assertEquals("090****777", root.at("/nested/phoneNumber").asText());

        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/tokens/0").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/tokens/1").asText());

        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/items/0/clientSecret").asText());
        assertEquals("Audit Check", root.at("/items/0/safeLabel").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/items/1/notes").asText());
        assertEquals(DataMaskingUtil.MASKED_VALUE, root.at("/items/1/rawJwt").asText());
    }
}

package Travel_Planner.Travel_Planner.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.fasterxml.jackson.databind.node.TextNode;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import jakarta.persistence.Entity;
import org.hibernate.proxy.HibernateProxy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.lang.reflect.Array;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.util.*;
import java.util.regex.Pattern;

/**
 * Audit snapshot serialization and masking utility.
 *
 * Enforces:
 * 1. Zero direct serialization of JPA @Entity objects or Hibernate proxies.
 * 2. Allowlist-first DTO snapshots with recursive denylist fallback across nested objects and collections.
 * 3. Redaction of credentials, tokens, secrets, and partial masking of PII (emails, phones).
 */
@Component
public class DataMaskingUtil {

    public static final String MASKED_VALUE = "***MASKED***";
    private static final int MAX_DEPTH = 16;

    private static final Pattern JWT_PATTERN =
            Pattern.compile("^eyJ[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{4,}$");
    private static final Pattern BEARER_PATTERN =
            Pattern.compile("(?i)^Bearer\\s+\\S+$");

    private static final Set<String> CREDENTIAL_KEY_TOKENS = Set.of(
            "password", "passwd", "pwd", "passcode",
            "token", "accesstoken", "refreshtoken", "idtoken", "jwttoken", "claimtoken",
            "resettoken", "verificationtoken", "tokenversion",
            "secret", "clientsecret", "apikey", "privatekey",
            "authorization", "authheader", "cookie", "setcookie",
            "sessionid", "credential", "credentials", "otp", "pin",
            "pepper", "salt", "hash", "otphash", "tokenhash", "passwordhash", "signature", "bearer", "jwt"
    );

    private static final Set<String> EMAIL_KEYS = Set.of(
            "email", "useremail", "contactemail", "oldemail", "newemail", "actoremail"
    );

    private static final Set<String> PHONE_KEYS = Set.of(
            "phone", "phonenumber", "mobile", "telephone", "tel"
    );

    private final ObjectMapper objectMapper;

    public DataMaskingUtil() {
        ObjectMapper mapper = new ObjectMapper();
        mapper.registerModule(new JavaTimeModule());
        mapper.disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);
        this.objectMapper = mapper;
    }

    @Autowired
    public DataMaskingUtil(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper != null ? objectMapper : new DataMaskingUtil().objectMapper;
    }

    /**
     * Converts an allowlist snapshot DTO, Map, or Collection into a masked JSON string.
     * Returns null when snapshot is null.
     */
    public String toMaskedJson(Object snapshot) {
        if (snapshot == null) {
            return null;
        }
        if (snapshot instanceof String rawJson) {
            return maskJsonString(rawJson);
        }

        rejectJpaEntities(snapshot, Collections.newSetFromMap(new IdentityHashMap<>()), 0);

        JsonNode rootNode = objectMapper.valueToTree(snapshot);
        if (rootNode == null || rootNode.isNull()) {
            return null;
        }
        JsonNode maskedNode = maskNode(rootNode, null, 0);
        try {
            return objectMapper.writeValueAsString(maskedNode);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Failed to serialize masked audit snapshot", e);
        }
    }

    /**
     * Parses a valid JSON string and applies recursive credential and PII masking.
     */
    public String maskJsonString(String rawJson) {
        if (rawJson == null || rawJson.isBlank()) {
            return null;
        }
        try {
            JsonNode root = objectMapper.readTree(rawJson);
            if (root == null || root.isNull()) {
                return null;
            }
            JsonNode masked = maskNode(root, null, 0);
            return objectMapper.writeValueAsString(masked);
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException("Audit snapshot string must be valid JSON", e);
        }
    }

    public static String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return email;
        }
        String trimmed = email.trim();
        int atIndex = trimmed.indexOf('@');
        if (atIndex <= 0 || atIndex == trimmed.length() - 1) {
            return MASKED_VALUE;
        }
        String local = trimmed.substring(0, atIndex);
        String domain = trimmed.substring(atIndex);
        if (local.length() == 1) {
            return "***" + domain;
        }
        return local.charAt(0) + "***" + domain;
    }

    public static String maskPhone(String phone) {
        if (phone == null || phone.isBlank()) {
            return phone;
        }
        String trimmed = phone.trim();
        if (trimmed.length() <= 4) {
            return "****";
        }
        String suffix = trimmed.substring(trimmed.length() - 3);
        if (trimmed.length() >= 7) {
            String prefix = trimmed.substring(0, 3);
            return prefix + "****" + suffix;
        }
        return "****" + suffix;
    }

    private JsonNode maskNode(JsonNode node, String fieldName, int depth) {
        if (node == null || node.isNull()) {
            return node;
        }
        if (depth > MAX_DEPTH) {
            return TextNode.valueOf("[MAX_DEPTH_TRUNCATED]");
        }

        if (node.isObject()) {
            ObjectNode source = (ObjectNode) node;
            ObjectNode copy = objectMapper.createObjectNode();
            Iterator<Map.Entry<String, JsonNode>> fields = source.fields();
            while (fields.hasNext()) {
                Map.Entry<String, JsonNode> entry = fields.next();
                String key = entry.getKey();
                JsonNode value = entry.getValue();
                copy.set(key, maskNode(value, key, depth + 1));
            }
            return copy;
        }

        if (node.isArray()) {
            ArrayNode sourceArray = (ArrayNode) node;
            ArrayNode copyArray = objectMapper.createArrayNode();
            for (JsonNode element : sourceArray) {
                // Propagate parent key policy if scalar elements sit inside e.g. tokens: ["t1", "t2"]
                String elementKeyHint = (element != null && element.isValueNode()) ? fieldName : null;
                copyArray.add(maskNode(element, elementKeyHint, depth + 1));
            }
            return copyArray;
        }

        return maskScalarNode(node, fieldName);
    }

    private JsonNode maskScalarNode(JsonNode node, String fieldName) {
        String normalizedKey = normalizeKey(fieldName);

        if (isSensitiveCredentialKey(normalizedKey)) {
            return TextNode.valueOf(MASKED_VALUE);
        }

        if (node.isTextual()) {
            String text = node.asText();
            if (isEmailKey(normalizedKey)) {
                return TextNode.valueOf(maskEmail(text));
            }
            if (isPhoneKey(normalizedKey)) {
                return TextNode.valueOf(maskPhone(text));
            }
            if (looksLikeRawToken(text)) {
                return TextNode.valueOf(MASKED_VALUE);
            }
        }

        return node;
    }

    private void rejectJpaEntities(Object value, Set<Object> visited, int depth) {
        if (value == null || depth > MAX_DEPTH) {
            return;
        }
        Class<?> clazz = value.getClass();
        if (value instanceof HibernateProxy || clazz.isAnnotationPresent(Entity.class)) {
            throw new IllegalArgumentException(
                    "Direct serialization of JPA @Entity objects into audit snapshots is forbidden; use an allowlist snapshot DTO.");
        }
        if (isSimpleValueType(clazz)) {
            return;
        }
        if (!visited.add(value)) {
            throw new IllegalArgumentException("Circular reference detected in audit snapshot.");
        }

        try {
            if (value instanceof Map<?, ?> map) {
                for (Map.Entry<?, ?> entry : map.entrySet()) {
                    rejectJpaEntities(entry.getKey(), visited, depth + 1);
                    rejectJpaEntities(entry.getValue(), visited, depth + 1);
                }
            } else if (value instanceof Iterable<?> iterable) {
                for (Object item : iterable) {
                    rejectJpaEntities(item, visited, depth + 1);
                }
            } else if (clazz.isArray()) {
                int len = Array.getLength(value);
                for (int i = 0; i < len; i++) {
                    rejectJpaEntities(Array.get(value, i), visited, depth + 1);
                }
            } else if (!clazz.getPackageName().startsWith("java.")
                    && !clazz.getPackageName().startsWith("jakarta.")
                    && !clazz.getPackageName().startsWith("org.springframework.")) {
                for (Class<?> current = clazz; current != null && current != Object.class; current = current.getSuperclass()) {
                    for (Field field : current.getDeclaredFields()) {
                        if (Modifier.isStatic(field.getModifiers()) || field.isSynthetic()) {
                            continue;
                        }
                        if (field.trySetAccessible()) {
                            try {
                                Object fieldVal = field.get(value);
                                rejectJpaEntities(fieldVal, visited, depth + 1);
                            } catch (IllegalAccessException ignored) {
                                // Skip inaccessible JDK internals
                            }
                        }
                    }
                }
            }
        } finally {
            visited.remove(value);
        }
    }

    private boolean isSimpleValueType(Class<?> clazz) {
        return clazz.isPrimitive()
                || clazz.isEnum()
                || Number.class.isAssignableFrom(clazz)
                || Boolean.class.isAssignableFrom(clazz)
                || Character.class.isAssignableFrom(clazz)
                || CharSequence.class.isAssignableFrom(clazz)
                || java.time.temporal.TemporalAccessor.class.isAssignableFrom(clazz)
                || Date.class.isAssignableFrom(clazz)
                || UUID.class.isAssignableFrom(clazz);
    }

    private String normalizeKey(String key) {
        if (key == null) {
            return "";
        }
        return key.replaceAll("[^a-zA-Z0-9]", "").toLowerCase(Locale.ROOT);
    }

    private boolean isSensitiveCredentialKey(String normalizedKey) {
        if (normalizedKey.isEmpty()) {
            return false;
        }
        if (CREDENTIAL_KEY_TOKENS.contains(normalizedKey)) {
            return true;
        }
        return normalizedKey.contains("password")
                || normalizedKey.contains("passwd")
                || normalizedKey.contains("secret")
                || normalizedKey.contains("credential")
                || normalizedKey.contains("privatekey")
                || normalizedKey.contains("apikey")
                || normalizedKey.contains("authorization")
                || normalizedKey.contains("cookie")
                || normalizedKey.contains("sessionid")
                || normalizedKey.contains("token")
                || normalizedKey.startsWith("otp")
                || normalizedKey.endsWith("otp")
                || normalizedKey.endsWith("otps")
                || normalizedKey.endsWith("hash")
                || normalizedKey.endsWith("hashes");
    }

    private boolean isEmailKey(String normalizedKey) {
        return EMAIL_KEYS.contains(normalizedKey)
                || normalizedKey.endsWith("email")
                || normalizedKey.endsWith("emails");
    }

    private boolean isPhoneKey(String normalizedKey) {
        return PHONE_KEYS.contains(normalizedKey)
                || normalizedKey.endsWith("phone")
                || normalizedKey.endsWith("phones")
                || normalizedKey.endsWith("phonenumber")
                || normalizedKey.endsWith("phonenumbers");
    }

    private boolean looksLikeRawToken(String text) {
        if (text == null || text.isBlank()) {
            return false;
        }
        String trimmed = text.trim();
        return BEARER_PATTERN.matcher(trimmed).matches() || JWT_PATTERN.matcher(trimmed).matches();
    }
}

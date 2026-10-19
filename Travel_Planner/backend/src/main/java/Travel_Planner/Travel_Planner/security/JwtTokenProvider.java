package Travel_Planner.Travel_Planner.security;

import Travel_Planner.Travel_Planner.model.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;

import org.springframework.core.env.Environment;

@Component
public class JwtTokenProvider {

    public static final String DEFAULT_DEV_SECRET = "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970";

    private final SecretKey key;
    private final long expirationMs;

    public JwtTokenProvider(
            @Value("${jwt.secret:" + DEFAULT_DEV_SECRET + "}") String secret,
            @Value("${jwt.expiration:86400000}") long expirationMs,
            Environment environment) {
        validateJwtSecretForEnvironment(secret, environment);

        byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
        if (keyBytes.length < 32) {
            throw new IllegalStateException("JWT secret must be at least 256 bits (32 bytes) long for HMAC-SHA256.");
        }

        this.key = Keys.hmacShaKeyFor(keyBytes);
        this.expirationMs = expirationMs;
    }

    private void validateJwtSecretForEnvironment(String secret, Environment environment) {
        boolean isProduction = false;
        if (environment != null) {
            String[] activeProfiles = environment.getActiveProfiles();
            for (String profile : activeProfiles) {
                if ("prod".equalsIgnoreCase(profile) || "production".equalsIgnoreCase(profile)) {
                    isProduction = true;
                    break;
                }
            }
        }

        if (isProduction) {
            if (secret == null || secret.isBlank() || DEFAULT_DEV_SECRET.equals(secret)) {
                throw new IllegalStateException(
                    "FATAL SECURITY CONFIGURATION ERROR: In production profile ('prod'/'production'), " +
                    "the JWT secret cannot use the default hardcoded development secret. " +
                    "Please set the 'JWT_SECRET' environment variable with a strong, random key."
                );
            }
        }
    }

    public String generateToken(User user) {
        Date now = new Date();
        Date expiryDate = new Date(now.getTime() + expirationMs);

        return Jwts.builder()
                .subject(user.getUsername())
                .claim("userId", user.getUserId())
                .claim("email", user.getEmail())
                .claim("role", user.getRole().name())
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(key)
                .compact();
    }

    public String getUsernameFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        return claims.getSubject();
    }

    public boolean validateToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            return !claims.getExpiration().before(new Date());
        } catch (JwtException | IllegalArgumentException e) {
            return false;
        }
    }

    public Claims getClaimsFromToken(String token) {
        return Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }
}

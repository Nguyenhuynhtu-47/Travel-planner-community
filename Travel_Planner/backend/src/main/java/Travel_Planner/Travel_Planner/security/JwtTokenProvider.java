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
                .claim("tokenVersion", user.getTokenVersion() != null ? user.getTokenVersion() : 1)
                .issuedAt(now)
                .expiration(expiryDate)
                .signWith(key)
                .compact();
    }

    public String getUsernameFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        return claims.getSubject();
    }

    public Integer getTokenVersionFromToken(String token) {
        Claims claims = getClaimsFromToken(token);
        if (!claims.containsKey("tokenVersion")) {
            return null; // Genuinely absent claim (legacy token compatibility)
        }
        Object versionObj = claims.get("tokenVersion");
        if (versionObj == null) {
            throw new JwtException("tokenVersion claim cannot be null");
        }

        // Reject String values, even numeric strings
        if (versionObj instanceof String) {
            throw new JwtException("tokenVersion claim must not be a String. Integral numeric type required.");
        }

        // Reject Boolean, collections, and non-Number types
        if (!(versionObj instanceof Number)) {
            throw new JwtException("Unsupported tokenVersion claim type: " + versionObj.getClass().getName());
        }

        // Reject decimal / floating-point representations (Float, Double)
        if (versionObj instanceof Double || versionObj instanceof Float) {
            throw new JwtException("tokenVersion claim must be an integral number, not decimal or floating point.");
        }

        if (versionObj instanceof java.math.BigDecimal bd) {
            if (bd.scale() > 0 && bd.stripTrailingZeros().scale() > 0) {
                throw new JwtException("tokenVersion claim must be an integer, not decimal: " + bd);
            }
            try {
                long longVal = bd.longValueExact();
                if (longVal <= 0) {
                    throw new JwtException("Invalid tokenVersion claim value: " + longVal + ". Must be positive.");
                }
                if (longVal > Integer.MAX_VALUE) {
                    throw new JwtException("tokenVersion claim value " + longVal + " exceeds Integer.MAX_VALUE.");
                }
                return (int) longVal;
            } catch (ArithmeticException e) {
                throw new JwtException("tokenVersion claim overflows integral type: " + bd);
            }
        }

        if (versionObj instanceof java.math.BigInteger bi) {
            if (bi.compareTo(java.math.BigInteger.ONE) < 0) {
                throw new JwtException("Invalid tokenVersion claim value: " + bi + ". Must be positive.");
            }
            if (bi.compareTo(java.math.BigInteger.valueOf(Integer.MAX_VALUE)) > 0) {
                throw new JwtException("tokenVersion claim value " + bi + " exceeds Integer.MAX_VALUE.");
            }
            return bi.intValueExact();
        }

        // Integral numbers (Integer, Long, Short, Byte)
        long longVal = ((Number) versionObj).longValue();
        if (longVal <= 0) {
            throw new JwtException("Invalid tokenVersion claim value: " + longVal + ". Must be a positive integer.");
        }
        if (longVal > Integer.MAX_VALUE) {
            throw new JwtException("tokenVersion claim value " + longVal + " exceeds Integer.MAX_VALUE (" + Integer.MAX_VALUE + ").");
        }

        return (int) longVal;
    }

    public boolean validateToken(String token) {
        try {
            Claims claims = getClaimsFromToken(token);
            if (claims.getExpiration().before(new Date())) {
                return false;
            }
            if (claims.containsKey("tokenVersion")) {
                getTokenVersionFromToken(token);
            }
            return true;
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

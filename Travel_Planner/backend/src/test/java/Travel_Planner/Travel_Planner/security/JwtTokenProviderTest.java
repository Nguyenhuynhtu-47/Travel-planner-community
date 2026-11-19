package Travel_Planner.Travel_Planner.security;

import org.junit.jupiter.api.Test;
import org.springframework.mock.env.MockEnvironment;

import static org.junit.jupiter.api.Assertions.*;

class JwtTokenProviderTest {

    @Test
    void whenDevProfileWithDefaultSecret_thenInitializationSucceeds() {
        MockEnvironment env = new MockEnvironment();
        // default environment (no active profiles)
        assertDoesNotThrow(() -> new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, env));
    }

    @Test
    void whenProdProfileWithDefaultSecret_thenThrowsIllegalStateException() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, env));

        assertTrue(ex.getMessage().contains("FATAL SECURITY CONFIGURATION ERROR"));
        assertTrue(ex.getMessage().contains("production"));
    }

    @Test
    void whenProdProfileWithBlankSecret_thenThrowsIllegalStateException() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("production");

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> new JwtTokenProvider("   ", 86400000L, env));

        assertTrue(ex.getMessage().contains("FATAL SECURITY CONFIGURATION ERROR"));
    }

    @Test
    void whenProdProfileWithCustomSecureSecret_thenInitializationSucceeds() {
        MockEnvironment env = new MockEnvironment();
        env.setActiveProfiles("prod");

        String strongSecret = "A_Very_Strong_And_Secure_Random_Production_Key_1234567890!@#";
        assertDoesNotThrow(() -> new JwtTokenProvider(strongSecret, 86400000L, env));
    }

    @Test
    void whenSecretIsShorterThan32Bytes_thenThrowsIllegalStateException() {
        MockEnvironment env = new MockEnvironment();
        String shortSecret = "too-short-key";

        IllegalStateException ex = assertThrows(IllegalStateException.class,
                () -> new JwtTokenProvider(shortSecret, 86400000L, env));

        assertTrue(ex.getMessage().contains("at least 256 bits (32 bytes)"));
    }

    @Test
    void whenTokenHasValidPositiveVersion_thenReturnsVersionAndValidatesTrue() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String token = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", 2)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertTrue(provider.validateToken(token));
        assertEquals(2, provider.getTokenVersionFromToken(token));
    }

    @Test
    void whenTokenLacksTokenVersionClaim_thenReturnsNullAndValidatesTrue() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String legacyToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertTrue(provider.validateToken(legacyToken));
        assertNull(provider.getTokenVersionFromToken(legacyToken));
    }

    @Test
    void whenTokenHasMalformedTokenVersionClaim_thenThrowsJwtExceptionAndValidateReturnsFalse() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        String token = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", "not_a_number")
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(token));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(token));
    }

    @Test
    void whenTokenHasNegativeOrZeroTokenVersionClaim_thenThrowsJwtExceptionAndValidateReturnsFalse() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));

        String negativeToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", -1)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(negativeToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(negativeToken));

        String zeroToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", 0)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(zeroToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(zeroToken));
    }

    @Test
    void whenTokenHasFractionalTokenVersionClaim_thenThrowsJwtExceptionAndValidateReturnsFalse() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));

        String fractionalToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", 1.5)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(fractionalToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(fractionalToken));
    }

    @Test
    void whenTokenHasNumericStringTokenVersionClaim_thenThrowsJwtExceptionAndValidateReturnsFalse() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));

        // Even parseable numeric strings must be strictly rejected
        String numericStringToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", "1")
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(numericStringToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(numericStringToken));
    }

    @Test
    void whenTokenHasIntegerMaxValue_thenReturnsMaxValueAndValidatesTrue() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));

        String maxIntToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", Integer.MAX_VALUE)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertTrue(provider.validateToken(maxIntToken));
        assertEquals(Integer.MAX_VALUE, provider.getTokenVersionFromToken(maxIntToken));
    }

    @Test
    void whenTokenHasIntegerMaxValuePlusOneOrVeryLargeNumber_thenThrowsJwtExceptionAndValidateReturnsFalse() {
        JwtTokenProvider provider = new JwtTokenProvider(JwtTokenProvider.DEFAULT_DEV_SECRET, 86400000L, new MockEnvironment());
        javax.crypto.SecretKey key = io.jsonwebtoken.security.Keys.hmacShaKeyFor(JwtTokenProvider.DEFAULT_DEV_SECRET.getBytes(java.nio.charset.StandardCharsets.UTF_8));

        // Integer.MAX_VALUE + 1
        long maxPlusOne = (long) Integer.MAX_VALUE + 1L;
        String maxPlusOneToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", maxPlusOne)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(maxPlusOneToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(maxPlusOneToken));

        // Very large numeric value: Long.MAX_VALUE
        String veryLargeToken = io.jsonwebtoken.Jwts.builder()
                .subject("testuser")
                .claim("tokenVersion", Long.MAX_VALUE)
                .issuedAt(new java.util.Date())
                .expiration(new java.util.Date(System.currentTimeMillis() + 86400000))
                .signWith(key)
                .compact();

        assertFalse(provider.validateToken(veryLargeToken));
        assertThrows(io.jsonwebtoken.JwtException.class, () -> provider.getTokenVersionFromToken(veryLargeToken));
    }
}

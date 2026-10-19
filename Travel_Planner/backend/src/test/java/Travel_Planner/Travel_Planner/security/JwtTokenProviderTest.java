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
}

package Travel_Planner.Travel_Planner.security;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.junit.jupiter.api.Assertions.*;

class ClientIpResolverTest {

    private ClientIpResolver resolver;

    @BeforeEach
    void setUp() {
        // Configure trusted proxies: loopback and internal proxies 10.0.0.1 and 10.0.0.2
        resolver = new ClientIpResolver("127.0.0.1, 0:0:0:0:0:0:0:1, ::1, 10.0.0.1, 10.0.0.2");
    }

    @Test
    void resolveClientIp_whenDirectUntrustedClientSendsForwardedFor_shouldIgnoreHeaderAndReturnDirectIp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("203.0.113.50"); // Direct untrusted client socket IP
        request.addHeader("X-Forwarded-For", "198.51.100.99"); // Spoofed header
        request.addHeader("X-Real-IP", "198.51.100.99");

        String resolvedIp = resolver.resolveClientIp(request);

        // Security requirement: Must return direct remote socket IP, rejecting client-supplied spoofed headers
        assertEquals("203.0.113.50", resolvedIp);
    }

    @Test
    void resolveClientIp_whenClientSpoofsHeaderThroughTrustedProxy_shouldTraverseRightToLeftAndReturnRealClientIp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1"); // Trusted proxy socket
        // Attacker sent "X-Forwarded-For: 1.1.1.1", and proxy appended attacker's real IP "203.0.113.195"
        request.addHeader("X-Forwarded-For", "1.1.1.1, 203.0.113.195");

        String resolvedIp = resolver.resolveClientIp(request);

        // Right-to-left traversal picks the first untrusted IP from the right, defeating 1.1.1.1 spoofing
        assertEquals("203.0.113.195", resolvedIp);
    }

    @Test
    void resolveClientIp_whenMultipleConsecutiveTrustedProxiesInChain_shouldSkipAllTrustedProxies() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1"); // Trusted edge proxy
        // Chain: Client (203.0.113.195) -> Internal Proxy (10.0.0.2) -> Ingress (10.0.0.1) -> Spring Boot
        // Also contains spoofed header from client (8.8.8.8)
        request.addHeader("X-Forwarded-For", "8.8.8.8, 203.0.113.195, 10.0.0.2");

        String resolvedIp = resolver.resolveClientIp(request);

        // Should skip 10.0.0.2 (trusted proxy) and pick 203.0.113.195 (first untrusted IP from right)
        assertEquals("203.0.113.195", resolvedIp);
    }

    @Test
    void resolveClientIp_whenUntrustedProxyInChain_shouldStopAtUntrustedIntermediary() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1"); // Trusted proxy
        // Client passed through an untrusted intermediary proxy 198.51.100.4 before reaching our trusted proxy
        request.addHeader("X-Forwarded-For", "1.1.1.1, 198.51.100.4");

        String resolvedIp = resolver.resolveClientIp(request);

        // 198.51.100.4 is NOT in trustedProxies, so we cannot trust anything to its left (1.1.1.1).
        // It must return 198.51.100.4
        assertEquals("198.51.100.4", resolvedIp);
    }

    @Test
    void resolveClientIp_whenChainContainsMalformedOrInvalidIps_shouldSkipInvalidCandidates() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1");
        request.addHeader("X-Forwarded-For", "spoofed-ip, 999.999.999.999, , 203.0.113.88");

        String resolvedIp = resolver.resolveClientIp(request);

        assertEquals("203.0.113.88", resolvedIp);
    }

    @Test
    void resolveClientIp_whenTrustedProxySendsXRealIp_shouldReturnRealIp() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.1");
        request.addHeader("X-Real-IP", "203.0.113.196");

        String resolvedIp = resolver.resolveClientIp(request);

        assertEquals("203.0.113.196", resolvedIp);
    }

    @Test
    void resolveClientIp_whenIPv6WithBracketsAndPort_shouldStripBracketsAndPort() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("[2001:db8:cafe::17]:8080");

        String resolvedIp = resolver.resolveClientIp(request);

        assertEquals("2001:db8:cafe::17", resolvedIp);
    }

    @Test
    void resolveClientIp_whenIPv4WithPort_shouldStripPort() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("198.51.100.14:54321");

        String resolvedIp = resolver.resolveClientIp(request);

        assertEquals("198.51.100.14", resolvedIp);
    }

    @Test
    void resolveClientIp_whenQuotedIpHeader_shouldStripQuotes() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("127.0.0.1"); // Trusted proxy
        request.addHeader("X-Forwarded-For", "\"203.0.113.77\"");

        String resolvedIp = resolver.resolveClientIp(request);

        assertEquals("203.0.113.77", resolvedIp);
    }

    @Test
    void resolveClientIp_whenRequestIsNull_shouldReturnUnknown() {
        assertEquals("unknown", resolver.resolveClientIp(null));
    }

    @Test
    void resolveClientIp_whenRemoteAddrIsEmpty_shouldReturnUnknown() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("");

        assertEquals("unknown", resolver.resolveClientIp(request));
    }
}

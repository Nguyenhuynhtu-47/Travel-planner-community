package Travel_Planner.Travel_Planner.security;

public interface GoogleTokenVerifier {
    /**
     * Verifies the authenticity and validity of the Google ID Token.
     * Checks cryptographic signature, expiration, issuer, audience, and essential claims.
     *
     * @param idTokenString raw JWT ID token sent from the client
     * @return verified Google user information
     * @throws Travel_Planner.Travel_Planner.exception.BadRequestException if token is invalid or unverified
     */
    GoogleUserInfo verify(String idTokenString);
}

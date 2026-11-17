package Travel_Planner.Travel_Planner.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.lang.NonNull;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenProvider tokenProvider;
    private final UserDetailsServiceImpl userDetailsService;

    public JwtAuthenticationFilter(JwtTokenProvider tokenProvider, UserDetailsServiceImpl userDetailsService) {
        this.tokenProvider = tokenProvider;
        this.userDetailsService = userDetailsService;
    }

    @Override
    protected void doFilterInternal(
            @NonNull HttpServletRequest request,
            @NonNull HttpServletResponse response,
            @NonNull FilterChain filterChain) throws ServletException, IOException {

        String jwt = getJwtFromRequest(request);

        if (StringUtils.hasText(jwt) && tokenProvider.validateToken(jwt)) {
            try {
                String username = tokenProvider.getUsernameFromToken(jwt);
                Integer tokenVersionFromJwt = tokenProvider.getTokenVersionFromToken(jwt);

                UserDetails userDetails = userDetailsService.loadUserByUsername(username);
                if (userDetails.isEnabled() && userDetails.isAccountNonLocked()) {
                    // Global JWT Revocation Check via strict token_version comparison
                    if (userDetails instanceof CustomUserDetails customUser) {
                        int currentDbVersion = customUser.getTokenVersion() != null ? customUser.getTokenVersion() : 1;

                        // 1. Missing tokenVersion claim: compatible ONLY when current database version is exactly 1
                        if (tokenVersionFromJwt == null) {
                            if (currentDbVersion != 1) {
                                SecurityContextHolder.clearContext();
                                filterChain.doFilter(request, response);
                                return;
                            }
                        } else {
                            // 2. Present claim: must strictly equal current database version (rejects stale and future versions)
                            if (tokenVersionFromJwt != currentDbVersion) {
                                SecurityContextHolder.clearContext();
                                filterChain.doFilter(request, response);
                                return;
                            }
                        }
                    }

                    UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                            userDetails, null, userDetails.getAuthorities());
                    authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));

                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            } catch (Exception e) {
                SecurityContextHolder.clearContext();
            }
        }

        filterChain.doFilter(request, response);
    }

    private String getJwtFromRequest(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}

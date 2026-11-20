package com.vms.backend.auth;

import com.vms.backend.user.AppUser;
import com.vms.backend.user.UserRepository;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AuthService {
    private final UserRepository users;
    private final PasswordEncoder passwords;
    private final JwtEncoder jwtEncoder;
    private final String issuer;
    private final long ttlMinutes;

    public AuthService(UserRepository users, PasswordEncoder passwords, JwtEncoder jwtEncoder,
                       @Value("${vms.jwt.issuer}") String issuer,
                       @Value("${vms.jwt.ttl-minutes}") long ttlMinutes) {
        this.users = users;
        this.passwords = passwords;
        this.jwtEncoder = jwtEncoder;
        this.issuer = issuer;
        this.ttlMinutes = ttlMinutes;
    }

    @Transactional
    public AuthResponse register(RegisterRequest request) {
        var email = normalizeEmail(request.email());
        if (users.existsByEmail(email)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email is already registered");
        }
        var user = users.saveAndFlush(new AppUser(
            request.fullName().trim(), email, passwords.encode(request.password())));
        return issueToken(user);
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest request) {
        var email = normalizeEmail(request.email());
        var user = users.findByEmail(email).orElse(null);
        if (user == null || !passwords.matches(request.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid email or password");
        }
        return issueToken(user);
    }

    private static String normalizeEmail(String raw) {
        return raw.trim().toLowerCase(Locale.ROOT);
    }

    private AuthResponse issueToken(AppUser user) {
        Instant now = Instant.now();
        Instant expiry = now.plus(ttlMinutes, ChronoUnit.MINUTES);
        var claims = JwtClaimsSet.builder()
            .issuer(issuer)
            .subject(user.getId().toString())
            .issuedAt(now)
            .expiresAt(expiry)
            .claim("name", user.getFullName())
            .build();
        var header = JwsHeader.with(MacAlgorithm.HS256).build();
        String token = jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
        return new AuthResponse(token, "Bearer", ttlMinutes * 60, user.getFullName(), user.getEmail());
    }
}

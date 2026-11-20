package com.vms.backend.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

record RegisterRequest(
    @NotBlank @Size(max = 80) String fullName,
    @NotBlank @Email @Size(max = 254) String email,
    @NotBlank @Size(min = 8, max = 72) String password) {}

record LoginRequest(
    @NotBlank @Email String email,
    @NotBlank String password) {}

record AuthResponse(String accessToken, String tokenType, long expiresInSeconds,
                    String fullName, String email) {}

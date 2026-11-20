package com.vms.backend.vehicle;

import java.util.Locale;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

public final class PlateNormalizer {
    private PlateNormalizer() {}
    public static String normalize(String input) {
        if (input == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Number plate is required");
        }
        String compact = input.trim().toUpperCase(Locale.ROOT)
            .replaceAll("\\s*-\\s*", "-")
            .replaceAll("\\s+", " ");
        if (!compact.matches("DHAKA METRO-[A-Z]{1,5}-[0-9]{2}-[0-9]{4}")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Plate format: DHAKA METRO - GHA - 12 - 3456");
        }
        return compact.replace("-", " - ");
    }
}

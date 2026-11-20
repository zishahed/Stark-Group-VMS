package com.vms.backend.vehicle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class PlateNormalizerTest {
    @Test
    void normalizesCaseAndSpacing() {
        assertEquals("DHAKA METRO - GHA - 12 - 3456",
            PlateNormalizer.normalize("  dhaka metro-gha-12-3456  "));
    }

    @Test
    void rejectsInvalidPlate() {
        assertThrows(ResponseStatusException.class,
            () -> PlateNormalizer.normalize("DHAKA METRO - GHA - 12 - 345"));
    }
}

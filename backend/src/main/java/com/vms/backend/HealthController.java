
package com.vms.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/health")
    public Map<String, Object> health() {
        return Map.of(
            "success", true,
            "message", "Stark Group VMS backend is running",
            "timestamp", Instant.now().toString()
        );
    }
}

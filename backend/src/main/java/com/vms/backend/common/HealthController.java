package com.vms.backend.common;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/api/v1/health")
    public Map<String, Object> health() {
        return Map.of(
            "success", true,
            "message", "Stark Group VMS backend is running",
            "timestamp", Instant.now().toString()
        );
    }
}

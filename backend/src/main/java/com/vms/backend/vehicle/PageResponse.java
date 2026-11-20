package com.vms.backend.vehicle;

import java.util.List;
import org.springframework.data.domain.Page;

public record PageResponse<T>(List<T> items, long total, int page, int size, int totalPages) {
    public static <T> PageResponse<T> from(Page<T> p) {
        return new PageResponse<>(p.getContent(), p.getTotalElements(), p.getNumber(),
            p.getSize(), p.getTotalPages());
    }
}

package com.vms.backend.vehicle;

/** Non-deleted fleet counts for the authenticated vehicle owner. */
public record FleetSummaryResponse(
    long total,
    long active,
    long available,
    long assigned,
    long maintenance,
    long inactive
) {}

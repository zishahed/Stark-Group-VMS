package com.vms.backend.vehicle;

import java.time.Instant;
import java.util.UUID;

public record VehicleResponse(
    UUID id, String vehicleName, String manufacturer, String model,
    String color, int seatCapacity, String numberPlate, int engineCc,
    VehicleType vehicleType, FuelType fuelType, VehicleStatus status,
    String assignedDepot, int manufactureYear, String notes,
    Instant createdAt, Instant updatedAt
) {
    public static VehicleResponse from(Vehicle v) {
        return new VehicleResponse(v.getId(), v.getVehicleName(), v.getManufacturer(),
            v.getModel(), v.getColor(), v.getSeatCapacity(), v.getNumberPlate(),
            v.getEngineCc(), v.getVehicleType(), v.getFuelType(), v.getStatus(),
            v.getAssignedDepot(), v.getManufactureYear(), v.getNotes(),
            v.getCreatedAt(), v.getUpdatedAt());
    }
}


package com.vms.backend.vehicle;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record VehicleRequest(
    @NotBlank
    @Size(max = 50)
    String vehicleName,

    @NotBlank
    @Size(max = 50)
    String manufacturer,

    @NotBlank
    @Size(max = 50)
    String model,

    @NotBlank
    @Size(max = 30)
    String color,

    @NotNull
    @Min(1)
    @Max(80)
    Integer seatCapacity,

    @NotBlank
    String numberPlate,

    @NotNull
    @Min(0)
    @Max(20000)
    Integer engineCc,

    @NotNull
    VehicleType vehicleType,

    @NotNull
    FuelType fuelType,

    @NotNull
    VehicleStatus status,

    @NotBlank
    @Size(max = 100)
    String assignedDepot,

    @NotNull
    @Min(1950)
    @Max(2100)
    Integer manufactureYear,

    @NotBlank
    @Pattern(
        regexp = "PRIVATE|COMMERCIAL",
        message = "Registration usage must be PRIVATE or COMMERCIAL"
    )
    String registrationUsage,

    @Size(max = 500)
    String notes
) {}

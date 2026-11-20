package com.vms.backend.vehicle;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vehicles")
public class Vehicle {
    @Id @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;
    @Column(name = "owner_id", nullable = false)
    private UUID ownerId;
    @Column(name = "vehicle_name", nullable = false, length = 50)
    private String vehicleName;
    @Column(nullable = false, length = 50)
    private String manufacturer;
    @Column(nullable = false, length = 50)
    private String model;
    @Column(nullable = false, length = 30)
    private String color;
    @Column(name = "seat_capacity", nullable = false)
    private int seatCapacity;
    @Column(name = "number_plate", nullable = false, length = 50)
    private String numberPlate;
    @Column(name = "engine_cc", nullable = false)
    private int engineCc;
    @Enumerated(EnumType.STRING)
    @Column(name = "vehicle_type", nullable = false, length = 30)
    private VehicleType vehicleType;
    @Enumerated(EnumType.STRING)
    @Column(name = "fuel_type", nullable = false, length = 30)
    private FuelType fuelType;
    @Enumerated(EnumType.STRING)
    @Column(name = "vehicle_status", nullable = false, length = 30)
    private VehicleStatus status;
    @Column(name = "assigned_depot", nullable = false, length = 100)
    private String assignedDepot;
    @Column(name = "manufacture_year", nullable = false)
    private int manufactureYear;
    @Column(length = 500)
    private String notes;
    @Column(name = "is_deleted", nullable = false)
    private boolean deleted;
    @Column(name = "created_at", nullable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected Vehicle() {}
    public Vehicle(UUID ownerId) { this.ownerId = ownerId; }

    public void apply(VehicleRequest data, String plate) {
        this.vehicleName = data.vehicleName().trim();
        this.manufacturer = data.manufacturer().trim();
        this.model = data.model().trim();
        this.color = data.color().trim();
        this.seatCapacity = data.seatCapacity();
        this.numberPlate = plate;
        this.engineCc = data.engineCc();
        this.vehicleType = data.vehicleType();
        this.fuelType = data.fuelType();
        this.status = data.status();
        this.assignedDepot = data.assignedDepot().trim();
        this.manufactureYear = data.manufactureYear();
        this.notes = data.notes() == null ? null : data.notes().trim();
    }

    public void softDelete() { this.deleted = true; }
    @PrePersist void beforeInsert() { createdAt = Instant.now(); updatedAt = createdAt; }
    @PreUpdate void beforeUpdate() { updatedAt = Instant.now(); }

    public UUID getId() { return id; }
    public UUID getOwnerId() { return ownerId; }
    public String getVehicleName() { return vehicleName; }
    public String getManufacturer() { return manufacturer; }
    public String getModel() { return model; }
    public String getColor() { return color; }
    public int getSeatCapacity() { return seatCapacity; }
    public String getNumberPlate() { return numberPlate; }
    public int getEngineCc() { return engineCc; }
    public VehicleType getVehicleType() { return vehicleType; }
    public FuelType getFuelType() { return fuelType; }
    public VehicleStatus getStatus() { return status; }
    public String getAssignedDepot() { return assignedDepot; }
    public int getManufactureYear() { return manufactureYear; }
    public String getNotes() { return notes; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
}

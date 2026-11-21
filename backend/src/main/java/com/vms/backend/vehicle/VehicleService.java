package com.vms.backend.vehicle;

import java.time.Year;
import java.util.UUID;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;


@Service
public class VehicleService {
    private final VehicleRepository vehicles;
    public VehicleService(VehicleRepository vehicles) { this.vehicles = vehicles; }

    @Transactional(readOnly = true)
    public PageResponse<VehicleResponse> list(Jwt jwt, int page, int size, String search) {
        if (page < 0 || size < 1) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Invalid pagination parameters");
        }
        String q = search == null ? "" : search.trim();
        if (q.length() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Search is too long");
        }
        var pageable = PageRequest.of(page, Math.min(size, 50), Sort.by("createdAt").descending());
        return PageResponse.from(vehicles.search(owner(jwt), q, pageable).map(VehicleResponse::from));
    }

    @Transactional(readOnly = true)
    public FleetSummaryResponse summary(Jwt jwt) {
        UUID ownerId = owner(jwt);
        long total = vehicles.countByOwnerIdAndDeletedFalse(ownerId);
        long active = vehicles.countByOwnerIdAndDeletedFalseAndStatus(ownerId, VehicleStatus.ACTIVE);
        long maintenance = vehicles.countByOwnerIdAndDeletedFalseAndStatus(ownerId, VehicleStatus.MAINTENANCE);
        long inactive = vehicles.countByOwnerIdAndDeletedFalseAndStatus(ownerId, VehicleStatus.INACTIVE);
        return new FleetSummaryResponse(total, active, active, 0, maintenance, inactive);
    }

    @Transactional(readOnly = true)
    public VehicleResponse get(Jwt jwt, UUID id) {
        return VehicleResponse.from(owned(jwt, id));
    }

    @Transactional
    public VehicleResponse add(Jwt jwt, VehicleRequest data) {
        checkYear(data.manufactureYear());
        // Automatically classify and format the number plate.
        String plate = generatePlate(data);
        // Prevent duplicate active number plates.
        if (vehicles.existsByNumberPlateAndDeletedFalse(plate)) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT,
                "Vehicle number plate already exists"
            );
        }
        var vehicle = new Vehicle(owner(jwt));
        vehicle.apply(data, plate);
        return VehicleResponse.from(
            vehicles.saveAndFlush(vehicle)
        );
    }

    @Transactional
    public VehicleResponse update(
            Jwt jwt,
            UUID id,
            VehicleRequest data) {
        var vehicle = owned(jwt, id);
        checkYear(data.manufactureYear());
        // Automatically classify and format the number plate.
        String plate = generatePlate(data);
        // Exclude the current vehicle when checking duplicates.
        if (vehicles.existsByNumberPlateAndDeletedFalseAndIdNot(
                plate, id)) {
            throw new ResponseStatusException(
                HttpStatus.CONFLICT,
                "Vehicle number plate already exists"
            );
        }
        vehicle.apply(data, plate);
        return VehicleResponse.from(
            vehicles.saveAndFlush(vehicle)
        );
    }

    @Transactional
    public void delete(Jwt jwt, UUID id) {
        var vehicle = owned(jwt, id);
        vehicle.softDelete();
        vehicles.saveAndFlush(vehicle);
    }
    private Vehicle owned(Jwt jwt, UUID id) {
        return vehicles.findByIdAndOwnerIdAndDeletedFalse(id, owner(jwt))
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Vehicle not found"));
    }
    private static void checkYear(int year) {
        if (year > Year.now().getValue()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                "Manufacture year cannot be in the future");
        }
    }

    private static String generatePlate(VehicleRequest data) {
    try {
        String plateClass = VehiclePlateClassifier.classify(
            data.vehicleType().name(),
            data.engineCc(),
            data.registrationUsage()
        );
        return NumberPlateFormatter.format(
            plateClass,
            data.numberPlate()
        );
    } catch (IllegalArgumentException ex) {
        throw new ResponseStatusException(
            HttpStatus.BAD_REQUEST,
            ex.getMessage()
            );
        }
    }   
    private UUID owner(Jwt jwt) { return UUID.fromString(jwt.getSubject()); }
}

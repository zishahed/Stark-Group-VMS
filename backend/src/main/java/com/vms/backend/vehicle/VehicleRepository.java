package com.vms.backend.vehicle;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface VehicleRepository extends JpaRepository<Vehicle, UUID> {
    boolean existsByNumberPlateAndDeletedFalse(String plate);
    boolean existsByNumberPlateAndDeletedFalseAndIdNot(String plate, UUID id);
    Optional<Vehicle> findByIdAndOwnerIdAndDeletedFalse(UUID id, UUID ownerId);
    long countByOwnerIdAndDeletedFalse(UUID ownerId);

    @Query("""
        SELECT v FROM Vehicle v
        WHERE v.ownerId = :ownerId AND v.deleted = false
          AND (:q = '' OR lower(v.vehicleName) LIKE lower(concat('%', :q, '%'))
               OR lower(v.numberPlate) LIKE lower(concat('%', :q, '%'))
               OR lower(v.assignedDepot) LIKE lower(concat('%', :q, '%')))
        """)
    Page<Vehicle> search(@Param("ownerId") UUID ownerId, @Param("q") String q, Pageable pageable);
}

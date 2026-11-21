
package com.vms.backend.vehicle;

import com.vms.backend.user.AppUser;
import com.vms.backend.user.UserRepository;

import java.util.Locale;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;

@Configuration
@Profile("dev")
public class VehicleDevSeeder {

    @Bean
    CommandLineRunner seedDemoData(
            UserRepository users,
            VehicleRepository vehicles,
            PasswordEncoder encoder,
            @Value("${VMS_DEMO_EMAIL:}") String email,
            @Value("${VMS_DEMO_PASSWORD:}") String password
    ) {
        return args -> {

            if (email.isBlank() || password.isBlank()) {
                return;
            }

            if (password.length() < 8) {
                throw new IllegalStateException(
                    "Demo password too short"
                );
            }

            String normalized = email.trim()
                .toLowerCase(Locale.ROOT);

            var user = users.findByEmail(normalized)
                .orElseGet(() -> users.saveAndFlush(
                    new AppUser(
                        "Demo Fleet Manager",
                        normalized,
                        encoder.encode(password)
                    )
                ));

            if (vehicles.countByOwnerIdAndDeletedFalse(
                    user.getId()) != 0) {
                return;
            }

            var samples = new VehicleRequest[] {

                new VehicleRequest(
                    "Executive Jeep 01",
                    "Toyota",
                    "Land Cruiser",
                    "White",
                    7,
                    "123456",
                    2800,
                    VehicleType.SUV,
                    FuelType.DIESEL,
                    VehicleStatus.ACTIVE,
                    "Dhaka Central Depot",
                    2023,
                    "PRIVATE",
                    "Demo vehicle"
                ),

                new VehicleRequest(
                    "Office Sedan 02",
                    "Toyota",
                    "Axio",
                    "Silver",
                    5,
                    "184921",
                    1500,
                    VehicleType.SEDAN,
                    FuelType.PETROL,
                    VehicleStatus.ACTIVE,
                    "Mirpur Depot",
                    2021,
                    "PRIVATE",
                    "Demo vehicle"
                ),

                new VehicleRequest(
                    "Staff Microbus",
                    "Toyota",
                    "Hiace",
                    "White",
                    12,
                    "152450",
                    2700,
                    VehicleType.MICROBUS,
                    FuelType.DIESEL,
                    VehicleStatus.MAINTENANCE,
                    "Dhaka Central Depot",
                    2020,
                    "PRIVATE",
                    "Demo vehicle"
                ),

                new VehicleRequest(
                    "Logistics Van",
                    "Nissan",
                    "NV200",
                    "Grey",
                    2,
                    "115923",
                    1600,
                    VehicleType.VAN,
                    FuelType.PETROL,
                    VehicleStatus.ACTIVE,
                    "Uttara Depot",
                    2022,
                    "PRIVATE",
                    "Demo vehicle"
                ),

                new VehicleRequest(
                    "Field Operations SUV",
                    "Mitsubishi",
                    "Pajero",
                    "Black",
                    7,
                    "228912",
                    2500,
                    VehicleType.SUV,
                    FuelType.DIESEL,
                    VehicleStatus.ACTIVE,
                    "Mirpur Depot",
                    2024,
                    "PRIVATE",
                    "Demo vehicle"
                ),

                new VehicleRequest(
                    "Office Car 06",
                    "Honda",
                    "Civic",
                    "Blue",
                    5,
                    "241875",
                    1800,
                    VehicleType.SEDAN,
                    FuelType.HYBRID,
                    VehicleStatus.ACTIVE,
                    "Uttara Depot",
                    2023,
                    "PRIVATE",
                    "Demo vehicle"
                )
            };

            for (VehicleRequest sample : samples) {

                String plateClass;

                try {
                    plateClass = VehiclePlateClassifier.classify(
                        sample.vehicleType().name(),
                        sample.engineCc(),
                        sample.registrationUsage()
                    );
                } catch (IllegalArgumentException ex) {
                    System.err.println(
                        "Skipping demo vehicle: " +
                        sample.vehicleName() +
                        " - " + ex.getMessage()
                    );
                    continue;
                }

                String plate = NumberPlateFormatter.format(
                    plateClass,
                    sample.numberPlate()
                );

                if (vehicles.existsByNumberPlateAndDeletedFalse(
                        plate)) {
                    continue;
                }

                Vehicle vehicle = new Vehicle(user.getId());

                vehicle.apply(sample, plate);

                vehicles.save(vehicle);
            }

            vehicles.flush();
        };
    }
}

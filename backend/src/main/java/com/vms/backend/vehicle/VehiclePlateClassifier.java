
package com.vms.backend.vehicle;

import java.util.Locale;

public final class VehiclePlateClassifier {

    private VehiclePlateClassifier() {}
    public static String classify(
            String vehicleType,
            Integer engineCc,
            String usage) {
        String type = normalize(vehicleType);
        String use = normalize(usage);
        return switch (type) {
            case "CAR", "PRIVATE_CAR", "SEDAN", "HATCHBACK", "SALOON" -> classifyCar(engineCc);
            case "JEEP", "HARD_JEEP", "SOFT_JEEP", "SUV", "CROSSOVER" -> "GHA";
            case "MOTORCYCLE", "MOTORBIKE", "BIKE", "SCOOTER" -> classifyMotorcycle(engineCc);
            case "MICROBUS" -> switch (use) {
                case "PRIVATE", "PRIVATE_SERVICE" -> "CHA";
                case "HIRE", "COMMERCIAL" -> "CAA";
                default -> throw invalidUsage();
            };
            case "MINIBUS" -> switch (use) {
                case "PRIVATE", "PRIVATE_SERVICE" -> "JHA";
                case "HIRE", "COMMERCIAL" -> "JA";
                default -> throw invalidUsage();
            };
            case "BUS", "OMNIBUS" -> switch (use) {
                case "PRIVATE", "PRIVATE_SERVICE" -> "SA";
                case "HIRE", "COMMERCIAL" -> "BA";
                default -> throw invalidUsage();
            };
            case "AUTO_RICKSHAW", "CNG" -> switch (use) {
                case "PRIVATE" -> "DAW";
                case "HIRE", "COMMERCIAL" -> "TAW";
                default -> throw invalidUsage();
            };
            case "TAXI", "TAXICAB" -> "PA";
            case "AMBULANCE" -> "CAA";
            case "AGRICULTURAL_TRACTOR" -> "E";
            case "DELIVERY_VAN" -> "MA";
            case "DOUBLE_CAB_PICKUP", "DUAL_PURPOSE_PICKUP" -> "THA";
            case "SPECIAL_PURPOSE" -> "SHA";
            default -> throw new IllegalArgumentException(
                "Automatic plate classification is not available "
                + "for this vehicle type. Check its BRTA certificate."
            );
        };
    }

    private static String classifyCar(Integer cc) {
        requireCc(cc);
        if (cc <= 1000) return "KA";
        if (cc <= 1300) return "KHA";
        if (cc <= 2000) return "GA";
        return "BHA";
    }
    private static String classifyMotorcycle(Integer cc) {
        requireCc(cc);
        if (cc <= 50) return "A";
        if (cc <= 125) return "HA";
        return "LA";
    }
    private static void requireCc(Integer cc) {
        if (cc == null || cc <= 0) {
            throw new IllegalArgumentException(
                "Valid engine capacity (CC) is required."
            );
        }
    }
    private static IllegalArgumentException invalidUsage() {
        return new IllegalArgumentException(
            "Select PRIVATE or COMMERCIAL vehicle usage."
        );
    }
    private static String normalize(String value) {
        if (value == null) return "";
        return value.trim()
            .toUpperCase(Locale.ROOT)
            .replaceAll("[\\s-]+", "_");
    }
}

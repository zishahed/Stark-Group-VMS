
package com.vms.backend.vehicle;

import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public final class NumberPlateFormatter {

    private static final Pattern FULL_PLATE =
        Pattern.compile("^DHAKAMETRO([A-Z]+)([0-9]{6})$");
    private NumberPlateFormatter() {}
    public static String format(
            String calculatedClass,
            String enteredPlate) {
        if (enteredPlate == null) {
            throw new IllegalArgumentException(
                "Registration number is required."
            );
        }
        String compact = enteredPlate
            .toUpperCase(Locale.ROOT)
            .replaceAll("[\\s-]+", "");
        String digits;
        if (compact.matches("[0-9]{6}")) {
            digits = compact;
        } else {
            Matcher matcher = FULL_PLATE.matcher(compact);
            if (!matcher.matches()) {
                throw new IllegalArgumentException(
                    "Invalid plate. Use six digits or a "
                    + "DHAKA METRO plate."
                );
            }
            String enteredClass = matcher.group(1);
            if (!enteredClass.equals(calculatedClass)) {
                throw new IllegalArgumentException(
                    "Plate category differs from the "
                    + "suggested class. Verify the "
                    + "BRTA registration certificate."
                );
            }
            digits = matcher.group(2);
        }
        String series = digits.substring(0, 2);
        String registration = digits.substring(2);
        return "DHAKA METRO-"
            + calculatedClass
            + "-" + series
            + "-" + registration;
    }
}

class PlateRules {
  static String _normalize(String? value) {
    return (value ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
  }

  static String? suggestedClass({
    required String vehicleType,
    int? engineCc,
    String usage = 'PRIVATE',
  }) {
    final type = _normalize(vehicleType);
    final use = _normalize(usage);

    switch (type) {
      case 'CAR':
      case 'PRIVATE_CAR':
      case 'SEDAN':
      case 'HATCHBACK':
      case 'SALOON':
        if (engineCc == null || engineCc <= 0) return null;
        if (engineCc <= 1000) return 'KA';
        if (engineCc <= 1300) return 'KHA';
        if (engineCc <= 2000) return 'GA';
        return 'BHA';
      case 'SUV':
      case 'JEEP':
      case 'HARD_JEEP':
      case 'SOFT_JEEP':
      case 'CROSSOVER':
        return 'GHA';
      case 'MOTORCYCLE':
      case 'MOTORBIKE':
      case 'BIKE':
      case 'SCOOTER':
        if (engineCc == null || engineCc <= 0) return null;
        if (engineCc <= 50) return 'A';
        if (engineCc <= 125) return 'HA';
        return 'LA';
      case 'MICROBUS':
        if (use == 'PRIVATE' || use == 'PRIVATE_SERVICE') return 'CHA';
        if (use == 'COMMERCIAL' || use == 'HIRE') return 'CAA';
        return null;
      case 'MINIBUS':
        if (use == 'PRIVATE' || use == 'PRIVATE_SERVICE') return 'JHA';
        if (use == 'COMMERCIAL' || use == 'HIRE') return 'JA';
        return null;
      case 'BUS':
      case 'OMNIBUS':
        if (use == 'PRIVATE' || use == 'PRIVATE_SERVICE') return 'SA';
        if (use == 'COMMERCIAL' || use == 'HIRE') return 'BA';
        return null;
      case 'AUTO_RICKSHAW':
      case 'CNG':
        if (use == 'PRIVATE') return 'DAW';
        if (use == 'COMMERCIAL' || use == 'HIRE') return 'TAW';
        return null;
      case 'TAXI':
      case 'TAXICAB':
        return 'PA';
      case 'AMBULANCE':
        return 'CAA';
      case 'AGRICULTURAL_TRACTOR':
        return 'E';
      case 'DELIVERY_VAN':
        return 'MA';
      case 'DOUBLE_CAB_PICKUP':
      case 'DUAL_PURPOSE_PICKUP':
        return 'THA';
      case 'SPECIAL_PURPOSE':
        return 'SHA';
      default:
        return null;
    }
  }

  static String? preview({
    required String vehicleType,
    required String registrationDigits,
    int? engineCc,
    String usage = 'PRIVATE',
  }) {
    final code = suggestedClass(
      vehicleType: vehicleType,
      engineCc: engineCc,
      usage: usage,
    );
    final digits = registrationDigits.replaceAll(RegExp(r'\D'), '');
    if (code == null || digits.length != 6) return null;
    return 'DHAKA METRO-$code-${digits.substring(0, 2)}-${digits.substring(2)}';
  }

  static String digitsFromExistingPlate(String? plate) {
    final compact = (plate ?? '').replaceAll(RegExp(r'[\s-]+'), '');
    final match = RegExp(r'(\d{6})$').firstMatch(compact);
    return match?.group(1) ?? '';
  }
}

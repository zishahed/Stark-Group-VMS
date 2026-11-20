import 'dart:convert';

import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, this.status);
  @override
  String toString() => message;
}

class AuthSession {
  final String token;
  final String fullName;
  final String email;
  const AuthSession(this.token, this.fullName, this.email);
  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    json['accessToken'] as String,
    json['fullName'] as String,
    json['email'] as String,
  );
}

class Vehicle {
  final String id;
  final String vehicleName, manufacturer, model, color, numberPlate;
  final String vehicleType, fuelType, status, assignedDepot;
  final String notes;
  final int seatCapacity, engineCc, manufactureYear;
  final DateTime? createdAt, updatedAt;

  const Vehicle({
    required this.id,
    required this.vehicleName,
    required this.manufacturer,
    required this.model,
    required this.color,
    required this.numberPlate,
    required this.vehicleType,
    required this.fuelType,
    required this.status,
    required this.assignedDepot,
    required this.notes,
    required this.seatCapacity,
    required this.engineCc,
    required this.manufactureYear,
    this.createdAt,
    this.updatedAt,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
    id: json['id'] as String,
    vehicleName: json['vehicleName'] as String,
    manufacturer: json['manufacturer'] as String,
    model: json['model'] as String,
    color: json['color'] as String,
    numberPlate: json['numberPlate'] as String,
    vehicleType: json['vehicleType'] as String,
    fuelType: json['fuelType'] as String,
    status: json['status'] as String,
    assignedDepot: json['assignedDepot'] as String,
    notes: (json['notes'] as String?) ?? '',
    seatCapacity: json['seatCapacity'] as int,
    engineCc: json['engineCc'] as int,
    manufactureYear: json['manufactureYear'] as int,
    createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? ''),
    updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? ''),
  );

  Map<String, dynamic> toRequest() => {
    'vehicleName': vehicleName,
    'manufacturer': manufacturer,
    'model': model,
    'color': color,
    'numberPlate': numberPlate,
    'vehicleType': vehicleType,
    'fuelType': fuelType,
    'status': status,
    'assignedDepot': assignedDepot,
    'notes': notes,
    'seatCapacity': seatCapacity,
    'engineCc': engineCc,
    'manufactureYear': manufactureYear,
  };
}

class VehiclePage {
  final List<Vehicle> items;
  final int total, page, size, totalPages;
  const VehiclePage(
    this.items,
    this.total,
    this.page,
    this.size,
    this.totalPages,
  );
  factory VehiclePage.fromJson(Map<String, dynamic> data) => VehiclePage(
    (data['items'] as List)
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .toList(),
    data['total'] as int,
    data['page'] as int,
    data['size'] as int,
    data['totalPages'] as int,
  );
}

class FleetSummary {
  final int total, active, available, assigned, maintenance, inactive;
  const FleetSummary({
    required this.total,
    required this.active,
    required this.available,
    required this.assigned,
    required this.maintenance,
    required this.inactive,
  });

  factory FleetSummary.fromJson(Map<String, dynamic> json) => FleetSummary(
    total: json['total'] as int,
    active: json['active'] as int,
    available: json['available'] as int,
    assigned: json['assigned'] as int,
    maintenance: json['maintenance'] as int,
    inactive: json['inactive'] as int,
  );
}

class ApiClient {
  final http.Client _http = http.Client();
  String? token;

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final base = apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    http.Response response;
    try {
      final encoded = body == null ? null : jsonEncode(body);
      response = switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'POST' => await _http.post(uri, headers: headers, body: encoded),
        'PUT' => await _http.put(uri, headers: headers, body: encoded),
        'DELETE' => await _http.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported HTTP method'),
      };
    } catch (error) {
      throw ApiException(
        'Cannot reach the server. Check your connection and API URL.',
        0,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    String message = switch (response.statusCode) {
      401 => 'Your session has expired or your credentials are invalid.',
      403 => 'You do not have permission to do this.',
      409 => 'An account or active vehicle with this value already exists.',
      _ => 'Request failed (${response.statusCode}).',
    };
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic> && json['message'] is String) {
        message = json['message'] as String;
      }
    } catch (_) {}
    throw ApiException(message, response.statusCode);
  }

  Future<AuthSession> signIn(String email, String password) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    final session = AuthSession.fromJson(data as Map<String, dynamic>);
    token = session.token;
    return session;
  }

  Future<AuthSession> signUp(String name, String email, String password) async {
    final data = await _request(
      'POST',
      '/api/v1/auth/register',
      body: {'fullName': name, 'email': email, 'password': password},
      authenticated: false,
    );
    final session = AuthSession.fromJson(data as Map<String, dynamic>);
    token = session.token;
    return session;
  }

  Future<VehiclePage> listVehicles({
    int page = 0,
    String search = '',
    int size = 6,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        'size': '$size',
        if (search.isNotEmpty) 'search': search,
      },
    ).query;
    final data = await _request('GET', '/api/v1/vehicles?$query');
    return VehiclePage.fromJson(data as Map<String, dynamic>);
  }

  Future<FleetSummary> getFleetSummary() async {
    final data = await _request('GET', '/api/v1/vehicles/summary');
    return FleetSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<void> createVehicle(Map<String, dynamic> body) async {
    await _request('POST', '/api/v1/vehicles', body: body);
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> body) async {
    await _request('PUT', '/api/v1/vehicles/$id', body: body);
  }

  Future<void> deleteVehicle(String id) async {
    await _request('DELETE', '/api/v1/vehicles/$id');
  }

  void signOut() {
    token = null;
  }

  void close() {
    _http.close();
  }
}

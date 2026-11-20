import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'main.dart';

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF9D253D),
      content: Text(error.toString()),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final ApiClient api;
  final ValueChanged<AuthSession> onAuthenticated;
  const AuthScreen({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool registering = false;
  bool busy = false;
  bool reveal = false;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => busy = true);
    try {
      final session = registering
          ? await widget.api.signUp(
              name.text.trim(),
              email.text.trim(),
              password.text,
            )
          : await widget.api.signIn(email.text.trim(), password.text);
      if (mounted) widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 720;
                final formCard = Container(
                  width: wide ? 440 : double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .06),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.directions_car_filled_rounded,
                          color: forest,
                          size: 42,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          registering ? 'Create an account' : 'Welcome back',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        const Text(
                          'Manage your fleet securely and efficiently.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6E7B72)),
                        ),
                        const SizedBox(height: 27),
                        if (registering) ...[
                          TextFormField(
                            controller: name,
                            maxLength: 80,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter a valid email',
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: password,
                          obscureText: !reveal,
                          onFieldSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                reveal
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () => setState(() => reveal = !reveal),
                            ),
                          ),
                          validator: (v) =>
                              (v ?? '').length < (registering ? 8 : 1)
                              ? (registering
                                    ? 'Use at least 8 characters'
                                    : 'Enter your password')
                              : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: busy ? null : submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: busy
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  registering ? 'Create account' : 'Sign in',
                                ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () =>
                                    setState(() => registering = !registering),
                          child: Text(
                            registering
                                ? 'Already registered? Sign in'
                                : 'New to VMS? Create an account',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                final introduction = Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: forest.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Text(
                            'STARK GROUP',
                            style: TextStyle(
                              color: forest,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Every vehicle.\nOne clear view.',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 49,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'A streamlined vehicle registry with secure access, '
                          'live fleet records, and organized depot assignments.',
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xFF607166),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: forest),
                            SizedBox(width: 12),
                            Text('Secure account access'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: forest),
                            SizedBox(width: 12),
                            Text('Verified registration plates'),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
                return wide
                    ? Row(children: [introduction, formCard])
                    : Column(
                        children: [
                          const Text(
                            'STARK GROUP VMS',
                            style: TextStyle(
                              fontSize: 22,
                              color: forest,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          formCard,
                        ],
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final ApiClient api;
  final AuthSession session;
  final VoidCallback onLogout;
  const DashboardScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final search = TextEditingController();
  VehiclePage? listing;
  bool loading = true;
  int currentPage = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> refresh({int? page}) async {
    if (page != null) currentPage = page;
    setState(() => loading = true);
    try {
      final result = await widget.api.listVehicles(
        page: currentPage,
        search: search.text.trim(),
      );
      if (mounted) setState(() => listing = result);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showVehicleForm([Vehicle? vehicle]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VehicleFormDialog(api: widget.api, vehicle: vehicle),
    );
    if (changed == true && mounted) await refresh(page: 0);
  }

  Future<void> remove(Vehicle vehicle) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive this vehicle?'),
        content: Text(
          '${vehicle.vehicleName} (${vehicle.numberPlate}) '
          'will be hidden from the active fleet. Its record will remain in PostgreSQL.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: accent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Archive vehicle'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await widget.api.deleteVehicle(vehicle.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle archived successfully.')),
        );
        await refresh(page: 0);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = listing;
    final items = list?.items ?? <Vehicle>[];
    final active = items.where((v) => v.status == 'ACTIVE').length;
    final maintenance = items.where((v) => v.status == 'MAINTENANCE').length;
    final inactive = items.where((v) => v.status == 'INACTIVE').length;
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: forest,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car_filled,
                    color: Colors.white,
                    size: 29,
                  ),
                  const SizedBox(width: 12),
                  const Flexible(
                    child: Text(
                      'STARK GROUP  /  VMS',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (MediaQuery.sizeOf(context).width > 650)
                    Text(
                      widget.session.fullName,
                      style: const TextStyle(color: Colors.white),
                    ),
                  const SizedBox(width: 15),
                  IconButton(
                    onPressed: widget.onLogout,
                    tooltip: 'Sign out',
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1280),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fleet dashboard',
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Your registered vehicles and depot assignments',
                                    style: TextStyle(color: Color(0xFF65766A)),
                                  ),
                                ],
                              ),
                              FilledButton.icon(
                                onPressed: () => showVehicleForm(),
                                icon: const Icon(Icons.add),
                                label: const Text('Register vehicle'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 22,
                                    vertical: 19,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              StatCard(
                                label: 'Active fleet',
                                value: '${list?.total ?? 0}',
                                icon: Icons.directions_car_rounded,
                              ),
                              StatCard(
                                label: 'Active (page)',
                                value: '$active',
                                icon: Icons.check_circle_outline,
                              ),
                              StatCard(
                                label: 'Inactive (page)',
                                value: '$inactive',
                                icon: Icons.cancel_outlined,
                              ),
                              StatCard(
                                label: 'Maintenance (page)',
                                value: '$maintenance',
                                icon: Icons.build_circle_outlined,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE8EAE6),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 14,
                                  runSpacing: 14,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'Vehicle registry',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 310,
                                      child: TextField(
                                        controller: search,
                                        onSubmitted: (_) => refresh(page: 0),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Name, plate, or depot',
                                          prefixIcon: const Icon(Icons.search),
                                          suffixIcon: IconButton(
                                            tooltip: 'Search',
                                            onPressed: () => refresh(page: 0),
                                            icon: const Icon(
                                              Icons.arrow_forward,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => refresh(page: 0),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                if (loading)
                                  const Padding(
                                    padding: EdgeInsets.all(40),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else if (items.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(50),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.no_crash_outlined,
                                            size: 50,
                                            color: forest,
                                          ),
                                          SizedBox(height: 12),
                                          Text('No active vehicles found.'),
                                          SizedBox(height: 4),
                                          Text(
                                            'Register a vehicle to get started.',
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columnSpacing: 25,
                                      headingRowColor: WidgetStateProperty.all(
                                        ivory,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('VEHICLE')),
                                        DataColumn(label: Text('NUMBER PLATE')),
                                        DataColumn(label: Text('TYPE')),
                                        DataColumn(label: Text('DEPOT')),
                                        DataColumn(label: Text('STATUS')),
                                        DataColumn(label: Text('SEATS')),
                                        DataColumn(label: Text('ACTIONS')),
                                      ],
                                      rows: items
                                          .map(
                                            (v) => DataRow(
                                              cells: [
                                                DataCell(
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        v.vehicleName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${v.manufacturer} ${v.model}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    v.numberPlate,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(Text(v.vehicleType)),
                                                DataCell(Text(v.assignedDepot)),
                                                DataCell(
                                                  StatusPill(status: v.status),
                                                ),
                                                DataCell(
                                                  Text('${v.seatCapacity}'),
                                                ),
                                                DataCell(
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        tooltip: 'Edit vehicle',
                                                        onPressed: () =>
                                                            showVehicleForm(v),
                                                        icon: const Icon(
                                                          Icons.edit_outlined,
                                                          color: forest,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip:
                                                            'Archive vehicle',
                                                        onPressed: () =>
                                                            remove(v),
                                                        icon: const Icon(
                                                          Icons.delete_outline,
                                                          color: accent,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Text(
                                      'Page ${currentPage + 1} of ${math.max(1, list?.totalPages ?? 1)}',
                                      style: const TextStyle(
                                        color: Color(0xFF65766A),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: 'Previous',
                                      onPressed: !loading && currentPage > 0
                                          ? () => refresh(page: currentPage - 1)
                                          : null,
                                      icon: const Icon(Icons.chevron_left),
                                    ),
                                    IconButton(
                                      tooltip: 'Next',
                                      onPressed:
                                          !loading &&
                                              list != null &&
                                              currentPage + 1 < list.totalPages
                                          ? () => refresh(page: currentPage + 1)
                                          : null,
                                      icon: const Icon(Icons.chevron_right),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 215,
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE8EAE6)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: forest, size: 27),
        const SizedBox(height: 15),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF68746B), fontSize: 12),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'ACTIVE' => forest,
      'MAINTENANCE' => const Color(0xFFC08419),
      'INACTIVE' => const Color(0xFFD94060),
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class VehicleFormDialog extends StatefulWidget {
  final ApiClient api;
  final Vehicle? vehicle;
  const VehicleFormDialog({super.key, required this.api, this.vehicle});
  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String type, fuel, status;
  bool saving = false;

  static const types = [
    'SEDAN',
    'SUV',
    'MICROBUS',
    'BUS',
    'TRUCK',
    'MOTORBIKE',
    'VAN',
    'OTHER',
  ];
  static const fuels = [
    'PETROL',
    'DIESEL',
    'CNG',
    'HYBRID',
    'ELECTRIC',
    'OTHER',
  ];
  static const statuses = ['ACTIVE', 'MAINTENANCE', 'INACTIVE'];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;
    fields = {
      'vehicleName': TextEditingController(text: v?.vehicleName ?? ''),
      'manufacturer': TextEditingController(text: v?.manufacturer ?? ''),
      'model': TextEditingController(text: v?.model ?? ''),
      'color': TextEditingController(text: v?.color ?? ''),
      'seatCapacity': TextEditingController(text: '${v?.seatCapacity ?? 5}'),
      'numberPlate': TextEditingController(text: v?.numberPlate ?? ''),
      'engineCc': TextEditingController(text: '${v?.engineCc ?? 1500}'),
      'assignedDepot': TextEditingController(text: v?.assignedDepot ?? ''),
      'manufactureYear': TextEditingController(
        text: '${v?.manufactureYear ?? DateTime.now().year}',
      ),
      'notes': TextEditingController(text: v?.notes ?? ''),
    };
    type = v?.vehicleType ?? 'SEDAN';
    fuel = v?.fuelType ?? 'PETROL';
    status = v?.status ?? 'ACTIVE';
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget textField(
    String key,
    String label, {
    int maxLength = 50,
    bool numeric = false,
    bool optional = false,
    int? min,
    int? max,
  }) {
    return TextFormField(
      controller: fields[key],
      maxLength: maxLength,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(labelText: label, counterText: ''),
      validator: (value) {
        final s = (value ?? '').trim();
        if (s.isEmpty && !optional) return '$label is required';
        if (s.length > maxLength) return 'Maximum $maxLength characters';
        if (numeric) {
          final n = int.tryParse(s);
          if (n == null) return 'Enter a whole number';
          if (min != null && n < min) return 'Minimum is $min';
          if (max != null && n > max) return 'Maximum is $max';
        }
        if (key == 'numberPlate' &&
            !RegExp(
              r'^DHAKA METRO\s*-\s*[A-Z]{1,5}\s*-\s*\d{2}\s*-\s*\d{4}$',
              caseSensitive: false,
            ).hasMatch(s)) {
          return 'Example: DHAKA METRO - GHA - 12 - 3456';
        }
        return null;
      },
    );
  }

  Widget drop(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> change,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: options
        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
        .toList(),
    onChanged: (s) {
      if (s != null) setState(() => change(s));
    },
  );

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;
    setState(() => saving = true);
    final body = <String, dynamic>{
      for (final key in fields.keys) key: fields[key]!.text.trim(),
      'vehicleType': type,
      'fuelType': fuel,
      'status': status,
    };
    for (final key in ['seatCapacity', 'engineCc', 'manufactureYear']) {
      body[key] = int.parse(body[key] as String);
    }
    try {
      if (widget.vehicle == null) {
        await widget.api.createVehicle(body);
      } else {
        await widget.api.updateVehicle(widget.vehicle!.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: ivory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: math.min(750, screen.width - 30),
        height: math.min(770, screen.height - 50),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.vehicle == null
                          ? 'Register a new vehicle'
                          : 'Edit vehicle details',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 23,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth > 560
                          ? (constraints.maxWidth - 16) / 2
                          : constraints.maxWidth;
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          SizedBox(
                            width: width,
                            child: textField('vehicleName', 'Vehicle name'),
                          ),
                          SizedBox(
                            width: width,
                            child: textField('manufacturer', 'Manufacturer'),
                          ),
                          SizedBox(
                            width: width,
                            child: textField('model', 'Model'),
                          ),
                          SizedBox(
                            width: width,
                            child: textField('color', 'Color', maxLength: 30),
                          ),
                          SizedBox(
                            width: width,
                            child: textField(
                              'seatCapacity',
                              'Seat capacity',
                              numeric: true,
                              min: 1,
                              max: 80,
                              maxLength: 2,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: textField(
                              'engineCc',
                              'Engine CC',
                              numeric: true,
                              min: 0,
                              max: 20000,
                              maxLength: 5,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: drop(
                              'Vehicle type',
                              type,
                              types,
                              (v) => type = v,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: drop(
                              'Fuel type',
                              fuel,
                              fuels,
                              (v) => fuel = v,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: drop(
                              'Status',
                              status,
                              statuses,
                              (v) => status = v,
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: textField(
                              'manufactureYear',
                              'Manufacture year',
                              numeric: true,
                              min: 1950,
                              max: DateTime.now().year,
                              maxLength: 4,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: textField(
                              'numberPlate',
                              'Number plate (DHAKA METRO - GHA - 12 - 3456)',
                              maxLength: 50,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: textField(
                              'assignedDepot',
                              'Assigned station / depot',
                              maxLength: 100,
                            ),
                          ),
                          SizedBox(
                            width: constraints.maxWidth,
                            child: textField(
                              'notes',
                              'Notes (optional)',
                              optional: true,
                              maxLength: 500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: saving ? null : save,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                    ),
                    icon: saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      widget.vehicle == null
                          ? 'Register vehicle'
                          : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

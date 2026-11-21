import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'plate_rules.dart';

import 'api.dart';
import 'main.dart';

const _pine = Color(0xFF1C3027);
const _muted = Color(0xFF6E7B72);

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

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final ValueNotifier<int> _frameIndex = ValueNotifier<int>(0);
  bool registering = false;
  bool busy = false;
  bool reveal = false;

  // Timeline checkpoints (0.0 = start of GIF, 1.0 = end of GIF).
  static const double _arriveEnd = 0.56; // Bus reaches middle and stops
  static const double _vibrateStart = 0.56; // Vibration starts
  static const double _vibrateEnd = 0.72; // Vibration ends
  static const double _exitStart = 0.72; // Bus drives off to the left

  late final AnimationController _gifController;
  List<ui.Image> _frames = [];

  @override
  void initState() {
    super.initState();
    _gifController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_syncFrame);
    _loadGif();
  }

  void _syncFrame() {
    if (_frames.isEmpty) return;
    final next = (_gifController.value * (_frames.length - 1)).round().clamp(
      0,
      _frames.length - 1,
    );
    if (_frameIndex.value != next) {
      _frameIndex.value = next;
    }
  }

  Future<void> _loadGif() async {
    try {
      final data = await rootBundle.load('lib/assets/microbus.gif');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: 480,
      );

      final loaded = <ui.Image>[];
      var totalMs = 0;
      final step = codec.frameCount > 60 ? (codec.frameCount / 60).ceil() : 1;

      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        totalMs += frame.duration.inMilliseconds;
        if (i % step == 0 || i == codec.frameCount - 1) {
          loaded.add(frame.image);
        } else {
          frame.image.dispose();
        }
      }
      codec.dispose();

      if (!mounted) {
        for (final img in loaded) {
          img.dispose();
        }
        return;
      }

      setState(() {
        _frames = loaded;
        if (totalMs > 0) {
          _gifController.duration = Duration(milliseconds: totalMs);
        }
      });

      _gifController.value = 0.0;
      _gifController.animateTo(_arriveEnd);
    } catch (e) {
      debugPrint('Failed to load microbus GIF: $e');
    }
  }

  Future<void> _playVibrate() async {
    if (_frames.isEmpty) return;
    _gifController.value = _vibrateStart;
    await _gifController.animateTo(_vibrateEnd);
    if (mounted) {
      _gifController.value = _arriveEnd;
    }
  }

  Future<void> _playExit() async {
    if (_frames.isEmpty) return;
    _gifController.value = _exitStart;
    await _gifController.animateTo(1.0);
  }

  @override
  void dispose() {
    _gifController.removeListener(_syncFrame);
    _gifController.dispose();
    _frameIndex.dispose();
    for (final img in _frames) {
      img.dispose();
    }
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

      if (!registering) {
        await _playExit();
      }
      if (mounted) widget.onAuthenticated(session);
    } catch (error) {
      if (!registering) {
        _playVibrate();
      }
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _buildControlledGif({double? height}) {
    if (_frames.isEmpty) {
      return SizedBox(height: height ?? 240);
    }
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.hardEdge,
        child: ValueListenableBuilder<int>(
          valueListenable: _frameIndex,
          builder: (context, index, _) {
            return RawImage(
              image: _frames[index],
              height: height,
              width: double.infinity,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.low,
            );
          },
        ),
      ),
    );
  }

  Widget _buildRegistrationPerks() {
    const perks = [
      (
        Icons.directions_bus_outlined,
        'Centralized fleet registry',
        'Track every sedan, microbus, and utility vehicle in one place.',
      ),
      (
        Icons.verified_outlined,
        'Verified registration plates',
        'Built-in Dhaka Metro plate validation keeps records clean and compliant.',
      ),
      (
        Icons.location_city_outlined,
        'Organized depot assignments',
        'Monitor station allocations and vehicle availability at a glance.',
      ),
      (
        Icons.shield_outlined,
        'Secure account & audit history',
        'Protected sign-in with safe archiving so fleet records are never lost.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Stark Group Limited',
          style: GoogleFonts.greatVibes(
            color: _pine,
            fontWeight: FontWeight.bold,
            fontSize: 28,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Why manage your fleet with our VMS?',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: _pine,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Create an account to unlock streamlined fleet operations across all depots.',
          style: TextStyle(fontSize: 15, color: _muted, height: 1.5),
        ),
        const SizedBox(height: 24),
        for (final (icon, title, subtitle) in perks) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: forest.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: forest, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: _pine,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildFormContent() {
    return Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            registering ? 'Create an account' : 'Welcome back',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          const Text(
            'Manage your fleet securely with our VMS.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
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
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Enter your name' : null,
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
                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
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
                icon: Icon(reveal ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => reveal = !reveal),
              ),
            ),
            validator: (v) => (v ?? '').length < (registering ? 8 : 1)
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
                : Text(registering ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: busy
                ? null
                : () {
                    setState(() => registering = !registering);
                    if (!registering && _frames.isNotEmpty) {
                      _gifController.value = 0.0;
                      _gifController.animateTo(_arriveEnd);
                    }
                  },
            child: Text(
              registering
                  ? 'Already registered? Sign in'
                  : 'New to VMS? Create an account',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewport.maxHeight,
                minWidth: viewport.maxWidth,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 720;

                          // LOGIN VIEW: Animation + Login Card inside one white container
                          if (!registering) {
                            return Container(
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
                              child: wide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              right: 28,
                                            ),
                                            child: Center(
                                              child: _buildControlledGif(),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 1,
                                          height: 360,
                                          color: const Color(0xFFE8EAE6),
                                        ),
                                        const SizedBox(width: 28),
                                        SizedBox(
                                          width: 400,
                                          child: _buildFormContent(),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        _buildControlledGif(height: 180),
                                        const SizedBox(height: 24),
                                        _buildFormContent(),
                                      ],
                                    ),
                            );
                          }

                          // REGISTRATION VIEW: Stark Group Limited + VMS Perks + Form Card
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
                            child: _buildFormContent(),
                          );

                          return wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 36,
                                        ),
                                        child: _buildRegistrationPerks(),
                                      ),
                                    ),
                                    formCard,
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildRegistrationPerks(),
                                    const SizedBox(height: 20),
                                    formCard,
                                  ],
                                );
                        },
                      ),
                    ),
                  ),
                  const _DashboardFooter(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardFooter extends StatelessWidget {
  const _DashboardFooter();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 10),
        SizedBox(
          width: 260,
          child: Divider(height: 1, thickness: 2, color: Color(0xFFD8DFD6)),
        ),
        SizedBox(height: 5),
        Text(
          'Vehicle management system v1.0.0',
          style: TextStyle(
            color: _pine,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'by ',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
            _AuthorLink(
              label: 'Zunayed Iqbal Shahed',
              url: 'https://github.com/zishahed',
            ),
          ],
        ),
        SizedBox(height: 15),
      ],
    );
  }
}

class _AuthorLink extends StatefulWidget {
  final String label;
  final String url;
  const _AuthorLink({required this.label, required this.url});

  @override
  State<_AuthorLink> createState() => _AuthorLinkState();
}

class _AuthorLinkState extends State<_AuthorLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          Clipboard.setData(ClipboardData(text: widget.url));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Copied link: ${widget.url}')));
        },
        child: Text(
          widget.label,
          style: TextStyle(
            color: _pine,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            height: 1.2,
            decoration: _hovered
                ? TextDecoration.underline
                : TextDecoration.none,
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
    final assigned = items.where((v) => v.status == 'ASSIGNED').length;
    final available = items.where((v) => v.status == 'AVAILABLE').length;
    final maintenance = items.where((v) => v.status == 'MAINTENANCE').length;
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
                                label: 'Available (page)',
                                value: '$available',
                                icon: Icons.check_circle_outline,
                              ),
                              StatCard(
                                label: 'Assigned (page)',
                                value: '$assigned',
                                icon: Icons.route_outlined,
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
      'AVAILABLE' => forest,
      'ASSIGNED' => const Color(0xFF4964A6),
      'MAINTENANCE' => const Color(0xFFC08419),
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
  final ValueChanged<Object>? onError;
  const VehicleFormDialog({
    super.key,
    required this.api,
    this.vehicle,
    this.onError,
  });
  @override
  State<VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<VehicleFormDialog> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> fields;
  late String type, fuel, status;
  String _registrationUsage = 'PRIVATE';
  bool saving = false;
  String? numberPlateError;

  static const types = [
    'SEDAN',
    'HATCHBACK',
    'SUV',
    'JEEP',
    'MICROBUS',
    'MINIBUS',
    'BUS',
    'TRUCK',
    'PICKUP',
    'DOUBLE_CAB_PICKUP',
    'VAN',
    'DELIVERY_VAN',
    'MOTORBIKE',
    'SCOOTER',
    'AUTO_RICKSHAW',
    'TAXI',
    'AMBULANCE',
    'TRACTOR',
    'SPECIAL_PURPOSE',
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
      'numberPlate': TextEditingController(
        text: PlateRules.digitsFromExistingPlate(v?.numberPlate),
      ),
      'engineCc': TextEditingController(text: '${v?.engineCc ?? 1500}'),
      'assignedDepot': TextEditingController(text: v?.assignedDepot ?? ''),
      'manufactureYear': TextEditingController(
        text: '${v?.manufactureYear ?? DateTime.now().year}',
      ),
      'notes': TextEditingController(text: v?.notes ?? ''),
    };
    type = v?.vehicleType.trim().toUpperCase() ?? 'SEDAN';
    fuel = v?.fuelType.trim().toUpperCase() ?? 'PETROL';
    status = v?.status.trim().toUpperCase() ?? 'ACTIVE';
    // Existing API model does not expose registration usage yet.
    // Default to PRIVATE until it is returned by the backend.
    _registrationUsage = 'PRIVATE';
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
    String? errorText,
  }) {
    final controller = fields[key]!;
    return TextFormField(
      controller: controller,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters: [
        LengthLimitingTextInputFormatter(maxLength),
        if (numeric) FilteringTextInputFormatter.digitsOnly,
      ],
      decoration: InputDecoration(labelText: label, errorText: errorText),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) {
          return optional ? null : 'This field is required.';
        }
        if (numeric) {
          final parsed = int.tryParse(text);
          if (parsed == null ||
              (min != null && parsed < min) ||
              (max != null && parsed > max)) {
            return 'Enter a valid value.';
          }
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
  ) {
    final safeOptions = options.contains(value) ? options : [value, ...options];
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: safeOptions
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: (s) {
        if (s != null) setState(() => change(s));
      },
    );
  }

  Future<void> save() async {
    if (!(form.currentState?.validate() ?? false)) return;

    final generatedPlate = PlateRules.preview(
      vehicleType: type,
      engineCc: int.tryParse(fields['engineCc']!.text),
      usage: _registrationUsage,
      registrationDigits: fields['numberPlate']!.text,
    );

    if (generatedPlate == null) {
      showError(
        context,
        'Cannot determine a plate class for these details. '
        'Check the vehicle type, CC and BRTA registration certificate.',
      );
      return;
    }

    final body = <String, dynamic>{
      for (final key in fields.keys) key: fields[key]!.text.trim(),
      'vehicleType': type,
      'fuelType': fuel,
      'status': status,
      // Send the six issued digits; Spring Boot generates the full plate.
      'numberPlate': fields['numberPlate']!.text.trim(),
      'registrationUsage': _registrationUsage,
    };
    for (final key in ['seatCapacity', 'engineCc', 'manufactureYear']) {
      body[key] = int.parse(body[key] as String);
    }

    setState(() => saving = true);
    try {
      if (widget.vehicle == null) {
        await widget.api.createVehicle(body);
      } else {
        await widget.api.updateVehicle(widget.vehicle!.id, body);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString();
      if (message.toLowerCase().contains(
        'vehicle number plate already exists',
      )) {
        setState(() {
          numberPlateError =
              'This number plate is already registered in Database.';
        });
      }
      // Preserve the dashboard error notification.
      if (widget.onError != null) {
        widget.onError!(error);
      } else {
        showError(context, error);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    final generatedPlate = PlateRules.preview(
      vehicleType: type,
      engineCc: int.tryParse(fields['engineCc']?.text ?? ''),
      usage: _registrationUsage,
      registrationDigits: fields['numberPlate']?.text ?? '',
    );

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
                            child: TextFormField(
                              controller: fields['engineCc'],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Engine Capacity (CC)',
                                hintText: 'e.g. 1500',
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(5),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                final cc = int.tryParse(value ?? '');

                                if (cc == null || cc <= 0 || cc > 20000) {
                                  return 'Enter valid engine CC';
                                }

                                return null;
                              },
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
                            width: width,
                            child: DropdownButtonFormField<String>(
                              initialValue: _registrationUsage,
                              decoration: const InputDecoration(
                                labelText: 'Registration usage',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PRIVATE',
                                  child: Text('Private'),
                                ),
                                DropdownMenuItem(
                                  value: 'COMMERCIAL',
                                  child: Text('Commercial / Hire'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _registrationUsage = value;
                                  });
                                }
                              },
                            ),
                          ),

                          SizedBox(
                            width: width,
                            child: TextFormField(
                              controller: fields['numberPlate'],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                errorText: numberPlateError,
                                labelText: 'Registration number',
                                hintText: '123456',
                                helperText: 'Enter the 6-digit BRTA number',
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              onChanged: (_) => setState(() {}),
                              validator: (value) {
                                if (value == null ||
                                    !RegExp(r'^\d{6}$').hasMatch(value)) {
                                  return 'Enter exactly 6 digits';
                                }
                                return null;
                              },
                            ),
                          ),

                          SizedBox(
                            width: constraints.maxWidth,
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F6F1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFFD8E5DB),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AUTOMATIC NUMBER PLATE',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    generatedPlate ??
                                        'Complete the vehicle details',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Plate class is suggested from '
                                    'vehicle type, CC and usage. '
                                    'Verify against the BRTA certificate.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
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

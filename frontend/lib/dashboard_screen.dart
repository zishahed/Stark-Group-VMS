import 'dart:math' as math;

import 'package:google_fonts/google_fonts.dart';

import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'main.dart';
import 'screens.dart' show VehicleFormDialog, showError;

const _pine = Color(0xFF1C3027);
const _muted = Color(0xFF647368);
const _border = Color(0xFFE4E9E2);
const _panel = Color(0xFFF1F2EE);
const _amber = Color(0xFFE4A62A);
const _blue = Color.fromARGB(255, 1, 106, 253);

const _pageSize = 5;
const _registryMaxWidth = 750.0;
const _colCheck = 42.0;
const _colGap = 8.0;
const _colVehicle = 175.0;
const _colPlate = 275.0;
const _colStatus = 60.0;

/// Desktop-first dashboard. Uses the existing authenticated API and retains
/// the existing VehicleFormDialog for adding/editing vehicle records.
class FleetDashboardScreen extends StatefulWidget {
  final ApiClient api;
  final AuthSession session;
  final VoidCallback onLogout;

  const FleetDashboardScreen({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  @override
  State<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends State<FleetDashboardScreen> {
  final _search = TextEditingController();
  final Set<String> _selectedIds = <String>{};

  VehiclePage? _listing;
  FleetSummary? _summary;
  Vehicle? _drawerVehicle;
  bool _drawerOpen = false;
  bool _loading = true;
  bool _archiving = false;
  String _appliedSearch = '';
  int _currentPage = 0;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({int? page}) async {
    final requestedPage = page ?? _currentPage;
    final generation = ++_loadGeneration;
    setState(() {
      _currentPage = requestedPage;
      _loading = true;
      _selectedIds.clear();
      _drawerOpen = false;
    });

    try {
      // The summary is fleet-wide, not derived from the visible vehicles.
      final results = await Future.wait<Object>([
        widget.api.listVehicles(
          page: requestedPage,
          size: _pageSize,
          search: _appliedSearch,
        ),
        widget.api.getFleetSummary(),
      ]);
      if (!mounted || generation != _loadGeneration) return;

      final vehicles = results[0] as VehiclePage;
      final summary = results[1] as FleetSummary;
      if (requestedPage > 0 &&
          vehicles.items.isEmpty &&
          requestedPage >= vehicles.totalPages) {
        // Deleting the last vehicle on a page should not strand the user.
        await _reload(page: math.max(0, vehicles.totalPages - 1));
        return;
      }
      setState(() {
        _listing = vehicles;
        _summary = summary;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _loading = false);
      showError(context, error);
    }
  }

  void _applySearch() {
    _appliedSearch = _search.text.trim();
    _reload(page: 0);
  }

  void _openVehicle(Vehicle vehicle) {
    setState(() {
      _drawerVehicle = vehicle;
      _drawerOpen = true;
    });
  }

  void _closeVehicle() {
    setState(() => _drawerOpen = false);
  }

  void _toggleSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
  }

  void _toggleAll(bool? selected) {
    setState(() {
      final ids = (_listing?.items ?? <Vehicle>[])
          .take(_pageSize)
          .map((v) => v.id);
      if (selected == true) {
        _selectedIds.addAll(ids);
      } else {
        _selectedIds.removeAll(ids);
      }
    });
  }

  Future<void> _editVehicle([Vehicle? vehicle]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => VehicleFormDialog(api: widget.api, vehicle: vehicle),
    );
    if (changed == true && mounted) {
      await _reload(page: vehicle == null ? 0 : _currentPage);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vehicle == null
                  ? 'Vehicle registered successfully.'
                  : 'Vehicle updated successfully.',
            ),
          ),
        );
      }
    }
  }

  Future<bool> _confirmArchive(List<Vehicle> vehicles) async {
    final many = vehicles.length > 1;
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              many
                  ? 'Archive ${vehicles.length} selected vehicles?'
                  : 'Archive ${vehicles.first.vehicleName}?',
            ),
            content: const Text(
              'These vehicles will be removed from the active registry. '
              'Their records remain in PostgreSQL with is_deleted = true.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.archive_outlined),
                label: Text(many ? 'Archive selected' : 'Archive vehicle'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _archive(List<Vehicle> vehicles) async {
    if (vehicles.isEmpty || _archiving) return;
    if (!await _confirmArchive(vehicles) || !mounted) return;

    setState(() => _archiving = true);
    var archived = 0;
    final failures = <String>[];
    for (final vehicle in vehicles) {
      try {
        // Existing DELETE is ownership-protected and performs soft deletion.
        await widget.api.deleteVehicle(vehicle.id);
        archived++;
      } catch (_) {
        failures.add(vehicle.numberPlate);
      }
    }
    if (!mounted) return;
    setState(() => _archiving = false);
    await _reload(page: _currentPage);
    if (!mounted) return;
    final message = failures.isEmpty
        ? '$archived vehicle${archived == 1 ? '' : 's'} archived.'
        : '$archived archived, ${failures.length} failed. '
              'Check: ${failures.join(', ')}';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final items = _listing?.items ?? <Vehicle>[];
    return Scaffold(
      backgroundColor: ivory,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final outer = constraints.maxWidth >= 1200 ? 22.0 : 13.0;
            final layoutWidth = math.min(
              1440.0,
              math.max(0.0, constraints.maxWidth - outer * 2),
            );
            final sidebarWidth = (layoutWidth * 0.225).clamp(205.0, 284.0);
            final drawerWidth = (layoutWidth * 0.46).clamp(355.0, 480.0);
            final gutter = layoutWidth >= 1150 ? 20.0 : 12.0;
            final availableForRight = math.max(
              0.0,
              layoutWidth - sidebarWidth - gutter,
            );
            final showWorkArea =
                availableForRight >= _registryMaxWidth + gutter + 80;

            return Center(
              child: SizedBox(
                width: layoutWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    _FloatingNavigation(
                      user: widget.session,
                      onLogout: widget.onLogout,
                      onDashboard: () => _reload(page: 0),
                      onRegistry: _closeVehicle,
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ClipRect(
                        child: Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: sidebarWidth,
                                  child: _DashboardSidebar(
                                    session: widget.session,
                                    summary: _summary,
                                    loading: _loading && _summary == null,
                                  ),
                                ),
                                SizedBox(width: gutter),
                                if (showWorkArea) ...[
                                  SizedBox(
                                    width: _registryMaxWidth,
                                    child: _mainContent(items, layoutWidth),
                                  ),
                                  SizedBox(width: gutter),
                                  // Reserved space to the right of the vehicle list
                                  // for your additional widgets/features.
                                  const Expanded(child: SizedBox.expand()),
                                ] else
                                  Expanded(
                                    child: _mainContent(items, layoutWidth),
                                  ),
                              ],
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                ignoring: !_drawerOpen,
                                child: AnimatedOpacity(
                                  opacity: _drawerOpen ? 1 : 0,
                                  duration: const Duration(milliseconds: 260),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: _closeVehicle,
                                    child: Container(
                                      color: _pine.withValues(alpha: .20),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 380),
                              curve: Curves.easeOutCubic,
                              right: _drawerOpen ? 0 : -drawerWidth - 4,
                              top: 0,
                              bottom: 0,
                              width: drawerWidth,
                              child: _drawerVehicle == null
                                  ? const SizedBox.shrink()
                                  : _VehicleDetailsDrawer(
                                      key: ValueKey(_drawerVehicle!.id),
                                      vehicle: _drawerVehicle!,
                                      onClose: _closeVehicle,
                                      onEdit: _archiving
                                          ? null
                                          : () => _editVehicle(_drawerVehicle),
                                      onArchive: _archiving
                                          ? null
                                          : () => _archive([_drawerVehicle!]),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _mainContent(List<Vehicle> items, double viewportWidth) {
    final narrow = viewportWidth < 1170;
    final pageItems = items.take(_pageSize).toList();
    final selectedOnPage = pageItems
        .where((v) => _selectedIds.contains(v.id))
        .toList();
    final allSelected =
        pageItems.isNotEmpty && selectedOnPage.length == pageItems.length;
    final partiallySelected = selectedOnPage.isNotEmpty && !allSelected;

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 4 : 8, 2, narrow ? 4 : 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fleet dashboard',
            style: GoogleFonts.spaceGrotesk(
              fontSize: narrow ? 28 : 36,
              fontWeight: FontWeight.bold,
              height: 1.1,
              letterSpacing: -.75,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage every vehicle from one clear workspace.',
            style: TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: _pine.withValues(alpha: .045),
                  blurRadius: 26,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: EdgeInsets.all(narrow ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle registry',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Select a vehicle to open its full details.',
                            style: TextStyle(color: _muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _archiving ? null : () => _editVehicle(),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Register vehicle'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _loading || _archiving
                          ? null
                          : () => _reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      tooltip: 'Refresh vehicles',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onSubmitted: (_) => _applySearch(),
                        textInputAction: TextInputAction.search,
                        decoration: InputDecoration(
                          hintText: 'Search name, number plate, or depot',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            tooltip: 'Apply search',
                            onPressed: _applySearch,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ),
                      ),
                    ),
                    if (selectedOnPage.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _archiving || _loading
                            ? null
                            : () => _archive(selectedOnPage),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                        ),
                        icon: _archiving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.archive_outlined, size: 18),
                        label: Text('Archive (${selectedOnPage.length})'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                _RegistryHead(
                  checked: allSelected,
                  partlyChecked: partiallySelected,
                  onSelectAll: _loading || pageItems.isEmpty || _archiving
                      ? null
                      : (_) => _toggleAll(!allSelected),
                ),
                const SizedBox(height: 6),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 82),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (pageItems.isEmpty)
                  const _EmptyRegistry()
                else
                  ...pageItems.map(
                    (vehicle) => Padding(
                      key: ValueKey(vehicle.id),
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _VehicleListRow(
                        vehicle: vehicle,
                        checked: _selectedIds.contains(vehicle.id),
                        highlighted:
                            _drawerOpen && _drawerVehicle?.id == vehicle.id,
                        onChecked: (checked) =>
                            _toggleSelection(vehicle.id, checked),
                        onTap: () => _openVehicle(vehicle),
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                _Pagination(
                  page: _currentPage,
                  totalPages: _listing?.totalPages ?? 0,
                  totalCount: _listing?.total ?? 0,
                  visibleCount: pageItems.length,
                  disabled: _loading || _archiving,
                  onPage: (page) => _reload(page: page),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavigation extends StatelessWidget {
  final AuthSession user;
  final VoidCallback onLogout, onDashboard, onRegistry;

  const _FloatingNavigation({
    required this.user,
    required this.onLogout,
    required this.onDashboard,
    required this.onRegistry,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 1030;
        return Container(
          height: 68,
          padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 20),
          decoration: BoxDecoration(
            color: _pine,
            borderRadius: BorderRadius.circular(38),
            boxShadow: [
              BoxShadow(
                color: _pine.withValues(alpha: .23),
                blurRadius: 25,
                offset: const Offset(0, 11),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: const Color(0xFF087B5D),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.directions_car_filled_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              const Text(
                'Stark Group',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.35,
                ),
              ),
              SizedBox(width: compact ? 16 : 30),
              _NavLink(label: 'Dashboard', active: true, onTap: onDashboard),
              const SizedBox(width: 6),
              if (!compact)
                _NavLink(label: 'Vehicles', active: false, onTap: onRegistry),
              const Spacer(),
              if (!compact) ...[
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: Color(0xFF88B99B),
                ),
                const SizedBox(width: 7),
                const Text(
                  'Secure workspace',
                  style: TextStyle(color: Color(0xFFB6C8BC), fontSize: 12),
                ),
                const SizedBox(width: 24),
              ],
              PopupMenuButton<String>(
                tooltip: 'Account menu',
                onSelected: (value) {
                  if (value == 'signout') onLogout();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    enabled: false,
                    child: Text(user.email, overflow: TextOverflow.ellipsis),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'signout',
                    child: Row(
                      children: [
                        Icon(Icons.logout_rounded, size: 19),
                        SizedBox(width: 10),
                        Text('Sign out'),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compact) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 145),
                        child: Text(
                          user.fullName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                    ],
                    CircleAvatar(
                      backgroundColor: forest,
                      radius: 19,
                      child: Text(
                        _initials(user.fullName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}

class _NavLink extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: widget.active
              ? ivory
              : _hover
              ? Colors.white.withValues(alpha: .12)
              : Colors.transparent,
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .18),
                    blurRadius: 13,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.active ? _pine : const Color(0xFFD0DBD3),
                fontWeight: widget.active ? FontWeight.w800 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  final AuthSession session;
  final FleetSummary? summary;
  final bool loading;

  const _DashboardSidebar({
    required this.session,
    required this.summary,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'FLEET OVERVIEW',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'YOUR PROFILE',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: forest.withValues(alpha: .13),
                  child: Text(
                    _initials(session.fullName),
                    style: const TextStyle(
                      color: forest,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    session.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.alternate_email_rounded,
                  color: _muted,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: SelectableText(
                    session.email,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 15, color: forest),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Authenticated account',
                    style: TextStyle(
                      color: forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${summary?.total ?? '—'} registered vehicles',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _StatTile(
              'Active',
              summary?.active,
              Icons.local_shipping_outlined,
              forest,
            ),
            _StatTile(
              'Assigned',
              summary?.assigned,
              Icons.route_outlined,
              _blue,
            ),
            _StatTile(
              'Available',
              summary?.available,
              Icons.check_circle_outline,
              forest,
            ),
            _StatTile(
              'Maintenance',
              summary?.maintenance,
              Icons.handyman_outlined,
              _amber,
            ),
            if (loading) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 8),
            Text(
              summary == null
                  ? 'Counts are across the entire fleet.'
                  : 'Counts are across the entire fleet · ${summary!.inactive} inactive.',
              style: const TextStyle(fontSize: 11, color: _muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatefulWidget {
  final String label;
  final int? count;
  final IconData icon;
  final Color color;
  const _StatTile(this.label, this.count, this.icon, this.color);

  @override
  State<_StatTile> createState() => _StatTileState();
}

class _StatTileState extends State<_StatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: _hover ? widget.color.withValues(alpha: .24) : _border,
          ),
          boxShadow: _hover
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: .09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${widget.count ?? '—'}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistryHead extends StatelessWidget {
  final bool checked, partlyChecked;
  final ValueChanged<bool?>? onSelectAll;

  const _RegistryHead({
    required this.checked,
    required this.partlyChecked,
    required this.onSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: _pine,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      letterSpacing: .4,
    );
    return Row(
      children: [
        SizedBox(
          width: _colCheck,
          child: Tooltip(
            message: 'Select all vehicles on this page',
            child: Checkbox(
              value: partlyChecked ? null : checked,
              tristate: true,
              onChanged: onSelectAll,
              activeColor: forest,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(
          width: _colVehicle,
          child: Text('VEHICLE', style: style),
        ),
        const SizedBox(width: _colGap),
        const SizedBox(
          width: _colPlate,
          child: Text('NUMBER PLATE', style: style),
        ),
        const SizedBox(width: _colGap),
        const Expanded(child: Text('DEPOT', style: style)),
        const SizedBox(width: _colGap),
        const SizedBox(
          width: _colStatus,
          child: Center(child: Text('STATUS', style: style)),
        ),
      ],
    );
  }
}

class _VehicleListRow extends StatefulWidget {
  final Vehicle vehicle;
  final bool checked, highlighted;
  final ValueChanged<bool> onChecked;
  final VoidCallback onTap;

  const _VehicleListRow({
    super.key,
    required this.vehicle,
    required this.checked,
    required this.highlighted,
    required this.onChecked,
    required this.onTap,
  });

  @override
  State<_VehicleListRow> createState() => _VehicleListRowState();
}

class _VehicleListRowState extends State<_VehicleListRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final emphasize = _hover || widget.highlighted;
    final vehicle = widget.vehicle;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, emphasize ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.highlighted
              ? const Color(0xFFE8F3EB)
              : emphasize
              ? const Color(0xFFFBFDFC)
              : ivory,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: widget.highlighted
                ? forest
                : emphasize
                ? const Color(0xFFBADAC5)
                : _border,
            width: widget.highlighted ? 1.7 : 1,
          ),
          boxShadow: emphasize
              ? [
                  BoxShadow(
                    color: forest.withValues(
                      alpha: widget.highlighted ? .16 : .11,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: widget.onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                children: [
                  SizedBox(
                    width: _colCheck,
                    child: Tooltip(
                      message: 'Select ${vehicle.vehicleName}',
                      child: Checkbox(
                        value: widget.checked,
                        onChanged: (checked) =>
                            widget.onChecked(checked ?? false),
                        activeColor: forest,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: _colVehicle,
                    child: Text(
                      vehicle.vehicleName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  SizedBox(
                    width: _colPlate,
                    child: Text(
                      vehicle.numberPlate,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    child: Text(
                      vehicle.assignedDepot,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _muted, fontSize: 11.5),
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  SizedBox(
                    width: _colStatus,
                    child: Center(
                      child: Tooltip(
                        message: _nice(vehicle.status),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _statusDot(vehicle.status),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _statusDot(vehicle.status)
                                    .withValues(alpha: .25),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Color _statusDot(String status) {
  return switch (status) {
    'INACTIVE' => accent,
    'MAINTENANCE' => _amber,
    _ => forest, // AVAILABLE and ASSIGNED both mean operational / active
  };
}

String _nice(String value) {
  return value
      .toLowerCase()
      .split('_')
      .map((piece) {
        if (piece.isEmpty) return piece;
        return '${piece[0].toUpperCase()}${piece.substring(1)}';
      })
      .join(' ');
}

class _EmptyRegistry extends StatelessWidget {
  const _EmptyRegistry();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 70),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined, size: 50, color: forest),
          SizedBox(height: 13),
          Text(
            'No vehicles found',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 5),
          Text(
            'Try another search or register a vehicle.',
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _Pagination extends StatelessWidget {
  final int page, totalPages, totalCount, visibleCount;
  final bool disabled;
  final ValueChanged<int> onPage;

  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.visibleCount,
    required this.disabled,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final from = totalCount == 0 ? 0 : page * _pageSize + 1;
    final to = totalCount == 0 ? 0 : page * _pageSize + visibleCount;
    final numbered = <int>[];
    for (var i = 0; i < totalPages; i++) {
      if (i == 0 || i == totalPages - 1 || (i - page).abs() <= 1) {
        numbered.add(i);
      }
    }
    final controls = <Widget>[
      IconButton(
        tooltip: 'Previous page',
        onPressed: !disabled && page > 0 ? () => onPage(page - 1) : null,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
    ];
    int? last;
    for (final number in numbered) {
      if (last != null && number > last + 1) {
        controls.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 1),
            child: Text('…', style: TextStyle(color: _muted)),
          ),
        );
      }
      final active = number == page;
      controls.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: active
              ? FilledButton(
                  onPressed: disabled ? null : () => onPage(number),
                  style: FilledButton.styleFrom(
                    backgroundColor: forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                  ),
                  child: Text('${number + 1}'),
                )
              : OutlinedButton(
                  onPressed: disabled ? null : () => onPage(number),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pine,
                    minimumSize: const Size(34, 34),
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: _border),
                  ),
                  child: Text('${number + 1}'),
                ),
        ),
      );
      last = number;
    }
    controls.add(
      IconButton(
        tooltip: 'Next page',
        onPressed: !disabled && page + 1 < totalPages
            ? () => onPage(page + 1)
            : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    );

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        spacing: 14,
        runSpacing: 10,
        children: [
          Text(
            'Showing $from–$to of $totalCount vehicles',
            style: const TextStyle(color: _muted, fontSize: 12),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: controls),
        ],
      ),
    );
  }
}

class _VehicleDetailsDrawer extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onClose;
  final VoidCallback? onEdit, onArchive;

  const _VehicleDetailsDrawer({
    super.key,
    required this.vehicle,
    required this.onClose,
    required this.onEdit,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 25,
      shadowColor: _pine.withValues(alpha: .3),
      color: Colors.white,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(25)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFFF0F6F1),
            padding: const EdgeInsets.fromLTRB(23, 20, 13, 19),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.directions_car_filled_rounded,
                    color: forest,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VEHICLE DETAILS',
                        style: TextStyle(
                          color: forest,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicle.vehicleName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close details',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(23, 18, 23, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _statusDot(vehicle.status),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        _nice(vehicle.status),
                        style: const TextStyle(
                          color: _pine,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Fleet record',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Identification',
                    children: [
                      _DetailField('Vehicle name', vehicle.vehicleName),
                      _DetailField(
                        'Number plate',
                        vehicle.numberPlate,
                        emphasis: true,
                      ),
                      _DetailField('Vehicle type', _nice(vehicle.vehicleType)),
                      _DetailField('Manufacturer', vehicle.manufacturer),
                      _DetailField('Model', vehicle.model),
                      _DetailField(
                        'Manufacture year',
                        '${vehicle.manufactureYear}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _DetailSection(
                    title: 'Specifications',
                    children: [
                      _DetailField('Color', vehicle.color),
                      _DetailField(
                        'Seat capacity',
                        '${vehicle.seatCapacity} seats',
                      ),
                      _DetailField('Engine capacity', '${vehicle.engineCc} CC'),
                      _DetailField('Fuel type', _nice(vehicle.fuelType)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _DetailSection(
                    title: 'Fleet assignment',
                    children: [
                      _DetailField('Status', _nice(vehicle.status)),
                      _DetailField('Station / depot', vehicle.assignedDepot),
                      _DetailField(
                        'Notes',
                        vehicle.notes.isEmpty ? '—' : vehicle.notes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _DetailSection(
                    title: 'Record metadata',
                    children: [
                      _DetailField('Record ID', vehicle.id),
                      _DetailField('Created', _dateTime(vehicle.createdAt)),
                      _DetailField(
                        'Last updated',
                        _dateTime(vehicle.updatedAt),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 13, 20, 18),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit vehicle'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: forest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onArchive,
                    icon: const Icon(Icons.archive_outlined, size: 18),
                    label: const Text('Archive'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTime(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String digits(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${digits(local.month)}-${digits(local.day)} '
      '${digits(local.hour)}:${digits(local.minute)}';
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _DetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: ivory,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: forest,
            ),
          ),
          const SizedBox(height: 13),
          ...children,
        ],
      ),
    );
  }
}

class _DetailField extends StatelessWidget {
  final String label, value;
  final bool emphasis;
  const _DetailField(this.label, this.value, {this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              letterSpacing: .65,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              color: emphasis ? forest : _pine,
              fontWeight: emphasis ? FontWeight.w900 : FontWeight.w600,
              fontSize: 13,
              height: 1.33,
            ),
          ),
        ],
      ),
    );
  }
}

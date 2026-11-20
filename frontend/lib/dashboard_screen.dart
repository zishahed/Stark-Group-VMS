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

const _pageSize = 8;
const _colCheck = 42.0;
const _colGap = 8.0;
const _colVehicle = 175.0;
const _colPlate = 325.0;
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
            final outer = constraints.maxWidth >= 1200 ? 18.0 : 12.0;
            final layoutWidth = math.max(0.0, constraints.maxWidth - outer * 2);
            final sidebarWidth = (layoutWidth * 0.19).clamp(205.0, 270.0);
            final gutter = layoutWidth >= 1150 ? 20.0 : 12.0;
            final showWorkArea = layoutWidth >= 1080;
            final workWidth = showWorkArea
                ? (layoutWidth * 0.28).clamp(330.0, 430.0)
                : 0.0;
            final narrow = layoutWidth < 1170;

            return Center(
              child: SizedBox(
                width: layoutWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 14),
                    Text(
                      'Stark   Group   LTD.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.greatVibes(
                        color: _pine,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 60),
                    Expanded(
                      child: ClipRect(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: sidebarWidth,
                              child: Align(
                                alignment: Alignment.center,
                                child: _DashboardSidebar(
                                  summary: _summary,
                                  loading: _loading && _summary == null,
                                ),
                              ),
                            ),
                            SizedBox(width: gutter),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _mainContent(items, layoutWidth),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      narrow ? 4 : 8,
                                      0,
                                      narrow ? 4 : 8,
                                      18,
                                    ),
                                    child: Center(
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 580,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(31),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _pine.withValues(
                                                        alpha: .20,
                                                      ),
                                                      blurRadius: 28,
                                                      spreadRadius: 1,
                                                      offset: const Offset(
                                                        0,
                                                        12,
                                                      ),
                                                    ),
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: .06,
                                                          ),
                                                      blurRadius: 10,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                child: _FloatingNavigation(
                                                  user: widget.session,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            _SignOutButton(
                                              onPressed: widget.onLogout,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (showWorkArea) ...[
                              SizedBox(width: gutter),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 380),
                                curve: Curves.easeOutCubic,
                                width: workWidth,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: _drawerOpen && _drawerVehicle != null
                                      ? TweenAnimationBuilder<double>(
                                          key: ValueKey(
                                            'drawer-${_drawerVehicle!.id}',
                                          ),
                                          tween: Tween(begin: 1, end: 0),
                                          duration: const Duration(
                                            milliseconds: 380,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          builder: (context, progress, child) {
                                            return Transform.translate(
                                              offset: Offset(-progress * 38, 0),
                                              child: Opacity(
                                                opacity: 1 - progress,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Stack(
                                            children: [
                                              Positioned(
                                                left: 0,
                                                top: 112,
                                                child: Container(
                                                  width: 18,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                    border: Border.all(
                                                      color: _border,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.chevron_left_rounded,
                                                    size: 17,
                                                    color: forest,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 10,
                                                  bottom: 14,
                                                ),
                                                child: _VehicleDetailsDrawer(
                                                  key: ValueKey(
                                                    _drawerVehicle!.id,
                                                  ),
                                                  vehicle: _drawerVehicle!,
                                                  onClose: _closeVehicle,
                                                  onEdit: _archiving
                                                      ? null
                                                      : () => _editVehicle(
                                                          _drawerVehicle,
                                                        ),
                                                  onArchive: _archiving
                                                      ? null
                                                      : () => _archive([
                                                          _drawerVehicle!,
                                                        ]),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : const SizedBox.expand(
                                          key: ValueKey('blank-workspace'),
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
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

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(narrow ? 4 : 8, 2, narrow ? 4 : 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Vehicle registry',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Select a vehicle to open its full details.',
                            style: GoogleFonts.spaceGrotesk(
                              color: _muted,
                              fontSize: 12,
                            ),
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
                  const _RegistrySkeleton()
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

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7ECE7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _RegistrySkeleton extends StatelessWidget {
  const _RegistrySkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBF9),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                _SkeletonBox(width: 18, height: 18, radius: 5),
                SizedBox(width: 18),
                _SkeletonBox(width: 130, height: 12),
                SizedBox(width: 18),
                _SkeletonBox(width: 150, height: 12),
                Spacer(),
                _SkeletonBox(width: 58, height: 22, radius: 11),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _SignOutButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _SignOutButton({required this.onPressed});

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _hovered ? accent : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: _hovered ? accent : accent.withValues(alpha: .35),
          ),
          boxShadow: [
            BoxShadow(
              color: _hovered
                  ? accent.withValues(alpha: .30)
                  : _pine.withValues(alpha: .12),
              blurRadius: _hovered ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: IconButton(
          tooltip: 'Sign out',
          onPressed: widget.onPressed,
          style: IconButton.styleFrom(
            foregroundColor: _hovered ? Colors.white : accent,
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.logout_rounded, size: 21),
        ),
      ),
    );
  }
}

class _FloatingNavigation extends StatelessWidget {
  final AuthSession user;
  const _FloatingNavigation({required this.user});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 550;
        return Container(
          height: 62,
          padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 20),
          decoration: BoxDecoration(
            color: _pine.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(31),
            border: Border.all(color: Colors.white.withValues(alpha: .10)),
            boxShadow: [
              BoxShadow(
                color: _pine.withValues(alpha: .16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'lib/assets/app_icon.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              if (!compact)
                const Text(
                  'Vehicle Management System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Vehicle Management System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (!compact) const Spacer(),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFC8D7CD),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: .12),
                radius: 17,
                child: Text(
                  _initials(user.fullName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
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

class _DashboardSidebar extends StatelessWidget {
  final FleetSummary? summary;
  final bool loading;

  const _DashboardSidebar({required this.summary, required this.loading});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: constraints.hasBoundedHeight
                ? constraints.maxHeight
                : double.infinity,
          ),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFE3E8E1)),
          ),
          child: Scrollbar(
            thumbVisibility: false,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 14),
                  _StatTile(
                    'Total vehicles',
                    summary?.total,
                    Icons.directions_car_filled_rounded,
                    const Color(0xFF4964A6),
                  ),
                  _StatTile(
                    'Active',
                    summary?.active,
                    Icons.local_shipping_outlined,
                    forest,
                  ),
                  _StatTile(
                    'Maintenance',
                    summary?.maintenance,
                    Icons.handyman_outlined,
                    _amber,
                  ),
                  _StatTile(
                    'Inactive',
                    summary?.inactive,
                    Icons.cancel_outlined,
                    accent,
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
                    style: const TextStyle(
                      fontSize: 11,
                      color: _muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    final style = GoogleFonts.poppins(
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
        SizedBox(
          width: _colVehicle,
          child: Text('VEHICLE', style: style),
        ),
        const SizedBox(width: _colGap),
        SizedBox(
          width: _colPlate,
          child: Text('NUMBER PLATE', style: style),
        ),
        const SizedBox(width: _colGap),
        Expanded(child: Text('DEPOT', style: style)),
        const SizedBox(width: _colGap),
        SizedBox(
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
    _ => forest,
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
                      Expanded(
                        child: Text(
                          vehicle.assignedDepot,
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    title: 'Identification',
                    children: [
                      _DetailTile('Vehicle name', vehicle.vehicleName),
                      _DetailTile(
                        'Number plate',
                        vehicle.numberPlate,
                        emphasis: true,
                      ),
                      _DetailTile('Vehicle type', _nice(vehicle.vehicleType)),
                      _DetailTile('Manufacturer', vehicle.manufacturer),
                      _DetailTile('Model', vehicle.model),
                      _DetailTile(
                        'Manufacture year',
                        '${vehicle.manufactureYear}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _DetailSection(
                    title: 'Specifications',
                    children: [
                      _DetailTile('Color', vehicle.color),
                      _DetailTile(
                        'Seat capacity',
                        '${vehicle.seatCapacity} seats',
                      ),
                      _DetailTile('Engine capacity', '${vehicle.engineCc} CC'),
                      _DetailTile('Fuel type', _nice(vehicle.fuelType)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _DetailSection(
                    title: 'Notes',
                    children: [
                      _DetailTile(
                        'Vehicle note',
                        vehicle.notes.isEmpty ? '—' : vehicle.notes,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = constraints.maxWidth >= 310
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: children
                    .map((child) => SizedBox(width: tileWidth, child: child))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label, value;
  final bool emphasis;
  const _DetailTile(this.label, this.value, {this.emphasis = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE7ECE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
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

import 'dart:math' as math;
import 'dart:async';

import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'main.dart';
import 'screens.dart' show VehicleFormDialog;

const _pine = Color(0xFF1C3027);
const _muted = Color(0xFF647368);
const _border = Color(0xFFE4E9E2);
const _panel = Color(0xFFF1F2EE);
const _amber = Color(0xFFE4A62A);
const _pageSize = 9;
const _colCheck = 42.0;
const _colGap = 8.0;
const _colVehicle = 175.0;
const _colPlate = 325.0;
const _colStatus = 60.0;

const _flexVehicle = 22;
const _flexBrand = 14;
const _flexType = 12;
const _flexPlate = 26;
const _flexDepot = 18;

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
  final _notificationKey = GlobalKey<_NotificationsCardState>();

  void _notify(String message, {bool isError = false}) {
    _notificationKey.currentState?.addNotification(message, isError: isError);
  }

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
      _notify('Unable to load vehicles: $error', isError: true);
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
      builder: (_) => VehicleFormDialog(
        api: widget.api,
        vehicle: vehicle,
        onError: (error) =>
            _notify('Unable to save vehicle: $error', isError: true),
      ),
    );
    if (changed == true && mounted) {
      await _reload(page: vehicle == null ? 0 : _currentPage);
      if (mounted) {
        _notify(
          vehicle == null
              ? 'Vehicle successfully registered.'
              : 'Vehicle successfully edited.',
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
                  ? 'Delete ${vehicles.length} selected vehicles?'
                  : 'Delete ${vehicles.first.vehicleName}?',
            ),
            content: const Text(
              'Are you sure you want to delete this vehicle from the list? ',
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
                icon: const Icon(Icons.delete_outlined),
                label: Text(many ? 'Deletion selected' : 'Delete vehicle'),
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
    if (archived > 0) {
      _notify(
        archived == 1
            ? 'Vehicle successfully deleted.'
            : '$archived vehicles successfully deleted.',
      );
    }
    if (failures.isNotEmpty) {
      _notify(
        '${failures.length} deletion(s) failed: ${failures.join(', ')}',
        isError: true,
      );
    }
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
            return Center(
              child: SizedBox(
                width: layoutWidth,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: sidebarWidth,
                          child: _ProfileSignOutBar(
                            user: widget.session,
                            onLogout: widget.onLogout,
                          ),
                        ),
                        SizedBox(width: gutter),
                        Expanded(
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _pine.withValues(alpha: .65),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Stark Group Limited',
                                style: GoogleFonts.greatVibes(
                                  color: _pine,
                                  fontSize: 42,
                                  height: 1.15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: gutter),
                        SizedBox(
                          width: showWorkArea ? workWidth : 280,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _NotificationsCard(key: _notificationKey),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: sidebarWidth,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _DashboardSidebar(
                                  summary: _summary,
                                  loading: _loading && _summary == null,
                                ),
                                const SizedBox(height: 14),
                                const Expanded(child: _ComingSoonCard()),
                              ],
                            ),
                          ),
                          SizedBox(width: gutter),
                          Expanded(child: _mainContent(items, layoutWidth)),
                          if (showWorkArea) ...[
                            SizedBox(width: gutter),
                            SizedBox(
                              width: workWidth,
                              child: ClipRect(
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
                                          child: _VehicleDetailsDrawer(
                                            key: ValueKey(_drawerVehicle!.id),
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
                                        )
                                      : const _EmptyVehicleDetailsDrawer(
                                          key: ValueKey('blank-workspace'),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerRight,
                      child: _DashboardFooter(),
                    ),
                    const SizedBox(height: 6),
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
      padding: EdgeInsets.symmetric(horizontal: narrow ? 4 : 8),
      child: Container(
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
                  onPressed: _loading || _archiving ? null : () => _reload(),
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
                        : const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: Text('Delete (${selectedOnPage.length})'),
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
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context)
                    .copyWith(scrollbars: false),
                child: _loading
                    ? const SingleChildScrollView(child: _RegistrySkeleton())
                    : pageItems.isEmpty
                    ? const Center(child: _EmptyRegistry())
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            ...pageItems.map(
                              (vehicle) => Padding(
                                key: ValueKey(vehicle.id),
                                padding: const EdgeInsets.only(bottom: 7),
                                child: _VehicleListRow(
                                  vehicle: vehicle,
                                  checked: _selectedIds.contains(vehicle.id),
                                  highlighted:
                                      _drawerOpen &&
                                      _drawerVehicle?.id == vehicle.id,
                                  onChecked: (checked) =>
                                      _toggleSelection(vehicle.id, checked),
                                  onTap: () => _openVehicle(vehicle),
                                ),
                              ),
                            ),
                          ],
                        ),
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
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
      padding: const EdgeInsets.all(18),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _border),
                  boxShadow: [
                    BoxShadow(
                      color: _pine.withValues(alpha: .06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.handyman_outlined,
                  color: _amber,
                  size: 26,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'More features are coming',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _pine,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
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
  Future<void> _openLink() async {
    final uri = Uri.parse(widget.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.url,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: _openLink,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered ? _pine : forest,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.2,
              decoration: _hovered
                  ? TextDecoration.underline
                  : TextDecoration.none,
              decorationColor: _pine,
            ),
          ),
        ),
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
      children: List.generate(_pageSize, (index) {
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
                SizedBox(
                  width: _colCheck - 12,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 18, height: 18, radius: 5),
                  ),
                ),
                Expanded(
                  flex: _flexVehicle,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 110, height: 12),
                  ),
                ),
                SizedBox(width: _colGap),
                Expanded(
                  flex: _flexBrand,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 70, height: 12),
                  ),
                ),
                SizedBox(width: _colGap),
                Expanded(
                  flex: _flexType,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 55, height: 12),
                  ),
                ),
                SizedBox(width: _colGap),
                Expanded(
                  flex: _flexPlate,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 140, height: 12),
                  ),
                ),
                SizedBox(width: _colGap),
                Expanded(
                  flex: _flexDepot,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _SkeletonBox(width: 90, height: 12),
                  ),
                ),
                SizedBox(width: _colGap),
                SizedBox(
                  width: _colStatus - 12,
                  child: Center(
                    child: _SkeletonBox(width: 12, height: 12, radius: 6),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  final FleetSummary? summary;
  final bool loading;
  const _DashboardSidebar({required this.summary, required this.loading});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFE3E8E1)),
      ),
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
        ],
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
        Expanded(
          flex: _flexVehicle,
          child: Text(
            'VEHICLE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _colGap),
        Expanded(
          flex: _flexBrand,
          child: Text(
            'BRAND',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _colGap),
        Expanded(
          flex: _flexType,
          child: Text(
            'TYPE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _colGap),
        Expanded(
          flex: _flexPlate,
          child: Text(
            'NUMBER PLATE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        const SizedBox(width: _colGap),
        Expanded(
          flex: _flexDepot,
          child: Text(
            'DEPOT',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
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
                  Expanded(
                    flex: _flexVehicle,
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
                  Expanded(
                    flex: _flexBrand,
                    child: Text(
                      vehicle.manufacturer,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _pine,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    flex: _flexType,
                    child: Text(
                      _nice(vehicle.vehicleType),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: _colGap),
                  Expanded(
                    flex: _flexPlate,
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
                    flex: _flexDepot,
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
  if (value.toUpperCase() == 'SUV') return 'SUV';
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

class _EmptyVehicleDetailsDrawer extends StatelessWidget {
  const _EmptyVehicleDetailsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF0F6F1),
            padding: const EdgeInsets.fromLTRB(23, 20, 23, 18),
            child: const Text(
              'Vehicle details',
              style: TextStyle(
                color: _pine,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car_filled_outlined,
                      size: 44,
                      color: _muted,
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Click on a vehicle to show details',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFFF0F6F1),
            padding: const EdgeInsets.fromLTRB(23, 20, 13, 10),
            child: Row(
              children: [
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Delete'),
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

class _ProfileSignOutBar extends StatefulWidget {
  final AuthSession user;
  final VoidCallback onLogout;
  const _ProfileSignOutBar({required this.user, required this.onLogout});
  @override
  State<_ProfileSignOutBar> createState() => _ProfileSignOutBarState();
}

class _ProfileSignOutBarState extends State<_ProfileSignOutBar> {
  bool _signOutHovered = false;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 17, 14, 17),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFFE3E8E1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: forest.withValues(alpha: .14),
                  radius: 20,
                  child: const Icon(Icons.person_outlined),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.user.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _pine,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _signOutHovered = true),
                  onExit: (_) => setState(() => _signOutHovered = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _signOutHovered ? accent : _panel,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _signOutHovered
                            ? accent
                            : const Color(0xFFE3E8E1),
                      ),
                      boxShadow: _signOutHovered
                          ? [
                              BoxShadow(
                                color: accent.withValues(alpha: .28),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ]
                          : null,
                    ),
                    child: IconButton(
                      tooltip: 'Sign out',
                      onPressed: widget.onLogout,
                      style: IconButton.styleFrom(
                        foregroundColor: _signOutHovered
                            ? Colors.white
                            : accent,
                        shape: const CircleBorder(),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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

class _LocalNotification {
  final int id;
  final String message;
  final bool isError;
  final DateTime createdAt;
  _LocalNotification(this.id, this.message, this.isError)
    : createdAt = DateTime.now();
}

/// Notifications are stored only in Flutter memory and never sent to Neon.
/// Floating-style tonal button notification stored only in Flutter memory.
class _NotificationsCard extends StatefulWidget {
  const _NotificationsCard({super.key});

  @override
  State<_NotificationsCard> createState() => _NotificationsCardState();
}

class _NotificationsCardState extends State<_NotificationsCard> {
  _LocalNotification? _current;
  Timer? _autoHideTimer;
  int _nextId = 0;

  void addNotification(String message, {bool isError = false}) {
    _autoHideTimer?.cancel();
    setState(() {
      _current = _LocalNotification(++_nextId, message, isError);
    });
    _autoHideTimer = Timer(const Duration(seconds: 4), _dismiss);
  }

  void _dismiss() {
    _autoHideTimer?.cancel();
    if (!mounted || _current == null) return;
    setState(() => _current = null);
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _current;
    final tint = item != null && item.isError ? accent : forest;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0.18, 0),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: item == null
          ? const SizedBox.shrink(key: ValueKey('no-notification'))
          : Tooltip(
              key: ValueKey(item.id),
              message: 'Click to dismiss',
              child: FilledButton.tonal(
                onPressed: _dismiss,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: item.isError ? accent : _pine,
                  elevation: 3,
                  shadowColor: _pine.withValues(alpha: .10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                    side: BorderSide(
                      color: item.isError
                          ? accent.withValues(alpha: .35)
                          : _border,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.isError
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color: tint,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        item.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.close_rounded, size: 18, color: _muted),
                  ],
                ),
              ),
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

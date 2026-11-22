import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'plan_models.dart';

const _maximumMapLatitude = 85.0511287798066;

/// A view of the places already in the local plan. Selecting a place only
/// changes the view; edits and saves stay with the existing parent callbacks.
class PlanMapPanel extends StatefulWidget {
  const PlanMapPanel({
    super.key,
    required this.plan,
    required this.onEditPlace,
    required this.onSetPin,
  });

  final GroupPlan plan;
  final void Function(bool primary) onEditPlace;
  final void Function(bool primary) onSetPin;

  @override
  State<PlanMapPanel> createState() => _PlanMapPanelState();
}

class _PlanLocation {
  const _PlanLocation({required this.primary, required this.place});

  final bool primary;
  final MeetingPlace place;

  String get role => primary ? 'Primary meeting place' : 'Backup meeting place';

  String get name {
    if (place.name.trim().isNotEmpty) return place.name.trim();
    if (place.address.trim().isNotEmpty) return place.address.trim();
    return role;
  }

  LatLng? get point {
    final latitude = place.latitude;
    final longitude = place.longitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > _maximumMapLatitude ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  String get pinStatus {
    if (!place.isSet) return 'No location details added';
    if (!place.hasCoordinates) return 'No map pin chosen';
    if (point == null) return 'Saved pin is outside this map’s coverage';
    return 'Pin shown on map';
  }
}

class _PlanMapPanelState extends State<PlanMapPanel> {
  // A narrow label still leaves enough room to fit two points at world zoom
  // on a 320-pixel phone. Full, wrapping names are also in the list and details.
  static const _markerWidth = 136.0;
  final _mapController = MapController();
  late bool _selectedPrimary;
  late String _geometrySignature;
  bool _mapReady = false;
  bool _tileError = false;
  bool _errorScheduled = false;
  int _tileRevision = 0;

  List<_PlanLocation> get _locations => [
    _PlanLocation(primary: true, place: widget.plan.primary),
    _PlanLocation(primary: false, place: widget.plan.backup),
  ];

  List<_PlanLocation> get _mappedLocations =>
      _locations.where((location) => location.point != null).toList();

  _PlanLocation get _selected => _PlanLocation(
    primary: _selectedPrimary,
    place: _selectedPrimary ? widget.plan.primary : widget.plan.backup,
  );

  String get _currentGeometry =>
      '${widget.plan.primary.latitude},${widget.plan.primary.longitude}|'
      '${widget.plan.backup.latitude},${widget.plan.backup.longitude}';

  double get _markerLabelHeight => math.max(
    48.0,
    MediaQuery.textScalerOf(context).scale(13) * 1.35 * 2 + 20,
  );

  double get _markerHeight => _markerLabelHeight + 36;

  EdgeInsets get _fitPadding => EdgeInsets.fromLTRB(
    _markerWidth / 2 + 10,
    _markerHeight + 12,
    _markerWidth / 2 + 10,
    32,
  );

  @override
  void initState() {
    super.initState();
    _selectedPrimary = widget.plan.primary.isSet || !widget.plan.backup.isSet;
    _geometrySignature = _currentGeometry;
  }

  @override
  void didUpdateWidget(covariant PlanMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GroupPlan is mutable, so compare the stored values rather than the
    // oldWidget's plan reference after an existing editor changes a place.
    if (_geometrySignature == _currentGeometry) return;
    _geometrySignature = _currentGeometry;
    if (_mappedLocations.isEmpty) {
      _mapReady = false;
      return;
    }
    _scheduleShowAll();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  List<LatLng> _fittingPoints(List<_PlanLocation> locations) {
    if (locations.isEmpty) return const [];
    final first = locations.first.point!;
    final result = <LatLng>[first];
    for (final location in locations.skip(1)) {
      final point = location.point!;
      // Fit the nearest wrapped copy, so 179E and 179W are two degrees apart.
      // These temporary longitudes are for the camera only. Stored coordinates
      // and the marker points remain exactly as the plan supplied them.
      final delta = ((point.longitude - first.longitude + 540) % 360) - 180;
      final fitted = LatLng(point.latitude, first.longitude + delta);
      if ((fitted.latitude - first.latitude).abs() > 1e-9 ||
          (fitted.longitude - first.longitude).abs() > 1e-9) {
        result.add(fitted);
      }
    }
    return result;
  }

  CameraFit? _cameraFit(List<_PlanLocation> locations) {
    final points = _fittingPoints(locations);
    if (points.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: points,
      padding: _fitPadding,
      minZoom: 0,
      maxZoom: 15,
    );
  }

  void _scheduleShowAll() {
    if (!mounted) return;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      if (mounted && _mapReady) _showAll();
    });
    // A callback registered during onMapReady's post-frame phase needs a
    // subsequent frame, even if the app is otherwise idle.
    binding.ensureVisualUpdate();
  }

  void _onMapReady() {
    if (!mounted || _mappedLocations.isEmpty) return;
    _mapReady = true;
    // The external controller retains its camera when the map is removed and
    // later reattached. Refit only after readiness, including a single new pin
    // whose initialCameraFit is null; never move inside this callback itself.
    _scheduleShowAll();
  }

  void _showAll() {
    if (!_mapReady) return;
    final locations = _mappedLocations;
    if (locations.isEmpty) return;
    final fit = _cameraFit(locations);
    if (fit == null) {
      _mapController.move(locations.first.point!, 15);
    } else {
      _mapController.fitCamera(fit);
    }
  }

  void _selectLocation(_PlanLocation location, {bool centerMap = false}) {
    setState(() => _selectedPrimary = location.primary);
    final point = location.point;
    if (centerMap && _mapReady && point != null) {
      _mapController.move(point, 15);
    }
  }

  void _zoom(double change) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + change).clamp(0.0, 18.0).toDouble(),
    );
  }

  void _showTileError() {
    if (!mounted || _tileError || _errorScheduled) return;
    _errorScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.addPostFrameCallback((_) {
      _errorScheduled = false;
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
    // Image errors can arrive while no frame is scheduled. Request one so the
    // deferred banner does not wait for a tap or other unrelated UI activity.
    binding.ensureVisualUpdate();
  }

  Future<void> _openAttribution() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      // Keep the location list usable if a link cannot be opened.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Map credits: https://www.openstreetmap.org/copyright'),
        ),
      );
    }
  }

  Marker _marker(_PlanLocation location) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = location.primary == _selectedPrimary;
    final labelColor = selected ? colors.onPrimary : colors.onSurface;
    return Marker(
      point: location.point!,
      width: _markerWidth,
      height: _markerHeight,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${location.role}: ${location.name}. Show location details.',
        excludeSemantics: true,
        onTap: () => _selectLocation(location),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _selectLocation(location),
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  height: _markerLabelHeight,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? colors.primary
                        : colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? colors.primary : colors.outline,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      location.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        color: labelColor,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.location_pin,
                  size: 36,
                  color: colors.primary,
                  shadows: [
                    Shadow(
                      color: colors.scrim.withValues(alpha: 0.85),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapView(List<_PlanLocation> locations) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ordered = [...locations]
      ..sort((a, b) {
        if (a.primary == b.primary) return 0;
        return a.primary == _selectedPrimary ? 1 : -1;
      });
    final sharePin =
        locations.length > 1 && _fittingPoints(locations).length == 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _showAll,
              style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.center_focus_strong),
              label: const Text('Show all'),
            ),
            IconButton(
              onPressed: () => _zoom(1),
              tooltip: 'Zoom in',
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.add),
            ),
            IconButton(
              onPressed: () => _zoom(-1),
              tooltip: 'Zoom out',
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.remove),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_tileError) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map imagery could not load. Saved names, pins, and notes '
                    'are still listed below.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => setState(() {
                      _tileError = false;
                      _tileRevision++;
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.onErrorContainer,
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Retry map imagery'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: _markerHeight + 300,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: locations.first.point!,
                initialZoom: 15,
                initialCameraFit: _cameraFit(locations),
                minZoom: 0,
                maxZoom: 18,
                backgroundColor: colors.surfaceContainerHighest,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
              ),
              children: [
                TileLayer(
                  key: ValueKey(_tileRevision),
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'BlackBoxPrototype',
                  maxNativeZoom: 19,
                  panBuffer: 0,
                  errorTileCallback: (_, error, stackTrace) => _showTileError(),
                ),
                MarkerLayer(markers: ordered.map(_marker).toList()),
              ],
            ),
          ),
        ),
        Material(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          child: Semantics(
            link: true,
            child: InkWell(
              onTap: _openAttribution,
              borderRadius: BorderRadius.circular(6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Center(
                    child: Text(
                      '© OpenStreetMap contributors',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurface,
                        decoration: TextDecoration.underline,
                        decorationColor: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (sharePin) ...[
          const SizedBox(height: 10),
          Text(
            'Both locations share one pin. Select either name below.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _locationRow(_PlanLocation location) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = location.primary == _selectedPrimary;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        selected: selected,
        child: Material(
          color: selected
              ? colors.primaryContainer
              : colors.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected ? colors.primary : colors.outlineVariant,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _selectLocation(location, centerMap: true),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    location.primary
                        ? Icons.location_on_outlined
                        : Icons.alt_route,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.role,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          location.place.isSet
                              ? location.name
                              : 'Not added yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          location.pinStatus,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: selected
                                ? foreground
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_circle_outline,
                      color: foreground,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationDetails(_PlanLocation location) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final place = location.place;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selected location', style: theme.textTheme.labelMedium),
                const SizedBox(height: 8),
                Text(location.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(location.role, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (place.address.trim().isNotEmpty &&
              place.address.trim() != location.name) ...[
            const SizedBox(height: 14),
            SelectableText(place.address),
          ],
          if (place.hasCoordinates) ...[
            const SizedBox(height: 14),
            Text('Saved coordinates', style: theme.textTheme.labelMedium),
            const SizedBox(height: 5),
            SelectableText(
              '${place.latitude!.toStringAsFixed(6)}, '
              '${place.longitude!.toStringAsFixed(6)}',
            ),
            if (location.point == null) ...[
              const SizedBox(height: 8),
              const Text(
                'This map cannot display the saved pin. Its polar coverage '
                'ends at about 85° north and south; the saved coordinates '
                'have not been changed.',
              ),
            ],
          ] else ...[
            const SizedBox(height: 14),
            const Text('Choose a map pin to show this location on the map.'),
          ],
          if (place.notes.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Meeting instructions', style: theme.textTheme.labelMedium),
            const SizedBox(height: 6),
            SelectableText(place.notes),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => widget.onEditPlace(location.primary),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.edit_outlined),
                label: Text(place.isSet ? 'Edit details' : 'Add location'),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onSetPin(location.primary),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.pin_drop_outlined),
                label: Text(place.hasCoordinates ? 'Change pin' : 'Choose pin'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locations = _mappedLocations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.cloud_outlined,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Map imagery needs internet. Location details below come from '
                'this local plan.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (locations.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, color: colors.primary, size: 30),
                const SizedBox(height: 12),
                Text(
                  _locations.any((location) => location.place.hasCoordinates)
                      ? 'No pins in map coverage'
                      : 'No pins to display',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _locations.any((location) => location.place.hasCoordinates)
                      ? 'The saved pins cannot be drawn on this map. Their '
                            'names and coordinates are still available below.'
                      : 'Select a location below, then choose its map pin. '
                            'Written addresses do not place pins automatically.',
                ),
              ],
            ),
          )
        else
          _mapView(locations),
        const SizedBox(height: 24),
        Text('Locations in this plan', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Select a name to see its full details.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        ..._locations.map(_locationRow),
        const SizedBox(height: 6),
        _locationDetails(_selected),
        const SizedBox(height: 16),
      ],
    );
  }
}

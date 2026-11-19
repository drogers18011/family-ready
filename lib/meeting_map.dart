import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Picks a draft point. The parent decides when to save the meeting place.
///
/// Tiles are requested only for normal interactive viewing. This is not an
/// offline map downloader; the plan's coordinates are stored separately.
class MeetingMapPicker extends StatefulWidget {
  const MeetingMapPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onSelected,
  });

  final double? initialLatitude;
  final double? initialLongitude;
  final void Function(double latitude, double longitude) onSelected;

  @override
  State<MeetingMapPicker> createState() => _MeetingMapPickerState();
}

class _MeetingMapPickerState extends State<MeetingMapPicker> {
  static const _defaultCenter = LatLng(39.5, -98.35);
  static const _maximumMapLatitude = 85.0511287798066;
  final _mapController = MapController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  LatLng? _selected;
  String? _coordinateError;
  bool _mapReady = false;
  bool _tileError = false;
  bool _errorScheduled = false;
  int _tileRevision = 0;

  @override
  void initState() {
    super.initState();
    final latitude = widget.initialLatitude;
    final longitude = widget.initialLongitude;
    if (_validCoordinates(latitude, longitude)) {
      _selected = LatLng(latitude!, longitude!);
      _updateFields(_selected!);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  bool _validCoordinates(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  LatLng _cameraCenter(LatLng point) => LatLng(
    point.latitude.clamp(-_maximumMapLatitude, _maximumMapLatitude).toDouble(),
    point.longitude,
  );

  bool get _outsideMapCoverage =>
      _selected != null && _selected!.latitude.abs() > _maximumMapLatitude;

  void _updateFields(LatLng point) {
    _latitude.text = point.latitude.toStringAsFixed(6);
    _longitude.text = point.longitude.toStringAsFixed(6);
  }

  void _selectPoint(LatLng point, {bool moveMap = false}) {
    // World wrapping can return longitudes outside the usual geographic range.
    final normalizedLongitude = ((point.longitude + 180) % 360) - 180;
    final selected = LatLng(point.latitude, normalizedLongitude);
    if (!_validCoordinates(selected.latitude, selected.longitude)) return;
    setState(() {
      _selected = selected;
      _coordinateError = null;
      _updateFields(selected);
    });
    if (moveMap && _mapReady) {
      _mapController.move(_cameraCenter(selected), 15);
    }
    widget.onSelected(selected.latitude, selected.longitude);
  }

  void _applyCoordinates() {
    final latitude = double.tryParse(_latitude.text.trim());
    final longitude = double.tryParse(_longitude.text.trim());
    if (!_validCoordinates(latitude, longitude)) {
      setState(() {
        _coordinateError =
            'Enter latitude from -90 to 90 and longitude from -180 to 180, '
            'using decimal degrees.';
      });
      return;
    }
    _selectPoint(LatLng(latitude!, longitude!), moveMap: true);
  }

  void _zoom(double change) {
    if (!_mapReady) return;
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + change).clamp(2.0, 18.0).toDouble(),
    );
  }

  void _showTileError() {
    // Image callbacks can arrive while a frame is being built.
    if (!mounted || _tileError || _errorScheduled) return;
    _errorScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorScheduled = false;
      if (mounted && !_tileError) setState(() => _tileError = true);
    });
  }

  Future<void> _openAttribution() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      // Keep the picker usable when the browser blocks a new tab.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text('Map credits: https://www.openstreetmap.org/copyright'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = _selected;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Drag to move, zoom in, then click or tap your meeting point. '
          'The map needs an internet connection.',
        ),
        const SizedBox(height: 12),
        if (_tileError) ...[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Some map tiles could not load. Check your connection '
                    'or enter coordinates below.',
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _tileError = false;
                    _tileRevision++;
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 310,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _cameraCenter(selected ?? _defaultCenter),
                    initialZoom: selected == null ? 3.5 : 15,
                    minZoom: 2,
                    maxZoom: 18,
                    backgroundColor: const Color(0xFFE6ECE7),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () => _mapReady = true,
                    onTap: (_, point) => _selectPoint(point),
                  ),
                  children: [
                    TileLayer(
                      key: ValueKey(_tileRevision),
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'FamilyReadyPrototype',
                      maxNativeZoom: 19,
                      panBuffer: 0,
                      errorTileCallback: (_, error, stackTrace) =>
                          _showTileError(),
                    ),
                    if (selected != null && !_outsideMapCoverage)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: selected,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: Semantics(
                              label: 'Selected meeting point',
                              child: const Icon(
                                Icons.location_pin,
                                color: Color(0xFF285B48),
                                size: 48,
                                shadows: [
                                  Shadow(color: Colors.white, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    elevation: 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _zoom(1),
                          tooltip: 'Zoom in',
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          onPressed: () => _zoom(-1),
                          tooltip: 'Zoom out',
                          icon: const Icon(Icons.remove),
                        ),
                        if (selected != null)
                          IconButton(
                            onPressed: () {
                              if (_mapReady) {
                                _mapController.move(
                                  _cameraCenter(selected),
                                  15,
                                );
                              }
                            },
                            tooltip: 'Return to selected point',
                            icon: const Icon(Icons.center_focus_strong),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: _openAttribution,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1F513D),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          selected == null
              ? 'No pin selected yet.'
              : 'Selected: ${selected.latitude.toStringAsFixed(6)}, '
                    '${selected.longitude.toStringAsFixed(6)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (_outsideMapCoverage) ...[
          const SizedBox(height: 6),
          const Text(
            'These coordinates are outside this map’s polar coverage. '
            'The coordinates are kept, but a pin cannot be shown here.',
          ),
        ],
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Latitude',
                  hintText: '39.500000',
                ),
                onSubmitted: (_) => _applyCoordinates(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-98.350000',
                ),
                onSubmitted: (_) => _applyCoordinates(),
              ),
            ),
          ],
        ),
        if (_coordinateError != null) ...[
          const SizedBox(height: 8),
          Text(_coordinateError!, style: TextStyle(color: colors.error)),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _applyCoordinates,
            icon: const Icon(Icons.pin_drop_outlined),
            label: const Text('Use coordinates'),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Typing an address elsewhere does not move this pin. '
          'Confirm the pin and written address describe the same place. '
          'Offline map downloads are not included in this prototype.',
          style: TextStyle(fontSize: 12, color: Color(0xFF59655D)),
        ),
      ],
    );
  }
}

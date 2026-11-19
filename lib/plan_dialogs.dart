import 'package:material_ui/material_ui.dart';

import 'meeting_map.dart';
import 'plan_models.dart';

Future<({double latitude, double longitude})?> chooseMeetingPoint(
  BuildContext context, {
  double? latitude,
  double? longitude,
}) => showDialog<({double latitude, double longitude})>(
  context: context,
  builder: (_) => _PinDialog(latitude: latitude, longitude: longitude),
);

Future<MeetingPlace?> editMeetingPlace(
  BuildContext context, {
  required MeetingPlace initial,
  required bool primary,
}) => showDialog<MeetingPlace>(
  context: context,
  builder: (_) => _PlaceEditor(initial: initial, primary: primary),
);

class _PlaceEditor extends StatefulWidget {
  const _PlaceEditor({required this.initial, required this.primary});
  final MeetingPlace initial;
  final bool primary;

  @override
  State<_PlaceEditor> createState() => _PlaceEditorState();
}

class _PlaceEditorState extends State<_PlaceEditor> {
  late String _name = widget.initial.name;
  late String _address = widget.initial.address;
  late String _notes = widget.initial.notes;
  late double? _latitude = widget.initial.latitude;
  late double? _longitude = widget.initial.longitude;

  Future<void> _pickPin() async {
    final point = await chooseMeetingPoint(
      context,
      latitude: _latitude,
      longitude: _longitude,
    );
    if (point == null || !mounted) return;
    setState(() {
      _latitude = point.latitude;
      _longitude = point.longitude;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.primary ? 'Primary meeting place' : 'Backup meeting place',
    ),
    content: SizedBox(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            initialValue: _name,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Location name'),
            onChanged: (value) => _name = value,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _address,
            maxLength: 240,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Written address or landmark',
            ),
            onChanged: (value) => _address = value,
          ),
          const SizedBox(height: 16),
          const Text(
            'MAP PIN',
            style: TextStyle(fontSize: 12, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            _latitude == null
                ? 'No map pin added.'
                : '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickPin,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _latitude == null ? 'Choose on map' : 'View / change pin',
                ),
              ),
              if (_latitude != null)
                TextButton(
                  onPressed: () => setState(() {
                    _latitude = null;
                    _longitude = null;
                  }),
                  child: const Text('Remove pin'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'The map needs internet. Check that your pin and written address '
            'describe the same place; one does not update the other.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 20),
          TextFormField(
            initialValue: _notes,
            maxLength: 1200,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Meeting instructions',
              hintText: 'Exact entrance, when to use the backup, and what to do if plans change.',
              alignLabelWithHint: true,
            ),
            onChanged: (value) => _notes = value,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          MeetingPlace(
            name: _name.trim(),
            address: _address.trim(),
            notes: _notes.trim(),
            latitude: _latitude,
            longitude: _longitude,
          ),
        ),
        child: const Text('Save meeting place'),
      ),
    ],
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({this.latitude, this.longitude});
  final double? latitude;
  final double? longitude;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  late double? _latitude = widget.latitude;
  late double? _longitude = widget.longitude;

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Choose a meeting point'),
    content: SizedBox(
      width: 640,
      child: MeetingMapPicker(
        initialLatitude: widget.latitude,
        initialLongitude: widget.longitude,
        onSelected: (latitude, longitude) => setState(() {
          _latitude = latitude;
          _longitude = longitude;
        }),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _latitude == null
            ? null
            : () => Navigator.pop(context, (
                latitude: _latitude!,
                longitude: _longitude!,
              )),
        child: const Text('Use selected pin'),
      ),
    ],
  );
}

Future<Supply?> editSupplyDialog(
  BuildContext context, {
  required List<FamilyMember> members,
  required String newId,
  Supply? initial,
}) {
  final form = GlobalKey<FormState>();
  var name = initial?.name ?? '';
  var quantity = initial?.quantity ?? '';
  var category = initial?.category ?? 'Other';
  var notes = initial?.notes ?? '';
  var person = initial?.assignedTo ?? '';
  return showDialog<Supply>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(initial == null ? 'Add a supply' : 'Edit supply'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                autofocus: true,
                maxLength: 140,
                decoration: const InputDecoration(labelText: 'Supply name'),
                onChanged: (value) => name = value,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? 'Please enter a supply item.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: quantity,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Quantity (optional)',
                  hintText: 'For example: 2 flashlights or 1 bag',
                ),
                onChanged: (value) => quantity = value,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: supplyCategories
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => category = value ?? 'Other',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: person,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Who brings it?'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Unassigned')),
                  ...members.map(
                    (member) => DropdownMenuItem(
                      value: member.id,
                      child: Text(member.name),
                    ),
                  ),
                ],
                onChanged: (value) => person = value ?? '',
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: notes,
                maxLength: 800,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Where it is stored, sizes, or anything to check.',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => notes = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            Navigator.pop(
              dialogContext,
              Supply(
                initial?.id ?? newId,
                name.trim(),
                quantity: quantity.trim(),
                category: category,
                notes: notes.trim(),
                assignedTo: person.isEmpty ? null : person,
                packed: initial?.packed ?? false,
              ),
            );
          },
          child: const Text('Save supply'),
        ),
      ],
    ),
  );
}

import 'dart:convert';

/// Personal items never enter the group's plan or its backup document.
const maxPersonalPackItems = 500;
const maxPersonalPacklistBytes = 2 * 1024 * 1024;

String _packString(
  Object? value,
  String label,
  int maximum, {
  bool allowEmpty = false,
}) {
  if (value is! String ||
      value.length > maximum ||
      (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('Invalid personal packing-list $label.');
  }
  return value;
}

class PersonalPackItem {
  factory PersonalPackItem({
    required String id,
    required String name,
    String quantity = '',
    String notes = '',
    bool packed = false,
  }) {
    _packString(id, 'item ID', 100);
    if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(id)) {
      throw const FormatException('Invalid personal packing-list item ID.');
    }
    return PersonalPackItem._(
      id: id,
      name: _packString(name, 'item name', 140),
      quantity: _packString(quantity, 'quantity', 80, allowEmpty: true),
      notes: _packString(notes, 'notes', 1200, allowEmpty: true),
      packed: packed,
    );
  }

  const PersonalPackItem._({
    required this.id,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.packed,
  });

  final String id;
  final String name;
  final String quantity;
  final String notes;
  final bool packed;

  PersonalPackItem copyWith({
    String? name,
    String? quantity,
    String? notes,
    bool? packed,
  }) => PersonalPackItem(
    id: id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    notes: notes ?? this.notes,
    packed: packed ?? this.packed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'notes': notes,
    'packed': packed,
  };

  factory PersonalPackItem.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['packed'] is! bool) {
      throw const FormatException('Invalid personal packing-list item.');
    }
    return PersonalPackItem(
      id: _packString(value['id'], 'item ID', 100),
      name: _packString(value['name'], 'item name', 140),
      quantity: _packString(
        value['quantity'],
        'quantity',
        80,
        allowEmpty: true,
      ),
      notes: _packString(value['notes'], 'notes', 1200, allowEmpty: true),
      packed: value['packed'] as bool,
    );
  }
}

class PersonalPacklist {
  factory PersonalPacklist({
    Iterable<PersonalPackItem> items = const [],
    DateTime? savedAt,
  }) {
    final copied = List<PersonalPackItem>.unmodifiable(items);
    if (copied.length > maxPersonalPackItems) {
      throw const FormatException(
        'A personal checklist supports up to 500 items.',
      );
    }
    if (copied.map((item) => item.id).toSet().length != copied.length) {
      throw const FormatException(
        'Personal packing-list item IDs must be unique.',
      );
    }
    return PersonalPacklist._(copied, savedAt?.toUtc());
  }

  const PersonalPacklist._(this.items, this.savedAt);

  final List<PersonalPackItem> items;
  final DateTime? savedAt;

  int get packedCount => items.where((item) => item.packed).length;

  PersonalPacklist withItems(Iterable<PersonalPackItem> value) =>
      PersonalPacklist(items: value, savedAt: savedAt);

  PersonalPacklist saved(DateTime value) =>
      PersonalPacklist(items: items, savedAt: value);

  Map<String, Object?> toJson() => {
    'kind': 'black_box.personal_packlist',
    'version': 1,
    'items': items.map((item) => item.toJson()).toList(),
    'savedAt': savedAt?.toIso8601String(),
  };

  String encode() {
    final raw = jsonEncode(toJson());
    if (utf8.encode(raw).length > maxPersonalPacklistBytes) {
      throw const FormatException(
        'This personal checklist is too large to save.',
      );
    }
    return raw;
  }

  factory PersonalPacklist.decode(String raw) {
    // Reject an oversized record before decoding it.
    if (raw.length > maxPersonalPacklistBytes ||
        utf8.encode(raw).length > maxPersonalPacklistBytes) {
      throw const FormatException('The saved personal checklist is too large.');
    }
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['kind'] != 'black_box.personal_packlist' ||
        value['version'] != 1 ||
        value['items'] is! List) {
      throw const FormatException('Unsupported personal checklist format.');
    }
    final rawItems = value['items'] as List;
    if (rawItems.length > maxPersonalPackItems) {
      throw const FormatException(
        'The saved personal checklist has too many items.',
      );
    }
    DateTime? savedAt;
    if (value['savedAt'] != null) {
      final date = value['savedAt'];
      if (date is! String || date.length > 50) {
        throw const FormatException('Invalid personal checklist save time.');
      }
      savedAt = DateTime.tryParse(date);
      if (savedAt == null) {
        throw const FormatException('Invalid personal checklist save time.');
      }
    }
    return PersonalPacklist(
      items: rawItems.map(PersonalPackItem.fromJson),
      savedAt: savedAt,
    );
  }

  String readableText({required bool unsavedChanges}) {
    final output = StringBuffer()
      ..writeln('BLACK BOX - MY PACKING LIST')
      ..writeln('Personal list; separate from the shared plan.')
      ..writeln('$packedCount of ${items.length} items packed.');
    if (unsavedChanges) {
      output.writeln('Contains changes not yet saved in the app.');
    } else if (savedAt != null) {
      output.writeln('Last saved: ${savedAt!.toIso8601String()}');
    }
    output.writeln();
    for (final item in items) {
      output.writeln('${item.packed ? '[x]' : '[ ]'} ${item.name}');
      if (item.quantity.isNotEmpty)
        output.writeln('  Quantity: ${item.quantity}');
      if (item.notes.isNotEmpty) output.writeln('  Notes: ${item.notes}');
      output.writeln();
    }
    return output.toString();
  }
}

class PersonalPacklistSnapshot {
  const PersonalPacklistSnapshot({
    required this.document,
    this.rawStored,
    this.loadError,
    this.saveError,
    this.dirty = false,
  });

  final PersonalPacklist document;
  final String? rawStored;
  final String? loadError;
  final String? saveError;
  final bool dirty;
}

/// Serializes reads and writes across successive widget instances. A failed
/// save retains the working draft in this app session and keeps the last
/// successfully written record. Corrupt stored data is never auto-replaced.
class PersonalPacklistStore {
  PersonalPacklistStore({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    DateTime Function()? now,
  }) : _read = read,
       _write = write,
       _now = now ?? DateTime.now;

  static const storageKey = 'black_box.personal_packlist.v1';
  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final DateTime Function() _now;
  Future<void> _tail = Future<void>.value();
  PersonalPacklistSnapshot? _snapshot;

  Future<T> _ordered<T>(Future<T> Function() action) {
    final operation = _tail.then((_) => action());
    _tail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<PersonalPacklistSnapshot> _load({bool retry = false}) async {
    if (_snapshot != null && (!retry || _snapshot!.dirty)) return _snapshot!;
    String? raw;
    try {
      raw = await _read(storageKey);
      return _snapshot = PersonalPacklistSnapshot(
        document: raw == null
            ? PersonalPacklist()
            : PersonalPacklist.decode(raw),
        rawStored: raw,
      );
    } catch (_) {
      return _snapshot = PersonalPacklistSnapshot(
        document: PersonalPacklist(),
        rawStored: raw,
        loadError:
            'The personal checklist could not be read. '
            'Its saved data has not been replaced.',
      );
    }
  }

  Future<PersonalPacklistSnapshot> load({bool retry = false}) =>
      _ordered(() => _load(retry: retry));

  Future<PersonalPacklistSnapshot> _persist(PersonalPacklist document) async {
    final previous = await _load();
    if (previous.loadError != null) {
      throw StateError(
        'Resolve the personal checklist read error before editing.',
      );
    }
    _snapshot = PersonalPacklistSnapshot(
      document: document,
      rawStored: previous.rawStored,
      dirty: true,
    );
    try {
      final saved = document.saved(_now());
      final encoded = saved.encode();
      await _write(storageKey, encoded);
      return _snapshot = PersonalPacklistSnapshot(
        document: saved,
        rawStored: encoded,
      );
    } catch (_) {
      return _snapshot = PersonalPacklistSnapshot(
        document: document,
        rawStored: previous.rawStored,
        dirty: true,
        saveError:
            'Saving failed. These changes are only in this open app. '
            'Retry saving or copy your list before closing the app.',
      );
    }
  }

  Future<PersonalPacklistSnapshot> save(PersonalPacklist document) =>
      _ordered(() => _persist(document));

  Future<PersonalPacklistSnapshot> retrySave() => _ordered(() async {
    final current = await _load();
    if (!current.dirty) return current;
    return _persist(current.document);
  });
}

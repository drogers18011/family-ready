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
    bool owned = false,
    bool packed = false,
    String? sourceSuggestionId,
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
      owned: owned || packed,
      packed: packed,
      sourceSuggestionId: _suggestionId(sourceSuggestionId),
    );
  }

  const PersonalPackItem._({
    required this.id,
    required this.name,
    required this.quantity,
    required this.notes,
    required this.owned,
    required this.packed,
    required this.sourceSuggestionId,
  });

  final String id;
  final String name;
  final String quantity;
  final String notes;

  /// Explicit confirmation that this item is physically available. A shopping
  /// link click or an unverified order never changes this value.
  final bool owned;
  final bool packed;
  final String? sourceSuggestionId;

  PersonalPackItem copyWith({
    String? name,
    String? quantity,
    String? notes,
    bool? owned,
    bool? packed,
  }) {
    // Packing confirms possession. Explicitly clearing ownership also clears
    // packed status, including when callers supply conflicting flags.
    final nextPacked = owned == false ? false : packed ?? this.packed;
    return PersonalPackItem(
      id: id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      notes: notes ?? this.notes,
      owned: nextPacked || (owned ?? this.owned),
      packed: nextPacked,
      sourceSuggestionId: sourceSuggestionId,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'notes': notes,
    'owned': owned,
    'packed': packed,
    'sourceSuggestionId': sourceSuggestionId,
  };

  factory PersonalPackItem.fromJson(Object? value, {int version = 2}) {
    if (value is! Map<String, dynamic> || value['packed'] is! bool) {
      throw const FormatException('Invalid personal packing-list item.');
    }
    final packed = value['packed'] as bool;
    final owned = version == 1 ? packed : value['owned'];
    if (owned is! bool || (packed && !owned)) {
      throw const FormatException('Invalid personal item ownership state.');
    }
    final suggestion = version == 1 ? null : value['sourceSuggestionId'];
    if (suggestion != null && suggestion is! String) {
      throw const FormatException('Invalid personal item suggestion ID.');
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
      owned: owned,
      packed: packed,
      sourceSuggestionId: suggestion as String?,
    );
  }
}

String? _suggestionId(String? value) {
  if (value != null &&
      (value.length > 80 || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value))) {
    throw const FormatException('Invalid personal item suggestion ID.');
  }
  return value;
}

class PersonalPacklist {
  factory PersonalPacklist({
    Iterable<PersonalPackItem> items = const [],
    DateTime? savedAt,
    bool migratedFromVersion1 = false,
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
    final suggestions = copied
        .map((item) => item.sourceSuggestionId)
        .whereType<String>()
        .toList();
    if (suggestions.toSet().length != suggestions.length) {
      throw const FormatException(
        'A suggestion can appear only once in My pack.',
      );
    }
    return PersonalPacklist._(copied, savedAt?.toUtc(), migratedFromVersion1);
  }

  const PersonalPacklist._(this.items, this.savedAt, this.migratedFromVersion1);

  final List<PersonalPackItem> items;
  final DateTime? savedAt;

  /// A session-only explanation for the first migration from the older list.
  final bool migratedFromVersion1;

  int get packedCount => items.where((item) => item.packed).length;
  int get ownedCount => items.where((item) => item.owned).length;
  int get unconfirmedCount => items.where((item) => !item.owned).length;

  PersonalPacklist withItems(Iterable<PersonalPackItem> value) =>
      PersonalPacklist(
        items: value,
        savedAt: savedAt,
        migratedFromVersion1: migratedFromVersion1,
      );

  PersonalPacklist saved(DateTime value) => PersonalPacklist(
    items: items,
    savedAt: value,
    migratedFromVersion1: migratedFromVersion1,
  );

  Map<String, Object?> toJson() => {
    'kind': 'black_box.personal_packlist',
    'version': 2,
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
        value['version'] is! int ||
        (value['version'] != 1 && value['version'] != 2) ||
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
      items: rawItems.map(
        (item) =>
            PersonalPackItem.fromJson(item, version: value['version'] as int),
      ),
      savedAt: savedAt,
      migratedFromVersion1: value['version'] == 1,
    );
  }

  String readableText({required bool unsavedChanges}) {
    final output = StringBuffer()
      ..writeln('BLACK BOX - MY PACKING LIST')
      ..writeln('Personal list; separate from the shared plan.')
      ..writeln(
        '$ownedCount owned; $packedCount of ${items.length} items packed.',
      );
    if (unsavedChanges) {
      output.writeln('Contains changes not yet saved in the app.');
    } else if (savedAt != null) {
      output.writeln('Last saved: ${savedAt!.toIso8601String()}');
    }
    output.writeln();
    for (final item in items) {
      output.writeln('${item.packed ? '[x]' : '[ ]'} ${item.name}');
      output.writeln('  ${item.owned ? 'Owned' : 'Not marked owned'}');
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

class SuggestedPackResult {
  const SuggestedPackResult({
    required this.snapshot,
    required this.item,
    required this.added,
  });
  final PersonalPacklistSnapshot snapshot;
  final PersonalPackItem item;
  final bool added;
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
  final _listeners = <void Function(PersonalPacklistSnapshot)>{};
  int _nextId = 0;

  void addListener(void Function(PersonalPacklistSnapshot) listener) =>
      _listeners.add(listener);

  void removeListener(void Function(PersonalPacklistSnapshot) listener) =>
      _listeners.remove(listener);

  PersonalPacklistSnapshot _publish(PersonalPacklistSnapshot value) {
    _snapshot = value;
    for (final listener in _listeners.toList(growable: false)) {
      try {
        listener(value);
      } catch (_) {
        // A detached/broken view must not change a storage operation's outcome.
      }
    }
    return value;
  }

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
      return _publish(
        PersonalPacklistSnapshot(
          document: raw == null
              ? PersonalPacklist()
              : PersonalPacklist.decode(raw),
          rawStored: raw,
        ),
      );
    } catch (_) {
      return _publish(
        PersonalPacklistSnapshot(
          document: PersonalPacklist(),
          rawStored: raw,
          loadError:
              'The personal checklist could not be read. '
              'Its saved data has not been replaced.',
        ),
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
    _publish(
      PersonalPacklistSnapshot(
        document: document,
        rawStored: previous.rawStored,
        dirty: true,
      ),
    );
    try {
      final saved = document.saved(_now());
      final encoded = saved.encode();
      await _write(storageKey, encoded);
      return _publish(
        PersonalPacklistSnapshot(document: saved, rawStored: encoded),
      );
    } catch (_) {
      return _publish(
        PersonalPacklistSnapshot(
          document: document,
          rawStored: previous.rawStored,
          dirty: true,
          saveError:
              'Saving failed. These changes are only in this open app. '
              'Retry saving or copy your list before closing the app.',
        ),
      );
    }
  }

  Future<PersonalPacklistSnapshot> save(PersonalPacklist document) =>
      _ordered(() => _persist(document));

  /// Edits the latest in-memory draft inside the write queue. Views should use
  /// this instead of replacing a whole document captured before a route opened.
  Future<PersonalPacklistSnapshot> mutate(
    PersonalPacklist Function(PersonalPacklist current) change,
  ) => _ordered(() async {
    final current = await _load();
    if (current.loadError != null) {
      throw StateError(
        'Resolve the personal checklist read error before editing.',
      );
    }
    return _persist(change(current.document));
  });

  /// Adds an item by stable catalog ID, or returns the existing user-edited
  /// item. This does not record, detect, or verify an Amazon order. Pass
  /// confirmedOwned only after the user explicitly confirms possession.
  Future<SuggestedPackResult> addSuggestedItem({
    required String suggestionId,
    required String name,
    String quantity = '',
    String notes = '',
    bool confirmedOwned = false,
  }) => _ordered(() async {
    final catalogId = _suggestionId(suggestionId)!;
    final current = await _load();
    if (current.loadError != null) {
      throw StateError(
        'Resolve the personal checklist read error before adding items.',
      );
    }
    PersonalPackItem? existing;
    for (final item in current.document.items) {
      if (item.sourceSuggestionId == catalogId) {
        existing = item;
        break;
      }
    }
    if (existing != null) {
      if (!confirmedOwned || existing.owned) {
        return SuggestedPackResult(
          snapshot: current,
          item: existing,
          added: false,
        );
      }
      final updated = existing.copyWith(owned: true);
      final snapshot = await _persist(
        current.document.withItems([
          for (final item in current.document.items)
            if (item.id == updated.id) updated else item,
        ]),
      );
      return SuggestedPackResult(
        snapshot: snapshot,
        item: updated,
        added: false,
      );
    }
    if (current.document.items.length >= maxPersonalPackItems) {
      throw const FormatException('My pack has reached its 500-item limit.');
    }
    var id = 'suggestion_${_now().microsecondsSinceEpoch}_${_nextId++}';
    while (current.document.items.any((item) => item.id == id)) {
      id = 'suggestion_${_now().microsecondsSinceEpoch}_${_nextId++}';
    }
    final item = PersonalPackItem(
      id: id,
      name: name,
      quantity: quantity,
      notes: notes,
      owned: confirmedOwned,
      sourceSuggestionId: catalogId,
    );
    final snapshot = await _persist(
      current.document.withItems([...current.document.items, item]),
    );
    return SuggestedPackResult(snapshot: snapshot, item: item, added: true);
  });

  Future<PersonalPacklistSnapshot> retrySave() => _ordered(() async {
    final current = await _load();
    if (!current.dirty) return current;
    return _persist(current.document);
  });
}

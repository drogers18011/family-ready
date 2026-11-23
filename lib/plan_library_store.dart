import 'dart:convert';
import 'dart:math';

import 'plan_models.dart';
import 'plan_store.dart';

/// Library metadata is separate from each plan and from personal lists/guides.
/// The original record is registered in place, without rewriting its bytes.
class PlanLibraryEntry {
  const PlanLibraryEntry({
    required this.id,
    required this.name,
    required this.createdAt,
    this.archived = false,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final bool archived;

  PlanLibraryEntry withArchived(bool value) => PlanLibraryEntry(
    id: id,
    name: name,
    createdAt: createdAt,
    archived: value,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'archived': archived,
  };

  factory PlanLibraryEntry.fromJson(Object? value) {
    final map = readMap(value);
    final id = readString(map, 'id');
    if (!_validPlanId(id)) {
      throw const FormatException('A plan library identifier is invalid.');
    }
    final archived = map['archived'];
    final createdAt = DateTime.tryParse(readString(map, 'createdAt'));
    if (archived is! bool || createdAt == null) {
      throw const FormatException('A plan library entry is incomplete.');
    }
    return PlanLibraryEntry(
      id: id,
      name: readString(map, 'name'),
      createdAt: createdAt.toUtc(),
      archived: archived,
    );
  }
}

class PlanLibraryManifest {
  PlanLibraryManifest._({
    required this.activeId,
    required List<PlanLibraryEntry> entries,
  }) : entries = List.unmodifiable(entries);

  final String activeId;
  final List<PlanLibraryEntry> entries;

  PlanLibraryEntry get activeEntry =>
      entries.firstWhere((entry) => entry.id == activeId);

  PlanLibraryEntry? entry(String id) {
    for (final entry in entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'activeId': activeId,
    'entries': entries.map((entry) => entry.toJson()).toList(),
  };

  factory PlanLibraryManifest.fromJson(Object? value) {
    final map = readMap(value);
    if (map['version'] is! int || map['version'] != 1) {
      throw const FormatException(
        'This plan library version is not supported.',
      );
    }
    final rawEntries = map['entries'];
    if (rawEntries is! List || rawEntries.isEmpty) {
      throw const FormatException('The plan library has no entries.');
    }
    final entries = rawEntries.map(PlanLibraryEntry.fromJson).toList();
    final ids = <String>{};
    for (final entry in entries) {
      if (!ids.add(entry.id)) {
        throw const FormatException(
          'The plan library contains duplicate identifiers.',
        );
      }
    }
    final activeId = readString(map, 'activeId');
    final active = entries.where((entry) => entry.id == activeId);
    if (active.isEmpty || active.single.archived) {
      throw const FormatException('The selected plan is missing or archived.');
    }
    // The original slot is never deleted, even when archived. Keeping it in
    // the directory prevents accidental hiding of legacy recovery records.
    if (!ids.contains(PlanLibraryStore.originalPlanId)) {
      throw const FormatException('The original plan entry is missing.');
    }
    return PlanLibraryManifest._(activeId: activeId, entries: entries);
  }
}

class PlanLibraryItem {
  const PlanLibraryItem({
    required this.entry,
    required this.plan,
    this.error,
    this.isSample = false,
  });

  final PlanLibraryEntry entry;
  final GroupPlan? plan;
  final String? error;
  final bool isSample;

  bool get available => plan != null;
  String get displayName => plan?.groupName ?? entry.name;
}

class PlanLibraryException implements Exception {
  const PlanLibraryException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Initialization found no existing directory, but could not save the first
/// directory. The caller may keep reading the original plan using [manifest]
/// while clearly reporting that library initialization needs to be retried.
/// This fallback must never be used for an unreadable or invalid directory.
class PlanLibraryInitializationFailure extends PlanLibraryException {
  const PlanLibraryInitializationFailure({
    required this.manifest,
    required this.cause,
  }) : super(
         'The plan list could not be saved. Existing plan records have not '
         'been replaced. Try opening Plans again to initialize the list.',
       );

  final PlanLibraryManifest manifest;
  final Object cause;
}

/// Per-plan records retain the existing GroupPlan JSON format. The manifest
/// changes only the directory/selection, never the stored plan or its backups.
///
/// Calls on this instance are serialized. The caller must also finish or block
/// active-plan edits before switching, copying, or archiving. This local store
/// is not an account, cloud sync, or cross-process transaction service.
class PlanLibraryStore {
  PlanLibraryStore({
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
    DateTime Function()? clock,
    String Function()? idFactory,
  }) : _read = read,
       _write = write,
       _clock = clock ?? DateTime.now,
       _idFactory = idFactory ?? _randomPlanId;

  static const manifestKey = 'black_box.plan_library.v1';
  static const originalPlanId = 'original';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final DateTime Function() _clock;
  final String Function() _idFactory;
  Future<void> _tail = Future<void>.value();

  static PlanStorageKeys keysFor(String id) {
    if (!_validPlanId(id)) {
      throw const PlanLibraryException('The plan identifier is invalid.');
    }
    if (id == originalPlanId) {
      return const PlanStorageKeys(
        current: PlanStore.currentKey,
        previous: PlanStore.previousKey,
        recovery: PlanStore.recoveryKey,
      );
    }
    return PlanStorageKeys(
      current: 'black_box.plans.$id.current.v1',
      previous: 'black_box.plans.$id.previous',
      recovery: 'black_box.plans.$id.restore_recovery',
    );
  }

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<PlanLibraryManifest> load() => _serial(_load);

  Future<PlanLibraryManifest> _load() async {
    final raw = await _read(manifestKey);
    if (raw != null) return PlanLibraryManifest.fromJson(jsonDecode(raw));
    final manifest = PlanLibraryManifest._(
      activeId: originalPlanId,
      entries: [
        PlanLibraryEntry(
          id: originalPlanId,
          name: 'Original plan',
          createdAt: _clock().toUtc(),
        ),
      ],
    );
    // A failed read never reaches this write. No legacy record is touched,
    // including unreadable current/previous/recovery data.
    try {
      await _writeManifest(manifest);
    } catch (cause, stackTrace) {
      Error.throwWithStackTrace(
        PlanLibraryInitializationFailure(manifest: manifest, cause: cause),
        stackTrace,
      );
    }
    return manifest;
  }

  Future<void> _writeManifest(PlanLibraryManifest manifest) async {
    final encoded = jsonEncode(manifest.toJson());
    // Validate the complete next directory before any directory mutation.
    PlanLibraryManifest.fromJson(jsonDecode(encoded));
    await _write(manifestKey, encoded);
  }

  Future<List<PlanLibraryItem>> summaries(PlanLibraryManifest manifest) =>
      Future.wait(manifest.entries.map(_summary));

  Future<PlanLibraryItem> _summary(PlanLibraryEntry entry) async {
    try {
      final raw = await _read(keysFor(entry.id).current);
      if (raw == null && entry.id == originalPlanId) {
        return PlanLibraryItem(
          entry: entry,
          plan: GroupPlan.sample(),
          isSample: true,
        );
      }
      if (raw == null) {
        return PlanLibraryItem(
          entry: entry,
          plan: null,
          error:
              'The saved plan record is missing. No replacement was created.',
        );
      }
      return PlanLibraryItem(
        entry: entry,
        plan: GroupPlan.fromJson(jsonDecode(raw)),
      );
    } catch (_) {
      return PlanLibraryItem(
        entry: entry,
        plan: null,
        error: 'This saved plan could not be read. Its stored data has not been changed.',
      );
    }
  }

  Future<GroupPlan> _requiredPlan(PlanLibraryEntry entry) async {
    final item = await _summary(entry);
    if (item.plan == null) throw PlanLibraryException(item.error!);
    return item.plan!;
  }

  Future<PlanLibraryManifest> select(String id) => _serial(() async {
    final manifest = await _load();
    final entry = manifest.entry(id);
    if (entry == null || entry.archived) {
      throw const PlanLibraryException(
        'Choose an available plan from the active list.',
      );
    }
    await _requiredPlan(entry);
    if (manifest.activeId == id) return manifest;
    final updated = PlanLibraryManifest._(
      activeId: id,
      entries: manifest.entries,
    );
    await _writeManifest(updated);
    return updated;
  });

  Future<PlanLibraryManifest> create(
    String name, {
    String? copyFromId,
    GroupPlan? importedPlan,
  }) => _serial(() async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw const PlanLibraryException(
        'Use a plan name between 1 and 80 characters.',
      );
    }
    if (copyFromId != null && importedPlan != null) {
      throw const PlanLibraryException(
        'Choose either a copied plan or an imported plan.',
      );
    }
    final manifest = await _load();
    final now = _clock().toUtc();
    GroupPlan plan;
    if (copyFromId != null) {
      final entry = manifest.entry(copyFromId);
      if (entry == null)
        throw const PlanLibraryException(
          'The source plan is no longer listed.',
        );
      final source = await _requiredPlan(entry);
      plan = _clone(source, now);
      // A copied list describes a new kit. Packing must be checked again.
      for (final item in plan.supplies) {
        item.packed = false;
      }
    } else if (importedPlan != null) {
      plan = _clone(importedPlan, now);
    } else {
      plan = GroupPlan(
        groupName: trimmedName,
        members: [const FamilyMember('you', 'You')],
        supplies: [],
      );
    }
    plan.groupName = trimmedName;
    final id = await _unusedId(manifest);
    final encoded = jsonEncode(plan.toJson(now));
    GroupPlan.fromJson(jsonDecode(encoded));
    // Store the complete new record before making it visible or selected.
    // If the directory write fails, do not delete any stored record. A later
    // retry uses a fresh identifier, so this unlisted copy is never overwritten.
    await _write(keysFor(id).current, encoded);
    final updated = PlanLibraryManifest._(
      activeId: id,
      entries: [
        ...manifest.entries,
        PlanLibraryEntry(id: id, name: trimmedName, createdAt: now),
      ],
    );
    await _writeManifest(updated);
    return updated;
  });

  Future<String> _unusedId(PlanLibraryManifest manifest) async {
    for (var attempt = 0; attempt < 12; attempt++) {
      final id = _idFactory();
      if (!_validPlanId(id)) {
        throw const PlanLibraryException(
          'A new plan identifier could not be created.',
        );
      }
      if (id == originalPlanId || manifest.entry(id) != null) continue;
      final keys = keysFor(id);
      // Check all slots, including an unlisted record from a failed creation.
      final existing = await Future.wait([
        _read(keys.current),
        _read(keys.previous),
        _read(keys.recovery),
      ]);
      if (existing.every((raw) => raw == null)) return id;
    }
    throw const PlanLibraryException(
      'A new plan identifier could not be reserved. Try again.',
    );
  }

  Future<PlanLibraryManifest> setArchived(String id, bool archived) =>
      _serial(() async {
        final manifest = await _load();
        final entry = manifest.entry(id);
        if (entry == null)
          throw const PlanLibraryException('This plan is no longer listed.');
        if (archived && id == manifest.activeId) {
          throw const PlanLibraryException(
            'Open a different plan before archiving this one.',
          );
        }
        if (entry.archived == archived) return manifest;
        final updated = PlanLibraryManifest._(
          activeId: manifest.activeId,
          entries: manifest.entries
              .map(
                (value) =>
                    value.id == id ? value.withArchived(archived) : value,
              )
              .toList(),
        );
        await _writeManifest(updated);
        return updated;
      });
}

GroupPlan _clone(GroupPlan plan, DateTime fallback) => GroupPlan.fromJson(
  jsonDecode(jsonEncode(plan.toJson(plan.savedAt ?? fallback))),
);

bool _validPlanId(String id) =>
    id.isNotEmpty && id.length <= 80 && !RegExp(r'[^A-Za-z0-9_-]').hasMatch(id);

String _randomPlanId() {
  final random = Random.secure();
  return 'p_${List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

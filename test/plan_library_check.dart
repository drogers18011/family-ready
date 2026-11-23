import 'dart:convert';

import '../lib/plan_library_store.dart';
import '../lib/plan_models.dart';
import '../lib/plan_store.dart';

// Pure-Dart checks for data isolation, migration and interrupted writes.
// Run with the standalone Dart SDK: dart test/plan_library_check.dart
int _checks = 0;
final _now = DateTime.utc(2026, 11, 22, 15);

void check(bool condition, String description) {
  _checks++;
  if (!condition) throw StateError('FAILED: $description');
}

Future<Object> fails(
  Future<Object?> Function() action,
  String description,
) async {
  Object? failure;
  try {
    await action();
  } catch (error) {
    failure = error;
  }
  check(failure != null, description);
  return failure!;
}

class MemoryStore {
  final values = <String, String>{};
  final writes = <String>[];
  final removals = <String>[];
  final failure = StateError('Injected storage failure');
  String? failRead;
  String? failWrite;
  bool pauseWrites = false;
  int _id = 0;
  String Function()? candidate;

  Future<String?> read(String key) async {
    if (key == failRead) throw failure;
    return values[key];
  }

  Future<void> write(String key, String value) async {
    writes.add(key);
    if (pauseWrites) await Future<void>.delayed(Duration.zero);
    if (key == failWrite) throw failure;
    values[key] = value;
  }

  Future<void> remove(String key) async {
    removals.add(key);
    values.remove(key);
  }

  late final library = PlanLibraryStore(
    read: read,
    write: write,
    clock: () => _now,
    idFactory: () => candidate?.call() ?? 'plan_${_id++}',
  );

  GroupPlan plan(String id) => GroupPlan.fromJson(
    jsonDecode(values[PlanLibraryStore.keysFor(id).current]!),
  );

  PlanLibraryManifest get manifest => PlanLibraryManifest.fromJson(
    jsonDecode(values[PlanLibraryStore.manifestKey]!),
  );
}

String legacyFixture() => '''{
  "version": 1,
  "groupName": "Original family",
  "members": [{"id":"you","name":"Dennis"},{"id":"care","name":"Caregiver"}],
  "primary": {"name":"Library","address":"West entrance","notes":"Use agreed time"},
  "backup": {"name":"Park","address":"North gate","notes":"If primary is unavailable"},
  "supplies": [{"id":"water","name":"Water","assignedTo":"you","packed":true}],
  "savedAt":"2026-11-18T10:15:00.000Z"
}''';

MemoryStore withLegacy() => MemoryStore()
  ..values[PlanStore.currentKey] = legacyFixture()
  ..values[PlanStore.previousKey] = 'exact previous bytes'
  ..values[PlanStore.recoveryKey] = 'exact recovery bytes';

void preservesLegacy(MemoryStore memory, String description) {
  check(
    memory.values[PlanStore.currentKey] == legacyFixture(),
    '$description current',
  );
  check(
    memory.values[PlanStore.previousKey] == 'exact previous bytes',
    '$description previous',
  );
  check(
    memory.values[PlanStore.recoveryKey] == 'exact recovery bytes',
    '$description recovery',
  );
}

Future<void> registrationPreservesLegacy() async {
  final memory = withLegacy();
  final manifest = await memory.library.load();
  check(
    manifest.entries.length == 1,
    'migration registers only the original plan',
  );
  check(
    manifest.activeId == PlanLibraryStore.originalPlanId,
    'original stays selected',
  );
  check(
    memory.writes.join('|') == PlanLibraryStore.manifestKey,
    'migration writes only metadata',
  );
  preservesLegacy(memory, 'registration preserves exact');
  final keys = PlanLibraryStore.keysFor(manifest.activeId);
  check(keys.current == PlanStore.currentKey, 'original current key retained');
  check(
    keys.previous == PlanStore.previousKey,
    'original previous key retained',
  );
  check(
    keys.recovery == PlanStore.recoveryKey,
    'original recovery key retained',
  );
  final items = await memory.library.summaries(manifest);
  check(
    items.single.displayName == 'Original family',
    'summary uses actual name, not cached label',
  );
  check(
    items.single.plan!.members[0].name == 'Dennis',
    'old schema members remain accessible',
  );
  check(
    items.single.plan!.supplies.single.packed,
    'old packed status remains accessible',
  );
  check(!items.single.isSample, 'saved old plan is never labelled sample');
  final count = memory.writes.length;
  await memory.library.load();
  check(
    memory.writes.length == count,
    'reopening does not rewrite manifest or plan',
  );
  check(memory.removals.isEmpty, 'migration deletes nothing');
}

Future<void> blankCreationAndRestart() async {
  final memory = MemoryStore();
  final first = await memory.library.load();
  final samples = await memory.library.summaries(first);
  check(
    samples.single.isSample,
    'missing original retains explicit sample status',
  );
  check(
    !memory.values.containsKey(PlanStore.currentKey),
    'viewing sample does not save it',
  );
  final created = await memory.library.create('  Extended family  ');
  check(
    created.activeId != PlanLibraryStore.originalPlanId,
    'new plan gets separate stable ID',
  );
  check(created.activeEntry.name == 'Extended family', 'new name is trimmed');
  final plan = memory.plan(created.activeId);
  check(
    plan.groupName == 'Extended family',
    'new record contains its own name',
  );
  check(
    plan.members.length == 1 && plan.members.single.name == 'You',
    'blank plan has only You',
  );
  check(plan.supplies.isEmpty, 'blank plan has no sample supplies');
  check(
    !plan.primary.isSet && !plan.backup.isSet,
    'blank plan has no invented places',
  );
  check(plan.savedAt == _now, 'new record has its committed save time');
  check(
    !memory.values.containsKey(PlanStore.currentKey),
    'new plan never writes original slot',
  );
  final key = PlanLibraryStore.keysFor(created.activeId).current;
  check(
    memory.writes[memory.writes.length - 2] == key,
    'complete plan is written before index',
  );
  check(
    memory.writes.last == PlanLibraryStore.manifestKey,
    'selection commits after plan write',
  );
  final restarted = PlanLibraryStore(read: memory.read, write: memory.write);
  final loaded = await restarted.load();
  check(
    loaded.activeId == created.activeId,
    'selected plan persists across store restart',
  );
  check(loaded.entries.length == 2, 'both plans persist across restart');
  final items = await restarted.summaries(loaded);
  check(
    items.last.available && !items.last.isSample,
    'new stored plan is available, not sample',
  );
}

Future<void> copyingAndImporting() async {
  final memory = withLegacy();
  await memory.library.load();
  final copied = await memory.library.create(
    'Travel family',
    copyFromId: PlanLibraryStore.originalPlanId,
  );
  final duplicate = memory.plan(copied.activeId);
  check(
    duplicate.groupName == 'Travel family',
    'duplicate uses chosen new name',
  );
  check(
    duplicate.members.length == 2 && duplicate.members.first.id == 'you',
    'duplicate keeps scoped member IDs',
  );
  check(
    duplicate.primary.address == 'West entrance',
    'duplicate preserves meeting details',
  );
  check(
    !duplicate.supplies.single.packed,
    'duplicate requires packing to be checked again',
  );
  check(
    duplicate.supplies.single.assignedTo == 'you',
    'duplicate preserves assignment',
  );
  duplicate.members.add(const FamilyMember('extra', 'Neighbor'));
  duplicate.supplies.single.name = 'Changed copy';
  preservesLegacy(memory, 'duplicate leaves original exact');
  final source = GroupPlan.fromJson(jsonDecode(legacyFixture()));
  final sourceBefore = jsonEncode(source.toJson(source.savedAt!));
  final imported = await memory.library.create(
    'Imported family',
    importedPlan: source,
  );
  final importedPlan = memory.plan(imported.activeId);
  check(
    importedPlan.supplies.single.packed,
    'import preserves source packed status',
  );
  check(
    importedPlan.backup.notes == source.backup.notes,
    'import preserves full meeting notes',
  );
  check(
    jsonEncode(source.toJson(source.savedAt!)) == sourceBefore,
    'import does not mutate caller model',
  );
  check(
    imported.entries.length == 3,
    'import adds a third entry instead of replacing',
  );
  preservesLegacy(memory, 'import leaves original exact');
  final oldCopyRaw =
      memory.values[PlanLibraryStore.keysFor(copied.activeId).current];
  check(
    oldCopyRaw != null &&
        memory.plan(copied.activeId).groupName == 'Travel family',
    'import leaves sibling plan intact',
  );
  final beforeWrites = memory.writes.length;
  await fails(
    () => memory.library.create(
      'Bad',
      copyFromId: copied.activeId,
      importedPlan: source,
    ),
    'ambiguous create input rejected',
  );
  await fails(() => memory.library.create(''), 'blank name rejected');
  await fails(() => memory.library.create('x' * 81), 'overlong name rejected');
  await fails(
    () => memory.library.create('Copy missing', copyFromId: 'unknown'),
    'unknown copy source rejected',
  );
  check(
    memory.writes.length == beforeWrites,
    'rejected create inputs do not mutate storage',
  );
}

Future<void> selectionAndArchives() async {
  final memory = withLegacy();
  await memory.library.load();
  final second = await memory.library.create('Neighbors');
  final id = second.activeId;
  final planBytes = memory.values[PlanLibraryStore.keysFor(id).current];
  final selected = await memory.library.select(PlanLibraryStore.originalPlanId);
  check(
    selected.activeId == PlanLibraryStore.originalPlanId,
    'selection changes the active directory entry',
  );
  preservesLegacy(memory, 'selection preserves original exact');
  final archived = await memory.library.setArchived(id, true);
  check(archived.entry(id)!.archived, 'inactive plan can be archived');
  check(
    memory.values[PlanLibraryStore.keysFor(id).current] == planBytes,
    'archive retains full plan record',
  );
  final prior = memory.values[PlanLibraryStore.manifestKey];
  await fails(
    () => memory.library.select(id),
    'archived plan cannot be selected',
  );
  await fails(
    () => memory.library.setArchived(PlanLibraryStore.originalPlanId, true),
    'active plan cannot be archived',
  );
  await fails(
    () => memory.library.setArchived('unknown', true),
    'unknown plan cannot be archived',
  );
  await fails(
    () => memory.library.select('unknown'),
    'unknown plan cannot be selected',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == prior,
    'rejected actions preserve directory',
  );
  final unarchived = await memory.library.setArchived(id, false);
  check(!unarchived.entry(id)!.archived, 'archiving is reversible');
  await memory.library.select(id);
  final archivedOriginal = await memory.library.setArchived(
    PlanLibraryStore.originalPlanId,
    true,
  );
  check(
    archivedOriginal.entries.length == 2,
    'archiving original does not remove its entry',
  );
  preservesLegacy(memory, 'archiving original preserves exact');
  check(memory.removals.isEmpty, 'archive operations never delete records');
}

Future<void> familyBriefCopyAndImportIsolation() async {
  final memory = MemoryStore();
  final source = GroupPlan.fromJson(jsonDecode(legacyFixture()));
  source.familyBrief = FamilyBrief(
    outOfAreaName: 'Out-of-area relative',
    outOfAreaPhone: '+1 202-555-0100',
    communicationNotes: 'Use the agreed check-in window.',
    careNotes: 'Caregiver collects the children; neighbor checks on the dog.',
    departureNotes: 'Bring the prepared bags and written meeting instructions.',
    contacts: [
      PlanContact(
        name: 'School office',
        phone: '202-555-0101',
        role: 'Pickup contact',
      ),
      PlanContact(name: 'Neighbor', phone: '202-555-0102', role: 'Pet care'),
    ],
  );
  final sourceRaw = jsonEncode(source.toJson(_now));
  final briefRaw = jsonEncode(source.familyBrief.toJson());
  memory.values[PlanStore.currentKey] = sourceRaw;
  await memory.library.load();
  final copied = await memory.library.create(
    'Care plan copy',
    copyFromId: PlanLibraryStore.originalPlanId,
  );
  final copy = memory.plan(copied.activeId);
  check(
    jsonEncode(copy.familyBrief.toJson()) == briefRaw,
    'duplicate preserves every family brief field and contact',
  );
  check(
    copy.familyBrief.contacts.length == 2,
    'duplicate preserves complete contact list',
  );
  check(
    !copy.supplies.single.packed,
    'family brief duplication still clears shared Packed checks',
  );
  check(
    memory.values[PlanStore.currentKey] == sourceRaw,
    'family brief duplicate leaves original bytes intact',
  );

  final imported = await memory.library.create(
    'Imported care plan',
    importedPlan: source,
  );
  final importedPlan = memory.plan(imported.activeId);
  check(
    jsonEncode(importedPlan.familyBrief.toJson()) == briefRaw,
    'import preserves every family brief field and contact',
  );
  check(
    importedPlan.supplies.single.packed,
    'family brief import preserves imported Packed state',
  );
  check(
    jsonEncode(source.familyBrief.toJson()) == briefRaw,
    'import leaves caller family brief intact',
  );
  final importRaw =
      memory.values[PlanLibraryStore.keysFor(imported.activeId).current];

  copy.familyBrief = FamilyBrief(
    outOfAreaName: 'Different relative',
    careNotes: 'Separate pickup arrangements for this plan.',
    contacts: [
      PlanContact(
        name: 'Different contact',
        phone: '202-555-0199',
        role: 'Backup',
      ),
    ],
  );
  await memory.write(
    PlanLibraryStore.keysFor(copied.activeId).current,
    jsonEncode(copy.toJson(_now.add(const Duration(minutes: 1)))),
  );
  check(
    memory.plan(copied.activeId).familyBrief.contacts.single.name ==
        'Different contact',
    'editing copied contacts persists in the copied plan',
  );
  check(
    memory.values[PlanStore.currentKey] == sourceRaw,
    'editing copied family brief does not change original record',
  );
  check(
    memory.values[PlanLibraryStore.keysFor(imported.activeId).current] ==
        importRaw,
    'editing copied family brief does not change imported sibling',
  );
  check(
    memory.plan(PlanLibraryStore.originalPlanId).familyBrief.careNotes ==
        source.familyBrief.careNotes,
    'original care notes remain isolated after edit',
  );
  check(
    memory.plan(imported.activeId).familyBrief.contacts[1].role == 'Pet care',
    'imported contacts remain isolated after copied edit',
  );

  source.familyBrief = const FamilyBrief.empty();
  await memory.write(
    PlanStore.currentKey,
    jsonEncode(source.toJson(_now.add(const Duration(minutes: 2)))),
  );
  check(
    memory.plan(PlanLibraryStore.originalPlanId).familyBrief.isEmpty,
    'original may be edited independently later',
  );
  check(
    jsonEncode(memory.plan(imported.activeId).familyBrief.toJson()) == briefRaw,
    'later original edit does not erase imported family information',
  );
  check(
    memory.plan(copied.activeId).familyBrief.outOfAreaName ==
        'Different relative',
    'later original edit does not alter independently edited copy',
  );
}

Future<void> unavailablePlansFailClosed() async {
  final memory = withLegacy();
  await memory.library.load();
  final second = await memory.library.create('Neighbor plan');
  final id = second.activeId;
  await memory.library.select(PlanLibraryStore.originalPlanId);
  final originalManifest = memory.values[PlanLibraryStore.manifestKey];
  final keys = PlanLibraryStore.keysFor(id);
  memory.values[keys.current] = 'corrupt stored bytes';
  var items = await memory.library.summaries(memory.manifest);
  check(
    items.last.plan == null && items.last.error != null,
    'corrupt record is unavailable with explanation',
  );
  check(!items.last.isSample, 'corrupt record is not replaced by sample');
  check(items.first.available, 'one bad plan does not hide a readable sibling');
  await fails(
    () => memory.library.select(id),
    'corrupt target is not selected',
  );
  await fails(
    () => memory.library.create('Copy', copyFromId: id),
    'corrupt source is not duplicated',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == originalManifest,
    'corrupt target cannot change active plan',
  );
  check(
    memory.values[keys.current] == 'corrupt stored bytes',
    'corrupt bytes are retained',
  );
  memory.values.remove(keys.current);
  items = await memory.library.summaries(memory.manifest);
  check(
    !items.last.available && !items.last.isSample,
    'missing non-original record is never fabricated',
  );
  await fails(
    () => memory.library.select(id),
    'missing target is not selected',
  );
  memory.values[PlanStore.currentKey] = 'corrupt legacy bytes';
  items = await memory.library.summaries(memory.manifest);
  check(
    !items.first.available && !items.first.isSample,
    'corrupt legacy record remains unavailable',
  );
  check(
    memory.values[PlanStore.currentKey] == 'corrupt legacy bytes',
    'corrupt legacy stays recoverable',
  );
}

Map<String, dynamic> validManifest() => {
  'version': 1,
  'activeId': PlanLibraryStore.originalPlanId,
  'entries': <Map<String, dynamic>>[
    {
      'id': PlanLibraryStore.originalPlanId,
      'name': 'Original',
      'createdAt': _now.toIso8601String(),
      'archived': false,
    },
  ],
};

Future<void> rejectsInvalidDirectories() async {
  final invalid = <Object?>[
    null,
    [],
    validManifest()..['version'] = 2,
    validManifest()..['version'] = 1.0,
    validManifest()..['entries'] = [],
    validManifest()..['activeId'] = 'missing',
    validManifest()..['activeId'] = null,
    validManifest()..['entries'][0]['archived'] = true,
    validManifest()..['entries'][0]['archived'] = 'false',
    validManifest()..['entries'][0]['createdAt'] = 'bad date',
    validManifest()..['entries'][0]['id'] = '../bad',
    validManifest()..['entries'][0]['id'] = 'original\n',
    validManifest()..['entries'][0]['name'] = '',
  ];
  final duplicate = validManifest();
  (duplicate['entries'] as List).add(
    Map<String, dynamic>.from(duplicate['entries'][0]),
  );
  invalid.add(duplicate);
  final missingOriginal = validManifest();
  missingOriginal['activeId'] = 'other';
  missingOriginal['entries'][0]['id'] = 'other';
  invalid.add(missingOriginal);
  for (var i = 0; i < invalid.length; i++) {
    final memory = withLegacy();
    final raw = jsonEncode(invalid[i]);
    memory.values[PlanLibraryStore.manifestKey] = raw;
    final error = await fails(
      () => memory.library.load(),
      'invalid manifest $i rejected',
    );
    check(
      error is! PlanLibraryInitializationFailure,
      'invalid manifest $i cannot fall back to original-only list',
    );
    await fails(
      () => memory.library.create('New'),
      'invalid manifest $i cannot be overwritten by create',
    );
    check(
      memory.values[PlanLibraryStore.manifestKey] == raw,
      'invalid manifest $i bytes preserved',
    );
    check(
      memory.writes.isEmpty,
      'invalid manifest $i causes no storage writes',
    );
    preservesLegacy(memory, 'invalid manifest $i preserves legacy');
  }
}

Future<void> failedReadsAndWrites() async {
  final readFailure = withLegacy()..failRead = PlanLibraryStore.manifestKey;
  final readError = await fails(
    () => readFailure.library.load(),
    'failed directory read is reported',
  );
  check(
    readError is! PlanLibraryInitializationFailure,
    'failed read cannot offer an original-only fallback',
  );
  check(
    readFailure.writes.isEmpty,
    'failed read never initializes empty directory',
  );
  preservesLegacy(readFailure, 'read failure preserves');
  final initFailure = withLegacy()..failWrite = PlanLibraryStore.manifestKey;
  final initError = await fails(
    () => initFailure.library.load(),
    'failed initial write is reported',
  );
  check(
    initError is PlanLibraryInitializationFailure,
    'only confirmed missing-directory write failure offers fallback',
  );
  final initialization = initError as PlanLibraryInitializationFailure;
  check(
    identical(initialization.cause, initFailure.failure),
    'initialization failure retains its storage cause',
  );
  check(
    initialization.manifest.entries.length == 1 &&
        initialization.manifest.activeId == PlanLibraryStore.originalPlanId,
    'fallback references only the original plan',
  );
  check(
    !initialization.manifest.activeEntry.archived,
    'fallback original remains active',
  );
  final fallbackItems = await initFailure.library.summaries(
    initialization.manifest,
  );
  check(
    fallbackItems.single.plan!.groupName == 'Original family',
    'fallback can read existing original without directory write',
  );
  check(
    !initFailure.values.containsKey(PlanLibraryStore.manifestKey),
    'failed initialization has no false manifest',
  );
  preservesLegacy(initFailure, 'initialization failure preserves');

  final memory = withLegacy();
  await memory.library.load();
  final initial = memory.values[PlanLibraryStore.manifestKey];
  memory.failWrite = PlanLibraryStore.keysFor('plan_0').current;
  await fails(
    () => memory.library.create('Failed record'),
    'failed new record write is reported',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == initial,
    'new record failure leaves selection unchanged',
  );
  check(
    !memory.values.containsKey(memory.failWrite),
    'failed plan write has no false record',
  );
  memory.failWrite = PlanLibraryStore.manifestKey;
  final mutationError = await fails(
    () => memory.library.create('Failed directory'),
    'failed directory commit is reported',
  );
  check(
    mutationError is! PlanLibraryInitializationFailure,
    'existing-directory mutation failure never offers original-only fallback',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == initial,
    'failed directory commit keeps old visible plans',
  );
  final orphanKey = PlanLibraryStore.keysFor('plan_1').current;
  check(
    memory.values.containsKey(orphanKey),
    'unlisted new record is retained on commit failure',
  );
  final orphan = memory.values[orphanKey];
  check(memory.removals.isEmpty, 'failure never attempts destructive cleanup');
  memory.failWrite = null;
  var retry = 0;
  memory.candidate = () => retry++ == 0 ? 'plan_1' : 'plan_after_failure';
  final created = await memory.library.create('Retry');
  check(
    created.activeId == 'plan_after_failure',
    'retry avoids an unlisted occupied record',
  );
  check(
    memory.values[orphanKey] == orphan,
    'retry preserves previous unlisted bytes',
  );
  preservesLegacy(memory, 'creation failures preserve');
  final committed = memory.values[PlanLibraryStore.manifestKey];
  memory.failWrite = PlanLibraryStore.manifestKey;
  await fails(
    () => memory.library.select(PlanLibraryStore.originalPlanId),
    'selection commit failure is reported',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == committed,
    'failed switch retains old selected plan',
  );
  await fails(
    () => memory.library.setArchived(PlanLibraryStore.originalPlanId, true),
    'archive commit failure is reported',
  );
  check(
    memory.values[PlanLibraryStore.manifestKey] == committed,
    'failed archive retains old archive state',
  );
}

Future<void> serializedCreationAndCollisionHandling() async {
  final memory = withLegacy()..pauseWrites = true;
  await memory.library.load();
  final results = await Future.wait([
    memory.library.create('First concurrent request'),
    memory.library.create('Second concurrent request'),
  ]);
  check(
    results[0].activeId != results[1].activeId,
    'queued creates get separate identifiers',
  );
  check(
    memory.manifest.entries.length == 3,
    'queued creates never lose earlier entries',
  );
  check(
    memory.manifest.activeId == results.last.activeId,
    'last completed request becomes active',
  );
  final occupied = PlanLibraryStore.keysFor('occupied_only_previous');
  memory.values[occupied.previous] = 'previous-only record';
  var candidate = 0;
  memory.candidate = () =>
      candidate++ == 0 ? 'occupied_only_previous' : 'fresh';
  final created = await memory.library.create('Collision check');
  check(
    created.activeId == 'fresh',
    'identifier check protects previous-only orphan slot',
  );
  check(
    memory.values[occupied.previous] == 'previous-only record',
    'collision does not overwrite prior slot',
  );
  final before = Map<String, String>.from(memory.values);
  memory.candidate = () => 'fresh';
  await fails(
    () => memory.library.create('Repeated collision'),
    'repeated occupied identifier fails safely',
  );
  check(
    jsonEncode(memory.values) == jsonEncode(before),
    'collision failure causes no writes',
  );
  memory.candidate = () => '../unsafe';
  await fails(
    () => memory.library.create('Unsafe ID'),
    'unsafe generated identifier rejected',
  );
  check(
    jsonEncode(memory.values) == jsonEncode(before),
    'unsafe ID cannot escape storage namespace',
  );
}

Future<void> scopedRestoreIsolation() async {
  final memory = withLegacy();
  await memory.library.load();
  final second = await memory.library.create('Second');
  final third = await memory.library.create('Third');
  final sibling =
      memory.values[PlanLibraryStore.keysFor(third.activeId).current];
  final keys = PlanLibraryStore.keysFor(second.activeId);
  final current = memory.values[keys.current]!;
  const incoming = '{"incoming":"exact file bytes"}';
  const committed = '{"committed":"validated input"}';
  final result =
      await PlanStore(
        write: memory.write,
        remove: memory.remove,
        keys: keys,
      ).commitRestore(
        currentRaw: current,
        incomingRaw: incoming,
        committedRaw: committed,
      );
  check(
    !result.recoveryRemains,
    'scoped restore completes and cleans its own recovery',
  );
  check(
    memory.values[keys.current] == committed,
    'restore writes selected plan slot',
  );
  check(
    memory.values[keys.previous] == current,
    'restore preserves selected plan previous',
  );
  check(
    !memory.values.containsKey(keys.recovery),
    'restore cleans only its own journal',
  );
  preservesLegacy(memory, 'scoped restore preserves original exact');
  check(
    memory.values[PlanLibraryStore.keysFor(third.activeId).current] == sibling,
    'restore preserves sibling plan',
  );
  check(
    memory.manifest.activeId == third.activeId,
    'restore does not change global directory selection',
  );
}

Future<void> main() async {
  await registrationPreservesLegacy();
  await blankCreationAndRestart();
  await copyingAndImporting();
  await selectionAndArchives();
  await familyBriefCopyAndImportIsolation();
  await unavailablePlansFailClosed();
  await rejectsInvalidDirectories();
  await failedReadsAndWrites();
  await serializedCreationAndCollisionHandling();
  await scopedRestoreIsolation();
  print(
    'PASS: $_checks plan-library checks covering migration, isolation, failures, copies, imports, selection and archives.',
  );
}

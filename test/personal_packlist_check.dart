import 'dart:async';
import 'dart:convert';

import '../lib/personal_packlist_models.dart';

// Run with standalone Dart. No Flutter or third-party test packages are needed.
int _checks = 0;

void check(bool condition, String description) {
  _checks++;
  if (!condition) throw StateError('FAILED: $description');
}

void rejects(void Function() action, String description) {
  var rejected = false;
  try {
    action();
  } on FormatException {
    rejected = true;
  }
  check(rejected, description);
}

Future<void> main() async {
  final originalItem = PersonalPackItem(
    id: 'pack_1',
    name: 'Spare clothes — Dennis',
    quantity: '2 sets',
    notes: 'Side pocket\nKeep dry.',
  );
  final originalItems = [originalItem];
  final document = PersonalPacklist(items: originalItems);
  originalItems.clear();
  check(
    document.items.length == 1,
    'caller list changes cannot mutate a checklist',
  );
  final packed = document.withItems([originalItem.copyWith(packed: true)]);
  check(
    !document.items.first.packed && packed.packedCount == 1,
    'personal packed changes preserve the previous snapshot',
  );
  final saved = packed.saved(DateTime.utc(2026, 11, 22, 14, 30));
  final raw = saved.encode();
  check(
    PersonalPacklist.decode(raw).encode() == raw,
    'names, Unicode, quantities, notes, packed status, and time round-trip',
  );
  check(
    saved.readableText(unsavedChanges: true).contains('not yet saved') &&
        saved.readableText(unsavedChanges: true).contains('[x] Spare clothes'),
    'readable draft copy identifies unsaved changes and packed state',
  );
  final unsupported = saved.toJson()..['version'] = 3;
  rejects(
    () => PersonalPacklist.decode(jsonEncode(unsupported)),
    'a newer schema is not silently downgraded',
  );
  rejects(
    () => PersonalPacklist(items: [originalItem, originalItem]),
    'duplicate IDs cannot cause ambiguous edits/removals',
  );
  rejects(
    () => PersonalPackItem(id: 'bad', name: '   '),
    'blank names are rejected',
  );
  final invalidPacked = saved.toJson();
  invalidPacked['items'] = [originalItem.toJson()..['packed'] = 'true'];
  rejects(
    () => PersonalPacklist.decode(jsonEncode(invalidPacked)),
    'malformed packed values are rejected without guessing',
  );
  rejects(
    () => PersonalPacklist.decode(' ' * (maxPersonalPacklistBytes + 1)),
    'oversized stored input is bounded before JSON decoding',
  );

  final checkedPacked = originalItem.copyWith(packed: true);
  check(
    checkedPacked.owned && checkedPacked.packed,
    'explicit packed confirmation also confirms possession',
  );
  check(
    checkedPacked.copyWith(packed: false).owned,
    'unpacking does not discard ownership',
  );
  final noLongerOwned = checkedPacked.copyWith(owned: false);
  check(
    !noLongerOwned.owned && !noLongerOwned.packed,
    'clearing owned also clears packed',
  );
  check(
    !checkedPacked.copyWith(owned: false, packed: true).packed,
    'conflicting updates cannot leave an unowned item marked packed',
  );
  final contradictory = saved.toJson();
  contradictory['items'] = [checkedPacked.toJson()..['owned'] = false];
  rejects(
    () => PersonalPacklist.decode(jsonEncode(contradictory)),
    'contradictory persisted state is preserved as an error, not guessed',
  );
  final missingOwnership = saved.toJson();
  missingOwnership['items'] = [originalItem.toJson()..remove('owned')];
  rejects(
    () => PersonalPacklist.decode(jsonEncode(missingOwnership)),
    'new schema requires explicit boolean owned state',
  );

  final oldUnpacked = originalItem.toJson()
    ..remove('owned')
    ..remove('sourceSuggestionId');
  final oldPacked = checkedPacked.toJson()
    ..['id'] = 'pack_2'
    ..remove('owned')
    ..remove('sourceSuggestionId');
  final legacyRaw = jsonEncode({
    'kind': 'black_box.personal_packlist',
    'version': 1,
    'items': [oldUnpacked, oldPacked],
    'savedAt': saved.savedAt!.toIso8601String(),
  });
  final migrated = PersonalPacklist.decode(legacyRaw);
  check(
    migrated.migratedFromVersion1 &&
        migrated.ownedCount == 1 &&
        migrated.packedCount == 1 &&
        !migrated.items.first.owned,
    'old packed items become owned; old unpacked items remain unconfirmed',
  );
  check(
    migrated.items.first.name == originalItem.name &&
        migrated.items.first.notes == originalItem.notes &&
        migrated.items.first.quantity == originalItem.quantity &&
        migrated.savedAt == saved.savedAt,
    'ownership migration preserves every existing personal field and timestamp',
  );
  check(
    (jsonDecode(migrated.encode()) as Map)['version'] == 2,
    'new personal documents write schema2',
  );

  final suggestionItem = PersonalPackItem(
    id: 'suggested_a',
    name: 'My edited torch',
    quantity: '2',
    sourceSuggestionId: 'flashlight',
  );
  check(
    PersonalPacklist.decode(PersonalPacklist(items: [suggestionItem]).encode())
            .items
            .single
            .sourceSuggestionId ==
        'flashlight',
    'stable catalog identity survives offline persistence',
  );
  rejects(
    () => PersonalPacklist(
      items: [
        suggestionItem,
        PersonalPackItem(
          id: 'suggested_b',
          name: 'Duplicate torch',
          sourceSuggestionId: 'flashlight',
        ),
      ],
    ),
    'duplicate catalog identities cannot produce ambiguous add/owned actions',
  );
  rejects(
    () => PersonalPackItem(
      id: 'bad_suggestion',
      name: 'Torch',
      sourceSuggestionId: '../bad',
    ),
    'suggestion IDs reject URLs and unsafe syntax',
  );

  String? disk;
  var failWrite = false;
  var reads = 0;
  var writes = 0;
  final store = PersonalPacklistStore(
    read: (key) async {
      check(
        key == PersonalPacklistStore.storageKey,
        'reads use the personal key',
      );
      reads++;
      return disk;
    },
    write: (key, value) async {
      check(
        key == PersonalPacklistStore.storageKey,
        'writes use the personal key',
      );
      writes++;
      if (failWrite) throw StateError('Simulated storage unavailable');
      disk = value;
    },
    now: () => DateTime.utc(2026, 11, 22, 16),
  );
  final initial = await store.load();
  check(
    initial.document.items.isEmpty && writes == 0,
    'opening an empty checklist does not overwrite storage',
  );
  final first = await store.save(document);
  check(
    !first.dirty && first.saveError == null && disk != null,
    'a completed write is acknowledged as saved',
  );
  final firstDisk = disk;
  failWrite = true;
  final failed = await store.save(packed);
  check(
    failed.dirty && failed.saveError != null && disk == firstDisk,
    'a failed write retains the old stored copy and reports an unsaved draft',
  );
  final returningTab = await store.load();
  check(
    returningTab.document.packedCount == 1 && returningTab.dirty,
    'the unsaved draft survives destroying and recreating a tab',
  );
  final readsBeforeRetry = reads;
  final retryLoad = await store.load(retry: true);
  check(
    retryLoad.dirty &&
        retryLoad.document.packedCount == 1 &&
        reads == readsBeforeRetry,
    'retrying a load cannot discard an unsaved draft',
  );
  final freshApp = PersonalPacklistStore(
    read: (_) async => disk,
    write: (_, value) async => disk = value,
  );
  check(
    (await freshApp.load()).document.packedCount == 0,
    'a fresh app receives the last committed copy, matching the failure warning',
  );
  failWrite = false;
  final retried = await store.retrySave();
  check(
    !retried.dirty && PersonalPacklist.decode(disk!).packedCount == 1,
    'retry commits the preserved working draft',
  );

  final writeStarted = Completer<void>();
  final writeGate = Completer<void>();
  String? orderedDisk;
  final orderedStore = PersonalPacklistStore(
    read: (_) async => orderedDisk,
    write: (_, value) async {
      writeStarted.complete();
      await writeGate.future;
      orderedDisk = value;
    },
  );
  final pendingWrite = orderedStore.save(packed);
  await writeStarted.future;
  var queuedLoadFinished = false;
  final pendingLoad = orderedStore.load().then((value) {
    queuedLoadFinished = true;
    return value;
  });
  await Future<void>.delayed(Duration.zero);
  check(!queuedLoadFinished, 'a returning tab waits for an in-flight write');
  writeGate.complete();
  await pendingWrite;
  final afterWrite = await pendingLoad;
  check(
    !afterWrite.dirty && afterWrite.document.packedCount == 1,
    'queued load sees the completed write rather than stale disk data',
  );

  var corrupt = '{broken personal data';
  var corruptWrites = 0;
  final corruptStore = PersonalPacklistStore(
    read: (_) async => corrupt,
    write: (_, value) async {
      corruptWrites++;
      corrupt = value;
    },
  );
  final corruptLoad = await corruptStore.load();
  check(
    corruptLoad.loadError != null && corruptLoad.rawStored == corrupt,
    'malformed stored data remains available for recovery copying',
  );
  var blocked = false;
  try {
    await corruptStore.save(document);
  } on StateError {
    blocked = true;
  }
  check(
    blocked && corruptWrites == 0 && corrupt == '{broken personal data',
    'editing cannot overwrite a malformed stored record',
  );
  corrupt = raw;
  check(
    (await corruptStore.load(retry: true)).loadError == null,
    'a read retry can recover after the stored record is repaired',
  );

  var failRead = true;
  var unavailableWrites = 0;
  final unavailable = PersonalPacklistStore(
    read: (_) async {
      if (failRead) throw StateError('Storage unavailable');
      return null;
    },
    write: (_, value) async => unavailableWrites++,
  );
  check(
    (await unavailable.load()).loadError != null && unavailableWrites == 0,
    'read failure does not create a replacement empty record',
  );
  failRead = false;
  check(
    (await unavailable.load(retry: true)).loadError == null,
    'read failure can be retried safely',
  );

  String? catalogDisk;
  var catalogWriteFails = false;
  final catalogStore = PersonalPacklistStore(
    read: (_) async => catalogDisk,
    write: (_, value) async {
      if (catalogWriteFails) throw StateError('Simulated quota failure');
      catalogDisk = value;
    },
    now: () => DateTime.utc(2026, 11, 22, 18),
  );
  final added = await catalogStore.addSuggestedItem(
    suggestionId: 'flashlight',
    name: 'Flashlight',
    quantity: '1',
    notes: 'Keep batteries nearby.',
  );
  check(
    added.added &&
        !added.item.owned &&
        !added.item.packed &&
        !added.snapshot.dirty,
    'default suggestion add records shopping intent without claiming a purchase',
  );
  await catalogStore.mutate(
    (current) => current.withItems([
      current.items.single.copyWith(
        name: 'Already chosen torch',
        quantity: '3',
        notes: 'Kitchen shelf',
      ),
    ]),
  );
  final duplicate = await catalogStore.addSuggestedItem(
    suggestionId: 'flashlight',
    name: 'New catalog title',
    quantity: '99',
    notes: 'Replaced description',
  );
  check(
    !duplicate.added &&
        duplicate.snapshot.document.items.length == 1 &&
        duplicate.item.name == 'Already chosen torch' &&
        duplicate.item.quantity == '3' &&
        duplicate.item.notes == 'Kitchen shelf',
    'repeat shopping clicks neither duplicate nor overwrite user-edited inventory',
  );
  final confirmed = await catalogStore.addSuggestedItem(
    suggestionId: 'flashlight',
    name: 'Ignored catalog title',
    confirmedOwned: true,
  );
  check(
    !confirmed.added &&
        confirmed.item.owned &&
        !confirmed.item.packed &&
        confirmed.item.name == 'Already chosen torch',
    'explicit possession confirmation updates owned without inventing packed status',
  );
  await catalogStore.mutate(
    (current) =>
        current.withItems([current.items.single.copyWith(packed: true)]),
  );
  final laterClick = await catalogStore.addSuggestedItem(
    suggestionId: 'flashlight',
    name: 'Torch',
  );
  check(
    laterClick.item.owned && laterClick.item.packed,
    'a later shopping click never downgrades an owned or packed item',
  );

  final queuedAdds = await Future.wait([
    catalogStore.addSuggestedItem(
      suggestionId: 'weather_radio',
      name: 'Weather radio',
    ),
    catalogStore.addSuggestedItem(
      suggestionId: 'weather_radio',
      name: 'Same radio',
    ),
    catalogStore.addSuggestedItem(suggestionId: 'whistle', name: 'Whistle'),
  ]);
  final withConcurrent = await catalogStore.load();
  check(
    queuedAdds.where((result) => result.added).length == 2 &&
        withConcurrent.document.items.length == 3,
    'overlapping catalog requests serialize without duplicate or lost items',
  );
  await catalogStore.mutate(
    (current) => current.withItems([
      for (final item in current.items)
        if (item.sourceSuggestionId == 'flashlight')
          item.copyWith(quantity: '4')
        else
          item,
    ]),
  );
  final changedAfterRoute = await catalogStore.load();
  check(
    changedAfterRoute.document.items.length == 3 &&
        changedAfterRoute.document.items.first.quantity == '4',
    'editing after a suggestion route uses the latest document, preserving additions',
  );

  final beforeFailure = catalogDisk;
  catalogWriteFails = true;
  final failedAddition = await catalogStore.addSuggestedItem(
    suggestionId: 'water_container',
    name: 'Water container',
    confirmedOwned: true,
  );
  check(
    failedAddition.snapshot.dirty &&
        failedAddition.snapshot.saveError != null &&
        catalogDisk == beforeFailure,
    'failed suggestion persistence preserves prior disk data and reports an unsaved draft',
  );
  final repeatedFailed = await catalogStore.addSuggestedItem(
    suggestionId: 'water_container',
    name: 'Different catalog label',
  );
  check(
    !repeatedFailed.added &&
        repeatedFailed.snapshot.dirty &&
        repeatedFailed.item.owned,
    'repeated clicks preserve the failed draft and do not claim it was saved',
  );
  catalogWriteFails = false;
  final mergedDraft = await catalogStore.addSuggestedItem(
    suggestionId: 'duct_tape',
    name: 'Duct tape',
  );
  check(
    !mergedDraft.snapshot.dirty &&
        PersonalPacklist.decode(catalogDisk!).items.any(
          (item) => item.sourceSuggestionId == 'water_container' && item.owned,
        ),
    'a later successful mutation commits the whole retained draft without losing ownership',
  );

  var notifications = 0;
  PersonalPacklistSnapshot? notified;
  void listener(PersonalPacklistSnapshot value) {
    notifications++;
    notified = value;
  }

  void brokenListener(PersonalPacklistSnapshot value) =>
      throw StateError('Detached view');
  catalogStore.addListener(listener);
  catalogStore.addListener(brokenListener);
  final observed = await catalogStore.addSuggestedItem(
    suggestionId: 'manual_can_opener',
    name: 'Can opener',
  );
  check(
    notifications > 0 &&
        notified?.document.items.length == 6 &&
        !observed.snapshot.dirty,
    'mounted views receive the committed state and listener failures cannot fail a save',
  );
  catalogStore.removeListener(listener);
  catalogStore.removeListener(brokenListener);
  final notificationsBefore = notifications;
  await catalogStore.mutate(
    (current) => current.withItems(
      current.items.where(
        (item) => item.sourceSuggestionId != 'manual_can_opener',
      ),
    ),
  );
  check(
    notifications == notificationsBefore,
    'detached views receive no more store notifications',
  );

  var legacyWrites = 0;
  var legacyDisk = legacyRaw;
  final migrationStore = PersonalPacklistStore(
    read: (_) async => legacyDisk,
    write: (_, value) async {
      legacyWrites++;
      legacyDisk = value;
    },
  );
  await migrationStore.load();
  check(
    legacyWrites == 0 && legacyDisk == legacyRaw,
    'reading a legacy checklist does not prematurely overwrite the old stored record',
  );
  await migrationStore.mutate(
    (current) => current.withItems([
      for (final item in current.items) item.copyWith(owned: true),
    ]),
  );
  check(
    (jsonDecode(legacyDisk) as Map)['version'] == 2 &&
        PersonalPacklist.decode(legacyDisk).items.length == 2,
    'the first successful edit commits migrated schema2 and keeps all older items',
  );

  print('PASS: $_checks personal packing-list checks.');
}

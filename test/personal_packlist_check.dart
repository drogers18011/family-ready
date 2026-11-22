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
  final unsupported = saved.toJson()..['version'] = 2;
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

  print('PASS: $_checks personal packing-list checks.');
}

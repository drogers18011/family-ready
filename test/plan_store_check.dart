import '../lib/plan_store.dart';

const _current = '{"plan":"B: current edits"}';
const _incoming = '{"plan":"A: only previous copy"}';
const _committed = '{"plan":"A: validated and newly saved"}';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class MemoryStore {
  MemoryStore({this.failWrite, this.failCleanup = false});

  final int? failWrite;
  final bool failCleanup;
  final failure = StateError('Injected storage failure');
  final values = <String, String>{
    PlanStore.currentKey: _current,
    PlanStore.previousKey: _incoming,
  };
  final operations = <String>[];
  int _writeCount = 0;

  Future<void> write(String key, String value) async {
    operations.add('write:$key');
    _writeCount += 1;
    if (_writeCount == failWrite) throw failure;
    values[key] = value;
  }

  Future<void> remove(String key) async {
    operations.add('remove:$key');
    if (failCleanup) throw failure;
    values.remove(key);
  }

  PlanStore get store => PlanStore(write: write, remove: remove);
}

Future<RestoreResult> restore(MemoryStore memory) => memory.store.commitRestore(
  currentRaw: _current,
  incomingRaw: _incoming,
  committedRaw: _committed,
);

Future<void> successfulSwap() async {
  final memory = MemoryStore();
  final result = await restore(memory);
  check(!result.recoveryRemains, 'Successful cleanup must clear its flag.');
  check(
    memory.values[PlanStore.currentKey] == _committed,
    'Successful restore must commit the validated incoming record.',
  );
  check(
    memory.values[PlanStore.previousKey] == _current,
    'The complete former current record must remain available.',
  );
  check(
    !memory.values.containsKey(PlanStore.recoveryKey),
    'The journal must be removed after a fully successful restore.',
  );
  check(
    memory.operations.join('|') ==
        'write:${PlanStore.recoveryKey}|write:${PlanStore.previousKey}|'
            'write:${PlanStore.currentKey}|remove:${PlanStore.recoveryKey}',
    'Recovery must be written before either existing copy is replaced.',
  );
}

Future<void> failedWritePreservesCopies(int writeNumber) async {
  final memory = MemoryStore(failWrite: writeNumber);
  RestoreFailure? failure;
  try {
    await restore(memory);
  } on RestoreFailure catch (error) {
    failure = error;
  }
  check(failure != null, 'Write $writeNumber must report a restore failure.');
  check(
    identical(failure!.cause, memory.failure),
    'The original storage failure must be retained.',
  );
  check(
    failure.recoveryAvailable == (writeNumber > 1),
    'Recovery availability must reflect the successful journal write.',
  );
  check(
    failure.previousUpdated == (writeNumber > 2),
    'The previous-copy flag must reflect its successful write.',
  );
  check(
    memory.values[PlanStore.currentKey] == _current,
    'Write $writeNumber failure must preserve the current plan.',
  );
  check(
    memory.values.values.contains(_incoming),
    'Write $writeNumber failure must preserve the unique incoming copy.',
  );
  check(
    memory.values[PlanStore.previousKey] ==
        (writeNumber > 2 ? _current : _incoming),
    'The previous slot must contain the last successfully stored record.',
  );
  check(
    memory.values[PlanStore.recoveryKey] ==
        (writeNumber > 1 ? _incoming : null),
    'A journal that was saved must remain available after failure.',
  );
  check(
    memory.operations.every((operation) => !operation.startsWith('remove:')),
    'A write failure must never attempt to remove the recovery journal.',
  );
}

Future<void> failedCleanupIsCommittedSuccess() async {
  final memory = MemoryStore(failCleanup: true);
  final result = await restore(memory);
  check(
    result.recoveryRemains,
    'Failed cleanup must expose its recovery copy.',
  );
  check(
    memory.values[PlanStore.currentKey] == _committed,
    'Cleanup failure must not undo or misreport the committed plan.',
  );
  check(
    memory.values[PlanStore.previousKey] == _current,
    'Cleanup failure must preserve the former current plan.',
  );
  check(
    memory.values[PlanStore.recoveryKey] == _incoming,
    'Cleanup failure must leave the exact incoming record recoverable.',
  );
}

Future<void> failedFirstWriteKeepsOlderJournal() async {
  final memory = MemoryStore(failWrite: 1);
  const olderJournal = '{"plan":"Earlier failed restore"}';
  memory.values[PlanStore.recoveryKey] = olderJournal;
  try {
    await restore(memory);
    throw StateError('The injected write failure was not reported.');
  } on RestoreFailure catch (error) {
    check(
      !error.recoveryAvailable,
      'This attempt did not confirm a new journal write.',
    );
  }
  check(
    memory.values[PlanStore.recoveryKey] == olderJournal,
    'An unsuccessful first write must not delete an older journal.',
  );
}

Future<void> main() async {
  await successfulSwap();
  for (var write = 1; write <= 3; write += 1) {
    await failedWritePreservesCopies(write);
  }
  await failedCleanupIsCommittedSuccess();
  await failedFirstWriteKeepsOlderJournal();
  print(
    'PASS: 6 restore storage scenarios; current and recovery copies preserved.',
  );
}

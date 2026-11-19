/// The outcome of a committed restore. A failed journal cleanup does not make
/// an otherwise completed restore fail: the UI can offer that copy for recovery.
class RestoreResult {
  const RestoreResult({required this.recoveryRemains});

  final bool recoveryRemains;
}

/// A restore stopped before its current-plan write completed successfully.
///
/// These flags describe writes confirmed during this attempt. In particular,
/// recoveryAvailable == false does not prove that an older recovery key is
/// absent; it means this attempt did not confirm writing its recovery copy.
class RestoreFailure implements Exception {
  const RestoreFailure({
    required this.recoveryAvailable,
    required this.previousUpdated,
    required this.cause,
  });

  final bool recoveryAvailable;
  final bool previousUpdated;
  final Object cause;

  @override
  String toString() =>
      'RestoreFailure(recoveryAvailable: $recoveryAvailable, '
      'previousUpdated: $previousUpdated, cause: $cause)';
}

/// Coordinates restore writes without depending on Flutter or a storage plugin.
///
/// Callers validate the input plan and serialize operations. Each successful
/// [write] must store the complete value for its key before its Future completes.
class PlanStore {
  PlanStore({
    required Future<void> Function(String key, String value) write,
    required Future<void> Function(String key) remove,
  }) : _write = write,
       _remove = remove;

  static const currentKey = 'family_ready.prototype.v1';
  static const previousKey = 'family_ready.prototype.previous';
  static const recoveryKey = 'family_ready.prototype.restore_recovery';

  final Future<void> Function(String key, String value) _write;
  final Future<void> Function(String key) _remove;

  /// Keeps the incoming record recoverable before rotating the previous copy.
  ///
  /// [incomingRaw] is the exact record chosen for restoration; [committedRaw]
  /// is its validated current-schema serialization with the new save time.
  /// Failures leave the journal in place. The caller can then expose it for
  /// download or another restore attempt, including after the app is reopened.
  Future<RestoreResult> commitRestore({
    required String currentRaw,
    required String incomingRaw,
    required String committedRaw,
  }) async {
    var recoveryAvailable = false;
    var previousUpdated = false;

    try {
      await _write(recoveryKey, incomingRaw);
      recoveryAvailable = true;

      await _write(previousKey, currentRaw);
      previousUpdated = true;

      await _write(currentKey, committedRaw);
    } catch (cause, stackTrace) {
      Error.throwWithStackTrace(
        RestoreFailure(
          recoveryAvailable: recoveryAvailable,
          previousUpdated: previousUpdated,
          cause: cause,
        ),
        stackTrace,
      );
    }

    try {
      await _remove(recoveryKey);
      return const RestoreResult(recoveryRemains: false);
    } catch (_) {
      // Current and previous are already committed. Keep the journal and let
      // the UI show a successful restore with an additional recovery copy.
      return const RestoreResult(recoveryRemains: true);
    }
  }
}

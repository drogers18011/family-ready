import 'guide_models.dart';
export 'guide_models.dart';

abstract class PreparedGuide {
  bool get opensBrowserTab;
  Future<void> open();

  /// An opened browser URL remains alive until its document unloads or the
  /// guide is removed, because PDF/video readers may stream it lazily.
  void dispose();
}

abstract class GuideRepository {
  bool get isBrowser;
  int get maxImportBytes;
  Future<GuideLibrary> load();
  Future<GuideRecord> importFile(
    GuideSource source, {
    String? title,
    void Function(double)? onProgress,
  });
  Future<void> rename(GuideRecord record, String title);
  Future<void> remove(GuideRecord record);
  Future<PreparedGuide> prepareOpen(GuideRecord record);
}

/// Serializes operations within a repository, including reads after writes.
class GuideOperationQueue {
  Future<void> _tail = Future<void>.value();
  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

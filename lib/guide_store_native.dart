import 'dart:io';

import 'guide_store.dart';

/// Uses committed per-guide directories. A directory only becomes visible
/// after its file and metadata have been fully written and flushed.
class NativeGuideRepository implements GuideRepository {
  NativeGuideRepository({
    required Future<Directory> Function() directory,
    required Future<void> Function(String path, String mimeType) openFile,
  }) : _directory = directory,
       _openFile = openFile;

  final Future<Directory> Function() _directory;
  final Future<void> Function(String path, String mimeType) _openFile;
  final _queue = GuideOperationQueue();
  Future<Directory>? _rootFuture;
  Future<Directory> get _root {
    final existing = _rootFuture;
    if (existing != null) return existing;
    final future = _createRoot();
    _rootFuture = future;
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_rootFuture, future)) _rootFuture = null;
      },
    );
    return future;
  }

  @override
  bool get isBrowser => false;
  @override
  int get maxImportBytes => nativeGuideImportLimit;

  Future<Directory> _createRoot() async {
    try {
      final root = await _directory();
      await root.create(recursive: true);
      return root;
    } catch (_) {
      _rootFuture = null;
      rethrow;
    }
  }

  String _child(Directory directory, String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  Future<Directory> _guideDirectory(String id) async {
    if (!validGuideId(id))
      throw const GuideException('Invalid guide identifier.');
    return Directory(_child(await _root, id));
  }

  Future<_Metadata> _metadata(Directory directory) async {
    final candidates = <File>[];
    await for (final entry in directory.list(followLinks: false)) {
      if (entry is File &&
          RegExp(r'^record_[0-9]{10}\.json$')
              .hasMatch(entry.uri.pathSegments.last))
        candidates.add(entry);
    }
    if (candidates.isEmpty)
      throw const FormatException('Guide metadata is missing.');
    candidates.sort((a, b) => b.path.compareTo(a.path));
    final file = candidates.first;
    if (await file.length() > 8192)
      throw const FormatException('Guide metadata is too large.');
    final record = GuideRecord.decode(await file.readAsString());
    if (directory.uri.pathSegments.where((part) => part.isNotEmpty).last !=
        record.id) {
      throw const FormatException(
        'Guide identifier does not match its directory.',
      );
    }
    final revision = int.parse(file.uri.pathSegments.last.substring(7, 17));
    return _Metadata(record, revision);
  }

  File _content(Directory directory, GuideRecord record) =>
      File(_child(directory, 'content.${record.extension}'));

  Future<String?> _availability(Directory directory, GuideRecord record) async {
    final file = _content(directory, record);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      return 'The saved file is missing. Import the original again.';
    }
    if (await file.length() != record.bytes) {
      return 'The saved file is incomplete or changed. Import the original again.';
    }
    return null;
  }

  @override
  Future<GuideLibrary> load() => _queue.run(() async {
    final root = await _root;
    final entries = <GuideEntry>[];
    final warnings = <String>[];
    var unfinished = false;
    await for (final directory in root.list(followLinks: false)) {
      final name = directory.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (name.startsWith('.pending_')) {
        unfinished = true;
        continue;
      }
      if (directory is! Directory || !validGuideId(name)) continue;
      try {
        final metadata = await _metadata(directory);
        final problem = await _availability(directory, metadata.record);
        entries.add(
          GuideEntry(
            record: metadata.record,
            available: problem == null,
            problem: problem,
          ),
        );
      } catch (_) {
        warnings.add(
          'A guide record could not be read. Its files have been kept unchanged.',
        );
      }
    }
    if (unfinished)
      warnings.add(
        'An interrupted import has unfinished files. It is not listed as saved; import the original again.',
      );
    entries.sort((a, b) => b.record.addedAt.compareTo(a.record.addedAt));
    return GuideLibrary(entries: entries, warnings: warnings);
  });

  @override
  Future<GuideRecord> importFile(
    GuideSource source, {
    String? title,
    void Function(double)? onProgress,
  }) => _queue.run(() async {
    final record = recordForSource(source, maxImportBytes, title);
    final root = await _root;
    final pending = Directory(_child(root, '.pending_${record.id}'));
    await pending.create();
    RandomAccessFile? output;
    var committed = false;
    try {
      final file = _content(pending, record);
      output = await file.open(mode: FileMode.write);
      var received = 0;
      final header = <int>[];
      await for (final chunk in source.read()) {
        if (received + chunk.length > source.byteLength ||
            received + chunk.length > maxImportBytes) {
          throw const GuideException(
            'The file changed during import. Choose it again.',
          );
        }
        if (header.length < 32) header.addAll(chunk.take(32 - header.length));
        await output.writeFrom(chunk);
        received += chunk.length;
        try {
          onProgress?.call(received / record.bytes);
        } catch (_) {}
      }
      if (received != record.bytes)
        throw const GuideException(
          'The file was not completely copied. Import it again.',
        );
      checkGuideHeader(record.extension, header);
      await output.flush();
      await output.close();
      output = null;
      if (await file.length() != record.bytes)
        throw const GuideException('The saved copy could not be verified.');
      await File(_child(pending, 'record_0000000001.json'))
          .writeAsString(record.encode(), flush: true);
      await pending.rename(_child(root, record.id));
      committed = true;
      return record;
    } finally {
      if (output != null) {
        try {
          await output.close();
        } catch (_) {}
      }
      if (!committed) {
        try {
          await pending.delete(recursive: true);
        } catch (_) {}
      }
    }
  });

  @override
  Future<void> rename(GuideRecord record, String title) => _queue.run(() async {
    final directory = await _guideDirectory(record.id);
    final current = await _metadata(directory);
    final updated = current.record.withTitle(title);
    final revision = current.revision + 1;
    if (revision > 9999999999)
      throw const GuideException('This guide cannot be renamed again.');
    final filename = 'record_${revision.toString().padLeft(10, '0')}.json';
    final pending = File(_child(directory, '$filename.part'));
    try {
      await pending.writeAsString(updated.encode(), flush: true);
      // A new filename avoids replacing an existing file differently on
      // Windows. The previous revision remains recoverable if this fails.
      await pending.rename(_child(directory, filename));
    } finally {
      if (await pending.exists()) {
        try {
          await pending.delete();
        } catch (_) {}
      }
    }
  });

  @override
  Future<void> remove(GuideRecord record) => _queue.run(() async {
    final directory = await _guideDirectory(record.id);
    if (!await directory.exists()) return;
    // Path is derived from a validated random ID, never from an imported name.
    await directory.delete(recursive: true);
  });

  @override
  Future<PreparedGuide> prepareOpen(GuideRecord record) => _queue.run(() async {
    final directory = await _guideDirectory(record.id);
    final current = (await _metadata(directory)).record;
    final problem = await _availability(directory, current);
    if (problem != null) throw GuideException(problem);
    final file = _content(directory, current);
    final input = await file.open();
    try {
      checkGuideHeader(current.extension, await input.read(32));
    } finally {
      await input.close();
    }
    return _NativePreparedGuide(file.path, current.mimeType, _openFile);
  });
}

class _Metadata {
  const _Metadata(this.record, this.revision);
  final GuideRecord record;
  final int revision;
}

class _NativePreparedGuide implements PreparedGuide {
  _NativePreparedGuide(this.path, this.mimeType, this.opener);
  final String path;
  final String mimeType;
  final Future<void> Function(String, String) opener;
  bool _disposed = false;
  @override
  bool get opensBrowserTab => false;
  @override
  Future<void> open() async {
    if (_disposed)
      throw const GuideException('Prepare this guide again before opening it.');
    await opener(path, mimeType);
  }

  @override
  void dispose() => _disposed = true;
}

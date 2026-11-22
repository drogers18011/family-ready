import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'guide_store.dart';

GuideRepository createGuideRepository() => BrowserGuideRepository();

class BrowserGuideRepository implements GuideRepository {
  static const _databaseName = 'black_box.guides.v1';
  static const _metadataStore = 'metadata';
  static const _fileStore = 'files';
  static Future<web.IDBDatabase>? _databaseFuture;
  // Reuse one URL per opened guide. Revoking immediately after opening breaks
  // readers that load PDF/video lazily; the browser releases URLs on unload.
  static final _openedUrls = <String, String>{};
  final _queue = GuideOperationQueue();

  @override
  bool get isBrowser => true;
  @override
  int get maxImportBytes => browserGuideImportLimit;

  Future<web.IDBDatabase> get _database {
    final existing = _databaseFuture;
    if (existing != null) return existing;
    final future = _openDatabase();
    _databaseFuture = future;
    future.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {
        if (identical(_databaseFuture, future)) _databaseFuture = null;
      },
    );
    return future;
  }

  Future<web.IDBDatabase> _openDatabase() {
    final complete = Completer<web.IDBDatabase>();
    try {
      final request = web.window.indexedDB.open(_databaseName, 1);
      request.onupgradeneeded = ((web.Event _) {
        final db = request.result as web.IDBDatabase;
        db.createObjectStore(_metadataStore);
        db.createObjectStore(_fileStore);
      }).toJS;
      request.onsuccess = ((web.Event _) {
        final db = request.result as web.IDBDatabase;
        if (complete.isCompleted) {
          db.close();
          return;
        }
        db.onversionchange = ((web.Event _) {
          db.close();
          _databaseFuture = null;
        }).toJS;
        complete.complete(db);
      }).toJS;
      void fail() {
        _databaseFuture = null;
        if (!complete.isCompleted)
          complete.completeError(
            const GuideException(
              'Browser guide storage is unavailable. Check browser permissions and close older Black Box tabs.',
            ),
          );
      }

      request.onerror = ((web.Event _) => fail()).toJS;
      request.onblocked = ((web.Event _) => fail()).toJS;
    } catch (_) {
      _databaseFuture = null;
      complete.completeError(
        const GuideException('This browser cannot store guides.'),
      );
    }
    return complete.future;
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final complete = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!complete.isCompleted) complete.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!complete.isCompleted)
        complete.completeError(
          const GuideException(
            'Browser storage could not complete the request. Check available space and browser storage settings.',
          ),
        );
    }).toJS;
    return complete.future;
  }

  Future<void> _committed(web.IDBTransaction transaction) {
    final complete = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!complete.isCompleted) complete.complete();
    }).toJS;
    void fail() {
      if (!complete.isCompleted)
        complete.completeError(
          const GuideException(
            'The browser did not save this change. Storage may be full or unavailable; existing saved guides were kept.',
          ),
        );
    }

    transaction.onabort = ((web.Event _) => fail()).toJS;
    transaction.onerror = ((web.Event _) => fail()).toJS;
    return complete.future;
  }

  web.IDBTransaction _transaction(web.IDBDatabase database, String mode) =>
      database.transaction([_metadataStore.toJS, _fileStore.toJS].toJS, mode);

  GuideRecord _decode(JSAny? raw) {
    if (raw == null || !raw.isA<JSString>()) {
      throw const GuideException('The guide record is missing or unreadable.');
    }
    return GuideRecord.decode((raw as JSString).toDart);
  }

  @override
  Future<GuideLibrary> load() => _queue.run(() async {
    final db = await _database;
    final transaction = _transaction(db, 'readonly');
    final records = _request(transaction.objectStore(_metadataStore).getAll());
    final files = _request(transaction.objectStore(_fileStore).getAllKeys());
    final done = _committed(transaction);
    // Observe all errors immediately, including a transaction abort.
    final values = await Future.wait<JSAny?>([
      records,
      files,
      done.then<JSAny?>((_) => null),
    ]);
    final rawRecords = (values[0] as JSArray<JSAny?>).toDart;
    final rawKeys = (values[1] as JSArray<JSAny?>).toDart;
    final keys = rawKeys
        .where((key) => key != null && key.isA<JSString>())
        .map((key) => (key as JSString).toDart)
        .toSet();
    final entries = <GuideEntry>[];
    final warnings = <String>[];
    for (final raw in rawRecords) {
      try {
        final record = _decode(raw);
        final exists = keys.contains(record.id);
        entries.add(
          GuideEntry(
            record: record,
            available: exists,
            problem: exists
                ? null
                : 'The stored file is missing. Import the original again.',
          ),
        );
      } catch (_) {
        warnings.add(
          'A guide record could not be read. Its stored data has been kept unchanged.',
        );
      }
    }
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
    final parts = <JSAny>[];
    final header = <int>[];
    var received = 0;
    await for (final chunk in source.read()) {
      if (received + chunk.length > record.bytes ||
          received + chunk.length > maxImportBytes) {
        throw const GuideException(
          'The file changed during import. Choose it again.',
        );
      }
      if (header.length < 32) header.addAll(chunk.take(32 - header.length));
      // Copy each chunk because a source stream can reuse its buffer.
      parts.add(Uint8List.fromList(chunk).toJS);
      received += chunk.length;
      try {
        onProgress?.call(received / record.bytes);
      } catch (_) {}
    }
    if (received != record.bytes)
      throw const GuideException(
        'The file was not completely read. Import it again.',
      );
    checkGuideHeader(record.extension, header);
    final blob = web.Blob(
      parts.toJS,
      web.BlobPropertyBag(type: record.mimeType),
    );
    if (blob.size != record.bytes)
      throw const GuideException('The saved copy could not be verified.');
    final db = await _database;
    // Do not await file IO inside this transaction. IndexedDB commits the
    // metadata and full Blob together, or aborts both (including quota errors).
    final transaction = _transaction(db, 'readwrite');
    final done = _committed(transaction);
    try {
      transaction.objectStore(_fileStore).put(blob, record.id.toJS);
      transaction
          .objectStore(_metadataStore)
          .put(record.encode().toJS, record.id.toJS);
    } catch (_) {
      transaction.abort();
      // Observe the rejected commit before returning a useful error.
      try {
        await done;
      } catch (_) {}
      throw const GuideException(
        'The browser could not save this guide. Try a smaller file or free browser storage.',
      );
    }
    await done;
    return record;
  });

  @override
  Future<void> rename(GuideRecord record, String title) => _queue.run(() async {
    checkedGuideTitle(title);
    final db = await _database;
    final transaction = _transaction(db, 'readwrite');
    final done = _committed(transaction);
    final request = transaction.objectStore(_metadataStore).get(record.id.toJS);
    Object? failure;
    request.onsuccess = ((web.Event _) {
      try {
        final current = _decode(request.result);
        if (current.id != record.id)
          throw const GuideException('This guide record is inconsistent.');
        transaction
            .objectStore(_metadataStore)
            .put(current.withTitle(title).encode().toJS, record.id.toJS);
      } catch (error) {
        failure = error;
        transaction.abort();
      }
    }).toJS;
    try {
      await done;
    } catch (_) {
      if (failure != null) throw failure!;
      rethrow;
    }
  });

  @override
  Future<void> remove(GuideRecord record) => _queue.run(() async {
    if (!validGuideId(record.id))
      throw const GuideException('Invalid guide identifier.');
    final db = await _database;
    final transaction = _transaction(db, 'readwrite');
    final done = _committed(transaction);
    transaction.objectStore(_metadataStore).delete(record.id.toJS);
    transaction.objectStore(_fileStore).delete(record.id.toJS);
    await done;
    final url = _openedUrls.remove(record.id);
    if (url != null) web.URL.revokeObjectURL(url);
  });

  @override
  Future<PreparedGuide> prepareOpen(GuideRecord record) => _queue.run(() async {
    if (!validGuideId(record.id))
      throw const GuideException('Invalid guide identifier.');
    final db = await _database;
    final transaction = _transaction(db, 'readonly');
    final metadata = _request(
      transaction.objectStore(_metadataStore).get(record.id.toJS),
    );
    final file = _request(
      transaction.objectStore(_fileStore).get(record.id.toJS),
    );
    final done = _committed(transaction);
    final values = await Future.wait<JSAny?>([
      metadata,
      file,
      done.then<JSAny?>((_) => null),
    ]);
    final current = _decode(values[0]);
    final raw = values[1];
    if (current.id != record.id || raw == null || !raw.isA<web.Blob>()) {
      throw const GuideException(
        'The stored file is missing. Import the original again.',
      );
    }
    final blob = raw as web.Blob;
    if (blob.size != current.bytes)
      throw const GuideException(
        'The stored file is incomplete or changed. Import the original again.',
      );
    final first = await blob.slice(0, 32).arrayBuffer().toDart;
    checkGuideHeader(current.extension, first.toDart.asUint8List());
    final existing = _openedUrls[current.id];
    return _BrowserPreparedGuide(
      id: current.id,
      url: existing ?? web.URL.createObjectURL(blob),
      alreadyOpened: existing != null,
      remember: (url) => _openedUrls[current.id] = url,
    );
  });
}

class _BrowserPreparedGuide implements PreparedGuide {
  _BrowserPreparedGuide({
    required this.id,
    required this.url,
    required bool alreadyOpened,
    required this.remember,
  }) : _opened = alreadyOpened;
  final String id;
  final String url;
  final void Function(String) remember;
  bool _opened;
  bool _disposed = false;
  @override
  bool get opensBrowserTab => true;
  @override
  Future<void> open() async {
    if (_disposed)
      throw const GuideException('Prepare this guide again before opening it.');
    // This method must be called directly from a user click, after preparation.
    final link = web.HTMLAnchorElement()
      ..href = url
      ..target = '_blank'
      ..rel = 'noopener noreferrer';
    link.click();
    _opened = true;
    remember(url);
    // This is an open request, not proof that the browser decoded the media.
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (!_opened) web.URL.revokeObjectURL(url);
  }
}

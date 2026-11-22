import 'dart:convert';
import 'dart:io';

import '../lib/guide_models.dart';
import '../lib/guide_store_native.dart';

var checks = 0;
void check(bool condition, String message) {
  if (!condition) throw StateError(message);
  checks++;
}

Future<void> rejects(Future<void> Function() run, String message) async {
  var rejected = false;
  try {
    await run();
  } catch (_) {
    rejected = true;
  }
  check(rejected, message);
}

GuideSource source(String name, List<int> bytes, {int? advertised}) =>
    GuideSource(
      name: name,
      byteLength: advertised ?? bytes.length,
      read: () => Stream<List<int>>.fromIterable([
        bytes.take(3).toList(),
        bytes.skip(3).toList(),
      ]),
    );

Future<void> main() async {
  final folder = await Directory.systemTemp.createTemp(
    'black_box_guides_check_',
  );
  final data = Directory('${folder.path}/guides');
  final pdf = utf8.encode('%PDF-1.7\nexample fixture bytes\n%%EOF');
  final video = <int>[
    0,
    0,
    0,
    20,
    ...ascii.encode('ftyp'),
    ...ascii.encode('isom'),
    0,
    0,
    0,
    0,
  ];
  String? opened;
  NativeGuideRepository repository() => NativeGuideRepository(
    directory: () async => data,
    openFile: (path, _) async {
      opened = path;
    },
  );
  final store = repository();
  try {
    check(
      (await store.load()).entries.isEmpty,
      'Fresh library should be empty.',
    );
    final progress = <double>[];
    final first = await store.importFile(
      source('First guide.PDF', pdf),
      onProgress: progress.add,
    );
    check(
      first.extension == 'pdf' && first.kind == GuideKind.pdf,
      'Type should normalize.',
    );
    check(first.title == 'First guide', 'Title should come from name.');
    check(first.originalName == 'First guide.PDF', 'Original name retained.');
    check(
      progress.last == 1 && progress.first > 0,
      'Progress should reflect copied bytes.',
    );
    check(
      GuideRecord.decode(first.encode()).encode() == first.encode(),
      'Metadata round trip.',
    );
    final reopened = repository();
    final loaded = await reopened.load();
    check(
      loaded.entries.length == 1 && loaded.entries.first.available,
      'Cold reopen should find complete file.',
    );
    final ready = await reopened.prepareOpen(first);
    await ready.open();
    check(
      opened != null && opened!.endsWith('/content.pdf'),
      'Viewer receives copied path.',
    );
    check(
      await File(opened!)
          .readAsBytes()
          .then((bytes) => bytes.join(',') == pdf.join(',')),
      'Copied bytes must match source.',
    );
    ready.dispose();
    await rejects(ready.open, 'Disposed handle cannot reopen.');

    await store.rename(first, 'Water handbook');
    check(
      (await repository().load()).entries.single.record.title ==
          'Water handbook',
      'Rename persists after restart.',
    );
    await rejects(() => store.rename(first, '  '), 'Empty title must fail.');
    check(
      (await store.load()).entries.single.record.title == 'Water handbook',
      'Failed rename keeps old title.',
    );

    await rejects(() async {
      await store.importFile(source('bad.pdf', ascii.encode('not a PDF')));
    }, 'Mislabeled PDF rejected.');
    await rejects(() async {
      await store.importFile(
        source('short.pdf', pdf, advertised: pdf.length + 2),
      );
    }, 'Truncated stream rejected.');
    await rejects(() async {
      await store.importFile(
        source('growing.pdf', pdf, advertised: pdf.length - 1),
      );
    }, 'Overlong stream rejected.');
    await rejects(() async {
      await store.importFile(
        GuideSource(
          name: 'broken.pdf',
          byteLength: pdf.length,
          read: () async* {
            yield pdf.take(5).toList();
            throw StateError('Source disconnected');
          },
        ),
      );
    }, 'Read failure rejected.');
    await rejects(() async {
      await store.importFile(source('guide.exe', pdf));
    }, 'Unsupported extension rejected.');
    await rejects(() async {
      await store.importFile(source('empty.pdf', []));
    }, 'Empty source rejected.');
    var readOversized = false;
    await rejects(() async {
      await store.importFile(
        GuideSource(
          name: 'big.mp4',
          byteLength: nativeGuideImportLimit + 1,
          read: () {
            readOversized = true;
            return const Stream.empty();
          },
        ),
      );
    }, 'Oversized source rejected.');
    check(!readOversized, 'Oversized source must not be read.');
    check(
      (await store.load()).entries.length == 1,
      'Failed imports must not publish records.',
    );
    check(
      !(await data.list().toList()).any(
        (entry) => entry.path.contains('.pending_'),
      ),
      'Failed imports clean staging files when possible.',
    );

    final movie = await store.importFile(source('../../trip.mp4', video));
    check(
      movie.originalName == 'trip.mp4' && validGuideId(movie.id),
      'Imported names cannot control paths.',
    );
    check(movie.kind == GuideKind.video, 'Video kind recognized.');
    check((await store.load()).entries.length == 2, 'Both records coexist.');
    await store.remove(movie);
    check(
      (await store.load()).entries.single.record.id == first.id,
      'Deleting one guide preserves the other.',
    );

    final copy = File('${data.path}/${first.id}/content.pdf');
    await copy.writeAsBytes(pdf.take(5).toList(), flush: true);
    check(
      !(await store.load()).entries.single.available,
      'Changed size is never reported available.',
    );
    await rejects(() async {
      await store.prepareOpen(first);
    }, 'Changed file cannot be opened as complete.');
    await copy.writeAsBytes(pdf, flush: true);
    check(
      (await store.load()).entries.single.available,
      'Restored bytes can be used.',
    );
    await copy.delete();
    check(
      !(await store.load()).entries.single.available,
      'Missing file is visible but unavailable.',
    );
    await store.remove(first);
    check((await store.load()).entries.isEmpty, 'Removal clears final entry.');

    var firstDirectoryAttempt = true;
    final retryStore = NativeGuideRepository(
      directory: () async {
        if (firstDirectoryAttempt) {
          firstDirectoryAttempt = false;
          throw const FileSystemException('temporary');
        }
        return data;
      },
      openFile: (_, __) async {},
    );
    await rejects(() async {
      await retryStore.load();
    }, 'Directory failure exposed.');
    check(
      (await retryStore.load()).entries.isEmpty,
      'Directory retry can succeed.',
    );

    final a = store.importFile(source('a.pdf', pdf));
    final b = store.importFile(source('b.pdf', pdf));
    final pair = await Future.wait([a, b]);
    check(
      pair[0].id != pair[1].id && (await store.load()).entries.length == 2,
      'Queued imports preserve both files.',
    );
    final broken = File('${data.path}/${pair[0].id}/record_0000000001.json');
    await broken.writeAsString('corrupt', flush: true);
    final damaged = await store.load();
    check(
      damaged.entries.length == 1 && damaged.warnings.isNotEmpty,
      'Corrupt record produces warning.',
    );
    check(
      await broken.exists() &&
          await File('${data.path}/${pair[0].id}/content.pdf').exists(),
      'Corruption must not erase source files.',
    );
    await Directory('${data.path}/.pending_interrupted').create();
    check(
      (await store.load()).warnings.any(
        (warning) => warning.contains('interrupted'),
      ),
      'Interrupted import cannot be marked saved.',
    );

    print('$checks guide storage checks passed.');
  } finally {
    await folder.delete(recursive: true);
  }
}

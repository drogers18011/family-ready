import 'dart:convert';
import 'dart:math';

const nativeGuideImportLimit = 1024 * 1024 * 1024;
const browserGuideImportLimit = 100 * 1024 * 1024;

enum GuideKind { pdf, video }

class GuideException implements Exception {
  const GuideException(this.message);
  final String message;
  @override
  String toString() => message;
}

class GuideSource {
  const GuideSource({
    required this.name,
    required this.byteLength,
    required this.read,
  });
  final String name;
  final int byteLength;
  final Stream<List<int>> Function() read;
}

class GuideRecord {
  GuideRecord({
    required this.id,
    required this.title,
    required this.originalName,
    required this.extension,
    required this.bytes,
    required this.addedAt,
  }) {
    if (!validGuideId(id) ||
        title.trim().isEmpty ||
        title.length > 120 ||
        originalName.isEmpty ||
        originalName.length > 240 ||
        !guideMimeTypes.containsKey(extension) ||
        bytes <= 0 ||
        bytes > nativeGuideImportLimit) {
      throw const FormatException('Invalid guide metadata.');
    }
  }

  final String id;
  final String title;
  final String originalName;
  final String extension;
  final int bytes;
  final DateTime addedAt;
  GuideKind get kind => extension == 'pdf' ? GuideKind.pdf : GuideKind.video;
  String get mimeType => guideMimeTypes[extension]!;

  GuideRecord withTitle(String value) => GuideRecord(
    id: id,
    title: checkedGuideTitle(value),
    originalName: originalName,
    extension: extension,
    bytes: bytes,
    addedAt: addedAt,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'originalName': originalName,
    'extension': extension,
    'bytes': bytes,
    'addedAt': addedAt.toUtc().toIso8601String(),
  };
  String encode() => jsonEncode(toJson());

  factory GuideRecord.decode(String raw) {
    if (raw.length > 8192)
      throw const FormatException('Guide record too large.');
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['originalName'] is! String ||
        value['extension'] is! String ||
        value['bytes'] is! int ||
        value['addedAt'] is! String) {
      throw const FormatException('Invalid guide metadata.');
    }
    final date = DateTime.tryParse(value['addedAt'] as String);
    if (date == null) throw const FormatException('Invalid guide date.');
    return GuideRecord(
      id: value['id'] as String,
      title: value['title'] as String,
      originalName: value['originalName'] as String,
      extension: value['extension'] as String,
      bytes: value['bytes'] as int,
      addedAt: date.toUtc(),
    );
  }
}

const guideMimeTypes = <String, String>{
  'pdf': 'application/pdf',
  'mp4': 'video/mp4',
  'm4v': 'video/x-m4v',
  'mov': 'video/quicktime',
};

bool validGuideId(String id) => RegExp(r'^[a-f0-9]{32}$').hasMatch(id);
String newGuideId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

String checkedGuideTitle(String value) {
  final title = value.trim();
  if (title.isEmpty || title.length > 120) {
    throw const GuideException('Use a title between 1 and 120 characters.');
  }
  return title;
}

String cleanGuideFilename(String value) {
  final name = value
      .replaceAll('\\', '/')
      .split('/')
      .last
      .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
      .trim();
  if (name.isEmpty || name.length > 240) {
    throw const GuideException('Choose a file with a shorter, readable name.');
  }
  return name;
}

GuideRecord recordForSource(GuideSource source, int limit, String? title) {
  final name = cleanGuideFilename(source.name);
  final split = name.lastIndexOf('.');
  final extension = split >= 0 ? name.substring(split + 1).toLowerCase() : '';
  if (!guideMimeTypes.containsKey(extension)) {
    throw const GuideException('Choose a PDF, MP4, M4V, or MOV file.');
  }
  if (source.byteLength <= 0) throw const GuideException('This file is empty.');
  if (source.byteLength > limit) {
    throw GuideException(
      'Choose a file no larger than ${limit ~/ (1024 * 1024)} MB.',
    );
  }
  final suggested = name.substring(0, split).trim();
  final fallback = suggested.isEmpty ? name : suggested;
  return GuideRecord(
    id: newGuideId(),
    title: checkedGuideTitle(
      title ?? (fallback.length > 120 ? fallback.substring(0, 120) : fallback),
    ),
    originalName: name,
    extension: extension,
    bytes: source.byteLength,
    addedAt: DateTime.now().toUtc(),
  );
}

/// Minimal container recognition only; this does not prove media can decode.
void checkGuideHeader(String extension, List<int> header) {
  if (extension == 'pdf') {
    if (header.length < 5 ||
        ascii.decode(header.take(5).toList(), allowInvalid: true) != '%PDF-') {
      throw const GuideException('This does not look like a PDF file.');
    }
    return;
  }
  if (header.length < 12)
    throw const GuideException('This video file is incomplete.');
  final box = ascii.decode(header.sublist(4, 8), allowInvalid: true);
  final permitted = extension == 'mov'
      ? const {'ftyp', 'moov', 'mdat', 'wide', 'free', 'skip'}
      : const {'ftyp'};
  if (!permitted.contains(box)) {
    throw const GuideException(
      'This does not look like a supported video container.',
    );
  }
}

class GuideEntry {
  const GuideEntry({
    required this.record,
    required this.available,
    this.problem,
  });
  final GuideRecord record;
  final bool available;
  final String? problem;
}

class GuideLibrary {
  const GuideLibrary({required this.entries, this.warnings = const []});
  final List<GuideEntry> entries;
  final List<String> warnings;
}

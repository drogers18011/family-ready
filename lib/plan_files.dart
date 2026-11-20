import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_selector/file_selector.dart'
    show XTypeGroup, getSaveLocation, openFile;
import 'package:flutter/foundation.dart';

/// Importing a small plan should never allocate space for an arbitrary file.
const int maxPlanBackupBytes = 2 * 1024 * 1024;

const _jsonType = XTypeGroup(
  label: 'Black Box backup',
  extensions: ['json'],
  mimeTypes: ['application/json'],
  uniformTypeIdentifiers: ['public.json'],
);

const _textType = XTypeGroup(
  label: 'Text document',
  extensions: ['txt'],
  mimeTypes: ['text/plain'],
  uniformTypeIdentifiers: ['public.plain-text'],
);

class SelectedPlanFile {
  const SelectedPlanFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

class PlanFileException implements Exception {
  const PlanFileException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Picks and reads a backup without changing the current plan.
///
/// Cancellation returns null. JSON/schema validation belongs to the caller,
/// which can show a preview before the user chooses to replace a plan.
Future<SelectedPlanFile?> pickPlanBackup() async {
  final selected = await openFile(
    acceptedTypeGroups: const [_jsonType],
    confirmButtonText: 'Choose backup',
  );
  if (selected == null) return null;

  final length = await selected.length();
  if (length > maxPlanBackupBytes) {
    throw const PlanFileException('Choose a backup smaller than 2 MB.');
  }
  if (length == 0) {
    throw const PlanFileException('This file is empty. Choose another backup.');
  }

  // Keep the read bounded to the inspected size, even if a native file grows.
  // A native in-memory XFile uses Uint8List.sublist, so its end must not be
  // larger than the file length (web Blob.slice would clamp it automatically).
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in selected.openRead(0, length)) {
    if (buffer.length + chunk.length > maxPlanBackupBytes) {
      throw const PlanFileException('Choose a backup smaller than 2 MB.');
    }
    buffer.add(chunk);
  }

  String contents;
  try {
    contents = utf8.decode(buffer.takeBytes());
  } on FormatException {
    throw const PlanFileException(
      'This file is not a UTF-8 text backup. Choose a Black Box JSON file.',
    );
  }
  // Accept UTF-8 files saved by editors that include a byte-order mark.
  if (contents.startsWith('\uFEFF')) contents = contents.substring(1);
  if (contents.trim().isEmpty) {
    throw const PlanFileException('This file is empty. Choose another backup.');
  }

  return SelectedPlanFile(name: selected.name, contents: contents);
}

/// Saves a UTF-8 JSON or text document, or starts a browser download.
///
/// On desktop, false means that the save dialog was cancelled. On web, true
/// means that the download was requested: browsers do not report whether the
/// user ultimately kept the file. Call this from a user-initiated button.
Future<bool> savePlanFile({
  required String contents,
  required String filename,
  required String mimeType,
}) async {
  final file = XFile.fromData(
    Uint8List.fromList(utf8.encode(contents)),
    name: filename,
    mimeType: mimeType,
  );

  if (kIsWeb) {
    // cross_file 0.3.5+5 uses the XFile name as the download filename;
    // saveTo's path argument is deliberately ignored by its web version.
    await file.saveTo(filename);
    return true;
  }

  if (defaultTargetPlatform != TargetPlatform.windows &&
      defaultTargetPlatform != TargetPlatform.macOS &&
      defaultTargetPlatform != TargetPlatform.linux) {
    throw const PlanFileException(
      'File export is available in the browser and desktop preview. '
      'Mobile file sharing has not been added yet.',
    );
  }

  final location = await getSaveLocation(
    suggestedName: filename,
    acceptedTypeGroups: [
      mimeType == 'application/json' ? _jsonType : _textType,
    ],
    confirmButtonText: 'Save file',
  );
  if (location == null) return false;
  await file.saveTo(location.path);
  return true;
}

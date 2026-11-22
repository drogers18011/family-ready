import 'package:file_selector/file_selector.dart' show XTypeGroup, openFile;

import 'guide_store.dart';
import 'guide_platform_stub.dart'
    if (dart.library.io) 'guide_platform_native.dart'
    if (dart.library.js_interop) 'guide_platform_web.dart'
    as platform;
export 'guide_store.dart';

// Keep the operation queue and opened browser URLs across visits to Guides.
// A new screen must not create another retained URL for the same saved file.
GuideRepository? _repository;
GuideRepository createGuideRepository() =>
    _repository ??= platform.createGuideRepository();

const _guideTypes = XTypeGroup(
  label: 'PDF and video guides',
  extensions: ['pdf', 'mp4', 'm4v', 'mov'],
  mimeTypes: ['application/pdf', 'video/mp4', 'video/x-m4v', 'video/quicktime'],
  uniformTypeIdentifiers: [
    'com.adobe.pdf',
    'public.mpeg-4',
    'com.apple.m4v-video',
    'com.apple.quicktime-movie',
  ],
);

/// The picker may download a cloud-only source first. The repository then
/// copies the actual bytes; it never stores a picker or cloud URL as a guide.
Future<GuideSource?> pickGuideSource() async {
  final file = await openFile(
    acceptedTypeGroups: const [_guideTypes],
    confirmButtonText: 'Import guide',
  );
  if (file == null) return null;
  final size = await file.length();
  return GuideSource(
    name: file.name,
    byteLength: size,
    read: () => file.openRead(0, size),
  );
}

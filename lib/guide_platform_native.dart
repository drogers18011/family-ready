import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'guide_store.dart';
import 'guide_store_native.dart';

GuideRepository createGuideRepository() => NativeGuideRepository(
  directory: () async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(
      '${documents.path}${Platform.pathSeparator}black_box_guides_v1',
    );
  },
  openFile: (path, mimeType) async {
    if (Platform.isIOS || Platform.isAndroid) {
      final result = await OpenFilex.open(path, type: mimeType);
      if (result.type != ResultType.done) {
        throw const GuideException(
          'The device could not open this file. Check its format and that a suitable viewer is available.',
        );
      }
      return;
    }
    final opened = await launchUrl(
      Uri.file(path),
      mode: LaunchMode.externalApplication,
    );
    if (!opened)
      throw const GuideException(
        'No application could open this file on this computer.',
      );
  },
);

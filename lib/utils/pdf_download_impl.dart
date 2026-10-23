import 'package:flutter/foundation.dart';
import 'pdf_download_web.dart' if (dart.library.io) 'pdf_download_io.dart' as platform;

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  if (kIsWeb) {
    await platform.downloadPdf(bytes, filename);
    return;
  }

  await platform.downloadPdf(bytes, filename);
}

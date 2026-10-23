import 'dart:typed_data';
import 'dart:html' as html;
import 'package:entryon/utils/file_name_utils.dart';

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  final safeFileName = buildSafeExportFileName(filename, extension: 'pdf');
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeFileName)
    ..style.display = 'none';
  html.document.body!.children.add(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

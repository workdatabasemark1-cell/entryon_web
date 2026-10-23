import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:entryon/utils/file_name_utils.dart';

Future<void> downloadPdf(Uint8List bytes, String filename) async {
  final safeFileName = buildSafeExportFileName(filename, extension: 'pdf');
  final outputDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  final savePath = '${outputDir.path}/$safeFileName';
  final file = File(savePath);
  await file.writeAsBytes(bytes, flush: true);

  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save PDF',
    fileName: safeFileName,
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result != null) {
    final finalFile = File(result);
    await finalFile.writeAsBytes(bytes, flush: true);
  }
}

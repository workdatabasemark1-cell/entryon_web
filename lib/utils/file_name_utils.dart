String buildSafeExportFileName(String? value, {String extension = 'xlsx'}) {
  var normalized = (value ?? '').trim();
  final normalizedExtension = extension.toLowerCase();

  if (normalized.toLowerCase().endsWith('.$normalizedExtension')) {
    normalized = normalized.substring(0, normalized.length - normalizedExtension.length - 1);
  }

  final safeBase = normalized
      .replaceAll(RegExp(r'[\\/<>:"|?*\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  final baseName = safeBase.isEmpty ? 'invoice' : safeBase;
  return 'invoice_$baseName.$normalizedExtension';
}

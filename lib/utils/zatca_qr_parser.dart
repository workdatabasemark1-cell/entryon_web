import 'dart:convert';
import 'dart:typed_data';

/// Parses ZATCA (Saudi Arabia) e-invoice QR codes.
/// The QR payload is Base64-encoded TLV (Tag-Length-Value) data.
class ZatcaQrParser {
  /// Returns null if the string is not a valid ZATCA QR code.
  static ZatcaQrData? parse(String raw) {
    try {
      // The payload may already be Base64, or it may be raw TLV bytes
      // represented as a Base64 string.
      final bytes = _decodeBase64(raw);
      if (bytes == null) return null;
      return _parseTlv(bytes);
    } catch (_) {
      return null;
    }
  }

  static Uint8List? _decodeBase64(String input) {
    try {
      final value = input.trim();
      if (value.isEmpty) return null;
      final paddingLength = (4 - value.length % 4) % 4;
      return base64Decode(
        paddingLength == 0
            ? value
            : value.padRight(value.length + paddingLength, '='),
      );
    } catch (_) {
      return null;
    }
  }

  static ZatcaQrData _parseTlv(Uint8List bytes) {
    String sellerName = '';
    String vatNumber = '';
    String invoiceDate = '';
    String totalIncVat = '';
    String vatAmount = '';

    int i = 0;
    while (i < bytes.length) {
      if (bytes.length - i < 2) {
        throw const FormatException('Incomplete TLV header');
      }
      final tag = bytes[i];
      final length = bytes[i + 1];
      i += 2;
      if (length > bytes.length - i) {
        throw const FormatException('Incomplete TLV value');
      }
      final value = _decodeValue(bytes, i, i + length);
      i += length;

      switch (tag) {
        case 1:
          sellerName = value;
        case 2:
          vatNumber = value;
        case 3:
          invoiceDate = value;
        case 4:
          totalIncVat = value;
        case 5:
          vatAmount = value;
      }
    }

    return ZatcaQrData(
      sellerName: sellerName,
      vatNumber: vatNumber,
      invoiceDate: invoiceDate,
      totalIncVat: totalIncVat,
      vatAmount: vatAmount,
    );
  }
}

String _decodeValue(Uint8List bytes, int start, int end) {
  try {
    final valueBytes = Uint8List.sublistView(bytes, start, end);
    return utf8.decode(valueBytes, allowMalformed: true);
  } catch (_) {
    return String.fromCharCodes(bytes.sublist(start, end));
  }
}

class ZatcaQrData {
  final String sellerName;
  final String vatNumber;
  final String invoiceDate; // ISO-8601 string e.g. "2024-01-15T10:00:00Z"
  final String totalIncVat;
  final String vatAmount;

  const ZatcaQrData({
    required this.sellerName,
    required this.vatNumber,
    required this.invoiceDate,
    required this.totalIncVat,
    required this.vatAmount,
  });

  @override
  String toString() =>
      'ZatcaQrData(seller: $sellerName, vat: $vatNumber, '
      'date: $invoiceDate, total: $totalIncVat, vatAmt: $vatAmount)';
}

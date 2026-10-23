import 'dart:convert';
import 'dart:io' show File; // For mobile/desktop; on Web use bytes from picker.
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import '../models/customer_data.dart';

/// Groq Vision-based extraction service (no billing, free API).
class ExtractionService {
  /// Your Groq API key (set via --dart-define=GROQ_API_KEY=...).
  static const String apiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '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');

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.2-11b-vision';

  static const String _systemPrompt = '''
You are a data-extraction engine for Saudi business onboarding documents
(Commercial Registration certificates, TIN/tax number screenshots, ZATCA
address proofs, VAT certificates). You will be shown one or more images.
Read all Arabic and English text carefully, including tables and stamped
numbers, and extract the following fields.

Return ONLY a single valid JSON object, no markdown fences, no commentary,
no explanation before or after. If a field cannot be found in any image,
return it as an empty string - never guess or invent a value.

JSON keys to return:
{
  "organizationUnitName": "",   // e.g. branch trade name (الإسم التجاري للفرع)
  "organizationName": "",       // main entity / trader name (إسم التاجر)
  "organizationUnitTin": "",    // 10-digit tax identification number (الرقم الضريبي)
  "vatNo": "",                  // VAT number if shown separately from TIN
  "businessCategory": "",       // activity / نشاط
  "email": "",
  "telephone": "",              // هاتف
  "buildingNo": "",             // رقم المبنى
  "streetName": "",             // الشارع
  "districtName": "",           // الحي
  "cityName": "",               // المدينة
  "zipCode": "",                // الرمز البريدي
  "additionalNo": "",           // الرقم الفرعي / إضافي
  "unitNo": "",                 // unit number if present
  "cr": ""                      // commercial registration / unified number (رقم السجل التجاري / رقم الموحد)
}

Notes:
- TIN and VAT number are often the same 10-15 digit number; if only one
  numeric ID is present, put it in organizationUnitTin AND vatNo.
- Arabic-Indic digits (٠١٢٣٤٥٦٧٨٩) must be converted to normal digits.
- Do not include zatcaUsername, zatcaPassword, commonName, country, or
  registeredAddress - those are handled separately by the app.
''';

  /// [images] is the list of picked document screenshots.
  static Future<CustomerData> extractFields(List<File> images) async {
    if (apiKey.isEmpty) {
      throw ExtractionException(
        'No Groq API key configured. Pass --dart-define=GROQ_API_KEY=... '
        'for local testing/production.',
      );
    }
    if (images.isEmpty) {
      throw ExtractionException('No images selected.');
    }

    final imageBlocks = await Future.wait(images.map(_toImageBlock));

    final body = jsonEncode({
      'model': _model,
      'response_format': {'type': 'json_object'},
      'messages': [
        {
          'role': 'system',
          'content': [
            {
              'type': 'text',
              'text': _systemPrompt,
            },
          ],
        },
        {
          'role': 'user',
          'content': [
            ...imageBlocks,
            {
              'type': 'text',
              'text':
                  'Extract the fields from these document images and return only the JSON object.',
            },
          ],
        },
      ],
    });

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw ExtractionException(
        'Groq API error ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw ExtractionException('No choices returned from Groq API.');
    }

    final message = choices.first['message'] as Map<String, dynamic>;
    final contentBlocks = message['content'] as List<dynamic>? ?? [];
    final text = contentBlocks
        .where((b) => b['type'] == 'text')
        .map((b) => b['text'] as String)
        .join('\n');

    try {
      final parsed = jsonDecode(text) as Map<String, dynamic>;
      return CustomerData.fromJson(parsed);
    } catch (e) {
      throw ExtractionException(
        'Could not parse Groq response as JSON: $e\nRaw response:\n$text',
      );
    }
  }

  /// Builds a Groq vision content block from a local image file.
  static Future<Map<String, dynamic>> _toImageBlock(File file) async {
    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    final ext = p.extension(file.path).toLowerCase();
    final mediaType = switch (ext) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    final dataUri = 'data:$mediaType;base64,$base64Data';

    return {
      'type': 'image_url',
      'image_url': {
        'url': dataUri,
      },
    };
  }
}

class ExtractionException implements Exception {
  final String message;
  ExtractionException(this.message);
  @override
  String toString() => message;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:entryon/utils/customer_text_parser.dart';

void main() {
  group('CustomerTextParser Tests', () {
    test('Parses user sample text file format with mixed delimiters and spaces', () {
      const sample = '''
Country = SAUDI ARABIA
Organization Unit name  =Technology Computer 
Organization  name =مؤسسة عبدالرحمن عبدالله بن عبدالكريم الجهوري للصيانة
Organization Unit (TIN 10 Digit) =3108960731  
Common Name =Auto
Registered Address =Al Ajawad Street,Al Samir District,Jeddah Municipality – Buraiman Sub-Municipality,Jeddah, Saudi Arabia
Business Category = Trading
VAT No: 310896073100003
Email :
TelePhone :
Zatca credentials username :3108960731
  password :
Building no : 3525
street name :Al Ajawad
District Name : Al Samir
City Name : Jeddah
zip code : 23462
addit No : 7085
unit no :
Cr: 7021871715
''';

      final parsed = CustomerTextParser.parse(sample);

      expect(parsed.country, equals('SAUDI ARABIA'));
      expect(parsed.organizationUnitName, equals('Technology Computer'));
      expect(parsed.organizationName, equals('مؤسسة عبدالرحمن عبدالله بن عبدالكريم الجهوري للصيانة'));
      expect(parsed.commonName, equals('Auto'));
      expect(parsed.tin, equals('3108960731'));
      expect(parsed.registeredAddress, equals('Al Ajawad Street,Al Samir District,Jeddah Municipality – Buraiman Sub-Municipality,Jeddah, Saudi Arabia'));
      expect(parsed.businessCategory, equals('Trading'));
      expect(parsed.vatNo, equals('310896073100003'));
      expect(parsed.email, isNull);
      expect(parsed.phone, isNull);
      expect(parsed.zatcaUsername, equals('3108960731'));
      expect(parsed.zatcaPassword, isNull);
      expect(parsed.buildingNo, equals('3525'));
      expect(parsed.streetName, equals('Al Ajawad'));
      expect(parsed.districtName, equals('Al Samir'));
      expect(parsed.cityName, equals('Jeddah'));
      expect(parsed.zipCode, equals('23462'));
      expect(parsed.additionalNo, equals('7085'));
      expect(parsed.unitNo, isNull);
      expect(parsed.crNumber, equals('7021871715'));

      // Check primary getters
      expect(parsed.primaryCustomerName, equals('Technology Computer'));
      expect(parsed.primaryAddress, contains('Al Ajawad Street'));
      expect(parsed.filledFieldCount, greaterThanOrEqualTo(12));
    });

    test('Parses screenshot format from Digisuite/Saleculator settings', () {
      const screenshotSample = '''
Name = Moune Rodan Trading
Company Details (Arabic) Name = مؤسسة مؤن رودان التجارية
Company Details (Arabic) Address = حي السرورية , 22523, جدة , المملكة العربية السعودية
Address = Ahmad Baqi
Address 2 = 4202
Place = Jeddah
Building No = 4202
Postal No = 22523
Country = KSA
CR Number = 7054811213
Short Name = DIGISUITE
''';

      final parsed = CustomerTextParser.parse(screenshotSample);
      expect(parsed.primaryCustomerName, equals('Moune Rodan Trading'));
      expect(parsed.organizationName, equals('مؤسسة مؤن رودان التجارية'));
      expect(parsed.registeredAddress, contains('حي السرورية'));
      expect(parsed.generalAddress, contains('Ahmad Baqi'));
      expect(parsed.cityName, equals('Jeddah'));
      expect(parsed.buildingNo, equals('4202'));
      expect(parsed.zipCode, equals('22523'));
      expect(parsed.country, equals('KSA'));
      expect(parsed.crNumber, equals('7054811213'));
      expect(parsed.commonName, equals('DIGISUITE'));
    });
  });
}

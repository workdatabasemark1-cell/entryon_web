/// Data model representing company/customer information extracted
/// from imported text files or pasted strings.
class ParsedCustomerData {
  final String? country;
  final String? organizationUnitName;
  final String? organizationName;
  final String? commonName;
  final String? registeredAddress;
  final String? businessCategory;
  final String? vatNo;
  final String? email;
  final String? phone;
  final String? zatcaUsername;
  final String? zatcaPassword;
  final String? buildingNo;
  final String? streetName;
  final String? districtName;
  final String? cityName;
  final String? zipCode;
  final String? additionalNo;
  final String? unitNo;
  final String? crNumber;
  final String? careOf;
  final String? generalAddress;
  final String? tin;
  final Map<String, String> rawPairs;

  const ParsedCustomerData({
    this.country,
    this.organizationUnitName,
    this.organizationName,
    this.commonName,
    this.registeredAddress,
    this.businessCategory,
    this.vatNo,
    this.email,
    this.phone,
    this.zatcaUsername,
    this.zatcaPassword,
    this.buildingNo,
    this.streetName,
    this.districtName,
    this.cityName,
    this.zipCode,
    this.additionalNo,
    this.unitNo,
    this.crNumber,
    this.careOf,
    this.generalAddress,
    this.tin,
    this.rawPairs = const {},
  });

  /// Best display/primary customer name for the mandatory customer name field
  String get primaryCustomerName {
    if (organizationUnitName != null && organizationUnitName!.trim().isNotEmpty) {
      return organizationUnitName!.trim();
    }
    if (organizationName != null && organizationName!.trim().isNotEmpty) {
      return organizationName!.trim();
    }
    if (commonName != null && commonName!.trim().isNotEmpty) {
      return commonName!.trim();
    }
    return '';
  }

  /// Best composite primary address if generalAddress is not explicitly provided
  String get primaryAddress {
    if (generalAddress != null && generalAddress!.trim().isNotEmpty) {
      return generalAddress!.trim();
    }
    if (registeredAddress != null && registeredAddress!.trim().isNotEmpty) {
      return registeredAddress!.trim();
    }
    final parts = [
      if (buildingNo != null && buildingNo!.trim().isNotEmpty) buildingNo!.trim(),
      if (streetName != null && streetName!.trim().isNotEmpty) streetName!.trim(),
      if (districtName != null && districtName!.trim().isNotEmpty) districtName!.trim(),
      if (cityName != null && cityName!.trim().isNotEmpty) cityName!.trim(),
      if (zipCode != null && zipCode!.trim().isNotEmpty) zipCode!.trim(),
      if (country != null && country!.trim().isNotEmpty) country!.trim(),
    ];
    return parts.join(', ');
  }

  /// Count of non-empty attributes extracted
  int get filledFieldCount {
    int count = 0;
    if (_has(country)) count++;
    if (_has(organizationUnitName)) count++;
    if (_has(organizationName)) count++;
    if (_has(commonName)) count++;
    if (_has(registeredAddress)) count++;
    if (_has(businessCategory)) count++;
    if (_has(vatNo)) count++;
    if (_has(email)) count++;
    if (_has(phone)) count++;
    if (_has(zatcaUsername)) count++;
    if (_has(zatcaPassword)) count++;
    if (_has(buildingNo)) count++;
    if (_has(streetName)) count++;
    if (_has(districtName)) count++;
    if (_has(cityName)) count++;
    if (_has(zipCode)) count++;
    if (_has(additionalNo)) count++;
    if (_has(unitNo)) count++;
    if (_has(crNumber)) count++;
    if (_has(careOf)) count++;
    if (_has(generalAddress)) count++;
    return count;
  }

  bool _has(String? val) => val != null && val.trim().isNotEmpty;
}

/// Parser for structured key-value text files (.txt / .ini / raw copy-paste)
class CustomerTextParser {
  /// Parse text input into [ParsedCustomerData].
  /// Supports both `:` and `=` delimiters, case-insensitivity,
  /// trimmed whitespace, and flexible key naming conventions.
  static ParsedCustomerData parse(String text) {
    if (text.trim().isEmpty) {
      return const ParsedCustomerData();
    }

    final Map<String, String> pairs = {};
    final lines = text.split(RegExp(r'\r?\n'));

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      // Skip commented lines
      if (line.startsWith('#') || line.startsWith('//')) continue;

      // Find first delimiter '=' or ':'
      final eqIdx = line.indexOf('=');
      final colIdx = line.indexOf(':');

      int sepIdx = -1;
      if (eqIdx != -1 && colIdx != -1) {
        sepIdx = eqIdx < colIdx ? eqIdx : colIdx;
      } else if (eqIdx != -1) {
        sepIdx = eqIdx;
      } else if (colIdx != -1) {
        sepIdx = colIdx;
      }

      if (sepIdx != -1) {
        final rawKey = line.substring(0, sepIdx).trim();
        final rawVal = line.substring(sepIdx + 1).trim();
        if (rawKey.isNotEmpty) {
          pairs[rawKey] = rawVal;
        }
      }
    }

    String? country;
    String? organizationUnitName;
    String? organizationName;
    String? commonName;
    String? registeredAddress;
    String? businessCategory;
    String? vatNo;
    String? email;
    String? phone;
    String? zatcaUsername;
    String? zatcaPassword;
    String? buildingNo;
    String? streetName;
    String? districtName;
    String? cityName;
    String? zipCode;
    String? additionalNo;
    String? unitNo;
    String? crNumber;
    String? careOf;
    String? generalAddress;
    String? tin;

    pairs.forEach((k, v) {
      final norm = k.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      final val = v.trim();

      // Skip completely empty values
      if (val.isEmpty) return;

      // 1. Organization Unit Name (e.g. Technology Computer)
      if (norm.contains('organization unit name') ||
          norm == 'org unit name' ||
          norm == 'organization unit' ||
          norm == 'unit name') {
        organizationUnitName = val;
      }
      // 2. Organization Name (Arabic / legal entity name)
      else if (norm == 'organization name' ||
          norm == 'org name' ||
          (norm.contains('arabic') && norm.contains('name')) ||
          norm.contains('company name (arabic)') ||
          norm.contains('name (arabic)') ||
          norm == 'arabic name') {
        organizationName = val;
      }
      // 3. Organization Unit TIN (10 Digit)
      else if (norm.contains('tin') || norm.contains('unit (tin')) {
        tin = val;
      }
      // 4. Common Name / Short Name
      else if (norm == 'common name' ||
          norm == 'short name' ||
          norm == 'brand name') {
        commonName = val;
      }
      // 5. Registered Address
      else if (norm.contains('registered address') ||
          norm.contains('reg address') ||
          (norm.contains('arabic') && norm.contains('address')) ||
          norm.contains('arabic address')) {
        registeredAddress = val;
      }
      // 6. Business Category
      else if (norm.contains('business category') ||
          norm == 'category' ||
          norm == 'activity') {
        businessCategory = val;
      }
      // 7. VAT Number / TRN
      else if (norm.contains('vat no') ||
          norm.contains('vat number') ||
          norm.contains('tax no') ||
          norm.contains('tax number') ||
          norm == 'trn' ||
          norm.contains('trn (mob app)') ||
          norm == 'vat') {
        vatNo = val;
      }
      // 8. Email
      else if (norm == 'email' || norm == 'e-mail' || norm == 'mail') {
        email = val;
      }
      // 9. Phone / Telephone
      else if (norm.contains('telephone') ||
          norm == 'phone' ||
          norm == 'mobile' ||
          norm == 'tel' ||
          norm.contains('phone no')) {
        phone = val;
      }
      // 10. ZATCA Username
      else if (norm.contains('zatca credentials username') ||
          norm.contains('zatca username') ||
          norm == 'zatca user') {
        zatcaUsername = val;
      }
      // 11. ZATCA Password
      else if (norm.contains('zatca credentials password') ||
          norm.contains('zatca password') ||
          norm == 'password') {
        zatcaPassword = val;
      }
      // 12. Building No
      else if (norm.contains('building no') ||
          norm.contains('building number') ||
          norm == 'bldg no' ||
          norm == 'building') {
        buildingNo = val;
      }
      // 13. Street Name
      else if (norm.contains('street name') || norm == 'street') {
        streetName = val;
      }
      // 14. District Name
      else if (norm.contains('district name') ||
          norm == 'district' ||
          norm == 'neighborhood') {
        districtName = val;
      }
      // 15. City Name / Place
      else if (norm.contains('city name') ||
          norm == 'city' ||
          norm == 'place' ||
          norm == 'place 2') {
        cityName = val;
      }
      // 16. Zip Code / Postal Code
      else if (norm.contains('zip code') ||
          norm.contains('postal no') ||
          norm.contains('postal code') ||
          norm == 'zip') {
        zipCode = val;
      }
      // 17. Additional No (addit No)
      else if (norm.contains('addit no') ||
          norm.contains('additional no') ||
          norm.contains('additional number') ||
          norm.contains('addit number')) {
        additionalNo = val;
      }
      // 18. Unit No
      else if (norm.contains('unit no') ||
          norm.contains('unit number') ||
          norm == 'unit') {
        unitNo = val;
      }
      // 19. CR Number
      else if (norm == 'cr' ||
          norm.startsWith('cr ') ||
          norm.contains('cr no') ||
          norm.contains('cr number') ||
          norm.contains('commercial registration')) {
        crNumber = val;
      }
      // 20. Country
      else if (norm == 'country') {
        country = val;
      }
      // 21. Care Of
      else if (norm.contains('care of') || norm == 'c/o') {
        careOf = val;
      }
      // 22. General Address (e.g. "Address =", "Address 1 =")
      else if (norm == 'address' || norm == 'address 1') {
        generalAddress = val;
      } else if (norm == 'address 2') {
        if (generalAddress != null && generalAddress!.isNotEmpty) {
          generalAddress = '$generalAddress, $val';
        } else {
          generalAddress = val;
        }
      }
      // 23. Generic Name fallback (e.g. "Name =")
      else if (norm == 'name' || norm == 'customer name' || norm == 'company name') {
        organizationUnitName ??= val;
      }
    });

    // Fallbacks:
    // If zatcaUsername is missing but TIN was provided, use TIN as zatcaUsername
    if ((zatcaUsername == null || zatcaUsername!.isEmpty) && tin != null && tin!.isNotEmpty) {
      zatcaUsername = tin;
    }
    // If country is missing or blank, default to 'Saudi Arabia' if Saudi city or VAT provided
    if ((country == null || country!.isEmpty) &&
        (cityName != null || (vatNo != null && vatNo!.length == 15))) {
      country = 'Saudi Arabia';
    }

    return ParsedCustomerData(
      country: country,
      organizationUnitName: organizationUnitName,
      organizationName: organizationName,
      commonName: commonName,
      registeredAddress: registeredAddress,
      businessCategory: businessCategory,
      vatNo: vatNo,
      email: email,
      phone: phone,
      zatcaUsername: zatcaUsername,
      zatcaPassword: zatcaPassword,
      buildingNo: buildingNo,
      streetName: streetName,
      districtName: districtName,
      cityName: cityName,
      zipCode: zipCode,
      additionalNo: additionalNo,
      unitNo: unitNo,
      crNumber: crNumber,
      careOf: careOf,
      generalAddress: generalAddress,
      tin: tin,
      rawPairs: pairs,
    );
  }
}

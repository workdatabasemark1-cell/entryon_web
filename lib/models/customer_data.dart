/// Holds every field on the customer onboarding form.
/// Field names map 1:1 to the JSON keys the extraction service asks
/// the vision model to return, so parsing stays simple.
class CustomerData {
  String country;
  String organizationUnitName;
  String organizationName;
  String organizationUnitTin; // TIN - 10 digits
  String commonName; // auto-generated, but editable
  String registeredAddress; // assembled human-readable address
  String businessCategory;
  String vatNo;
  String email;
  String telephone;
  String zatcaUsername;
  String zatcaPassword;
  String buildingNo;
  String streetName;
  String districtName;
  String cityName;
  String zipCode;
  String additionalNo;
  String unitNo;
  String cr; // commercial registration number

  CustomerData({
    this.country = 'SAUDI ARABIA',
    this.organizationUnitName = '',
    this.organizationName = '',
    this.organizationUnitTin = '',
    this.commonName = '',
    this.registeredAddress = '',
    this.businessCategory = '',
    this.vatNo = '',
    this.email = '',
    this.telephone = '',
    this.zatcaUsername = '',
    this.zatcaPassword = '',
    this.buildingNo = '',
    this.streetName = '',
    this.districtName = '',
    this.cityName = '',
    this.zipCode = '',
    this.additionalNo = '',
    this.unitNo = '',
    this.cr = '',
  });

  /// Builds a CustomerData from the JSON the extraction service returns.
  /// Missing keys are simply left blank rather than throwing, since a
  /// document set won't always contain every field (e.g. no email on
  /// a CR certificate).
  factory CustomerData.fromJson(Map<String, dynamic> json) {
    String s(String key) => (json[key] ?? '').toString().trim();
    return CustomerData(
      country: s('country').isEmpty ? 'SAUDI ARABIA' : s('country'),
      organizationUnitName: s('organizationUnitName'),
      organizationName: s('organizationName'),
      organizationUnitTin: s('organizationUnitTin'),
      commonName: s('commonName'),
      registeredAddress: s('registeredAddress'),
      businessCategory: s('businessCategory'),
      vatNo: s('vatNo'),
      email: s('email'),
      telephone: s('telephone'),
      zatcaUsername: s('zatcaUsername'),
      zatcaPassword: s('zatcaPassword'),
      buildingNo: s('buildingNo'),
      streetName: s('streetName'),
      districtName: s('districtName'),
      cityName: s('cityName'),
      zipCode: s('zipCode'),
      additionalNo: s('additionalNo'),
      unitNo: s('unitNo'),
      cr: s('cr'),
    );
  }

  /// Recomputes the "Common Name" the same way ZATCA CSR configs usually
  /// build it: VAT number + organization name. Adjust this to match
  /// whatever exact convention your ZATCA onboarding flow requires -
  /// this is the one field in your list that isn't read off a document,
  /// it's derived, so I've left it as a clearly-editable auto value
  /// rather than guessing a format that might not match your process.
  String buildCommonName() {
    if (vatNo.isEmpty && organizationName.isEmpty) return '';
    return [vatNo, organizationName].where((s) => s.isNotEmpty).join('-');
  }

  /// Assembles a single-line address from the discrete address fields,
  /// used to fill "Registered Address" when the address proof is parsed.
  String buildRegisteredAddress() {
    final parts = [
      if (buildingNo.isNotEmpty) 'Bldg $buildingNo',
      streetName,
      if (unitNo.isNotEmpty) 'Unit $unitNo',
      districtName,
      cityName,
      if (zipCode.isNotEmpty) zipCode,
      if (additionalNo.isNotEmpty) additionalNo,
      country,
    ];
    return parts.where((s) => s.isNotEmpty).join(', ');
  }
}

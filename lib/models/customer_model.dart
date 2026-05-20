class Customer {
  // Basic information
  final String id;
  final String name;
  
  // Contact information
  final String phone;
  final String? phone2;
  final String? email;
  
  // Organization details
  final String? organizationName;
  final String? organizationUnitName;
  final String? commonName;
  final String? businessCategory;
  
  // Address information
  final String address;
  final String? registeredAddress;
  final String? buildingNo;
  final String? streetName;
  final String? districtName;
  final String? cityName;
  final String? zipCode;
  final String? additionalNo;
  final String? unitNo;
  final String? country;
  
  // Tax and registration information
  final String taxNumber; // VAT Number
  final String? crNumber; // Commercial Registration
  
  // Zatca credentials
  final String? zatcaUsername;
  final String? zatcaPassword;
  
  // Period section (optional)
  final String? periodSectionId;
  final String? periodSectionName;
  
  // Metadata
  final DateTime? createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.taxNumber,
    this.phone2,
    this.email,
    this.organizationName,
    this.organizationUnitName,
    this.commonName,
    this.businessCategory,
    this.registeredAddress,
    this.buildingNo,
    this.streetName,
    this.districtName,
    this.cityName,
    this.zipCode,
    this.additionalNo,
    this.unitNo,
    this.country,
    this.crNumber,
    this.zatcaUsername,
    this.zatcaPassword,
    this.periodSectionId,
    this.periodSectionName,
    this.createdAt,
  });

  // Convert Customer object to JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'phone2': phone2,
      'email': email,
      'organizationName': organizationName,
      'organizationUnitName': organizationUnitName,
      'commonName': commonName,
      'businessCategory': businessCategory,
      'address': address,
      'registeredAddress': registeredAddress,
      'buildingNo': buildingNo,
      'streetName': streetName,
      'districtName': districtName,
      'cityName': cityName,
      'zipCode': zipCode,
      'additionalNo': additionalNo,
      'unitNo': unitNo,
      'country': country,
      'taxNumber': taxNumber,
      'crNumber': crNumber,
      'zatcaUsername': zatcaUsername,
      'zatcaPassword': zatcaPassword,
      'periodSectionId': periodSectionId,
      'periodSectionName': periodSectionName,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  // Create Customer object from JSON
  factory Customer.fromMap(Map<String, dynamic> map, String documentId) {
    return Customer(
      id: documentId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      taxNumber: map['taxNumber'] ?? '',
      phone2: map['phone2'],
      email: map['email'],
      organizationName: map['organizationName'],
      organizationUnitName: map['organizationUnitName'],
      commonName: map['commonName'],
      businessCategory: map['businessCategory'],
      registeredAddress: map['registeredAddress'],
      buildingNo: map['buildingNo'],
      streetName: map['streetName'],
      districtName: map['districtName'],
      cityName: map['cityName'],
      zipCode: map['zipCode'],
      additionalNo: map['additionalNo'],
      unitNo: map['unitNo'],
      country: map['country'],
      crNumber: map['crNumber'],
      zatcaUsername: map['zatcaUsername'],
      zatcaPassword: map['zatcaPassword'],
      periodSectionId: map['periodSectionId'],
      periodSectionName: map['periodSectionName'],
      createdAt: _parseCreatedAt(map['createdAt']),
    );
  }

  // Safe helper method to parse Firestore timestamp
  static DateTime? _parseCreatedAt(dynamic timestamp) {
    if (timestamp == null) return null;
    try {
      if (timestamp is DateTime) {
        return timestamp;
      }
      // Handle Firestore Timestamp object
      if (timestamp.runtimeType.toString().contains('Timestamp')) {
        final dateTime = timestamp.toDate();
        return dateTime is DateTime ? dateTime : null;
      }
      // Handle string timestamps
      if (timestamp is String) {
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      // Silently fail and return null instead of throwing
      return null;
    }
  }

  // Copy with method for updating specific fields
  Customer copyWith({
    String? id,
    String? name,
    String? phone,
    String? phone2,
    String? email,
    String? organizationName,
    String? organizationUnitName,
    String? commonName,
    String? businessCategory,
    String? address,
    String? registeredAddress,
    String? buildingNo,
    String? streetName,
    String? districtName,
    String? cityName,
    String? zipCode,
    String? additionalNo,
    String? unitNo,
    String? country,
    String? taxNumber,
    String? crNumber,
    String? zatcaUsername,
    String? zatcaPassword,
    String? periodSectionId,
    String? periodSectionName,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      phone2: phone2 ?? this.phone2,
      email: email ?? this.email,
      organizationName: organizationName ?? this.organizationName,
      organizationUnitName: organizationUnitName ?? this.organizationUnitName,
      commonName: commonName ?? this.commonName,
      businessCategory: businessCategory ?? this.businessCategory,
      address: address ?? this.address,
      registeredAddress: registeredAddress ?? this.registeredAddress,
      buildingNo: buildingNo ?? this.buildingNo,
      streetName: streetName ?? this.streetName,
      districtName: districtName ?? this.districtName,
      cityName: cityName ?? this.cityName,
      zipCode: zipCode ?? this.zipCode,
      additionalNo: additionalNo ?? this.additionalNo,
      unitNo: unitNo ?? this.unitNo,
      country: country ?? this.country,
      taxNumber: taxNumber ?? this.taxNumber,
      crNumber: crNumber ?? this.crNumber,
      zatcaUsername: zatcaUsername ?? this.zatcaUsername,
      zatcaPassword: zatcaPassword ?? this.zatcaPassword,
      periodSectionId: periodSectionId ?? this.periodSectionId,
      periodSectionName: periodSectionName ?? this.periodSectionName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

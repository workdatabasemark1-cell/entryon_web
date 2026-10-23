class Staff {
  final String name;
  final String phone;

  Staff({
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
    );
  }

  Staff copyWith({
    String? name,
    String? phone,
  }) {
    return Staff(
      name: name ?? this.name,
      phone: phone ?? this.phone,
    );
  }
}

class Branch {
  final String name;
  final String phone;
  final String address;
  final String? careOf;
  final String? phone2;
  final String? email;
  final String? organizationName;
  final String? organizationUnitName;
  final String? commonName;
  final String? businessCategory;
  final String? registeredAddress;
  final String? buildingNo;
  final String? streetName;
  final String? districtName;
  final String? cityName;
  final String? zipCode;
  final String? additionalNo;
  final String? unitNo;
  final String? country;
  final String? taxNumber;
  final String? crNumber;
  final List<Staff> staff;
  final List<String> usedSoftwares;
  final List<Map<String, dynamic>> softwareActivations;
  final bool zatcaEnabled;
  final String? zatcaUsername;
  final String? zatcaPassword;
  final String? financialPeriodStartDate;
  final String? financialPeriodEndDate;
  final String? periodSectionId;
  final String? periodSectionName;

  Branch({
    required this.name,
    required this.phone,
    required this.address,
    this.careOf,
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
    this.taxNumber,
    this.crNumber,
    this.staff = const [],
    this.usedSoftwares = const [],
    this.softwareActivations = const [],
    this.zatcaEnabled = false,
    this.zatcaUsername,
    this.zatcaPassword,
    this.financialPeriodStartDate,
    this.financialPeriodEndDate,
    this.periodSectionId,
    this.periodSectionName,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'careOf': careOf,
      'phone2': phone2,
      'email': email,
      'organizationName': organizationName,
      'organizationUnitName': organizationUnitName,
      'commonName': commonName,
      'businessCategory': businessCategory,
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
      'staff': staff.map((s) => s.toMap()).toList(),
      'usedSoftwares': usedSoftwares,
      'softwareActivations': softwareActivations,
      'zatcaEnabled': zatcaEnabled,
      'zatcaUsername': zatcaUsername,
      'zatcaPassword': zatcaPassword,
      'financialPeriodStartDate': financialPeriodStartDate,
      'financialPeriodEndDate': financialPeriodEndDate,
      'periodSectionId': periodSectionId,
      'periodSectionName': periodSectionName,
    };
  }

  factory Branch.fromMap(Map<String, dynamic> map) {
    return Branch(
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      careOf: map['careOf'],
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
      taxNumber: map['taxNumber'],
      crNumber: map['crNumber'],
      staff: List<Staff>.from(
        (map['staff'] as List?)?.map((s) => Staff.fromMap(s as Map<String, dynamic>)) ?? [],
      ),
      usedSoftwares: List<String>.from(map['usedSoftwares'] ?? []),
      softwareActivations: List<Map<String, dynamic>>.from(map['softwareActivations'] ?? []),
      zatcaEnabled: map['zatcaEnabled'] as bool? ?? false,
      zatcaUsername: map['zatcaUsername'],
      zatcaPassword: map['zatcaPassword'],
      financialPeriodStartDate: map['financialPeriodStartDate'],
      financialPeriodEndDate: map['financialPeriodEndDate'],
      periodSectionId: map['periodSectionId'],
      periodSectionName: map['periodSectionName'],
    );
  }

  Branch copyWith({
    String? name,
    String? phone,
    String? address,
    String? careOf,
    String? phone2,
    String? email,
    String? organizationName,
    String? organizationUnitName,
    String? commonName,
    String? businessCategory,
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
    List<Staff>? staff,
    List<String>? usedSoftwares,
    List<Map<String, dynamic>>? softwareActivations,
    bool? zatcaEnabled,
    String? zatcaUsername,
    String? zatcaPassword,
    String? financialPeriodStartDate,
    String? financialPeriodEndDate,
    String? periodSectionId,
    String? periodSectionName,
  }) {
    return Branch(
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      careOf: careOf ?? this.careOf,
      phone2: phone2 ?? this.phone2,
      email: email ?? this.email,
      organizationName: organizationName ?? this.organizationName,
      organizationUnitName: organizationUnitName ?? this.organizationUnitName,
      commonName: commonName ?? this.commonName,
      businessCategory: businessCategory ?? this.businessCategory,
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
      staff: staff ?? this.staff,
      usedSoftwares: usedSoftwares ?? this.usedSoftwares,
      softwareActivations: softwareActivations ?? this.softwareActivations,
      zatcaEnabled: zatcaEnabled ?? this.zatcaEnabled,
      zatcaUsername: zatcaUsername ?? this.zatcaUsername,
      zatcaPassword: zatcaPassword ?? this.zatcaPassword,
      financialPeriodStartDate: financialPeriodStartDate ?? this.financialPeriodStartDate,
      financialPeriodEndDate: financialPeriodEndDate ?? this.financialPeriodEndDate,
      periodSectionId: periodSectionId ?? this.periodSectionId,
      periodSectionName: periodSectionName ?? this.periodSectionName,
    );
  }
}

class Customer {
  // Basic information
  final String id;
  final String name;
  final String? careOf;
  
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
  final bool? zatcaEnabled; // ZATCA integration enabled or not
  
  // Zatca credentials
  final String? zatcaUsername;
  final String? zatcaPassword;
  final bool cloudStorageEnabled;
  final String? cloudFinancialPeriodStartDate;
  final String? cloudFinancialPeriodEndDate;
  
// Period section (optional)
  final String? periodSectionId;
  final String? periodSectionName;


  // Financial Period
  final String? financialPeriodStartDate;
  final String? financialPeriodEndDate;

  // Audit fields
  final String? createdById;
  final String? createdByName;
  final String? editedById;
  final String? editedByName;
  final DateTime? editedDate;
  final DateTime? createdAt;

  // Software information
  final List<String> usedSoftwares;                    // Simple list of software names
  final List<Map<String, dynamic>> softwareActivations; // Detailed activation info

  // Staff and Branch information
  final List<Staff> staff;                             // Main customer staff
  final List<Branch> branches;                         // Customer branches and their staff

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.taxNumber,
    this.careOf,
    this.zatcaEnabled,
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
    this.cloudStorageEnabled = false,
    this.cloudFinancialPeriodStartDate,
    this.cloudFinancialPeriodEndDate,
    this.periodSectionId,
    this.periodSectionName,
    this.financialPeriodStartDate,
    this.financialPeriodEndDate,
    this.createdById,
    this.createdByName,
    this.editedById,
    this.editedByName,
    this.editedDate,
    this.createdAt,
    this.usedSoftwares = const [],
    this.softwareActivations = const [],
    this.staff = const [],
    this.branches = const [],
  });

  // Convert Customer object to JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'careOf': careOf,
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
      'zatcaEnabled': zatcaEnabled,
      'zatcaUsername': zatcaUsername,
      'zatcaPassword': zatcaPassword,
      'cloudStorageEnabled': cloudStorageEnabled,
      'cloudFinancialPeriodStartDate': cloudFinancialPeriodStartDate,
      'cloudFinancialPeriodEndDate': cloudFinancialPeriodEndDate,
      'periodSectionId': periodSectionId,
      'periodSectionName': periodSectionName,
      'financialPeriodStartDate': financialPeriodStartDate,
      'financialPeriodEndDate': financialPeriodEndDate,
      'createdById': createdById,
      'createdByName': createdByName,
      'editedById': editedById,
      'editedByName': editedByName,
      'editedDate': editedDate?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'usedSoftwares': usedSoftwares,
      'softwareActivations': softwareActivations,
      'staff': staff.map((s) => s.toMap()).toList(),
      'branches': branches.map((b) => b.toMap()).toList(),
    };
  }

  // Create Customer object from JSON
  factory Customer.fromMap(Map<String, dynamic> map, String documentId) {
    return Customer(
      id: documentId,
      name: map['name'] ?? '',
      careOf: map['careOf'],
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      taxNumber: map['taxNumber'] ?? '',
      zatcaEnabled: map['zatcaEnabled'] ?? false,
      
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
      cloudStorageEnabled: map['cloudStorageEnabled'] ?? false,
        cloudFinancialPeriodStartDate:
          map['cloudFinancialPeriodStartDate'] ?? map['cloudFinancialYear'],
        cloudFinancialPeriodEndDate: map['cloudFinancialPeriodEndDate'],
      periodSectionId: map['periodSectionId'],
      periodSectionName: map['periodSectionName'],
      financialPeriodStartDate: map['financialPeriodStartDate'],
      financialPeriodEndDate: map['financialPeriodEndDate'],
      
      createdById: map['createdById'],
      createdByName: map['createdByName'],
      editedById: map['editedById'],
      editedByName: map['editedByName'],
      editedDate: map['editedDate'] != null ? DateTime.parse(map['editedDate']) : null,
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt'].toString()) 
          : null,

      usedSoftwares: List<String>.from(map['usedSoftwares'] ?? []),
      softwareActivations: List<Map<String, dynamic>>.from(map['softwareActivations'] ?? []),
      staff: List<Staff>.from(
        (map['staff'] as List?)?.map((s) => Staff.fromMap(s as Map<String, dynamic>)) ?? [],
      ),
      branches: List<Branch>.from(
        (map['branches'] as List?)?.map((b) => Branch.fromMap(b as Map<String, dynamic>)) ?? [],
      ),
    );
  }

  // Copy with method
  Customer copyWith({
    String? id,
    String? name,
    String? careOf,
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
    bool? zatcaEnabled,
    String? zatcaUsername,
    String? zatcaPassword,
    bool? cloudStorageEnabled,
    String? cloudFinancialPeriodStartDate,
    String? cloudFinancialPeriodEndDate,
    
    String? periodSectionId,
    String? periodSectionName,
   
    String? financialPeriodStartDate,
    String? financialPeriodEndDate,
    String? createdById,
    String? createdByName,
    String? editedById,
    String? editedByName,
    DateTime? editedDate,
    DateTime? createdAt,
    List<String>? usedSoftwares,
    List<Map<String, dynamic>>? softwareActivations,
    List<Staff>? staff,
    List<Branch>? branches,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      careOf: careOf ?? this.careOf,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      taxNumber: taxNumber ?? this.taxNumber,
      zatcaEnabled: zatcaEnabled ?? this.zatcaEnabled,
      
      phone2: phone2 ?? this.phone2,
      email: email ?? this.email,
      organizationName: organizationName ?? this.organizationName,
      organizationUnitName: organizationUnitName ?? this.organizationUnitName,
      commonName: commonName ?? this.commonName,
      businessCategory: businessCategory ?? this.businessCategory,
      registeredAddress: registeredAddress ?? this.registeredAddress,
      buildingNo: buildingNo ?? this.buildingNo,
      streetName: streetName ?? this.streetName,
      districtName: districtName ?? this.districtName,
      cityName: cityName ?? this.cityName,
      zipCode: zipCode ?? this.zipCode,
      additionalNo: additionalNo ?? this.additionalNo,
      unitNo: unitNo ?? this.unitNo,
      country: country ?? this.country,
      crNumber: crNumber ?? this.crNumber,
      zatcaUsername: zatcaUsername ?? this.zatcaUsername,
      zatcaPassword: zatcaPassword ?? this.zatcaPassword,
      cloudStorageEnabled: cloudStorageEnabled ?? this.cloudStorageEnabled,
        cloudFinancialPeriodStartDate: cloudFinancialPeriodStartDate ??
          this.cloudFinancialPeriodStartDate,
        cloudFinancialPeriodEndDate: cloudFinancialPeriodEndDate ??
          this.cloudFinancialPeriodEndDate,
      periodSectionId: periodSectionId ?? this.periodSectionId,
      periodSectionName: periodSectionName ?? this.periodSectionName,
      
      financialPeriodStartDate: financialPeriodStartDate ?? this.financialPeriodStartDate,
      financialPeriodEndDate: financialPeriodEndDate ?? this.financialPeriodEndDate,
      
      createdById: createdById ?? this.createdById,
      createdByName: createdByName ?? this.createdByName,
      editedById: editedById ?? this.editedById,
      editedByName: editedByName ?? this.editedByName,
      editedDate: editedDate ?? this.editedDate,
      createdAt: createdAt ?? this.createdAt,
      
      usedSoftwares: usedSoftwares ?? this.usedSoftwares,
      softwareActivations: softwareActivations ?? this.softwareActivations,
      staff: staff ?? this.staff,
      branches: branches ?? this.branches,
    );
  }
}

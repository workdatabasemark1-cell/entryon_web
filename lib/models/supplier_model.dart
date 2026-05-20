class Supplier {
  final String? id;
 
  final String name;
  final String vatNumber;
  final String phone;
  final String? address;
  final String? email;
  final DateTime? createdAt;

  Supplier({
    this.id,
  
    required this.name,
    required this.vatNumber,
    required this.phone,
    this.address,
    this.email,
    this.createdAt,
  });

  // Convert Supplier object to JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
     
      'name': name,
      'vatNumber': vatNumber,
      'phone': phone,
      'address': address,
      'email': email,
      'createdAt': createdAt ?? DateTime.now(),
    };
  }

  // Create Supplier object from JSON
  factory Supplier.fromMap(Map<String, dynamic> map, String documentId) {
    return Supplier(
      id: documentId,
      
      name: map['name'] ?? '',
      vatNumber: map['vatNumber'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'],
      email: map['email'],
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
  Supplier copyWith({
    String? id,
   
    String? name,
    String? vatNumber,
    String? phone,
    String? address,
    String? email,
    DateTime? createdAt,
  }) {
    return Supplier(
      id: id ?? this.id,
     
      name: name ?? this.name,
      vatNumber: vatNumber ?? this.vatNumber,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

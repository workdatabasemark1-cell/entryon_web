import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String username;
  final String password;
  final String name;
  final String role; // admin / staff
  final DateTime? createdAt;

  AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.name,
    this.role = 'staff',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'name': name,
      'role': role,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return AppUser(
      id: documentId,
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      name: map['name'] ?? '',
      role: map['role'] ?? 'staff',
      createdAt: parseDate(map['createdAt']),
    );
  }
}
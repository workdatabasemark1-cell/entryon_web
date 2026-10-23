import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLogService {
  ActivityLogService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static String _userId = 'unknown';
  static String _userName = 'Unknown';

  static void setActor({required String userId, required String userName}) {
    _userId = userId;
    _userName = userName;
  }

  static void clearActor() {
    _userId = 'unknown';
    _userName = 'Unknown';
  }

  static Future<void> log({
    required String action,
    required String entity,
    String? entityId,
    Map<String, dynamic>? details,
    String? userId,
    String? userName,
  }) async {
    try {
      await _firestore.collection('activity_logs').add({
        'action': action,
        'entity': entity,
        'entityId': entityId,
        'details': details ?? <String, dynamic>{},
        'userId': userId ?? _userId,
        'userName': userName ?? _userName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Logging must not prevent the requested business operation.
    }
  }
}

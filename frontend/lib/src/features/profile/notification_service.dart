import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'notification_settings_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<NotificationSettingsModel> fetchSettings() async {
    final user = _auth.currentUser;
    if (user == null) return NotificationSettingsModel();

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('notificationSettings')) {
        return NotificationSettingsModel.fromMap(
          doc.data()!['notificationSettings'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      print('설정 불러오기 실패: $e');
    }
    return NotificationSettingsModel();
  }

  Future<void> updateSettings(NotificationSettingsModel settings) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'notificationSettings': settings.toMap(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('설정 저장 실패: $e');
    }
  }
}

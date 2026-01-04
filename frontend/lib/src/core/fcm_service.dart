import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("백그라운드 메시지 수신: ${message.messageId}");
  print("제목: ${message.notification?.title}");
  print("내용: ${message.notification?.body}");
  print("데이터: ${message.data}");
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _fcmToken;

  // FCM 초기화
  Future<void> initialize() async {
    try {
      print('🔔 FCM 초기화 시작...');
      
      // 알림 권한 요청 (iOS)
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('✅ 사용자가 알림 권한을 허용했습니다');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('⚠️ 사용자가 임시 알림 권한을 허용했습니다');
      } else {
        print('❌ 사용자가 알림 권한을 거부했습니다');
        return;
      }

      // FCM 토큰 가져오기
      _fcmToken = await _messaging.getToken();
      print('🔑 FCM 토큰: $_fcmToken');

      if (_fcmToken == null) {
        print('❌ FCM 토큰을 가져올 수 없습니다');
        return;
      }

      // 토큰을 Firestore에 저장
      await _saveTokenToFirestore(_fcmToken);
    } catch (e) {
      print('❌ FCM 초기화 에러: $e');
    }

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((newToken) {
      print('FCM 토큰 갱신: $newToken');
      _fcmToken = newToken;
      _saveTokenToFirestore(newToken);
    });

    // 포그라운드 메시지 핸들러
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('포그라운드 메시지 수신: ${message.messageId}');
      print('제목: ${message.notification?.title}');
      print('내용: ${message.notification?.body}');
      print('데이터: ${message.data}');
      
      // 여기서 로컬 알림을 표시할 수 있습니다
      // flutter_local_notifications 패키지를 사용하면 됩니다
    });

    // 백그라운드 메시지 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 알림 클릭 핸들러는 MyApp의 initState에서 처리합니다
  }

  // Firestore에 FCM 토큰 저장
  Future<void> _saveTokenToFirestore(String? token) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('❌ FCM 토큰 저장 실패: 사용자가 로그인하지 않았습니다');
      return;
    }
    if (token == null) {
      print('❌ FCM 토큰 저장 실패: 토큰이 null입니다');
      return;
    }

    try {
      print('💾 FCM 토큰 저장 시도: userId=${user.uid}, token=${token.substring(0, 20)}...');
      await _db.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ FCM 토큰을 Firestore에 저장했습니다');
    } catch (e) {
      print('❌ FCM 토큰 저장 에러: $e');
      print('❌ 에러 상세: ${e.toString()}');
    }
  }

  // FCM 토큰 가져오기
  String? get token => _fcmToken;

  // 특정 사용자에게 알림 전송 (서버 측에서 호출해야 함)
  // 클라이언트에서는 Firestore에 알림 데이터를 저장하고,
  // Cloud Functions에서 FCM으로 푸시 알림을 전송하는 것이 일반적입니다
  Future<void> sendNotificationToUser({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // 클라이언트에서는 Firestore에 알림 데이터만 저장
    // 실제 FCM 푸시는 Cloud Functions에서 처리해야 합니다
    try {
      await _db.collection('users').doc(targetUserId).collection('notifications').add({
        'type': data?['type'] ?? 'general',
        'message': body,
        'title': title,
        'topicId': data?['topicId'],
        'commentId': data?['commentId'],
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (e) {
      print('알림 저장 에러: $e');
    }
  }
}


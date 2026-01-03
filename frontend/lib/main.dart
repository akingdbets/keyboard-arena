import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // ★ 아까 만든 열쇠 파일
import 'src/app.dart';
import 'src/core/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ★ 파이어베이스 서버 연결 (자동 생성된 설정 사용)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Firestore 설정 (오프라인 지속성 활성화)
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  

  // FCM 초기화
  try {
    await FCMService().initialize();
  } catch (e) {
    print('❌ FCM 초기화 실패: $e');
    // FCM 초기화 실패해도 앱은 계속 실행
  }

  runApp(const MyApp());
}

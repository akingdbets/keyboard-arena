import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 추가
import 'features/feed/feed_screen.dart';
import 'features/auth/login_screen.dart'; // 추가
import 'features/auth/auth_service.dart'; // 추가
import 'core/theme_controller.dart'; // 테마 컨트롤러

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // 테마 변경 리스너 추가
    themeNotifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    // 테마 변경 시 setState만 호출하여 MaterialApp의 themeMode만 업데이트
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keyboard Arena',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: themeNotifier.value, // themeNotifier의 값을 사용
      
      // ★ 여기가 핵심 문지기!
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges, // 로그인 상태 감시
        builder: (context, snapshot) {
          // 1. 아직 로딩 중이면?
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // 2. 로그인 정보가 있으면? -> 피드 화면(Main)
          if (snapshot.hasData) {
            return const FeedScreen();
          }
          
          // 3. 없으면? -> 로그인 화면
          return const LoginScreen();
        },
      ),
    );
  }
}
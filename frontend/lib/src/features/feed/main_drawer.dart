import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme_controller.dart'; // 테마 컨트롤러
import '../profile/profile_screen.dart';   // 내 활동 화면
import '../profile/notification_setting_screen.dart'; // 알림 설정 화면
import '../../features/auth/auth_service.dart'; // ★ 로그아웃 기능 가져오기

class MainDrawer extends StatelessWidget {
  const MainDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final db = FirebaseFirestore.instance;

    return Drawer(
      child: Column(
        children: [
          // 1. 상단 프로필 영역 
          StreamBuilder<DocumentSnapshot>(
            stream: user != null 
                ? db.collection('users').doc(user.uid).snapshots()
                : null,
            builder: (context, snapshot) {
              String displayName = '익명 유저';
              String displayEmail = '로그인해주세요';

              if (user != null) {
                displayEmail = user.email ?? '이메일 없음';
                // 문서가 존재하거나 아직 로딩 중일 때 처리
                if (snapshot.connectionState == ConnectionState.waiting) {
                  displayName = '로딩 중...';
                } else if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  displayName = data?['nickname'] ?? '익명 유저';
                } else if (snapshot.hasError) {
                  displayName = '익명 유저';
                } else {
                  // 문서가 아직 생성되지 않았을 때 (회원 탈퇴 후 재가입 시)
                  displayName = user.displayName ?? '익명 유저';
                }
              }

              return UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Color(0xFFE91E63), size: 40),
                ),
                accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                accountEmail: Text(displayEmail),
                onDetailsPressed: () {
                  if (user != null) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ProfileScreen()),
                    );
                  }
                },
              );
            },
          ),

          // 2. 다크모드 / 라이트모드 전환 (ValueListenableBuilder로 감싸서 테마 변경 시에만 업데이트)
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentThemeMode, child) {
              final isDarkMode = currentThemeMode == ThemeMode.dark;
              return ListTile(
                leading: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                title: const Text('다크 모드'),
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    toggleTheme(); // 테마 전환 함수 호출
                  },
                  activeColor: const Color(0xFFE91E63),
                ),
              );
            },
          ),
          const Divider(),

          // 3. 내 활동 
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('내 활동'),
            onTap: () {
              Navigator.pop(context); // 메뉴 닫기
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
            },
          ),

          // 4. 앱 설정 
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('앱 설정'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingScreen()));
            },
          ),

          const Spacer(), // 남은 공간 밀어내기
          const Divider(),

          // 5. 퇴장하기 (로그아웃) [cite: 78, 85]
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('퇴장하기', style: TextStyle(color: Colors.red)),
            onTap: () async {
              // (1) 서랍 닫기 (선택사항, 깔끔하게 보이기 위해)
              Navigator.pop(context);

              // (2) ★ 진짜 로그아웃 실행!
              await AuthService().signOut();
              
              // (3) 화면 이동은 필요 없음
              // 이유: app.dart의 문지기(StreamBuilder)가 "어? 로그아웃 됐네?" 하고 
              // 알아서 로그인 화면으로 바꿔버립니다.
            },
          ),
        ],
      ),
    );
  }

}
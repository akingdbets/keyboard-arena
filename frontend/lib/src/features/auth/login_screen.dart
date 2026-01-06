import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_service.dart';
import '../feed/feed_screen.dart';
import 'nickname_screen.dart'; // ★ 추가됨

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  // 공통 로그인 처리 로직
  void _processLogin(Future<dynamic> loginFunction) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await loginFunction;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // ★ [핵심 수정] 프로필 존재 여부 확인
      final exists = await AuthService().hasProfile(user.uid);

      if (mounted) {
        if (exists) {
          // 기존 유저 -> 메인 화면
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(builder: (context) => const FeedScreen()),
          );
        } else {
          // 신규 유저 -> 닉네임 설정 화면
          Navigator.of(context, rootNavigator: true).pushReplacement(
            MaterialPageRoute(builder: (context) => NicknameScreen(user: user)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icon/icon.png', width: 120, height: 120),
            const SizedBox(height: 20),
            const Text(
              "KEY WAR",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "입으로만 싸우지 말고, 손가락으로 증명하라",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 60),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            if (_isLoading)
              const CircularProgressIndicator(color: Colors.white)
            else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  height: 54,
                  child: SignInWithAppleButton(
                    onPressed: () =>
                        _processLogin(AuthService().signInWithApple()),
                    style: SignInWithAppleButtonStyle.white,
                    text: 'Apple로 계속하기',
                    borderRadius: const BorderRadius.all(Radius.circular(30)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _processLogin(AuthService().signInWithGoogle()),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                        height: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Google로 시작하기",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

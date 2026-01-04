import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // PlatformException 사용
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import '../feed/feed_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  void _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null; // 에러 메시지 초기화
    });

    try {
      // 로그인 시도
      final user = await AuthService().signInWithGoogle();

      if (user == null) {
        // 사용자가 로그인을 취소한 경우
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // 로그인 성공 시 강제로 FeedScreen으로 이동
      // StreamBuilder가 반응하지 않는 문제 해결 (회원 탈퇴 후 재로그인 시)
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (context) => const FeedScreen()),
        );
      }
    } catch (e) {
      // 에러 발생 시 사용자에게 알림
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _getErrorMessage(e);
        });

        // 에러 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? '로그인에 실패했습니다.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // PlatformException 처리
    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = error.message ?? '';

      if (code.contains('sign_in') ||
          code.contains('10') ||
          (message.isNotEmpty && message.contains('10'))) {
        return 'SHA-1 인증서 지문이 등록되지 않았습니다.\n\n해결 방법:\n1. 터미널에서 다음 명령어 실행:\n   cd android && ./gradlew signingReport\n2. SHA-1 지문을 복사\n3. Firebase Console → 프로젝트 설정 → 일반 → Android 앱에 SHA-1 추가\n4. google-services.json 다시 다운로드';
      } else if (code.contains('network') || message.contains('network')) {
        return '인터넷 연결을 확인해주세요.';
      } else {
        return 'Google 로그인 오류 (${error.code}):\n${error.message ?? "알 수 없는 오류"}';
      }
    }

    if (errorString.contains('network') || errorString.contains('internet')) {
      return '인터넷 연결을 확인해주세요.';
    } else if (errorString.contains('sign_in_canceled') ||
        errorString.contains('canceled')) {
      return '로그인이 취소되었습니다.';
    } else if (errorString.contains('platform_exception')) {
      return 'Google 로그인 설정이 필요합니다.\nSHA-1 인증서 지문을 Firebase에 등록해주세요.';
    } else if (errorString.contains('oauth')) {
      return 'OAuth 설정이 필요합니다.\nFirebase Console에서 Google Sign-In을 활성화해주세요.';
    } else {
      return '로그인에 실패했습니다:\n${error.toString()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // 배경색 (원하는 대로 수정 가능)
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/icon.png', // 아까 저장한 이미지 경로
              width: 120, // 크기 조절
              height: 120,
            ),
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
            const SizedBox(height: 80),

            // 에러 메시지 표시
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 구글 로그인 버튼
            _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: _handleGoogleLogin,
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
            
            const SizedBox(height: 40),
            
            // 이용약관 및 개인정보처리방침 동의 문구
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                  children: [
                    const TextSpan(text: '로그인 시 '),
                    TextSpan(
                      text: '이용약관',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openTermsOfService(),
                    ),
                    const TextSpan(text: ' 및 '),
                    TextSpan(
                      text: '개인정보처리방침',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => _openPrivacyPolicy(),
                    ),
                    const TextSpan(text: '에 동의하는 것으로 간주합니다.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 이용약관 링크 열기
  Future<void> _openTermsOfService() async {
    // TODO: 실제 노션 페이지 링크로 교체 필요
    final uri = Uri.parse('https://www.google.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // 개인정보처리방침 링크 열기
  Future<void> _openPrivacyPolicy() async {
    // TODO: 실제 노션 페이지 링크로 교체 필요
    final uri = Uri.parse('https://www.google.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

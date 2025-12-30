import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // PlatformException 사용
import 'auth_service.dart';

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
      
      // 로그인이 성공하면 자동으로 화면이 넘어가므로, 여기선 에러 처리만
      if (user == null && mounted) {
        setState(() => _isLoading = false);
      }
      // 성공 시 로딩 상태 끌 필요 없음 (화면이 바뀌니까)
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
      
      if (code.contains('sign_in') || code.contains('10') || (message.isNotEmpty && message.contains('10'))) {
        return 'SHA-1 인증서 지문이 등록되지 않았습니다.\n\n해결 방법:\n1. 터미널에서 다음 명령어 실행:\n   cd android && ./gradlew signingReport\n2. SHA-1 지문을 복사\n3. Firebase Console → 프로젝트 설정 → 일반 → Android 앱에 SHA-1 추가\n4. google-services.json 다시 다운로드';
      } else if (code.contains('network') || message.contains('network')) {
        return '인터넷 연결을 확인해주세요.';
      } else {
        return 'Google 로그인 오류 (${error.code}):\n${error.message ?? "알 수 없는 오류"}';
      }
    }
    
    if (errorString.contains('network') || errorString.contains('internet')) {
      return '인터넷 연결을 확인해주세요.';
    } else if (errorString.contains('sign_in_canceled') || errorString.contains('canceled')) {
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
            const Icon(Icons.sports_esports, size: 100, color: Colors.white),
            const SizedBox(height: 20),
            const Text(
              "KEYBOARD ARENA",
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
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
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
          ],
        ),
      ),
    );
  }
}
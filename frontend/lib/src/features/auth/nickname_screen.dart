import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import '../feed/feed_screen.dart';

class NicknameScreen extends StatefulWidget {
  final User user;
  const NicknameScreen({super.key, required this.user});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  // 닉네임 제출 함수
  void _submit() async {
    // 키보드 내리기
    FocusScope.of(context).unfocus();

    final text = _controller.text.trim(); // 앞뒤 공백 제거

    // 유효성 검사
    if (text.isEmpty || text.length < 2) {
      setState(() => _errorText = "닉네임은 2글자 이상 입력해주세요.");
      return;
    }

    if (text.length > 10) {
      setState(() => _errorText = "닉네임은 10글자 이하로 설정해주세요.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      // AuthService를 통해 프로필 생성
      await AuthService().createProfile(widget.user, text);

      if (mounted) {
        // 성공 시 메인 화면(FeedScreen)으로 이동 (뒤로가기 불가하게 replacement)
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (context) => const FeedScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 에러 메시지에서 'Exception: ' 문구 제거하고 표시
          _errorText = e.toString().replaceAll("Exception: ", "");
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope: 뒤로가기 버튼 막기 (닉네임 설정은 필수)
    return PopScope(
      canPop: false,
      child: GestureDetector(
        // 화면 빈 곳 터치 시 키보드 내리기
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 80, color: Colors.white),
                const SizedBox(height: 20),
                const Text(
                  "닉네임을 정해주세요",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "전장에서 사용할 멋진 이름을 입력하세요.",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // 닉네임 입력 필드
                TextField(
                  controller: _controller,
                  style: const TextStyle(color: Colors.white),
                  maxLength: 10, // 최대 글자 수 제한
                  decoration: InputDecoration(
                    hintText: "닉네임 입력 (2~10자)",
                    hintStyle: const TextStyle(color: Colors.white38),
                    errorText: _errorText,
                    filled: true,
                    fillColor: Colors.white10,
                    counterText: "", // 하단 글자 수 카운터 숨김
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.white,
                        width: 1,
                      ),
                    ),
                  ),
                  // 엔터 키 누르면 바로 제출
                  onSubmitted: (_) => _submit(),
                ),

                const SizedBox(height: 20),

                // 입장 버튼
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.black,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "전장으로 입장",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

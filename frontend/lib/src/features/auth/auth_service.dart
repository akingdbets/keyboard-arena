import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // PlatformException 사용
import 'dart:math'; // 랜덤 숫자 뽑기용

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // GoogleSignIn 설정 개선 (scopes와 serverClientId 명시)
final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: ['email'],
);

  // 로그인 상태 감지 (로그인 했나? 안 했나?)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 현재 로그인한 유저 정보 가져오기
  User? get currentUser => _auth.currentUser;

  // ★ 구글 로그인 기능 (핵심)
  Future<User?> signInWithGoogle() async {
    try {
      // 1. 구글 로그인 창 띄우기
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("사용자가 로그인을 취소했습니다.");
        return null; // 사용자가 취소함
      }

      // 2. 인증표(토큰) 받아오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. 파이어베이스용 입장권 만들기
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. 파이어베이스에 입장!
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. 처음 온 손님이면 '익명' 닉네임 지어주기
        await _checkAndCreateUserProfile(user);
        print("✅ 로그인 성공: ${user.email}");
      }

      return user;
    } catch (e) {
      print("❌ 로그인 에러: $e");
      print("에러 타입: ${e.runtimeType}");
      
      // PlatformException의 경우 상세 정보 출력
      if (e is PlatformException) {
        print("PlatformException 코드: ${e.code}");
        print("PlatformException 메시지: ${e.message}");
        print("PlatformException 상세: ${e.details}");
      }
      
      rethrow; // 에러를 상위로 전달하여 UI에서 처리할 수 있게 함
    }
  }

  // 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ★ [익명 보장] 프로필 생성 로직
  Future<void> _checkAndCreateUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();

    // 데이터베이스에 내 정보가 없으면? (신규 가입)
    if (!doc.exists) {
      // 1000 ~ 9999 사이 랜덤 숫자
      String randomNickname = "익명${Random().nextInt(9000) + 1000}"; 

      await docRef.set({
        'uid': user.uid,
        'email': user.email, // 관리자만 볼 수 있게 저장
        'nickname': randomNickname, // ★ 익명 닉네임
        'photoUrl': null, // null이면 기본 프사 사용
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': true, // 프로필 공개 여부
      });
      print("✅ 신규 유저 생성 완료: $randomNickname");
    }
  }
}
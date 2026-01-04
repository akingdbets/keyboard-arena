import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // 1. 구글 로그인 (토큰 강제 갱신 추가)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase 로그인
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 프로필 생성 확인 (재시도 로직 포함)
        await _checkAndCreateUserProfile(user);
        
        // ★ 핵심: 탈퇴 후 재가입 시 연결 끊김 방지를 위한 '토큰 강제 갱신'
        try {
          print("🔄 인증 토큰 강제 갱신 중...");
          await user.reload();
          await user.getIdToken(true); // forceRefresh: true
          print("✅ 인증 토큰 갱신 완료");
        } catch (e) {
          print("⚠️ 토큰 갱신 중 경미한 오류: $e");
        }
      }

      return user;
    } catch (e) {
      print("❌ 로그인 에러: $e");
      rethrow;
    }
  }

  // 2. 로그아웃
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // 3. 회원 탈퇴 (완벽한 정리)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;

    try {
      // (1) 작성한 주제(게시글) 삭제
      final topicsSnapshot = await _db
          .collection('topics')
          .where('authorId', isEqualTo: userId)
          .get();

      for (var topicDoc in topicsSnapshot.docs) {
        // 주제 문서 삭제 (서브컬렉션 comments도 자동 삭제됨)
        await topicDoc.reference.delete();
        print("✅ 주제 삭제: ${topicDoc.id}");
      }
      print("🗑️ 작성한 주제 삭제 완료: ${topicsSnapshot.docs.length}개");

      // (2) 작성한 댓글 삭제 (모든 주제의 comments 서브컬렉션에서)
      final allTopicsSnapshot = await _db.collection('topics').get();
      int deletedCommentsCount = 0;

      for (var topicDoc in allTopicsSnapshot.docs) {
        // 각 주제의 comments 서브컬렉션에서 해당 유저의 댓글 찾기
        final commentsSnapshot = await _db
            .collection('topics')
            .doc(topicDoc.id)
            .collection('comments')
            .where('uid', isEqualTo: userId)
            .get();

        // 댓글 문서 삭제
        for (var commentDoc in commentsSnapshot.docs) {
          await commentDoc.reference.delete();
          deletedCommentsCount++;
        }

        // 대댓글(replies 배열)에서도 제거
        final allCommentsSnapshot = await _db
            .collection('topics')
            .doc(topicDoc.id)
            .collection('comments')
            .get();

        for (var commentDoc in allCommentsSnapshot.docs) {
          final commentData = commentDoc.data();
          final replies = commentData['replies'] as List<dynamic>? ?? [];
          bool hasUpdated = false;
          final updatedReplies = replies.where((reply) {
            final replyData = reply as Map<String, dynamic>;
            if (replyData['uid'] == userId) {
              hasUpdated = true;
              return false; // 해당 유저의 답글 제거
            }
            return true;
          }).toList();

          if (hasUpdated) {
            await commentDoc.reference.update({
              'replies': updatedReplies,
            });
          }
        }
      }
      print("🗑️ 작성한 댓글 삭제 완료: $deletedCommentsCount개");

      // (3) 투표 정보 삭제
      final votesSnapshot = await _db
          .collection('users')
          .doc(userId)
          .collection('votes')
          .get();

      for (var voteDoc in votesSnapshot.docs) {
        await voteDoc.reference.delete();
      }
      print("🗑️ 투표 정보 삭제 완료: ${votesSnapshot.docs.length}개");

      // (4) Firestore 유저 데이터 삭제
      await _db.collection('users').doc(userId).delete();
      print("🗑️ 유저 데이터 삭제 완료");

      // (5) Firebase Auth 계정 삭제
      await user.delete();
      print("🗑️ 계정 삭제 완료");

      // (6) ★ 중요: 로컬 인증 정보 찌꺼기 제거
      await _googleSignIn.signOut();
      await _auth.signOut();
      print("✨ 로컬 세션 초기화 완료");
    } catch (e) {
      print("❌ 회원 탈퇴 실패: $e");
      // 재로그인 필요 에러(requires-recent-login)일 경우 상위로 전파
      rethrow;
    }
  }

  // 4. 프로필 생성 및 확인 (Retry 로직)
  Future<void> _checkAndCreateUserProfile(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    
    // 이미 존재하는지 1차 확인
    DocumentSnapshot doc = await docRef.get();

    // 없으면 생성 (신규 가입)
    if (!doc.exists) {
      // 중복되지 않는 닉네임 생성 (익명 + 4~5자리 랜덤 숫자)
      String newNickname = "";
      bool isUnique = false;
      int attempts = 0;
      const maxAttempts = 50; // 최대 시도 횟수 (무한 루프 방지)
      
      while (!isUnique && attempts < maxAttempts) {
        // 5자리 랜덤 숫자 생성 (10000 ~ 99999)
        int randomNum = Random().nextInt(90000) + 10000;
        newNickname = "익명$randomNum";
        
        // Firestore에서 중복 확인
        final query = await _db
            .collection('users')
            .where('nickname', isEqualTo: newNickname)
            .limit(1)
            .get();
        
        if (query.docs.isEmpty) {
          isUnique = true;
        } else {
          attempts++;
          print("⚠️ 닉네임 중복: $newNickname, 재시도 중... ($attempts/$maxAttempts)");
        }
      }
      
      if (!isUnique) {
        // 최대 시도 횟수 초과 시 예외 발생
        throw Exception('고유한 닉네임을 생성할 수 없습니다. 잠시 후 다시 시도해주세요.');
      }
      
      print("📝 신규 유저 프로필 생성 시작: $newNickname");

      await docRef.set({
        'uid': user.uid,
        'email': user.email,
        'nickname': newNickname,
        'photoUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': true,
      });
    }

    // ★ 생성 확인 대기 (최대 3초)
    int retries = 0;
    while (retries < 30) {
      doc = await docRef.get();
      if (doc.exists) {
        print("✅ 유저 프로필 확인 완료 (재시도 $retries회)");
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      retries++;
    }
    print("⚠️ 프로필 생성이 지연되고 있습니다.");
  }
}

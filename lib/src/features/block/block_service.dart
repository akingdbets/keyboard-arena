import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 사용자 차단하기
  Future<bool> blockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (user.uid == blockedUserId) {
      throw Exception('자기 자신을 차단할 수 없습니다.');
    }

    try {
      // blockedUsers 배열에 추가
      await _db.collection('users').doc(user.uid).update({
        'blockedUsers': FieldValue.arrayUnion([blockedUserId]),
      });

      return true;
    } catch (e) {
      print('❌ 사용자 차단 에러: $e');
      throw Exception('사용자 차단 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 사용자 차단 해제하기
  Future<bool> unblockUser(String blockedUserId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    try {
      // blockedUsers 배열에서 제거
      await _db.collection('users').doc(user.uid).update({
        'blockedUsers': FieldValue.arrayRemove([blockedUserId]),
      });

      return true;
    } catch (e) {
      print('❌ 사용자 차단 해제 에러: $e');
      throw Exception('사용자 차단 해제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 차단한 사용자 목록 가져오기
  Future<List<String>> getBlockedUsers() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final data = userDoc.data();
      final blockedUsers = data?['blockedUsers'] as List<dynamic>? ?? [];
      return blockedUsers.map((e) => e.toString()).toList();
    } catch (e) {
      print('❌ 차단 목록 가져오기 에러: $e');
      return [];
    }
  }

  /// 사용자가 차단되었는지 확인
  Future<bool> isUserBlocked(String userId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final blockedUsers = await getBlockedUsers();
      return blockedUsers.contains(userId);
    } catch (e) {
      print('❌ 차단 여부 확인 에러: $e');
      return false;
    }
  }

  /// 차단한 사용자 목록 스트림 (실시간 업데이트)
  Stream<List<String>> getBlockedUsersStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _db.collection('users').doc(user.uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return [];
      final data = snapshot.data();
      final blockedUsers = data?['blockedUsers'] as List<dynamic>? ?? [];
      return blockedUsers.map((e) => e.toString()).toList();
    });
  }
}


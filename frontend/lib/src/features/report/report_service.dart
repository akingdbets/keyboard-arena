import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 신고하기
  /// 
  /// [targetId] 신고 대상의 ID (Topic ID 또는 Comment ID)
  /// [targetType] 'topic' 또는 'comment'
  /// [reason] 신고 사유
  /// 
  /// 반환값: 성공 여부
  Future<bool> report({
    required String targetId,
    required String targetType,
    required String reason,
  }) async {
    // 로그인 확인
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    // targetType 검증
    if (targetType != 'topic' && targetType != 'comment') {
      throw Exception('유효하지 않은 신고 대상 타입입니다.');
    }

    // 중복 신고 체크
    final existingReport = await _db
        .collection('reports')
        .where('reporterId', isEqualTo: user.uid)
        .where('targetId', isEqualTo: targetId)
        .where('targetType', isEqualTo: targetType)
        .limit(1)
        .get();

    if (existingReport.docs.isNotEmpty) {
      throw Exception('이미 신고한 항목입니다.');
    }

    // 신고 저장
    try {
      await _db.collection('reports').add({
        'reporterId': user.uid,
        'targetId': targetId,
        'targetType': targetType,
        'reason': reason,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      return true;
    } catch (e) {
      print('❌ 신고 저장 에러: $e');
      throw Exception('신고 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  /// 중복 신고 여부 확인
  Future<bool> hasReported({
    required String targetId,
    required String targetType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final existingReport = await _db
        .collection('reports')
        .where('reporterId', isEqualTo: user.uid)
        .where('targetId', isEqualTo: targetId)
        .where('targetType', isEqualTo: targetType)
        .limit(1)
        .get();

    return existingReport.docs.isNotEmpty;
  }
}


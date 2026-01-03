import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 알림 설정 상태 변수들
  bool _isProfilePublic = true;
  bool _notifyTopicComments = true;   // 내가 생성한 주제에 댓글
  bool _notifyCommentReplies = true;  // 내가 단 댓글에 답글
  bool _notifyCommentLikes = false;   // 내가 단 댓글에 공감
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Firestore에서 설정 불러오기
  Future<void> _loadSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _isProfilePublic = data?['isPublic'] as bool? ?? true;
          _notifyTopicComments = data?['notifyTopicComments'] as bool? ?? true;
          _notifyCommentReplies = data?['notifyCommentReplies'] as bool? ?? true;
          _notifyCommentLikes = data?['notifyCommentLikes'] as bool? ?? false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print("설정 불러오기 에러: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Firestore에 설정 저장
  Future<void> _saveSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _db.collection('users').doc(user.uid).set({
        'isPublic': _isProfilePublic,
        'notifyTopicComments': _notifyTopicComments,
        'notifyCommentReplies': _notifyCommentReplies,
        'notifyCommentLikes': _notifyCommentLikes,
      }, SetOptions(merge: true));
    } catch (e) {
      print("설정 저장 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 저장에 실패했습니다: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? Colors.grey[400] : Colors.grey[700];

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('앱 설정'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 설정'),
      ),
      body: ListView(
        children: [
          // ---------------------------------------------------------
          // 1. 공개 범위 설정 섹션
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('공개 범위 설정', style: TextStyle(fontWeight: FontWeight.bold, color: sectionTitleColor)),
          ),
          SwitchListTile(
            title: const Text('프로필 공개'),
            subtitle: Text(
              _isProfilePublic 
                  ? '모든 사람이 내 활동 내역을 볼 수 있습니다.' 
                  : '나만 내 활동 내역을 볼 수 있습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: _isProfilePublic,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                _isProfilePublic = value;
              });
              _saveSettings();
            },
            secondary: Icon(
              _isProfilePublic ? Icons.lock_open : Icons.lock,
              color: _isProfilePublic ? Colors.green : Colors.grey,
            ),
          ),
          
          const Divider(height: 40), // 구분선

          // ---------------------------------------------------------
          // 2. 알림 설정 섹션 (3가지 상세 설정)
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('알림 설정', style: TextStyle(fontWeight: FontWeight.bold, color: sectionTitleColor)),
          ),
          
          // (1) 내가 생성한 주제에 댓글
          SwitchListTile(
            title: const Text('내가 생성한 주제에 댓글'),
            subtitle: const Text('누군가 내 주제에 의견을 남기면 알려줍니다.', style: TextStyle(fontSize: 12)),
            value: _notifyTopicComments,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                _notifyTopicComments = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.campaign_outlined),
          ),

          // (2) 내가 단 댓글에 답글
          SwitchListTile(
            title: const Text('내가 단 댓글에 답글'),
            subtitle: const Text('내 의견에 반박이나 대댓글이 달리면 알려줍니다.', style: TextStyle(fontSize: 12)),
            value: _notifyCommentReplies,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                _notifyCommentReplies = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.chat_bubble_outline),
          ),

          // (3) 내가 단 댓글에 공감
          SwitchListTile(
            title: const Text('내가 단 댓글에 공감'),
            subtitle: const Text('누군가 내 의견에 좋아요를 누르면 알려줍니다.', style: TextStyle(fontSize: 12)),
            value: _notifyCommentLikes,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                _notifyCommentLikes = value;
              });
              _saveSettings();
            },
            secondary: const Icon(Icons.favorite_border),
          ),
        ],
      ),
    );
  }
}
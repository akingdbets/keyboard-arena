import 'package:flutter/material.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  // ★ 다른 화면(투표, 프로필)에서 참고할 전역 변수들
  // (실제 앱에서는 서버나 로컬 저장소에 저장해야 함)
  static bool isMyProfilePublic = true; 

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  // 알림 설정 상태 변수들 (화면 안에서만 쓰임)
  bool _notifyTopicComments = true;   // 내가 생성한 주제에 댓글
  bool _notifyCommentReplies = true;  // 내가 단 댓글에 답글
  bool _notifyCommentLikes = false;   // 내가 단 댓글에 공감

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionTitleColor = isDark ? Colors.grey[400] : Colors.grey[700];

    return Scaffold(
      appBar: AppBar(
        title: const Text('앱 설정'), // ★ 타이틀 변경
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
              NotificationSettingScreen.isMyProfilePublic 
                  ? '모든 사람이 내 활동 내역을 볼 수 있습니다.' 
                  : '나만 내 활동 내역을 볼 수 있습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            value: NotificationSettingScreen.isMyProfilePublic,
            activeColor: const Color(0xFFE91E63),
            onChanged: (value) {
              setState(() {
                NotificationSettingScreen.isMyProfilePublic = value;
              });
            },
            secondary: Icon(
              NotificationSettingScreen.isMyProfilePublic ? Icons.lock_open : Icons.lock,
              color: NotificationSettingScreen.isMyProfilePublic ? Colors.green : Colors.grey,
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
            },
            secondary: const Icon(Icons.favorite_border),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../block/block_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

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
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // 문서가 생성될 때까지 최대 3초 대기 (회원 탈퇴 후 재가입 시 대비)
      // 100ms 간격으로 최대 30회 재시도
      var userDoc = await _db.collection('users').doc(user.uid).get();
      int retries = 0;
      const maxRetries = 30;
      const retryInterval = Duration(milliseconds: 100);
      
      while (!userDoc.exists && retries < maxRetries) {
        await Future.delayed(retryInterval);
        userDoc = await _db.collection('users').doc(user.uid).get();
        retries++;
        
        // 문서가 생성되었으면 즉시 처리
        if (userDoc.exists) {
          break;
        }
      }

      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _isProfilePublic = data?['isPublic'] as bool? ?? true;
          _notifyTopicComments = data?['notifyTopicComments'] as bool? ?? true;
          _notifyCommentReplies = data?['notifyCommentReplies'] as bool? ?? true;
          _notifyCommentLikes = data?['notifyCommentLikes'] as bool? ?? false;
          _isLoading = false;
        });
        print("✅ 설정 불러오기 완료 (재시도 ${retries}회)");
      } else {
        // 문서가 없어도 기본값으로 설정하고 로딩 종료
        // 회원 탈퇴 후 재가입 시 프로필이 아직 생성되지 않았을 수 있음
        setState(() {
          _isLoading = false;
        });
        print("⚠️ 사용자 문서 없음, 기본값으로 설정 (재시도 ${retries}회)");
      }
    } catch (e) {
      print("❌ 설정 불러오기 에러: $e");
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

          const Divider(height: 40), // 구분선

          // ---------------------------------------------------------
          // 3. 차단 관리 섹션
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('차단 관리', style: TextStyle(fontWeight: FontWeight.bold, color: sectionTitleColor)),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('차단한 사용자 관리'),
            subtitle: const Text('차단한 사용자 목록을 확인하고 해제할 수 있습니다.', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
              );
            },
          ),

          const Divider(height: 40), // 구분선

          // ---------------------------------------------------------
          // 4. 회원 탈퇴 섹션
          // ---------------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('계정 관리', style: TextStyle(fontWeight: FontWeight.bold, color: sectionTitleColor)),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('회원 탈퇴', style: TextStyle(color: Colors.red)),
            subtitle: const Text('모든 활동 내역이 삭제되며 복구할 수 없습니다.', style: TextStyle(fontSize: 12, color: Colors.red)),
            onTap: () async {
              // 경고 팝업
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('회원 탈퇴'),
                  content: const Text(
                    '정말 탈퇴하시겠습니까?\n모든 활동 내역이 삭제되며 복구할 수 없습니다.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('탈퇴'),
                    ),
                  ],
                ),
              );

              if (confirmed != true) return;

              try {
                // 회원 탈퇴 실행 (AuthService의 deleteAccount 메서드 사용)
                await AuthService().deleteAccount();

                // 성공 시 로그인 화면으로 이동
                if (mounted) {
                  // 모든 화면을 닫고 루트로 이동 (app.dart의 StreamBuilder가 LoginScreen을 보여줌)
                  Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('회원 탈퇴가 완료되었습니다.')),
                  );
                }
              } on FirebaseAuthException catch (e) {
                // FirebaseAuthException 처리 (특히 requires-recent-login 케이스)
                print('❌ 회원 탈퇴 에러 (FirebaseAuthException): ${e.code} - ${e.message}');
                if (mounted) {
                  String errorMessage;
                  if (e.code == 'requires-recent-login') {
                    errorMessage = '안전을 위해 다시 로그인 후 탈퇴해주세요';
                  } else {
                    errorMessage = e.message ?? '회원 탈퇴 중 오류가 발생했습니다.';
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMessage),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              } catch (e) {
                // 일반 Exception 처리
                print('❌ 회원 탈퇴 에러: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceFirst('Exception: ', '')),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

// 차단한 사용자 관리 화면
class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final BlockService _blockService = BlockService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('차단한 사용자'),
      ),
      body: StreamBuilder<List<String>>(
        stream: _blockService.getBlockedUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '차단한 사용자가 없습니다',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final blockedUserIds = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUserIds.length,
            itemBuilder: (context, index) {
              final userId = blockedUserIds[index];
              return StreamBuilder<DocumentSnapshot>(
                stream: _db.collection('users').doc(userId).snapshots(),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                  final userName = userData?['nickname'] ?? '익명 유저';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 2))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.grey[600]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _unblockUser(userId),
                          child: const Text('차단 해제', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unblockUser(String userId) async {
    // 차단 해제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('차단 해제'),
        content: const Text('이 사용자의 차단을 해제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('해제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _blockService.unblockUser(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('차단이 해제되었습니다.')),
        );
      }
    } catch (e) {
      print('❌ 차단 해제 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
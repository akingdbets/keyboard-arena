import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ★ 로그인 정보 가져오기용
import '../profile/profile_screen.dart';
import '../profile/notification_setting_screen.dart';

class VoteScreen extends StatefulWidget {
  final String topicId; // 주제 ID (필수)
  final String? highlightComment; // 베스트 댓글 하이라이트용 (선택)
  
  const VoteScreen({
    super.key,
    required this.topicId,
    this.highlightComment,
  });

  @override
  State<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends State<VoteScreen> with AutomaticKeepAliveClientMixin {
  // ★ 파이어베이스 DB 인스턴스
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  int? _selectedOptionIndex;
  String _commentSort = '최신순'; // 댓글 정렬: 최신순, 인기순
  
  // 대댓글 관련 상태
  String? _replyingToDocId; // 대댓글 달 부모 댓글의 ID

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController(); // 스크롤 위치 저장용

  // 동적 옵션 데이터 (Firebase에서 가져옴)
  List<String> _optionNames = [];
  List<Color> _optionColors = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];

  // 스크롤 위치 저장
  double _savedScrollPosition = 0.0;
  
  // 스크롤 위치 자동 저장용 리스너
  bool _isNavigating = false;

  // Stream 변수 (리빌드 시에도 유지)
  Stream<DocumentSnapshot>? _topicStream;
  Stream<QuerySnapshot>? _commentsStream;

  @override
  bool get wantKeepAlive => true; // 상태 유지

  @override
  void initState() {
    super.initState();
    
    // Stream 초기화 (리빌드 시에도 유지되도록)
    _topicStream = _db.collection('topics').doc(widget.topicId).snapshots();
    _commentsStream = _db.collection('topics').doc(widget.topicId).collection('comments').snapshots();
    
    _loadUserVote(); // 사용자의 이전 투표 정보 불러오기
    
    // 스크롤 위치 자동 저장
    _scrollController.addListener(_onScroll);
    
    // 포커스 노드 리스너 추가 (키보드가 올라올 때 스크롤 위치 유지)
    _commentFocusNode.addListener(_onFocusChange);
  }
  
  void _onScroll() {
    // 네비게이션 중이 아닐 때만 저장
    if (!_isNavigating && _scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
    }
  }
  
  void _onFocusChange() {
    // 포커스가 변경될 때 스크롤 위치 유지
    if (_commentFocusNode.hasFocus) {
      // 포커스가 생겼을 때 (키보드가 올라올 때)
      _saveScrollPosition();
      final savedPos = _savedScrollPosition;
      
      // 키보드가 올라온 후 스크롤 위치 복원 (더 강력하게)
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted && _scrollController.hasClients && savedPos > 0) {
          _scrollController.jumpTo(savedPos);
        }
      });
      
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && _scrollController.hasClients && savedPos > 0) {
          _scrollController.jumpTo(savedPos);
        }
      });
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _scrollController.hasClients && savedPos > 0) {
          _scrollController.jumpTo(savedPos);
        }
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _scrollController.hasClients && savedPos > 0) {
          _scrollController.jumpTo(savedPos);
        }
      });
    }
  }
  
  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _commentFocusNode.removeListener(_onFocusChange);
    _commentController.dispose();
    _commentFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // 스크롤 위치 저장
  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.offset;
    }
  }
  
  // 스크롤 위치 복원 (애니메이션 없이 즉시 복원)
  void _restoreScrollPosition() {
    _restoreScrollToPosition(_savedScrollPosition);
  }
  
  // 스크롤 위치 복원 (특정 위치로)
  void _restoreScrollToPosition(double position) {
    if (position <= 0) return;
    
    // 즉시 복원
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(position);
    }
    
    // 프레임 후에도 계속 복원 시도 (10번)
    for (int i = 0; i < 10; i++) {
      Future.delayed(Duration(milliseconds: i * 16), () {
        if (mounted && _scrollController.hasClients && _scrollController.offset != position) {
          _scrollController.jumpTo(position);
        }
      });
    }
  }

  // 사용자의 이전 투표 정보 불러오기
  Future<void> _loadUserVote() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final voteDoc = await _db
          .collection('users')
          .doc(user.uid)
          .collection('votes')
          .doc(widget.topicId)
          .get();

      if (voteDoc.exists) {
        final data = voteDoc.data();
        final optionIndex = data?['optionIndex'] as int?;
        if (optionIndex != null && mounted) {
          setState(() {
            _selectedOptionIndex = optionIndex;
          });
        }
      }
    } catch (e) {
      print("투표 정보 불러오기 에러: $e");
    }
  }

  // [기능 1] 투표하기
  Future<void> _castVote(int index) async {
    if (_selectedOptionIndex == index) return;

    // 스크롤 위치 저장 (setState 전에)
    _saveScrollPosition();

    // 로그인 확인
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
      }
      return;
    }

    // 사용자의 이전 투표 정보 확인 (Firestore에서 가져오기)
    int? previousIndex = _selectedOptionIndex;
    
    // Firestore에서 실제 이전 투표 확인
    try {
      final userVoteDoc = await _db
          .collection('users')
          .doc(user.uid)
          .collection('votes')
          .doc(widget.topicId)
          .get();
      
      if (userVoteDoc.exists) {
        final voteData = userVoteDoc.data();
        previousIndex = voteData?['optionIndex'] as int?;
      }
    } catch (e) {
      print("이전 투표 정보 확인 에러: $e");
    }

    // 1. 내 앱에서 먼저 숫자를 바꿈 (반응속도 빠르게)
    // 스크롤 위치 저장 (setState 전에)
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;
    
    setState(() {
      _selectedOptionIndex = index;
    });
    
    // setState 직후 여러 번 복원 시도
    _restoreScrollToPosition(savedPos);

    // 2. 서버에 저장 (트랜잭션)
    final docRef = _db.collection('topics').doc(widget.topicId);
    
    try {
      print("📊 투표 시작: topicId=${widget.topicId}, optionIndex=$index, previousIndex=$previousIndex");
      
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          print("❌ 주제 문서가 존재하지 않음: ${widget.topicId}");
          throw Exception('주제를 찾을 수 없습니다.');
        }

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          print("❌ 주제 데이터가 null");
          throw Exception('주제 데이터를 읽을 수 없습니다.');
        }

        List<dynamic> counts = List.from(data['voteCounts'] ?? []);
        // totalVotes를 counts에서 직접 계산 (더 정확함)
        int totalVotes = counts.fold<int>(0, (sum, count) => sum + (count as int? ?? 0));
        
        print("📊 현재 투표 상태: counts=$counts, totalVotes=$totalVotes, counts.length=${counts.length}, previousIndex=$previousIndex");
        
        // 이전 선택 취소 (이미 투표한 경우에만)
        if (previousIndex != null && previousIndex >= 0 && previousIndex < counts.length) {
          final prevCount = counts[previousIndex] as int? ?? 0;
          if (prevCount > 0) {
            counts[previousIndex] = prevCount - 1;
            totalVotes--;
            print("📊 이전 투표 취소: previousIndex=$previousIndex, 이전 count=$prevCount");
          }
        }
        
        // 새 선택 추가
        if (index < counts.length) {
          final currentCount = counts[index] as int? ?? 0;
          counts[index] = currentCount + 1;
          totalVotes++;
          print("📊 새 투표 추가: index=$index, 이전 count=$currentCount, 새로운 count=${counts[index]}, 새로운 totalVotes=$totalVotes");
        } else {
          print("❌ 유효하지 않은 선택지: index=$index, counts.length=${counts.length}");
          throw Exception('유효하지 않은 선택지입니다.');
        }
        
        transaction.update(docRef, {
          'voteCounts': counts,
          'totalVotes': totalVotes,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        print("✅ 트랜잭션 업데이트 완료");
      });

      // 3. 사용자별 투표 정보 저장
      final userVoteRef = _db
          .collection('users')
          .doc(user.uid)
          .collection('votes')
          .doc(widget.topicId);
      
      await userVoteRef.set({
        'topicId': widget.topicId,
        'optionIndex': index,
        'votedAt': FieldValue.serverTimestamp(),
      }); // set()은 이미 덮어쓰기이므로 merge 불필요

      print("✅ 투표 저장 완료: users/${user.uid}/votes/${widget.topicId}, 옵션: $index");
      
      // 스크롤 위치 즉시 복원 (필요시)
      _restoreScrollPosition();
    } catch (e) {
      print("❌ 투표 에러: $e");
      
      // 에러 발생 시 이전 상태로 복원
      if (mounted) {
        setState(() {
          _selectedOptionIndex = previousIndex;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('투표에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // 에러 발생 시에도 스크롤 위치 즉시 복원
      _restoreScrollPosition();
    }
  }

  // [기능 2] 댓글 쓰기 (로그인 유저 정보 연동)
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) return;

    // 1. 현재 로그인한 사용자 정보 가져오기
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("로그인이 필요합니다.")));
      return;
    }

    // 2. 내 닉네임 가져오기 (DB에서 조회)
    final userDoc = await _db.collection('users').doc(user.uid).get();
    String myNickname = '알 수 없음';
    if (userDoc.exists) {
      myNickname = userDoc.data()?['nickname'] ?? '익명 유저';
    }

    // 뱃지(선택한 투표 옵션) 설정
    String badgeText = '관전';
    int badgeColorValue = Colors.grey.value; 

    if (_selectedOptionIndex != null && _selectedOptionIndex! < _optionNames.length) {
      badgeText = _optionNames[_selectedOptionIndex!].split(' ')[0]; 
      badgeColorValue = _optionColors[_selectedOptionIndex! % _optionColors.length].value;
    }

    // 3. 전송할 데이터 만들기
    final newComment = {
      'uid': user.uid, // 작성자 고유 ID
      'author': myNickname, // ★ DB에서 가져온 익명 닉네임
      'isPublic': NotificationSettingScreen.isMyProfilePublic,
      'content': _commentController.text,
      'badge': badgeText,
      'badgeColor': badgeColorValue,
      'time': Timestamp.now(),
      'likes': 0,
      'likedBy': [],
      'replies': [],
    };

    // 스크롤 위치 저장
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;
    
    if (_replyingToDocId != null) {
      // 대댓글: 해당 댓글 문서의 'replies' 배열에 추가
      final commentRef = _db.collection('topics').doc(widget.topicId).collection('comments').doc(_replyingToDocId);
      await commentRef.update({
        'replies': FieldValue.arrayUnion([newComment])
      });
      setState(() => _replyingToDocId = null);
    } else {
      // 일반 댓글: comments 컬렉션에 새 문서 추가
      await _db.collection('topics').doc(widget.topicId).collection('comments').add(newComment);
    }

    _commentController.clear();
    FocusScope.of(context).unfocus();
    
    // 스크롤 위치 즉시 복원 (여러 번 시도)
    _restoreScrollToPosition(savedPos);
  }

  // 답글 모드 시작
  void _startReply(String docId, String authorName) {
    // 스크롤 위치 저장 (setState 전에) - 투표와 동일한 방식
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;
    
    setState(() {
      _replyingToDocId = docId;
    });
    
    // setState 직후 여러 번 복원 시도 - 투표와 동일한 방식
    _restoreScrollToPosition(savedPos);
    
    // 키보드가 올라올 때 스크롤 위치 유지를 위한 추가 처리
    // 포커스는 약간의 딜레이 후
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        // 스크롤 위치 다시 확인 및 복원
        if (_scrollController.hasClients && savedPos > 0) {
          _scrollController.jumpTo(savedPos);
        }
        FocusScope.of(context).requestFocus(_commentFocusNode);
      }
    });
    
    // 키보드가 완전히 올라온 후에도 스크롤 위치 복원 (더 강력하게)
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _scrollController.hasClients && savedPos > 0) {
        _scrollController.jumpTo(savedPos);
      }
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _scrollController.hasClients && savedPos > 0) {
        _scrollController.jumpTo(savedPos);
      }
    });
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _scrollController.hasClients && savedPos > 0) {
        _scrollController.jumpTo(savedPos);
      }
    });
    
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted && _scrollController.hasClients && savedPos > 0) {
        _scrollController.jumpTo(savedPos);
      }
    });
  }

  void _cancelReply() {
    // 스크롤 위치 저장 (setState 전에) - 투표와 동일한 방식
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;
    
    setState(() {
      _replyingToDocId = null;
    });
    FocusScope.of(context).unfocus();
    
    // setState 직후 여러 번 복원 시도 - 투표와 동일한 방식
    _restoreScrollToPosition(savedPos);
  }

  // 댓글 삭제 기능
  Future<void> _deleteComment(String commentId, String? topicId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (topicId == null) return;

    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('댓글 삭제'),
        content: const Text('이 댓글을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 스크롤 위치 저장
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;

    try {
      await _db.collection('topics').doc(topicId).collection('comments').doc(commentId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('댓글이 삭제되었습니다.')),
        );
      }
      
      _restoreScrollToPosition(savedPos);
    } catch (e) {
      print("댓글 삭제 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('댓글 삭제에 실패했습니다: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      _restoreScrollToPosition(savedPos);
    }
  }

  // 대댓글 삭제 기능
  Future<void> _deleteReply(String commentId, String? topicId, int replyIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (topicId == null || commentId == null) return;

    // 삭제 확인 다이얼로그
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('답글 삭제'),
        content: const Text('이 답글을 정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 스크롤 위치 저장
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;

    try {
      final commentRef = _db.collection('topics').doc(topicId).collection('comments').doc(commentId);
      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return;

      final replies = List<Map<String, dynamic>>.from(commentDoc.data()?['replies'] ?? []);
      if (replyIndex >= replies.length) return;

      replies.removeAt(replyIndex);
      await commentRef.update({'replies': replies});
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답글이 삭제되었습니다.')),
        );
      }
      
      _restoreScrollToPosition(savedPos);
    } catch (e) {
      print("답글 삭제 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('답글 삭제에 실패했습니다: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
      _restoreScrollToPosition(savedPos);
    }
  }

  // 공감 기능
  Future<void> _toggleLike(Map<String, dynamic> item, String? commentId, String? topicId, int? replyIndex) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    if (topicId == null) return;

    // 스크롤 위치 저장
    _saveScrollPosition();
    final savedPos = _savedScrollPosition;

    try {
      if (replyIndex != null) {
        // 대댓글인 경우
        final commentRef = _db.collection('topics').doc(topicId).collection('comments').doc(commentId);
        final commentDoc = await commentRef.get();
        if (!commentDoc.exists) return;

        final replies = List<Map<String, dynamic>>.from(commentDoc.data()?['replies'] ?? []);
        if (replyIndex >= replies.length) return;

        final reply = replies[replyIndex];
        final likedBy = List<String>.from(reply['likedBy'] ?? []);
        final currentLikes = reply['likes'] as int? ?? 0;

        if (likedBy.contains(user.uid)) {
          // 공감 취소
          likedBy.remove(user.uid);
          replies[replyIndex] = {
            ...reply,
            'likedBy': likedBy,
            'likes': currentLikes - 1,
          };
        } else {
          // 공감 추가
          likedBy.add(user.uid);
          replies[replyIndex] = {
            ...reply,
            'likedBy': likedBy,
            'likes': currentLikes + 1,
          };
        }

        await commentRef.update({'replies': replies});
      } else {
        // 일반 댓글인 경우
        if (commentId == null || topicId == null) return;
        final commentRef = _db.collection('topics').doc(topicId).collection('comments').doc(commentId);
        final commentDoc = await commentRef.get();
        if (!commentDoc.exists) return;

        final likedBy = List<String>.from(commentDoc.data()?['likedBy'] ?? []);
        final currentLikes = commentDoc.data()?['likes'] as int? ?? 0;

        if (likedBy.contains(user.uid)) {
          // 공감 취소
          likedBy.remove(user.uid);
          await commentRef.update({
            'likedBy': likedBy,
            'likes': currentLikes - 1,
          });
        } else {
          // 공감 추가
          likedBy.add(user.uid);
          await commentRef.update({
            'likedBy': likedBy,
            'likes': currentLikes + 1,
          });
        }
      }
      
      // 스크롤 위치 즉시 복원 - 투표와 동일한 방식
      _restoreScrollToPosition(savedPos);
    } catch (e) {
      print("공감 에러: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('공감 처리에 실패했습니다: ${e.toString()}')),
        );
      }
      // 에러 발생 시에도 스크롤 위치 복원 - 투표와 동일한 방식
      _restoreScrollToPosition(savedPos);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardBgColor = isDark ? const Color(0xFF2D2D3A) : Colors.white;
    final inputFillColor = isDark ? const Color(0xFF1E1E2C) : Colors.grey[100];
    final borderColor = isDark ? Colors.white12 : Colors.grey[300]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('주제 상세'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      resizeToAvoidBottomInset: true, // 답글 입력창이 키보드 위로 올라오도록
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              key: const PageStorageKey('vote_screen_scroll'), // 스크롤 위치 유지 (프로필 화면에서 돌아와도 유지)
              controller: _scrollController, // 스크롤 컨트롤러 연결
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. [실시간] 투표 결과 카드
                  StreamBuilder<DocumentSnapshot>(
                    stream: _topicStream, // initState에서 초기화된 스트림 사용
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('주제를 불러올 수 없습니다: ${snapshot.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('돌아가기'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (!snapshot.hasData || !snapshot.data!.exists) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('주제를 찾을 수 없습니다'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('돌아가기'),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data == null) {
                        return const Center(child: Text('주제 데이터가 없습니다.'));
                      }

                      // 옵션 데이터 가져오기
                      final List<String> options = List<String>.from(data['options'] ?? []);
                      final List<String?> optionImages = (data['optionImages'] as List<dynamic>?)
                          ?.map((e) => e as String?)
                          .toList() ?? List.filled(options.length, null);
                      final List<dynamic> counts = List.from(data['voteCounts'] ?? []);
                      // totalVotes를 counts에서 직접 계산 (더 정확함)
                      final int totalVotes = counts.fold<int>(0, (a, b) => a + (b as int? ?? 0));

                      // 옵션 데이터는 StreamBuilder에서 직접 사용하므로 상태 업데이트 불필요

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))],
                        ),
                        child: Column(
                          children: [
                            Text(data['title'] ?? '제목 없음', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
                            const SizedBox(height: 24),
                            // 옵션 리스트
                            Column(
                              children: List.generate(options.length, (index) {
                                final count = index < counts.length ? (counts[index] as int) : 0;
                                final percent = totalVotes == 0 ? "0%" : "${((count / totalVotes) * 100).toStringAsFixed(1)}%";
                                final color = _optionColors[index % _optionColors.length];
                                final imageUrl = index < optionImages.length ? optionImages[index] : null;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildVoteOption(
                                    index, 
                                    options[index], 
                                    percent, 
                                    '($count표)', 
                                    color, 
                                    isDark, 
                                    _selectedOptionIndex != null,
                                    imageUrl: imageUrl,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('총 $totalVotes표 참여', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // 2. [실시간] 댓글 헤더 & 리스트
                  StreamBuilder<QuerySnapshot>(
                    stream: _commentsStream, // initState에서 초기화된 스트림 사용
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Text("댓글 로딩 중...");
                      
                      final docs = snapshot.data!.docs;
                      
                      // 클라이언트에서 정렬
                      final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                      if (_commentSort == '인기순') {
                        sortedDocs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aLikes = aData['likes'] as int? ?? 0;
                          final bLikes = bData['likes'] as int? ?? 0;
                          if (aLikes != bLikes) {
                            return bLikes.compareTo(aLikes); // 공감 많은 순
                          }
                          // 공감이 같으면 최신순
                          final aTime = aData['time'] as Timestamp?;
                          final bTime = bData['time'] as Timestamp?;
                          if (aTime == null && bTime == null) return 0;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });
                      } else {
                        // 최신순
                        sortedDocs.sort((a, b) {
                          final aData = a.data() as Map<String, dynamic>;
                          final bData = b.data() as Map<String, dynamic>;
                          final aTime = aData['time'] as Timestamp?;
                          final bTime = bData['time'] as Timestamp?;
                          if (aTime == null && bTime == null) return 0;
                          if (aTime == null) return 1;
                          if (bTime == null) return -1;
                          return bTime.compareTo(aTime);
                        });
                      }

                      // 댓글 개수 계산 (답글 포함)
                      int totalCommentCount = sortedDocs.length;
                      for (var doc in sortedDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final replies = data['replies'] as List<dynamic>? ?? [];
                        totalCommentCount += replies.length;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.orange), 
                                  const SizedBox(width: 4),
                                  Text('댓글 $totalCommentCount개', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                              // 정렬 버튼
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // 스크롤 위치 저장 (setState 전에)
                                      _saveScrollPosition();
                                      final savedPos = _savedScrollPosition;
                                      
                                      setState(() {
                                        _commentSort = _commentSort == '최신순' ? '인기순' : '최신순';
                                      });
                                      
                                      // setState 직후 여러 번 복원 시도
                                      _restoreScrollToPosition(savedPos);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _commentSort == '최신순' ? Icons.access_time : Icons.favorite,
                                            size: 16,
                                            color: textColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _commentSort,
                                            style: TextStyle(fontSize: 12, color: textColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 1000, // 충분한 캐시 영역 설정
                            itemCount: sortedDocs.length,
                            itemBuilder: (context, index) {
                              final doc = sortedDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final List<dynamic> replies = data['replies'] ?? [];
                              
                              // Color 복원
                              Color badgeColor = Color(data['badgeColor'] ?? Colors.grey.value);

                              return Column(
                                children: [
                                  _buildCommentItem(
                                    item: data,
                                    textColor: textColor,
                                    badgeColorOverride: badgeColor,
                                    isDark: isDark,
                                    commentId: doc.id,
                                    topicId: widget.topicId,
                                    onReplyTap: () => _startReply(doc.id, data['author']),
                                    onDelete: () => _deleteComment(doc.id, widget.topicId),
                                  ),
                                  // 대댓글
                                  if (replies.isNotEmpty)
                                    ...replies.map<Widget>((reply) {
                                      final replyData = reply as Map<String, dynamic>;
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 32.0),
                                        child: _buildCommentItem(
                                          item: replyData,
                                          textColor: textColor,
                                          badgeColorOverride: Color(replyData['badgeColor'] ?? Colors.grey.value),
                                          isDark: isDark,
                                          isReply: true,
                                          commentId: doc.id,
                                          topicId: widget.topicId,
                                          replyIndex: replies.indexOf(reply),
                                          onDelete: () => _deleteReply(doc.id, widget.topicId, replies.indexOf(reply)),
                                        ),
                                      );
                                    }).toList(),
                                ],
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 답글 배너
          if (_replyingToDocId != null)
             Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    "답글 작성 중...", 
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 18, color: Colors.grey),
                  ),
                ],
              ),
            ),

          // 입력창 (키보드가 올라와도 스크롤 위치 유지)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: cardBgColor, border: Border(top: BorderSide(color: borderColor))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: _replyingToDocId != null ? '답글을 입력하세요...' : '의견을 남기세요...',
                      filled: true,
                      fillColor: inputFillColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                    onTap: () {
                      // 텍스트 필드 탭 시 스크롤 위치 저장
                      _saveScrollPosition();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _addComment,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(color: Color(0xFFE91E63), shape: BoxShape.circle),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI 위젯들 ---

  Widget _buildVoteOption(int index, String label, String percent, String count, Color color, bool isDark, bool hasVoted, {String? imageUrl}) {
    final isSelected = _selectedOptionIndex == index;
    return GestureDetector(
      onTap: () => _castVote(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : (hasVoted ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!)), width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? color : Colors.grey[400], size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasVoted) ...[
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(percent, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isSelected ? color : (isDark ? Colors.white : Colors.black87))),
                      Text(count, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ],
            ),
            // 이미지 표시
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 16 / 9, // 정확히 16:9 비율 유지 (미리보기와 동일)
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover, // 16:9 비율로 크롭했으므로 cover 사용
                    cacheWidth: 800, // 캐시 최적화
                    cacheHeight: 450, // 16:9 비율에 맞춘 높이 (800 * 9 / 16 = 450)
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 300),
                        child: child,
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem({
    required Map<String, dynamic> item,
    required Color textColor,
    Color? badgeColorOverride,
    required bool isDark,
    bool isReply = false,
    String? commentId,
    String? topicId,
    int? replyIndex,
    VoidCallback? onReplyTap,
    VoidCallback? onDelete,
  }) {
    return _CommentItemWidget(
      key: ValueKey('${commentId}_${replyIndex ?? 'main'}'), // 고유 키
      item: item,
      textColor: textColor,
      badgeColorOverride: badgeColorOverride,
      isDark: isDark,
      isReply: isReply,
      commentId: commentId,
      topicId: topicId,
      replyIndex: replyIndex,
      onReplyTap: onReplyTap,
      onDelete: onDelete,
      scrollController: _scrollController,
      onToggleLike: (item, commentId, topicId, replyIndex) => _toggleLike(item, commentId, topicId, replyIndex),
    );
  }
}

// 댓글 아이템 위젯 (AutomaticKeepAliveClientMixin 적용)
class _CommentItemWidget extends StatefulWidget {
  final Map<String, dynamic> item;
  final Color textColor;
  final Color? badgeColorOverride;
  final bool isDark;
  final bool isReply;
  final String? commentId;
  final String? topicId;
  final int? replyIndex;
  final VoidCallback? onReplyTap;
  final VoidCallback? onDelete;
  final ScrollController scrollController;
  final Function(Map<String, dynamic>, String?, String?, int?) onToggleLike;

  const _CommentItemWidget({
    super.key,
    required this.item,
    required this.textColor,
    this.badgeColorOverride,
    required this.isDark,
    this.isReply = false,
    this.commentId,
    this.topicId,
    this.replyIndex,
    this.onReplyTap,
    this.onDelete,
    required this.scrollController,
    required this.onToggleLike,
  });

  @override
  State<_CommentItemWidget> createState() => _CommentItemWidgetState();
}

class _CommentItemWidgetState extends State<_CommentItemWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // 상태 유지

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 필수
    
    String timeStr = '방금 전';
    if (widget.item['time'] is Timestamp) {
      DateTime d = (widget.item['time'] as Timestamp).toDate();
      timeStr = "${d.month}/${d.day} ${d.hour}:${d.minute}";
    }

    void _goToUserProfile() async {
      // 스크롤 위치 저장 (즉시)
      final savedPos = widget.scrollController.hasClients ? widget.scrollController.offset : 0.0;
      
      // 프로필 페이지로 이동
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(
            userId: widget.item['uid'],
            userName: widget.item['author'],
            isPublic: widget.item['isPublic'] ?? true,
          ),
        ),
      );
      
      // 프로필 페이지에서 돌아온 후 스크롤 위치 즉시 복원
      if (mounted && savedPos > 0) {
        // 즉시 복원
        if (widget.scrollController.hasClients) {
          widget.scrollController.jumpTo(savedPos);
        }
        
        // 프레임 후에도 복원
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.scrollController.hasClients) {
            widget.scrollController.jumpTo(savedPos);
          }
        });
        
        // 여러 번 더 시도
        for (int i = 1; i <= 20; i++) {
          Future.delayed(Duration(milliseconds: i * 25), () {
            if (mounted && widget.scrollController.hasClients) {
              widget.scrollController.jumpTo(savedPos);
            }
          });
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _goToUserProfile,
            child: CircleAvatar(backgroundColor: Colors.grey[800], radius: widget.isReply ? 12 : 18, child: Text(widget.item['author'][0], style: TextStyle(color: Colors.white, fontSize: widget.isReply ? 10 : 14))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(onTap: _goToUserProfile, child: Text(widget.item['author'], style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFFBB86FC), fontSize: widget.isReply ? 13 : 14))),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(border: Border.all(color: widget.badgeColorOverride ?? Colors.grey), borderRadius: BorderRadius.circular(4)),
                      child: Text(widget.item['badge'], style: TextStyle(color: widget.badgeColorOverride ?? Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const Spacer(),
                    Text(timeStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(widget.item['content'], style: TextStyle(fontSize: 14, height: 1.4, color: widget.textColor)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!widget.isReply)
                      GestureDetector(
                        onTap: widget.onReplyTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          child: Text('답글', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    if (!widget.isReply) const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        if (widget.topicId != null) {
                          widget.onToggleLike(widget.item, widget.commentId, widget.topicId, widget.replyIndex);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              widget.item['likedBy']?.contains(FirebaseAuth.instance.currentUser?.uid) == true
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color: widget.item['likedBy']?.contains(FirebaseAuth.instance.currentUser?.uid) == true
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${widget.item['likes'] ?? 0}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 자신이 작성한 댓글에만 삭제 버튼 표시
                    if (widget.item['uid'] == FirebaseAuth.instance.currentUser?.uid && widget.onDelete != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: widget.onDelete,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text('삭제', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
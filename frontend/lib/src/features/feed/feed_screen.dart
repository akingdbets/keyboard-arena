import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_drawer.dart';
import '../vote/vote_screen.dart';
import '../profile/notification_history_screen.dart';
import 'create_topic_screen.dart';
import '../report/report_service.dart';
import '../report/report_dialog.dart';
import '../block/block_service.dart';
import '../auth/auth_service.dart';
import '../auth/login_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with AutomaticKeepAliveClientMixin {
  String _selectedCategory = '전체';
  String _selectedSort = '최신순';
  String _selectedPeriod = '전체'; // 조회기간: 전체, 1일, 1주, 1달, 직접설정
  DateTime? _customStartDate; // 직접 설정한 시작 날짜
  DateTime? _customEndDate; // 직접 설정한 종료 날짜

  // Firebase 인스턴스
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 신고된 주제 추적 (로컬 상태)
  final Set<String> _reportedTopics = {};
  final ReportService _reportService = ReportService();
  final BlockService _blockService = BlockService();

  // 스크롤 컨트롤러 및 상태
  late final ScrollController _scrollController;
  
  // Stream 캐싱을 위한 변수 (build 메서드에서 재생성 방지)
  Stream<QuerySnapshot>? _topicsStream;

  // 뒤로가기 버튼 두 번 눌러야 종료
  DateTime? _lastPressedAt;

  // 카테고리 리스트
  final List<String> _categories = [
    '전체',
    '음식',
    '게임',
    '연애',
    '스포츠',
    '유머',
    '정치',
    '직장인',
    '패션',
    '기타',
  ];

  // 조회기간 리스트
  final List<String> _periods = ['전체', '1일', '1주', '1달', '직접설정'];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // ScrollController 초기화는 initState에서만 수행
    _scrollController = ScrollController();
    _loadReportedTopics();
    
    // ★ [제재 체크] 화면이 빌드된 직후 유저 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUserBanStatus();
    });
  }

  // 제재된 유저 체크 및 강제 로그아웃
  Future<void> _checkUserBanStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return; // 로그인 안 되어 있으면 체크 불필요

    try {
      final authService = AuthService();
      final isAllowed = await authService.checkUserStatus(user.uid);
      
      if (!isAllowed && mounted) {
        // 제재된 유저: 강제 로그아웃 및 로그인 화면으로 이동
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // 모든 이전 화면 제거
        );
        
        // 이동 후 알림 표시 (약간의 지연 후)
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('계정이 정지되어 로그아웃되었습니다.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
        });
      }
    } catch (e) {
      print('❌ 유저 제재 상태 체크 에러: $e');
      // 에러 발생 시에도 앱은 계속 실행 (안전 처리)
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 신고한 주제 목록 불러오기 (앱 재시작 시에도 유지)
  Future<void> _loadReportedTopics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final reports = await _db
          .collection('reports')
          .where('reporterId', isEqualTo: user.uid)
          .where('targetType', isEqualTo: 'topic')
          .get();

      if (mounted) {
        setState(() {
          for (var report in reports.docs) {
            final targetId = report.data()['targetId'] as String?;
            if (targetId != null) {
              _reportedTopics.add(targetId);
            }
          }
        });
      }
    } catch (e) {
      print('❌ 신고한 주제 목록 불러오기 에러: $e');
    }
  }

  // Firestore 쿼리 생성 (인덱스 문제를 완전히 피하기 위해 orderBy도 제거)
  Query<Map<String, dynamic>> _getTopicsQuery() {
    // 모든 데이터를 가져온 후 클라이언트에서 필터링/정렬
    // 인덱스가 필요 없도록 가장 단순한 쿼리만 사용 (orderBy도 제거)
    return _db.collection('topics');
  }

  // Stream을 캐싱하여 build 메서드에서 재생성 방지
  Stream<QuerySnapshot> _getTopicsStream() {
    _topicsStream ??= _getTopicsQuery().snapshots();
    return _topicsStream!;
  }

  // 조회기간에 따른 시작 날짜 계산
  DateTime? _getPeriodStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case '1일':
        return now.subtract(const Duration(days: 1));
      case '1주':
        return now.subtract(const Duration(days: 7));
      case '1달':
        return now.subtract(const Duration(days: 30));
      case '직접설정':
        return _customStartDate;
      default:
        return null; // 전체
    }
  }

  // 클라이언트 측에서 필터링 및 정렬 처리
  List<QueryDocumentSnapshot> _filterAndSortDocuments(
    List<QueryDocumentSnapshot> docs,
  ) {
    // 0. status 필터링 (deleted, banned 제외)
    List<QueryDocumentSnapshot> filteredDocs = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final status = data?['status'] as String?;
      // active, review는 표시, deleted, banned는 숨김
      return status != 'deleted' && status != 'banned';
    }).toList();
    
    // 1. 카테고리 필터링
    if (_selectedCategory != '전체') {
      filteredDocs = filteredDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final category = data?['category'] as String?;
        return category == _selectedCategory;
      }).toList();
    }

    // 2. 조회기간 필터링
    final periodStart = _getPeriodStartDate();
    if (periodStart != null || _customEndDate != null) {
      filteredDocs = filteredDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        final createdAt = data?['createdAt'] as Timestamp?;
        if (createdAt == null) return false;

        final docDate = createdAt.toDate();
        final startDate = _customStartDate ?? periodStart;
        final endDate = _customEndDate ?? DateTime.now();

        return docDate.isAfter(startDate!) &&
            docDate.isBefore(endDate.add(const Duration(days: 1)));
      }).toList();
    }

    // 2. 정렬
    final sortedDocs = List<QueryDocumentSnapshot>.from(filteredDocs);

    if (_selectedSort == '인기순') {
      // 인기순: totalVotes 기준 내림차순
      sortedDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aVotes = aData?['totalVotes'] as int? ?? 0;
        final bVotes = bData?['totalVotes'] as int? ?? 0;
        return bVotes.compareTo(aVotes); // 내림차순
      });
    } else {
      // 최신순: createdAt 기준 내림차순
      sortedDocs.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>?;
        final bData = b.data() as Map<String, dynamic>?;
        final aTime = aData?['createdAt'] as Timestamp?;
        final bTime = bData?['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime); // 내림차순
      });
    }

    return sortedDocs;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin을 위해 필요
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        final now = DateTime.now();
        if (_lastPressedAt == null || 
            now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          // 첫 번째 누름이거나 2초 이상 지났으면
          setState(() {
            _lastPressedAt = now;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  '뒤로 버튼을 한번 더 누르면 종료됩니다.',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: isDark 
                    ? const Color(0xFF2D2D3A) 
                    : Colors.grey[800],
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } else {
          // 2초 이내에 다시 누르면 앱 종료
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      drawer: const MainDrawer(),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: const Color(0xFFFF512F),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF512F).withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateTopicScreen(),
              ),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Color(0xFFFF512F)),
          label: const Text(
            '새 주제',
            style: TextStyle(color: Color(0xFFFF512F), fontWeight: FontWeight.bold),
          ),
        ),
      ),
      body: CustomScrollView(
        key: const PageStorageKey<String>('feed_scroll_position'),
        controller: _scrollController,
        slivers: [
          // SliverAppBar
          SliverAppBar(
            floating: true,
            snap: true,
            pinned: false,
            title: const Text(
              'Key War',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationHistoryScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // 필터 영역 (카테고리, 조회기간, 정렬)
          SliverToBoxAdapter(
            child: Column(
              children: [
                // 1. 가로 스크롤 카테고리 바
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return _buildCategoryChip(context, _categories[index]);
                    },
                  ),
                ),

                // 조회기간 선택 바
                Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Text(
                        '조회기간: ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _periods.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            return _buildPeriodChip(context, _periods[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      _buildSortButton(context, '최신순'),
                      const SizedBox(width: 10),
                      _buildSortButton(context, '인기순'),
                      const Spacer(),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
              ],
            ),
          ),

          // Firebase 실시간 데이터 구독 (Sliver 위젯으로 변환)
          StreamBuilder<List<String>>(
            stream: _blockService.getBlockedUsersStream(),
            builder: (context, blockedUsersSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _getTopicsStream(),
                builder: (context, snapshot) {
                  // 로딩 중
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  // 에러 처리
                  if (snapshot.hasError) {
                    final error = snapshot.error.toString();
                    final isIndexError =
                        error.contains('index') ||
                        error.contains('failed-precondition');

                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isIndexError
                                  ? 'Firestore 인덱스가 필요합니다'
                                  : '오류가 발생했습니다',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (isIndexError) ...[
                              const Text(
                                '에러 메시지에 포함된 링크를 클릭하여\n인덱스를 생성해주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = '전체';
                                  });
                                },
                                child: const Text('전체 카테고리로 변경'),
                              ),
                            ] else ...[
                              Text(
                                error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  // 클라이언트 측에서 필터링 및 정렬 처리
                  final allDocs = _filterAndSortDocuments(
                    snapshot.data!.docs,
                  );
                  // 신고된 주제 필터링
                  final reportedFilteredDocs = allDocs
                      .where((doc) => !_reportedTopics.contains(doc.id))
                      .toList();
                  // 차단한 사용자의 주제 필터링 및 상태 필터링 (banned만 숨김, review는 표시)
                  final blockedUserIds = blockedUsersSnapshot.data ?? [];
                  final docs = reportedFilteredDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    final authorId = data?['authorId'] as String?;
                    final status = data?['status'] as String?;
                    
                    // banned 상태만 숨김 (review, active는 표시)
                    if (status == 'banned') {
                      return false;
                    }
                    
                    return authorId != null &&
                        !blockedUserIds.contains(authorId);
                  }).toList();
                  final topicCount = docs.length;

                  // 필터링 후 데이터 없음
                  if (topicCount == 0) {
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: const Color(0xFFFF512F).withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedCategory == '전체'
                                  ? '아직 주제가 없습니다'
                                  : '$_selectedCategory 카테고리에 주제가 없습니다',
                              style: TextStyle(
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '새로운 주제를 만들어보세요!',
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFFFF512F),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF512F).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const CreateTopicScreen(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: Color(0xFFFF512F),
                                ),
                                label: const Text(
                                  '주제 만들기',
                                  style: TextStyle(
                                    color: Color(0xFFFF512F),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: const Color(0xFFFF512F),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 데이터 목록 (SliverList 사용)
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // 주제 개수 표시 (첫 번째 아이템 위에)
                        if (index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 8.0,
                                ),
                                child: Text(
                                  '총 $topicCount개의 주제',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: _buildTopicItem(docs[index]),
                              ),
                            ],
                          );
                        }

                        // 일반 아이템
                        return Container(
                          margin: EdgeInsets.only(
                            left: 16.0,
                            right: 16.0,
                            top: 10.0,
                            bottom: index == docs.length - 1 ? 100.0 : 10.0,
                          ),
                          child: _buildTopicItem(docs[index]),
                        );
                      },
                      childCount: docs.length,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
    );
  }

  // 주제 아이템 빌더 (ArenaCard + StreamBuilder)
  Widget _buildTopicItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('topics')
          .doc(doc.id)
          .collection('comments')
          .snapshots(),
      builder: (context, commentsSnapshot) {
        String hotComment = '가장 먼저 댓글을 달아보세요 !';

        if (commentsSnapshot.hasData &&
            commentsSnapshot.data!.docs.isNotEmpty) {
          // 공감이 가장 많은 댓글 찾기
          QueryDocumentSnapshot? bestComment;
          int maxLikes = -1;

          for (var commentDoc in commentsSnapshot.data!.docs) {
            final commentData =
                commentDoc.data() as Map<String, dynamic>;
            final likes = commentData['likes'] as int? ?? 0;

            if (likes > maxLikes) {
              maxLikes = likes;
              bestComment = commentDoc;
            }
          }

          if (bestComment != null && maxLikes > 0) {
            final bestData = bestComment.data() as Map<String, dynamic>;
            hotComment = bestData['content'] as String? ??
                '가장 먼저 댓글을 달아보세요 !';
          }
        }

        return ArenaCard(
          topicId: doc.id,
          category: data['category'] ?? '기타',
          title: data['title'] ?? '제목 없음',
          initialVoteCounts: List<int>.from(
            data['voteCounts'] ?? [],
          ),
          options: List<String>.from(
            data['options'] ?? [],
          ),
          hotComment: hotComment,
          onReport: () => _reportTopic(doc.id),
        );
      },
    );
  }

  Widget _buildCategoryChip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedCategory == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF512F).withOpacity(0.1)
              : (isDark ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF512F)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFFF512F)
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isActive = _selectedSort == label;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSort = label;
        });
      },
      child: Text(
        label,
        style: TextStyle(
          color: isActive
              ? const Color(0xFFFF512F)
              : (isDark ? Colors.grey : Colors.black54),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  // 주제 신고 기능
  Future<void> _reportTopic(String topicId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      }
      return;
    }

    // 신고 사유 선택 다이얼로그 표시
    final reason = await ReportDialog.show(context);
    if (reason == null) return; // 사용자가 취소한 경우

    try {
      await _reportService.report(
        targetId: topicId,
        targetType: 'topic',
        reason: reason,
      );

      if (mounted) {
        // 신고된 주제를 Set에 추가하고 화면에서 숨김
        setState(() {
          _reportedTopics.add(topicId);
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('신고가 접수되었습니다.')));
      }
    } catch (e) {
      print('❌ 주제 신고 에러: $e');
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

  Widget _buildPeriodChip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedPeriod == label;

    return GestureDetector(
      onTap: () async {
        if (label == '직접설정') {
          // 날짜 선택 다이얼로그 표시
          final DateTimeRange? picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: _customStartDate != null && _customEndDate != null
                ? DateTimeRange(start: _customStartDate!, end: _customEndDate!)
                : null,
          );
          if (picked != null) {
            setState(() {
              _selectedPeriod = '직접설정';
              _customStartDate = picked.start;
              _customEndDate = picked.end;
            });
          }
        } else {
          setState(() {
            _selectedPeriod = label;
            _customStartDate = null;
            _customEndDate = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFF512F).withOpacity(0.1)
              : (isDark ? Colors.transparent : Colors.white),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF512F)
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFFF512F)
                : (isDark ? Colors.grey[400] : Colors.grey[700]),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ArenaCard 위젯 - 주제 카드 표시
class ArenaCard extends StatefulWidget {
  final String topicId; // 주제 ID 추가
  final String category;
  final String title;
  final List<int> initialVoteCounts;
  final List<String> options;
  final String hotComment;
  final List<Color>? colors; // 선택적 (기본 색상 사용)
  final VoidCallback? onReport; // 신고 콜백

  const ArenaCard({
    super.key,
    required this.topicId,
    required this.category,
    required this.title,
    required this.initialVoteCounts,
    required this.options,
    required this.hotComment,
    this.colors,
    this.onReport,
  });

  @override
  State<ArenaCard> createState() => _ArenaCardState();
}

class _ArenaCardState extends State<ArenaCard> {
  List<int> _voteCounts = [];
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isVoting = false; // 투표 중 상태

  @override
  void initState() {
    super.initState();
    _voteCounts = List.from(widget.initialVoteCounts);
  }

  @override
  void didUpdateWidget(ArenaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때 투표수만 업데이트 (선택한 옵션은 유지)
    if (oldWidget.initialVoteCounts != widget.initialVoteCounts) {
      setState(() {
        _voteCounts = List.from(widget.initialVoteCounts);
      });
    }
  }

  // 투표하기 (Firebase에 저장)
  Future<void> _castVote(int index) async {
    if (_isVoting) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인이 필요합니다.')));
      return;
    }

    // Firestore에서 실제 이전 투표 정보 확인 (VoteScreen과 동일하게)
    int? previousIndex;
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

    // 같은 선택지를 다시 선택하는 경우
    if (previousIndex == index) {
      return;
    }

    _isVoting = true;

    // 1. 로컬 상태 먼저 업데이트 (반응속도 향상)
    setState(() {
      if (previousIndex != null &&
          previousIndex >= 0 &&
          previousIndex < _voteCounts.length) {
        _voteCounts[previousIndex]--;
      }
      if (index >= 0 && index < _voteCounts.length) {
        _voteCounts[index]++;
      }
    });

    // 2. Firebase에 저장
    final docRef = _db.collection('topics').doc(widget.topicId);

    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('주제를 찾을 수 없습니다.');
        }

        final data = snapshot.data();
        if (data == null) {
          throw Exception('주제 데이터를 읽을 수 없습니다.');
        }

        List<dynamic> counts = List.from(data['voteCounts'] ?? []);
        // totalVotes를 counts에서 직접 계산 (더 정확함)
        int totalVotes = counts.fold<int>(
          0,
          (sum, count) => sum + (count as int? ?? 0),
        );

        print(
          "📊 피드 투표 시작: topicId=${widget.topicId}, optionIndex=$index, previousIndex=$previousIndex",
        );
        print("📊 현재 투표 상태: counts=$counts, totalVotes=$totalVotes");

        // 이전 선택 취소 (이미 투표한 경우에만)
        if (previousIndex != null &&
            previousIndex >= 0 &&
            previousIndex < counts.length) {
          final prevCount = counts[previousIndex] as int? ?? 0;
          if (prevCount > 0) {
            counts[previousIndex] = prevCount - 1;
            totalVotes--;
            print(
              "📊 이전 투표 취소: previousIndex=$previousIndex, 이전 count=$prevCount",
            );
          }
        }

        // 새 선택 추가
        if (index >= 0 && index < counts.length) {
          final currentCount = counts[index] as int? ?? 0;
          counts[index] = currentCount + 1;
          totalVotes++;
          print(
            "📊 새 투표 추가: index=$index, 이전 count=$currentCount, 새로운 count=${counts[index]}, 새로운 totalVotes=$totalVotes",
          );
        } else {
          throw Exception('유효하지 않은 선택지입니다.');
        }

        transaction.update(docRef, {
          'voteCounts': counts,
          'totalVotes': totalVotes,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        print("✅ 피드 트랜잭션 업데이트 완료");
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
      });

      print("✅ 피드에서 투표 저장 완료: ${widget.topicId}, 옵션: $index");
    } catch (e) {
      print("❌ 피드 투표 에러: $e");

      // 에러 발생 시 이전 상태로 복원
      if (mounted) {
        setState(() {
          if (previousIndex != null &&
              previousIndex >= 0 &&
              previousIndex < _voteCounts.length) {
            _voteCounts[previousIndex]++;
          }
          if (index >= 0 && index < _voteCounts.length) {
            _voteCounts[index]--;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('투표에 실패했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }

  double _getPercentValue(int index, int total) {
    if (total == 0) return 0.0;
    return _voteCounts[index] / total;
  }

  String _getPercentString(int index, int total) {
    if (total == 0) return '0%';
    return '${((_voteCounts[index] / total) * 100).toStringAsFixed(1)}%';
  }

  // 기본 색상 팔레트
  static const List<Color> _defaultColors = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];

  // 카테고리별 그라데이션 매핑 (프리미엄 뱃지 스타일)
  List<Color> _getCategoryGradient(String category) {
    final gradientMap = <String, List<Color>>{
      '음식': [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)], // Red-Orange
      '게임': [const Color(0xFF6B8DD6), const Color(0xFF8E37D7)], // Blue-Purple
      '연애': [const Color(0xFFFF6B9D), const Color(0xFFC44569)], // Pink-Red
      '스포츠': [const Color(0xFF4ECDC4), const Color(0xFF44A08D)], // Cyan-Green
      '유머': [const Color(0xFFFFD93D), const Color(0xFFFF6B6B)], // Yellow-Red
      '정치': [const Color(0xFF4A90E2), const Color(0xFF357ABD)], // Blue
      '직장인': [const Color(0xFF667EEA), const Color(0xFF764BA2)], // Indigo-Purple
      '패션': [const Color(0xFFF093FB), const Color(0xFFF5576C)], // Pink-Red
      '기타': [const Color(0xFF6B8DD6), const Color(0xFF8E37D7)], // Default Blue-Purple
    };
    return gradientMap[category] ?? [const Color(0xFF6B8DD6), const Color(0xFF8E37D7)];
  }

  // 카테고리별 글로우 색상
  Color _getCategoryGlowColor(String category) {
    final glowMap = <String, Color>{
      '음식': Colors.orangeAccent,
      '게임': Colors.purpleAccent,
      '연애': Colors.pinkAccent,
      '스포츠': Colors.greenAccent,
      '유머': Colors.amberAccent,
      '정치': Colors.blueAccent,
      '직장인': Colors.indigoAccent,
      '패션': Colors.pinkAccent,
      '기타': Colors.blueAccent,
    };
    return glowMap[category] ?? Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int totalVotes = _voteCounts.reduce((a, b) => a + b);
    final colors = widget.colors ?? _defaultColors;

    // 실시간으로 사용자의 투표 정보 가져오기 (StreamBuilder 사용)
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? _db
                .collection('users')
                .doc(user.uid)
                .collection('votes')
                .doc(widget.topicId)
                .snapshots()
          : null,
      builder: (context, voteSnapshot) {
        // 실시간으로 업데이트된 투표 정보 사용
        int? currentSelectedIndex;
        if (voteSnapshot.hasData && voteSnapshot.data!.exists) {
          final data = voteSnapshot.data!.data() as Map<String, dynamic>?;
          final optionIndex = data?['optionIndex'] as int?;
          if (optionIndex != null &&
              optionIndex >= 0 &&
              optionIndex < widget.options.length) {
            currentSelectedIndex = optionIndex;
          }
        }

        final bool hasVoted = currentSelectedIndex != null;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VoteScreen(topicId: widget.topicId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: isDark
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFFF5F7FA),
                      ],
                    ),
              color: isDark ? const Color(0xFF2D2D3A) : null,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Premium Badge-style Category Chip with Gradient
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? null
                          : LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _getCategoryGradient(widget.category),
                            ),
                      color: isDark ? Colors.white10 : null,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: _getCategoryGlowColor(widget.category)
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                spreadRadius: 0,
                              ),
                            ],
                    ),
                    child: Text(
                      widget.category,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (widget.onReport != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (value == 'report') {
                          widget.onReport?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(
                                Icons.flag_outlined,
                                size: 18,
                                color: Colors.red[400],
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '이 주제 신고하기',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: List.generate(widget.options.length, (index) {
                  final isSelected = currentSelectedIndex == index;
                  final color = colors[index % colors.length];
                  final percentValue = _getPercentValue(index, totalVotes);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: GestureDetector(
                      onTap: () => _castVote(index),
                      child: Stack(
                        children: [
                          Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey[100],
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? color
                                    : (hasVoted
                                          ? Colors.transparent
                                          : (isDark
                                                ? Colors.white24
                                                : Colors.grey[300]!)),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                          ),
                          if (hasVoted)
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  height: 56,
                                  width: constraints.maxWidth * percentValue,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                );
                              },
                            ),
                          Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            alignment: Alignment.centerLeft,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.options[index],
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 15,
                                      color: isSelected
                                          ? color
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.grey[700]),
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasVoted)
                                  Text(
                                    _getPercentString(index, totalVotes),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? color
                                          : (isDark
                                                ? Colors.grey
                                                : Colors.grey[600]),
                                    ),
                                  ),
                                if (isSelected)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: Icon(
                                      Icons.check_circle,
                                      color: color,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🔥 베댓: ',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.hotComment,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 14,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalVotes명 참여',
                        style: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              VoteScreen(topicId: widget.topicId),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[400] : Colors.grey[600],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '댓글 보기',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

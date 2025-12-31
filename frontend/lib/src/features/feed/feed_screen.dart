import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_drawer.dart';
import '../vote/vote_screen.dart';
import 'create_topic_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedCategory = '전체';
  String _selectedSort = '최신순';
  String _selectedPeriod = '전체'; // 조회기간: 전체, 1일, 1주, 1달, 직접설정
  DateTime? _customStartDate; // 직접 설정한 시작 날짜
  DateTime? _customEndDate; // 직접 설정한 종료 날짜

  // Firebase 인스턴스
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 카테고리 리스트
  final List<String> _categories = [
    '전체', '음식', '게임', '연애', '스포츠', '유머', '정치', '직장인', '패션', '기타'
  ];

  // 조회기간 리스트
  final List<String> _periods = ['전체', '1일', '1주', '1달', '직접설정'];

  // Firestore 쿼리 생성 (인덱스 문제를 완전히 피하기 위해 orderBy도 제거)
  Query<Map<String, dynamic>> _getTopicsQuery() {
    // 모든 데이터를 가져온 후 클라이언트에서 필터링/정렬
    // 인덱스가 필요 없도록 가장 단순한 쿼리만 사용 (orderBy도 제거)
    return _db.collection('topics');
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
    // 1. 카테고리 필터링
    List<QueryDocumentSnapshot> filteredDocs = docs;
    if (_selectedCategory != '전체') {
      filteredDocs = docs.where((doc) {
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
        
        return docDate.isAfter(startDate!) && docDate.isBefore(endDate.add(const Duration(days: 1)));
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
    return Scaffold(
      drawer: const MainDrawer(),
      appBar: AppBar(
        title: const Text('키보드 아레나', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFF9C27B0)]),
          borderRadius: BorderRadius.circular(30),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CreateTopicScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_circle_outline, color: Colors.white),
          label: const Text('새 주제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: Column(
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
                const Text('조회기간: ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _periods.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
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
                // 주제 개수는 StreamBuilder 안에서 표시
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // Firebase 실시간 데이터 구독
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getTopicsQuery().snapshots(),
              builder: (context, snapshot) {
                // 로딩 중
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 에러 처리
                if (snapshot.hasError) {
                  final error = snapshot.error.toString();
                  final isIndexError = error.contains('index') || error.contains('failed-precondition');
                  
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            isIndexError 
                              ? 'Firestore 인덱스가 필요합니다'
                              : '오류가 발생했습니다',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                // 카테고리를 전체로 변경하여 인덱스 없이도 작동하도록
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
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // 클라이언트 측에서 필터링 및 정렬 처리
                final docs = _filterAndSortDocuments(snapshot.data!.docs);
                final topicCount = docs.length;

                // 필터링 후 데이터 없음
                if (topicCount == 0) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _selectedCategory == '전체' 
                              ? '아직 주제가 없습니다'
                              : '$_selectedCategory 카테고리에 주제가 없습니다',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '새로운 주제를 만들어보세요!',
                            style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreateTopicScreen()),
                              );
                            },
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('주제 만들기'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // 주제 개수 표시
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '총 $topicCount개의 주제',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 주제 리스트
                    Expanded(
                      child: ListView.separated(
                        key: const PageStorageKey<String>('feed_scroll_position'), // 스크롤 위치 유지
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: docs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          return StreamBuilder<QuerySnapshot>(
                            stream: _db.collection('topics').doc(doc.id).collection('comments').snapshots(),
                            builder: (context, commentsSnapshot) {
                              String hotComment = '가장 먼저 댓글을 달아보세요 !';
                              
                              if (commentsSnapshot.hasData && commentsSnapshot.data!.docs.isNotEmpty) {
                                // 공감이 가장 많은 댓글 찾기
                                QueryDocumentSnapshot? bestComment;
                                int maxLikes = -1;
                                
                                for (var commentDoc in commentsSnapshot.data!.docs) {
                                  final commentData = commentDoc.data() as Map<String, dynamic>;
                                  final likes = commentData['likes'] as int? ?? 0;
                                  
                                  if (likes > maxLikes) {
                                    maxLikes = likes;
                                    bestComment = commentDoc;
                                  }
                                }
                                
                                if (bestComment != null && maxLikes > 0) {
                                  final bestData = bestComment.data() as Map<String, dynamic>;
                                  hotComment = bestData['content'] as String? ?? '가장 먼저 댓글을 달아보세요 !';
                                }
                              }
                              
                              return ArenaCard(
                                topicId: doc.id, // 문서 ID 전달
                                category: data['category'] ?? '기타',
                                title: data['title'] ?? '제목 없음',
                                initialVoteCounts: List<int>.from(data['voteCounts'] ?? []),
                                options: List<String>.from(data['options'] ?? []),
                                hotComment: hotComment,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedCategory == label;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          _selectedCategory = label;
        });
      },
      backgroundColor: isDark ? const Color(0xFF2D2D3A) : Colors.grey[200],
      selectedColor: const Color(0xFFE91E63),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      showCheckmark: false,
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
          color: isActive ? const Color(0xFFE91E63) : (isDark ? Colors.grey : Colors.black54),
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFE91E63) 
              : (isDark ? const Color(0xFF2D2D3A) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  const ArenaCard({
    super.key,
    required this.topicId,
    required this.category,
    required this.title,
    required this.initialVoteCounts,
    required this.options,
    required this.hotComment,
    this.colors,
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
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
      if (previousIndex != null && previousIndex >= 0 && previousIndex < _voteCounts.length) {
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

        final data = snapshot.data() as Map<String, dynamic>?;
        if (data == null) {
          throw Exception('주제 데이터를 읽을 수 없습니다.');
        }

        List<dynamic> counts = List.from(data['voteCounts'] ?? []);
        // totalVotes를 counts에서 직접 계산 (더 정확함)
        int totalVotes = counts.fold<int>(0, (sum, count) => sum + (count as int? ?? 0));
        
        print("📊 피드 투표 시작: topicId=${widget.topicId}, optionIndex=$index, previousIndex=$previousIndex");
        print("📊 현재 투표 상태: counts=$counts, totalVotes=$totalVotes");
        
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
        if (index >= 0 && index < counts.length) {
          final currentCount = counts[index] as int? ?? 0;
          counts[index] = currentCount + 1;
          totalVotes++;
          print("📊 새 투표 추가: index=$index, 이전 count=$currentCount, 새로운 count=${counts[index]}, 새로운 totalVotes=$totalVotes");
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
          if (previousIndex != null && previousIndex >= 0 && previousIndex < _voteCounts.length) {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    int totalVotes = _voteCounts.reduce((a, b) => a + b);
    final colors = widget.colors ?? _defaultColors;
    
    // 실시간으로 사용자의 투표 정보 가져오기 (StreamBuilder 사용)
    final user = FirebaseAuth.instance.currentUser;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null 
          ? _db.collection('users').doc(user.uid).collection('votes').doc(widget.topicId).snapshots()
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

        return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D3A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[100], 
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                ),
                child: Text(widget.category, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
              ),
              const Spacer(),
              Icon(Icons.people_outline, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text('$totalVotes명', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            ],
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, height: 1.3, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 20),
          Column(
            children: List.generate(widget.options.length, (index) {
              final isSelected = currentSelectedIndex == index;
              final color = colors[index % colors.length];
              final percentValue = _getPercentValue(index, totalVotes);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () => _castVote(index),
                  child: Stack(
                    children: [
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? color : (hasVoted ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!)),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                      if (hasVoted)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Container(
                              height: 50,
                              width: constraints.maxWidth * percentValue, 
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.25), 
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          },
                        ),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                widget.options[index],
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 15,
                                  color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasVoted)
                              Text(
                                _getPercentString(index, totalVotes),
                                style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? color : (isDark ? Colors.grey : Colors.grey[600])),
                              ),
                            if (isSelected) 
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Icon(Icons.check_circle, color: color, size: 18),
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
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (context) => VoteScreen(
                    topicId: widget.topicId,
                    highlightComment: widget.hotComment,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('🔥 베댓: ', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(widget.hotComment, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VoteScreen(topicId: widget.topicId),
                  ),
                );
              },
              icon: const Icon(Icons.comment_outlined, size: 18),
              label: const Text('토론장 입장해서 댓글 보기'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[500]),
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
/// 욕설 및 비속어 필터링 유틸리티
class ProfanityFilter {
  // 테스트용 비속어 리스트 (나중에 확장 가능)
  static const List<String> _badWords = [
    '앙기기',
    '씨발',
    '씨부랄',
    '씨발랄',
    '씨발랄',
    '개새끼',
    '개년',
    '개년새끼',
    '좆같은',
    '좆',
    '보지',
    '자지',
    '쟈지',
    '쟈지',
    '뷰지',
    '뷰짓',
    'ㅅㅂ',
    '애미',
  ];

  /// 입력된 텍스트에 비속어가 포함되어 있는지 확인
  /// 
  /// [text] 검사할 텍스트
  /// 
  /// 반환값: true = 비속어 포함, false = 정상
  static bool hasProfanity(String text) {
    if (text.isEmpty) return false;

    // 공백 제거 후 소문자로 변환 (대소문자 구분 없이 검사)
    final normalizedText = text.replaceAll(' ', '').toLowerCase();

    // 각 비속어가 포함되어 있는지 확인
    for (final badWord in _badWords) {
      final normalizedBadWord = badWord.toLowerCase();
      if (normalizedText.contains(normalizedBadWord)) {
        return true;
      }
    }

    return false;
  }
}


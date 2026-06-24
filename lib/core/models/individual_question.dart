/// 개별 질문(Individual Questions) 모델.
///
/// 구독과 별개로 단건 질문을 에스크로 예치하고 답을 받는다.
/// - open(공개): 멘토 지정 없이 가격을 붙여 공개 → 먼저 가져간 멘토 1명이 답변.
/// - direct(지정): 특정 멘토에게 1:1 유료 질문.
library;

enum IQType { open, direct }

enum IQStatus {
  escrowed, // 예치중
  open, // 공개중(풀 노출)
  assigned, // 담당 지정(지정형)
  claimed, // 멘토가 가져감(공개형)
  answered, // 답변완료(학생 확인 대기)
  released, // 정산완료
  expired, // 만료
  refunded, // 환불
  canceled, // 취소
}

IQType iqTypeFromString(String? s) =>
    s == 'direct' ? IQType.direct : IQType.open;

IQStatus iqStatusFromString(String? s) {
  switch (s) {
    case 'escrowed':
      return IQStatus.escrowed;
    case 'open':
      return IQStatus.open;
    case 'assigned':
      return IQStatus.assigned;
    case 'claimed':
      return IQStatus.claimed;
    case 'answered':
      return IQStatus.answered;
    case 'released':
      return IQStatus.released;
    case 'expired':
      return IQStatus.expired;
    case 'refunded':
      return IQStatus.refunded;
    case 'canceled':
      return IQStatus.canceled;
    default:
      return IQStatus.open;
  }
}

class IndividualQuestion {
  const IndividualQuestion({
    required this.id,
    required this.type,
    required this.status,
    required this.title,
    required this.body,
    required this.priceCash,
    this.askerId = 'demo-student',
    this.askerLabel = '학생',
    this.designatedMentorId,
    this.designatedMentorName,
    this.claimedMentorId,
    this.claimedMentorName,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final IQType type;
  final IQStatus status;
  final String title;
  final String body;
  final int priceCash;
  final String askerId;
  final String askerLabel;
  final String? designatedMentorId;
  final String? designatedMentorName;
  final String? claimedMentorId;
  final String? claimedMentorName;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isOpen => type == IQType.open;
  String? get answeringMentorName => claimedMentorName ?? designatedMentorName;
  String? get answeringMentorId => claimedMentorId ?? designatedMentorId;

  bool get isTerminal =>
      status == IQStatus.released ||
      status == IQStatus.refunded ||
      status == IQStatus.expired ||
      status == IQStatus.canceled;

  /// 멘토가 아직 답변 전(받은 지정/가져간 공개)이면 답변 가능.
  bool get awaitingAnswer =>
      status == IQStatus.assigned || status == IQStatus.claimed;

  IndividualQuestion copyWith({
    IQStatus? status,
    String? claimedMentorId,
    String? claimedMentorName,
    DateTime? expiresAt,
  }) =>
      IndividualQuestion(
        id: id,
        type: type,
        status: status ?? this.status,
        title: title,
        body: body,
        priceCash: priceCash,
        askerId: askerId,
        askerLabel: askerLabel,
        designatedMentorId: designatedMentorId,
        designatedMentorName: designatedMentorName,
        claimedMentorId: claimedMentorId ?? this.claimedMentorId,
        claimedMentorName: claimedMentorName ?? this.claimedMentorName,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
      );

  factory IndividualQuestion.fromMap(Map<String, dynamic> m) =>
      IndividualQuestion(
        id: m['id'] as String,
        type: iqTypeFromString(m['question_type'] as String?),
        status: iqStatusFromString(m['status'] as String?),
        title: (m['title'] as String?) ?? '개별 질문',
        body: (m['body'] as String?) ?? '',
        // 실제 컬럼은 price_cents. (구버전 키 amount_cents/amount_cash 폴백 유지)
        priceCash: (m['price_cents'] as num?) != null
            ? ((m['price_cents'] as num).toInt() ~/ 100)
            : (m['amount_cents'] as num?) != null
                ? ((m['amount_cents'] as num).toInt() ~/ 100)
                : ((m['amount_cash'] as num?)?.toInt() ?? 0),
        // 실제 컬럼은 student_id. (구버전 키 asker_id 폴백 유지)
        askerId: (m['student_id'] as String?) ??
            (m['asker_id'] as String?) ??
            'demo-student',
        askerLabel: (m['asker_label'] as String?) ?? '학생',
        designatedMentorId: m['designated_mentor_id'] as String?,
        designatedMentorName: m['designated_mentor_name'] as String?,
        claimedMentorId: m['claimed_mentor_id'] as String?,
        claimedMentorName: m['claimed_mentor_name'] as String?,
        createdAt: _d(m['created_at']),
        expiresAt: _d(m['expires_at']),
      );

  static String statusLabel(IQStatus s) {
    switch (s) {
      case IQStatus.escrowed:
        return '예치중';
      case IQStatus.open:
        return '공개중';
      case IQStatus.assigned:
        return '담당 지정';
      case IQStatus.claimed:
        return '멘토가 가져감';
      case IQStatus.answered:
        return '답변완료';
      case IQStatus.released:
        return '정산완료';
      case IQStatus.expired:
        return '만료';
      case IQStatus.refunded:
        return '환불';
      case IQStatus.canceled:
        return '취소';
    }
  }

  static String typeLabel(IQType t) => t == IQType.open ? '공개' : '지정';
}

class IndividualQuestionMessage {
  const IndividualQuestionMessage({
    required this.id,
    required this.questionId,
    required this.authorId,
    required this.body,
    this.createdAt,
  });
  final String id;
  final String questionId;
  final String authorId;
  final String body;
  final DateTime? createdAt;

  factory IndividualQuestionMessage.fromMap(Map<String, dynamic> m) =>
      IndividualQuestionMessage(
        id: m['id'] as String,
        questionId: (m['question_id'] as String?) ?? '',
        authorId: (m['author_id'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        createdAt: _d(m['created_at']),
      );
}

DateTime? _d(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

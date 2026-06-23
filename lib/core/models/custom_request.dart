/// custom_request_posts — 맞춤의뢰 게시글.
library;

class CustomRequestPost {
  const CustomRequestPost({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    this.subject,
    this.budgetMin,
    this.budgetMax,
    this.deadline,
    this.status = 'open',
    this.createdAt,
    this.applicationsCount = 0,
  });

  final String id;
  final String authorId; // 의뢰 올린 학생
  final String title;
  final String description;
  final String? subject;
  final int? budgetMin; // 캐시(=원)
  final int? budgetMax;
  final DateTime? deadline;
  final String status; // open | closed | cancelled | in_progress | fulfilled ...
  final DateTime? createdAt;
  final int applicationsCount;

  bool get isOpen => status == 'open';

  CustomRequestPost copyWith({String? status, int? applicationsCount}) =>
      CustomRequestPost(
        id: id,
        authorId: authorId,
        title: title,
        description: description,
        subject: subject,
        budgetMin: budgetMin,
        budgetMax: budgetMax,
        deadline: deadline,
        status: status ?? this.status,
        createdAt: createdAt,
        applicationsCount: applicationsCount ?? this.applicationsCount,
      );

  String get budgetLabel {
    if (budgetMin == null && budgetMax == null) return '예산 협의';
    if (budgetMin != null && budgetMax != null) {
      if (budgetMin == budgetMax) return '${_fmt(budgetMin!)} 캐시';
      return '${_fmt(budgetMin!)}~${_fmt(budgetMax!)} 캐시';
    }
    return '${_fmt((budgetMin ?? budgetMax)!)} 캐시';
  }

  factory CustomRequestPost.fromMap(Map<String, dynamic> m) => CustomRequestPost(
        id: m['id'] as String,
        authorId: (m['author_id'] as String?) ??
            (m['student_id'] as String?) ??
            (m['user_id'] as String?) ??
            '',
        title: (m['title'] as String?) ??
            (m['subject'] as String?) ??
            '제목 없는 의뢰',
        description: (m['description'] as String?) ??
            (m['body'] as String?) ??
            (m['content'] as String?) ??
            '',
        subject: m['subject'] as String?,
        budgetMin: (m['budget_min'] as num?)?.toInt(),
        budgetMax: (m['budget_max'] as num?)?.toInt(),
        deadline: _crDate(
            m['deadline'] ?? m['due_at'] ?? m['due_date']),
        status: (m['status'] as String?) ?? 'open',
        createdAt: _crDate(m['created_at']),
        applicationsCount:
            (m['applications_count'] as num?)?.toInt() ?? 0,
      );
}

String _fmt(int v) {
  final s = v.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

DateTime? _crDate(dynamic v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);

/// custom_request_applications — 멘토의 의뢰 지원.
class CustomRequestApplication {
  const CustomRequestApplication({
    required this.id,
    required this.postId,
    required this.mentorId,
    required this.mentorName,
    this.message = '',
    this.proposedCash,
    this.status = 'applied',
    this.createdAt,
    this.avgRating,
    this.universityName,
  });

  final String id;
  final String postId;
  final String mentorId;
  final String mentorName;
  final String message;
  final int? proposedCash; // 멘토 제안 금액(캐시)
  final String status; // applied | selected | rejected
  final DateTime? createdAt;
  final double? avgRating; // 표시용
  final String? universityName; // 표시용

  bool get isSelected => status == 'selected';
  bool get isRejected => status == 'rejected';

  CustomRequestApplication copyWith({String? status}) =>
      CustomRequestApplication(
        id: id,
        postId: postId,
        mentorId: mentorId,
        mentorName: mentorName,
        message: message,
        proposedCash: proposedCash,
        status: status ?? this.status,
        createdAt: createdAt,
        avgRating: avgRating,
        universityName: universityName,
      );

  factory CustomRequestApplication.fromMap(Map<String, dynamic> m) =>
      CustomRequestApplication(
        id: m['id'] as String,
        postId: (m['post_id'] as String?) ??
            (m['custom_request_post_id'] as String?) ??
            '',
        mentorId: (m['mentor_id'] as String?) ?? '',
        mentorName: (m['mentor_name'] as String?) ??
            (m['display_name'] as String?) ??
            '멘토',
        message: (m['message'] as String?) ?? (m['note'] as String?) ?? '',
        proposedCash: (m['proposed_cash'] as num?)?.toInt() ??
            (m['proposed_amount'] as num?)?.toInt(),
        status: (m['status'] as String?) ?? 'applied',
        createdAt: _crDate(m['created_at']),
        avgRating: (m['avg_rating'] as num?)?.toDouble(),
        universityName: m['university_name'] as String?,
      );
}

/// custom_orders — 선정 후 생성되는 주문(에스크로).
class CustomOrder {
  const CustomOrder({
    required this.id,
    required this.postId,
    required this.studentId,
    required this.mentorId,
    required this.mentorName,
    required this.title,
    required this.amountCash,
    this.status = 'escrow_held',
    this.createdAt,
  });

  final String id;
  final String postId;
  final String studentId;
  final String mentorId;
  final String mentorName;
  final String title;
  final int amountCash; // 에스크로 보관 금액(캐시)
  final String status; // escrow_held | in_progress | delivered | accepted | refunded | disputed
  final DateTime? createdAt;

  factory CustomOrder.fromMap(Map<String, dynamic> m) => CustomOrder(
        id: m['id'] as String,
        postId: (m['post_id'] as String?) ??
            (m['custom_request_post_id'] as String?) ??
            '',
        studentId: (m['student_id'] as String?) ??
            (m['client_id'] as String?) ??
            '',
        mentorId: (m['mentor_id'] as String?) ?? '',
        mentorName: (m['mentor_name'] as String?) ?? '멘토',
        title: (m['title'] as String?) ?? '맞춤의뢰 주문',
        amountCash: (m['amount_cash'] as num?)?.toInt() ??
            (m['amount'] as num?)?.toInt() ??
            0,
        status: (m['status'] as String?) ?? 'escrow_held',
        createdAt: _crDate(m['created_at']),
      );

  CustomOrder copyWith({String? status}) => CustomOrder(
        id: id,
        postId: postId,
        studentId: studentId,
        mentorId: mentorId,
        mentorName: mentorName,
        title: title,
        amountCash: amountCash,
        status: status ?? this.status,
        createdAt: createdAt,
      );
}

/// custom_order_deliverables — 멘토가 납품한 산출물.
class OrderDeliverable {
  const OrderDeliverable({
    required this.id,
    required this.orderId,
    required this.mentorId,
    this.message = '',
    this.fileName,
    this.createdAt,
  });

  final String id;
  final String orderId;
  final String mentorId;
  final String message;
  final String? fileName; // 데모: 파일명만(실제 업로드는 custom-order-deliverables 버킷)
  final DateTime? createdAt;

  factory OrderDeliverable.fromMap(Map<String, dynamic> m) => OrderDeliverable(
        id: m['id'] as String,
        orderId: (m['order_id'] as String?) ??
            (m['custom_order_id'] as String?) ??
            '',
        mentorId: (m['mentor_id'] as String?) ?? '',
        message: (m['message'] as String?) ?? (m['note'] as String?) ?? '',
        fileName: (m['file_name'] as String?) ?? (m['filename'] as String?),
        createdAt: _crDate(m['created_at']),
      );
}

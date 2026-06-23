/// content_reports — 신고/문의.
library;

class ContentReport {
  const ContentReport({
    required this.id,
    required this.targetType, // post | comment | shortform | user | inquiry
    this.targetId,
    required this.reason,
    this.description = '',
    this.status = 'pending',
    this.createdAt,
  });

  final String id;
  final String targetType;
  final String? targetId;
  final String reason;
  final String description;
  final String status; // pending | reviewing | resolved | rejected | dismissed
  final DateTime? createdAt;

  String get targetLabel => switch (targetType) {
        'post' => '게시글',
        'comment' => '댓글',
        'shortform' => '숏폼',
        'user' => '사용자',
        'inquiry' => '문의',
        _ => '신고',
      };

  String get statusLabel => switch (status) {
        'pending' => '접수됨',
        'reviewing' => '검토 중',
        'resolved' => '처리 완료',
        'rejected' || 'dismissed' => '반려',
        _ => status,
      };

  factory ContentReport.fromMap(Map<String, dynamic> m) => ContentReport(
        id: m['id'] as String,
        targetType: (m['target_type'] as String?) ?? 'inquiry',
        targetId: m['target_id'] as String?,
        reason: (m['reason'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
        createdAt: switch (m['created_at']) {
          String s => DateTime.tryParse(s),
          DateTime d => d,
          _ => null,
        },
      );
}

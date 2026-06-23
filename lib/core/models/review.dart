/// reviews — 멘토 후기.
library;

class Review {
  const Review({
    required this.id,
    required this.mentorId,
    required this.authorLabel,
    required this.rating,
    required this.body,
    this.createdAt,
  });

  final String id;
  final String mentorId;
  final String authorLabel;
  final int rating; // 1~5
  final String body;
  final DateTime? createdAt;

  factory Review.fromMap(Map<String, dynamic> m) => Review(
        id: m['id'] as String,
        mentorId: (m['mentor_id'] as String?) ?? '',
        authorLabel: (m['author_label'] as String?) ??
            (m['student_label'] as String?) ??
            '쌤버십 회원',
        rating: (m['rating'] as num?)?.toInt() ?? 5,
        body: (m['body'] as String?) ?? (m['content'] as String?) ?? '',
        createdAt: switch (m['created_at']) {
          String s => DateTime.tryParse(s),
          DateTime d => d,
          _ => null,
        },
      );
}

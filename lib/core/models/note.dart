/// 질문방·스레드·메시지·연결노트 모델.
/// 질문방: mentor_student_rooms → question_threads → question_messages (CLAUDE.md).
/// 연결노트: room 단위 connection_notes. ★ 필기 리뉴얼 확장 필드 포함.
library;

enum ThreadStatus { open, answered, closed }

ThreadStatus threadStatusFromString(String? v) => switch (v) {
      'answered' => ThreadStatus.answered,
      'closed' => ThreadStatus.closed,
      _ => ThreadStatus.open,
    };

extension ThreadStatusX on ThreadStatus {
  String get label => switch (this) {
        ThreadStatus.answered => '답변 완료',
        ThreadStatus.closed => '종료',
        ThreadStatus.open => '답변 대기',
      };
}

/// mentor_student_rooms — 학생↔멘토 1:1 질문방.
class Room {
  const Room({
    required this.id,
    required this.studentId,
    required this.mentorId,
    this.mentorName = '',
    this.studentName = '',
    this.subscriptionLabel,
    this.lastMessagePreview,
    this.updatedAt,
  });

  final String id;
  final String studentId;
  final String mentorId;
  final String mentorName;
  final String studentName;

  /// 표시용(조인 결과) — 예: '수학 · standard 구독'. DB 직접 컬럼 아님.
  final String? subscriptionLabel;
  final String? lastMessagePreview;
  final DateTime? updatedAt;

  factory Room.fromMap(Map<String, dynamic> m) => Room(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        mentorId: m['mentor_id'] as String,
        mentorName: (m['mentor_name'] as String?) ?? '',
        studentName: (m['student_name'] as String?) ?? '',
        subscriptionLabel: m['subscription_label'] as String?,
        lastMessagePreview: m['last_message_preview'] as String?,
        updatedAt: _date(m['updated_at']),
      );
}

/// question_threads — 방 안의 개별 질문 묶음.
class QuestionThread {
  const QuestionThread({
    required this.id,
    required this.roomId,
    required this.title,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String roomId;
  final String title;
  final ThreadStatus status;
  final DateTime? createdAt;

  factory QuestionThread.fromMap(Map<String, dynamic> m) => QuestionThread(
        id: m['id'] as String,
        roomId: m['room_id'] as String,
        title: (m['title'] as String?) ?? '제목 없음',
        status: threadStatusFromString(m['status'] as String?),
        createdAt: _date(m['created_at']),
      );
}

/// question_messages — 스레드 안의 메시지.
class QuestionMessage {
  const QuestionMessage({
    required this.id,
    required this.threadId,
    required this.authorId,
    required this.body,
    this.attachments = const [],
    this.createdAt,
  });

  final String id;
  final String threadId;
  final String authorId;
  final String body;
  final List<MessageAttachment> attachments;
  final DateTime? createdAt;

  factory QuestionMessage.fromMap(Map<String, dynamic> m) => QuestionMessage(
        id: m['id'] as String,
        threadId: (m['thread_id'] as String?) ?? '',
        authorId: (m['author_id'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        attachments: const [], // 첨부 조인은 다음 단계에서
        createdAt: _date(m['created_at']),
      );
}

/// 메시지 첨부 — 스캔 원본+주석 묶음도 여기로 연결 (스캔주석 기획서 8).
class MessageAttachment {
  const MessageAttachment({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.kind, // 'image' | 'file' | 'scan_annotation'
    this.annotationJsonUrl, // 스캔 주석: 재편집용 스트로크 JSON 위치
    this.previewUrl, // 평탄화 미리보기 PNG
  });

  final String id;
  final String fileName;
  final String fileUrl;
  final String kind;
  final String? annotationJsonUrl;
  final String? previewUrl;

  factory MessageAttachment.fromMap(Map<String, dynamic> m) => MessageAttachment(
        id: m['id'] as String,
        fileName: (m['file_name'] as String?) ?? '첨부',
        fileUrl: (m['file_url'] as String?) ?? '',
        kind: (m['kind'] as String?) ?? 'file',
        annotationJsonUrl: m['annotation_json_url'] as String?,
        previewUrl: m['preview_url'] as String?,
      );
}

/// 연결노트 카테고리 — 잠금 (전체/멘토에게 요청/멘토가 요청/메모).
enum NoteCategory { requestToMentor, requestedByMentor, memo }

NoteCategory noteCategoryFromString(String? v) => switch (v) {
      'requestToMentor' || 'request_to_mentor' => NoteCategory.requestToMentor,
      'requestedByMentor' ||
      'requested_by_mentor' =>
        NoteCategory.requestedByMentor,
      _ => NoteCategory.memo,
    };

extension NoteCategoryX on NoteCategory {
  String get label => switch (this) {
        NoteCategory.requestToMentor => '멘토에게 요청',
        NoteCategory.requestedByMentor => '멘토가 요청',
        NoteCategory.memo => '메모',
      };

  /// 9-1 단점 보완: 탭 의미를 한 줄로 노출.
  String get hint => switch (this) {
        NoteCategory.requestToMentor => '내가 멘토에게 부탁한 것',
        NoteCategory.requestedByMentor => '멘토가 나에게 요청한 것',
        NoteCategory.memo => '나만 보는/공유용 자유 메모',
      };

  /// DB 저장용 값.
  String get dbValue => switch (this) {
        NoteCategory.requestToMentor => 'request_to_mentor',
        NoteCategory.requestedByMentor => 'requested_by_mentor',
        NoteCategory.memo => 'memo',
      };
}

/// connection_notes — room 단위 공통 노트.
///
/// ★ 필기 리뉴얼 확장 (연결노트 기술기획서 5-1):
///   - hasInk           : 필기 포함 여부 (콘텐츠 유형)
///   - inkDataUrl       : 필기 원본 스트로크 JSON 위치 (Storage)
///   - inkThumbnailUrl  : 목록용 축소 PNG 위치 (원본과 분리 저장)
///   기존 텍스트 본문(body)은 그대로 유지 — 검색·요약 대상.
class ConnectionNote {
  const ConnectionNote({
    required this.id,
    required this.roomId,
    required this.authorId,
    required this.authorRole,
    required this.category,
    required this.title,
    required this.body,
    this.hasInk = false,
    this.inkDataUrl,
    this.inkThumbnailUrl,
    this.status = 'active',
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String authorId;
  final String authorRole; // 'student' | 'mentor'
  final NoteCategory category;
  final String title;
  final String body;
  final bool hasInk;
  final String? inkDataUrl;
  final String? inkThumbnailUrl;
  final String status;
  final DateTime? updatedAt;

  factory ConnectionNote.fromMap(Map<String, dynamic> m) => ConnectionNote(
        id: m['id'] as String,
        roomId: (m['mentor_student_room_id'] as String?) ??
            (m['room_id'] as String?) ??
            '',
        authorId: (m['author_id'] as String?) ?? '',
        authorRole: (m['author_role'] as String?) ?? 'student',
        category: noteCategoryFromString(m['category'] as String?),
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        hasInk: (m['has_ink'] as bool?) ?? false,
        inkDataUrl:
            (m['ink_data_url'] as String?) ?? (m['ink_data'] as String?),
        inkThumbnailUrl: (m['ink_thumbnail_path'] as String?) ??
            (m['ink_thumbnail_url'] as String?),
        status: (m['status'] as String?) ?? 'active',
        updatedAt: _date(m['updated_at']),
      );

  bool get isMentorAuthored => authorRole == 'mentor';

  ConnectionNote copyWith({
    String? title,
    String? body,
    bool? hasInk,
    String? inkDataUrl,
    String? inkThumbnailUrl,
    NoteCategory? category,
  }) =>
      ConnectionNote(
        id: id,
        roomId: roomId,
        authorId: authorId,
        authorRole: authorRole,
        category: category ?? this.category,
        title: title ?? this.title,
        body: body ?? this.body,
        hasInk: hasInk ?? this.hasInk,
        inkDataUrl: inkDataUrl ?? this.inkDataUrl,
        inkThumbnailUrl: inkThumbnailUrl ?? this.inkThumbnailUrl,
        status: status,
        updatedAt: updatedAt,
      );
}

DateTime? _date(dynamic v) =>
    v is String ? DateTime.tryParse(v) : (v is DateTime ? v : null);

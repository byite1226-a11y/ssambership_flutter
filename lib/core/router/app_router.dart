import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/user.dart';
import '../../features/auth/providers/session.dart';
import '../../features/auth/screens/launch_screen.dart';
import '../../features/cash/screens/cash_screen.dart';
import '../../features/commission/screens/commission_screens.dart';
import '../../features/community/screens/community_screens.dart';
import '../../features/connection_note/screens/connection_note_editor_screen.dart';
import '../../features/mentor/screens/mentor_detail_screen.dart';
import '../../features/mentor/screens/mentor_screens.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/support/screens/support_screen.dart';
import '../../features/individual_question/screens/individual_question_screens.dart';
import '../models/individual_question.dart';
import '../../features/qna/screens/thread_detail_screen.dart';
import '../../features/scan_annotation/screens/scan_annotation_editor_screen.dart';
import '../../features/scan_annotation/screens/scan_entry_screen.dart';
import '../../features/shell/screens/app_shell.dart';
import '../../features/student/screens/student_screens.dart';
import '../../providers/repository_providers.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _studentShellKey = GlobalKey<NavigatorState>();
final _mentorShellKey = GlobalKey<NavigatorState>();

/// 앱 라우터.
///
/// Expo RootNavigator의 흐름을 미러링합니다: 미인증이면 진입 화면(/), 인증되면
/// 역할에 따라 학생/멘토 셸로. 질문방 상세·연결노트·스캔 첨삭은 셸 위에 전체화면
/// 으로 띄웁니다(parentNavigatorKey = 루트). 라이브 인증 연동 시 redirect만
/// Supabase 세션 기준으로 바꾸면 됩니다.
final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  refreshListenable: demoSession,
  redirect: (context, state) {
    final loggedIn = demoSession.isAuthenticated;
    final role = demoSession.role;
    final loc = state.matchedLocation;
    final inStudent = loc.startsWith('/student');
    final inMentor = loc.startsWith('/mentor');
    final inApp = inStudent || inMentor;
    // 데모 미리보기 경로는 인증 없이 허용.
    final isPublicDemo = loc.startsWith('/demo') || loc == '/annotate';
    if (!loggedIn && inApp) return '/';
    if (!loggedIn && isPublicDemo) return null;
    // 로그인 상태: 반대 역할 영역 접근 차단(보안/UX 기대치 정렬).
    if (loggedIn && inStudent && role == UserRole.mentor) return '/mentor/rooms';
    if (loggedIn && inMentor && role == UserRole.student) return '/student/rooms';
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (_, __) => const LaunchScreen()),

    // ---- 핵심 기능 데모 미리보기 (진입 화면에서 바로) ----
    GoRoute(
      path: '/demo/connection-note',
      builder: (_, __) => const ConnectionNoteEditorScreen(
        roomId: 'demo-room-1',
        authorRole: 'student',
      ),
    ),
    GoRoute(
      path: '/demo/scan-annotation',
      builder: (_, __) => const ScanEntryScreen(authorRole: 'student'),
    ),

    // ---- 알림 ----
    GoRoute(
      path: '/notifications',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const NotificationsScreen(),
    ),
    // ---- 고객지원 ----
    GoRoute(
      path: '/support',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const SupportScreen(),
    ),
    // ---- 개별 질문(공개/지정) ----
    GoRoute(
      path: '/student/individual-questions',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const StudentIndividualQuestionsScreen(),
    ),
    GoRoute(
      path: '/student/individual-questions/new',
      parentNavigatorKey: _rootKey,
      builder: (_, __) =>
          const IndividualQuestionComposeScreen(mode: IQType.open),
    ),
    GoRoute(
      path: '/student/individual-questions/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          IndividualQuestionDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/student/mentors/:id/individual-question/new',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final extra = state.extra;
        final name = (extra is Map && extra['name'] is String)
            ? extra['name'] as String
            : '멘토';
        return IndividualQuestionComposeScreen(
          mode: IQType.direct,
          mentorId: state.pathParameters['id']!,
          mentorName: name,
        );
      },
    ),
    GoRoute(
      path: '/mentor/individual-questions',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const MentorIndividualQuestionsScreen(),
    ),
    GoRoute(
      path: '/mentor/individual-questions/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          IndividualQuestionDetailScreen(id: state.pathParameters['id']!),
    ),
    // ---- 커뮤니티 상세/작성 (학생·멘토 공용, 풀스크린) ----
    GoRoute(
      path: '/community/new',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const CommunityComposeScreen(),
    ),
    GoRoute(
      path: '/community/post/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          CommunityPostDetailScreen(postId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/community/shortform/:id',
      parentNavigatorKey: _rootKey,
      builder: (_, state) =>
          ShortformDetailScreen(shortformId: state.pathParameters['id']!),
    ),
    // ---- 스캔 → 주석 에디터 (path + role 을 extra 로 전달) ----
    GoRoute(
      path: '/annotate',
      parentNavigatorKey: _rootKey,
      builder: (_, state) {
        final extra = (state.extra as Map?) ?? const {};
        final path = extra['path'] as String?;
        final role = (extra['role'] as String?) ?? 'student';
        final roomId = extra['roomId'] as String?;
        if (path == null) {
          return const _MissingImage();
        }
        return Consumer(
          builder: (context, ref, _) {
            return ScanAnnotationEditorScreen(
              image: scanImageFromPath(path),
              authorRole: role,
              title: role == 'mentor' ? '스캔 첨삭' : '스캔 첨삭 요청',
              // 방 맥락이면 저장 연결(원본 바이트 + 정규화 주석 + 미리보기).
              onSave: roomId == null
                  ? null
                  : (payload) async {
                      final bytes = await File(path).readAsBytes();
                      final authorId = demoSession.user?.id ?? '';
                      await ref
                          .read(scanAnnotationsRepositoryProvider)
                          .saveAnnotation(
                            roomId: roomId,
                            authorId: authorId,
                            authorRole: role,
                            originalImage: bytes,
                            annotationJson: payload.annotationJson,
                            previewPng: payload.flattenedPng,
                            hasAnnotations: payload.hasAnnotations,
                          );
                      ref.invalidate(scanAnnotationsProvider(roomId));
                    },
            );
          },
        );
      },
    ),

    // ---- 캐시/구독 (학생, 셸 위 전체화면) ----
    GoRoute(
      path: '/student/cash',
      parentNavigatorKey: _rootKey,
      builder: (_, __) => const CashScreen(),
    ),

    // ========================================================================
    // 학생 셸 — 멘토찾기 · 질문방 · 커뮤니티 · 맞춤의뢰 · 마이
    // ========================================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        navigationShell: shell,
        destinations: const [
          ShellDest(
              icon: Icons.search,
              selectedIcon: Icons.search,
              label: '멘토찾기'),
          ShellDest(
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum,
              label: '질문방'),
          ShellDest(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: '커뮤니티'),
          ShellDest(
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: '맞춤의뢰'),
          ShellDest(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: '마이'),
        ],
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/student/mentors',
            builder: (_, __) => const StudentMentorSearchScreen(),
            routes: [
              GoRoute(
                path: ':mentorId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => MentorDetailScreen(
                  mentorId: state.pathParameters['mentorId']!,
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(
          navigatorKey: _studentShellKey,
          routes: [
            GoRoute(
              path: '/student/rooms',
              builder: (_, __) => const StudentRoomListScreen(),
              routes: [
                GoRoute(
                  path: ':roomId',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => StudentRoomDetailScreen(
                    roomId: state.pathParameters['roomId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'note',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ConnectionNoteEditorScreen(
                        roomId: state.pathParameters['roomId']!,
                        authorRole: 'student',
                      ),
                    ),
                    GoRoute(
                      path: 'scan',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ScanEntryScreen(
                        authorRole: 'student',
                        roomId: state.pathParameters['roomId'],
                      ),
                    ),
                    GoRoute(
                      path: 'thread/:threadId',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ThreadDetailScreen(
                        threadId: state.pathParameters['threadId']!,
                        title:
                            (state.extra as Map?)?['title'] as String? ?? '질문',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/student/community',
            builder: (_, __) => const CommunityHomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/student/commission',
            builder: (_, __) => const StudentCommissionScreen(),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: _rootKey,
                builder: (_, __) => const CustomRequestComposeScreen(),
              ),
              GoRoute(
                path: 'order/:orderId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => OrderDetailScreen(
                  orderId: state.pathParameters['orderId']!,
                  viewerRole: 'student',
                ),
              ),
              GoRoute(
                path: ':postId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => CustomRequestDetailScreen(
                  postId: state.pathParameters['postId']!,
                  viewerRole: 'student',
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/student/me',
            builder: (_, __) => const StudentMeScreen(),
          ),
        ]),
      ],
    ),

    // ========================================================================
    // 멘토 셸 — 대시보드 · 질문방 · 맞춤의뢰 · 커뮤니티 · 캐시/정산
    // ========================================================================
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(
        navigationShell: shell,
        destinations: const [
          ShellDest(
              icon: Icons.dashboard_outlined,
              selectedIcon: Icons.dashboard,
              label: '대시보드'),
          ShellDest(
              icon: Icons.forum_outlined,
              selectedIcon: Icons.forum,
              label: '질문방'),
          ShellDest(
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: '맞춤의뢰'),
          ShellDest(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: '커뮤니티'),
          ShellDest(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet,
              label: '캐시'),
        ],
      ),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/mentor/dashboard',
            builder: (_, __) => const MentorDashboardScreen(),
          ),
        ]),
        StatefulShellBranch(
          navigatorKey: _mentorShellKey,
          routes: [
            GoRoute(
              path: '/mentor/rooms',
              builder: (_, __) => const MentorRoomListScreen(),
              routes: [
                GoRoute(
                  path: ':roomId',
                  parentNavigatorKey: _rootKey,
                  builder: (_, state) => MentorRoomDetailScreen(
                    roomId: state.pathParameters['roomId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'note',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ConnectionNoteEditorScreen(
                        roomId: state.pathParameters['roomId']!,
                        authorRole: 'mentor',
                      ),
                    ),
                    GoRoute(
                      path: 'scan',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ScanEntryScreen(
                        authorRole: 'mentor',
                        roomId: state.pathParameters['roomId'],
                      ),
                    ),
                    GoRoute(
                      path: 'thread/:threadId',
                      parentNavigatorKey: _rootKey,
                      builder: (_, state) => ThreadDetailScreen(
                        threadId: state.pathParameters['threadId']!,
                        title:
                            (state.extra as Map?)?['title'] as String? ?? '질문',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/mentor/commission',
            builder: (_, __) => const MentorCommissionScreen(),
            routes: [
              GoRoute(
                path: 'order/:orderId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => OrderDetailScreen(
                  orderId: state.pathParameters['orderId']!,
                  viewerRole: 'mentor',
                ),
              ),
              GoRoute(
                path: ':postId',
                parentNavigatorKey: _rootKey,
                builder: (_, state) => CustomRequestDetailScreen(
                  postId: state.pathParameters['postId']!,
                  viewerRole: 'mentor',
                ),
              ),
            ],
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/mentor/community',
            builder: (_, __) => const CommunityHomeScreen(),
          ),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/mentor/cash',
            builder: (_, __) => const MentorCashScreen(),
          ),
        ]),
      ],
    ),
  ],
);

class _MissingImage extends StatelessWidget {
  const _MissingImage();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('이미지를 찾을 수 없어요')),
      );
}

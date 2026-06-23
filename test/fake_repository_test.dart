import 'package:flutter_test/flutter_test.dart';
import 'package:ssambership/core/models/user.dart';
import 'package:ssambership/data/repositories/fake/demo_store.dart';
import 'package:ssambership/data/repositories/fake/fake_community_repository.dart';
import 'package:ssambership/data/repositories/fake/fake_mentors_repository.dart';

/// 더미 데이터 계층의 핵심 상태 전이 회귀 검증.
void main() {
  test('구독하면 캐시가 요금만큼 차감되고 방 id가 생성된다', () async {
    final store = DemoStore.instance;
    store.ensureSeed();
    final before = store.walletCents;

    final repo = FakeMentorsRepository();
    final res = await repo.subscribe(
      mentorId: 'test-mentor-unit',
      mentorName: '단위테스트 멘토',
      plan: PlanType.limited,
    );

    final cost = PlanInfo.all[PlanType.limited]!.priceCash * 100;
    expect(res.roomId, isNotEmpty);
    expect(store.walletCents, before - cost);
  });

  test('커뮤니티 글 작성과 좋아요 토글이 일관되게 반영된다', () async {
    final repo = FakeCommunityRepository();

    final created = await repo.createPost(title: '단위테스트', body: '본문');
    final posts = await repo.fetchPosts();
    expect(posts.any((p) => p.id == created.id), isTrue);

    final before = (await repo.fetchPost(created.id))!;
    final liked =
        await repo.toggleLike(postId: created.id, postType: 'board');
    expect(liked, isTrue);

    final after = (await repo.fetchPost(created.id))!;
    expect(after.liked, isTrue);
    expect(after.likeCount, before.likeCount + 1);

    final unliked =
        await repo.toggleLike(postId: created.id, postType: 'board');
    expect(unliked, isFalse);
  });
}

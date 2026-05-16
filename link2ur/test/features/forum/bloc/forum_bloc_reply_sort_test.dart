// mocktail 的 when()/verify() 必须显式写出与生产代码相同的 named args,
// 即便值等于默认值; 否则匹配失败. 这里整体关闭这条 lint.
// ignore_for_file: avoid_redundant_argument_values

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/data/models/forum.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/features/forum/bloc/forum_bloc.dart';

class MockForumRepository extends Mock implements ForumRepository {}

ForumReply _reply(int id, {int? parentReplyId, int postId = 1}) => ForumReply(
      id: id,
      postId: postId,
      content: 'reply $id',
      authorId: 'u$id',
      parentReplyId: parentReplyId,
    );

void main() {
  late MockForumRepository repo;

  setUp(() {
    repo = MockForumRepository();
  });

  // ==================== ForumLoadMoreChildren ====================

  group('ForumBloc - ForumLoadMoreChildren', () {
    blocTest<ForumBloc, ForumState>(
      '首次展开 root=10: offset=3 (跳过 preview), 追加 children + 更新 hasMore/nextOffset',
      build: () {
        when(() => repo.getReplyChildren(10, offset: 3)).thenAnswer(
          (_) async => ForumReplyChildrenPage(
            replies: [_reply(101, parentReplyId: 10), _reply(102, parentReplyId: 10)],
            hasMore: true,
            nextOffset: 8,
          ),
        );
        return ForumBloc(forumRepository: repo);
      },
      act: (bloc) => bloc.add(const ForumLoadMoreChildren(10)),
      expect: () => [
        // 1. 标记 loading
        isA<ForumState>().having(
          (s) => s.loadingChildrenRoots.contains(10),
          'loading set contains 10',
          true,
        ),
        // 2. 加载完成: children/hasMore/nextOffset 更新, loading 移除
        isA<ForumState>()
            .having((s) => s.loadedChildren[10]?.length, 'children count', 2)
            .having((s) => s.loadedChildren[10]?.first.id, 'first child id', 101)
            .having((s) => s.hasMoreChildren[10], 'hasMore', true)
            .having((s) => s.nextChildOffset[10], 'nextOffset', 8)
            .having(
              (s) => s.loadingChildrenRoots.contains(10),
              'no longer loading',
              false,
            ),
      ],
      verify: (_) {
        verify(() => repo.getReplyChildren(10, offset: 3)).called(1);
      },
    );

    blocTest<ForumBloc, ForumState>(
      '第二次加载使用上次返回的 nextOffset, 已存在的 id 被去重',
      build: () {
        when(() => repo.getReplyChildren(10, offset: 8)).thenAnswer(
          (_) async => ForumReplyChildrenPage(
            replies: [
              _reply(102, parentReplyId: 10), // 重复, 应被去重
              _reply(103, parentReplyId: 10),
            ],
            hasMore: false,
            nextOffset: 10,
          ),
        );
        return ForumBloc(forumRepository: repo);
      },
      seed: () => ForumState(
        loadedChildren: {
          10: [_reply(101, parentReplyId: 10), _reply(102, parentReplyId: 10)],
        },
        hasMoreChildren: const {10: true},
        nextChildOffset: const {10: 8},
      ),
      act: (bloc) => bloc.add(const ForumLoadMoreChildren(10)),
      expect: () => [
        isA<ForumState>().having(
          (s) => s.loadingChildrenRoots.contains(10),
          'loading',
          true,
        ),
        isA<ForumState>()
            .having((s) => s.loadedChildren[10]?.length, 'children count', 3)
            .having((s) => s.loadedChildren[10]?.last.id, 'last child id', 103)
            .having((s) => s.hasMoreChildren[10], 'hasMore', false)
            .having((s) => s.nextChildOffset[10], 'nextOffset', 10)
            .having(
              (s) => s.loadingChildrenRoots.contains(10),
              'no longer loading',
              false,
            ),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      '正在加载中再次触发: 不发起请求, 不 emit',
      build: () {
        when(() => repo.getReplyChildren(any(),
                offset: any(named: 'offset'), limit: any(named: 'limit')))
            .thenAnswer((_) async => const ForumReplyChildrenPage(
                  replies: [],
                  hasMore: false,
                  nextOffset: 3,
                ));
        return ForumBloc(forumRepository: repo);
      },
      seed: () => const ForumState(loadingChildrenRoots: {10}),
      act: (bloc) => bloc.add(const ForumLoadMoreChildren(10)),
      expect: () => [],
      verify: (_) {
        verifyNever(() => repo.getReplyChildren(any(),
            offset: any(named: 'offset'), limit: any(named: 'limit')));
      },
    );
  });

  // ==================== ForumReplySortChanged ====================

  group('ForumBloc - ForumReplySortChanged', () {
    blocTest<ForumBloc, ForumState>(
      '切换 sort -> 清空 children 缓存 -> 触发 ForumLoadReplies 用新 sort 拉根',
      build: () {
        when(() => repo.getPostReplies(1, sort: 'newest'))
            .thenAnswer((_) async => [_reply(1)]);
        return ForumBloc(forumRepository: repo);
      },
      seed: () => ForumState(
        // replySort: 'hot' 是默认值
        loadedChildren: {
          10: [_reply(101, parentReplyId: 10)],
        },
        hasMoreChildren: const {10: true},
        nextChildOffset: const {10: 5},
      ),
      act: (bloc) => bloc.add(const ForumReplySortChanged(1, 'newest')),
      expect: () => [
        // 1. 清空 children + 切 sort
        isA<ForumState>()
            .having((s) => s.replySort, 'replySort', 'newest')
            .having((s) => s.loadedChildren, 'loadedChildren', isEmpty)
            .having((s) => s.hasMoreChildren, 'hasMoreChildren', isEmpty)
            .having((s) => s.nextChildOffset, 'nextChildOffset', isEmpty),
        // 2. ForumLoadReplies 完成 -> 新 replies
        isA<ForumState>()
            .having((s) => s.replies.length, 'replies count', 1)
            .having((s) => s.replies.first.id, 'first reply id', 1),
      ],
      verify: (_) {
        verify(() => repo.getPostReplies(1, sort: 'newest')).called(1);
      },
    );

    blocTest<ForumBloc, ForumState>(
      'sort 没变化 -> 不 emit, 不重新拉根',
      build: () {
        when(() => repo.getPostReplies(any(), sort: any(named: 'sort')))
            .thenAnswer((_) async => []);
        return ForumBloc(forumRepository: repo);
      },
      // replySort 默认就是 'hot'
      seed: () => const ForumState(),
      act: (bloc) => bloc.add(const ForumReplySortChanged(1, 'hot')),
      expect: () => [],
      verify: (_) {
        verifyNever(
            () => repo.getPostReplies(any(), sort: any(named: 'sort')));
      },
    );
  });

  // ==================== ForumLoadReplies (new signature) ====================

  group('ForumBloc - ForumLoadReplies (sort-aware)', () {
    blocTest<ForumBloc, ForumState>(
      '使用 state.replySort 传给 repository',
      build: () {
        when(() => repo.getPostReplies(1, sort: 'hot'))
            .thenAnswer((_) async => [_reply(1), _reply(2)]);
        return ForumBloc(forumRepository: repo);
      },
      act: (bloc) => bloc.add(const ForumLoadReplies(1)),
      expect: () => [
        isA<ForumState>()
            .having((s) => s.replies.length, 'replies count', 2)
            .having((s) => s.repliesHasMore, 'repliesHasMore', false),
      ],
      verify: (_) {
        verify(() => repo.getPostReplies(1, sort: 'hot')).called(1);
      },
    );
  });
}

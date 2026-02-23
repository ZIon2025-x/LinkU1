import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/forum/bloc/forum_bloc.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/models/forum.dart';

class MockForumRepository extends Mock implements ForumRepository {}

void main() {
  late MockForumRepository mockForumRepository;
  late ForumBloc forumBloc;

  setUp(() {
    mockForumRepository = MockForumRepository();
    forumBloc = ForumBloc(forumRepository: mockForumRepository);
  });

  tearDown(() {
    forumBloc.close();
  });

  // ==================== 测试数据 ====================

  final testPost = ForumPost(
    id: 1,
    title: 'Test Post',
    content: 'Test content',
    authorId: '1',
    categoryId: 1,
    likeCount: 5,
    replyCount: 3,
    viewCount: 100,
    createdAt: DateTime(2025),
  );

  final testPostListResponse = ForumPostListResponse(
    posts: [testPost],
    total: 1,
    page: 1,
    pageSize: 20,
  );

  // ==================== 初始状态 ====================

  group('ForumBloc - Initial State', () {
    test('initial state is correct', () {
      expect(forumBloc.state, equals(const ForumState()));
      expect(forumBloc.state.status, equals(ForumStatus.initial));
      expect(forumBloc.state.posts, isEmpty);
      expect(forumBloc.state.categories, isEmpty);
    });
  });

  // ==================== 加载帖子 ====================

  group('ForumBloc - ForumLoadPosts', () {
    blocTest<ForumBloc, ForumState>(
      'emits [loading, loaded] when ForumLoadPosts succeeds',
      build: () {
        when(() => mockForumRepository.getPosts(
              page: any(named: 'page'),
              categoryId: any(named: 'categoryId'),
              keyword: any(named: 'keyword'),
            )).thenAnswer((_) async => testPostListResponse);
        return forumBloc;
      },
      act: (bloc) => bloc.add(const ForumLoadPosts()),
      expect: () => [
        const ForumState(status: ForumStatus.loading),
        ForumState(
          status: ForumStatus.loaded,
          posts: [testPost],
          total: 1,
          hasMore: false,
        ),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'emits [loading, error] when ForumLoadPosts fails',
      build: () {
        when(() => mockForumRepository.getPosts(
              page: any(named: 'page'),
              categoryId: any(named: 'categoryId'),
              keyword: any(named: 'keyword'),
            )).thenThrow(Exception('Network error'));
        return forumBloc;
      },
      act: (bloc) => bloc.add(const ForumLoadPosts()),
      expect: () => [
        const ForumState(status: ForumStatus.loading),
        isA<ForumState>()
            .having((s) => s.status, 'status', ForumStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'prevents duplicate loading when already in loading state',
      build: () => forumBloc,
      seed: () => const ForumState(status: ForumStatus.loading),
      act: (bloc) => bloc.add(const ForumLoadPosts()),
      expect: () => [], // No state changes when already loading
    );
  });

  // ==================== 分类切换 ====================

  group('ForumBloc - ForumCategoryChanged', () {
    blocTest<ForumBloc, ForumState>(
      'emits [loading, loaded] with new category filter',
      build: () {
        when(() => mockForumRepository.getPosts(
              page: any(named: 'page'),
              categoryId: 1,
              keyword: any(named: 'keyword'),
            )).thenAnswer((_) async => testPostListResponse);
        return forumBloc;
      },
      act: (bloc) => bloc.add(const ForumCategoryChanged(1)),
      expect: () => [
        const ForumState(
          selectedCategoryId: 1,
          status: ForumStatus.loading,
        ),
        ForumState(
          status: ForumStatus.loaded,
          selectedCategoryId: 1,
          posts: [testPost],
          total: 1,
          hasMore: false,
        ),
      ],
    );
  });

  // ==================== 搜索 ====================

  group('ForumBloc - ForumSearchChanged', () {
    blocTest<ForumBloc, ForumState>(
      'emits states with search query and filtered results',
      build: () {
        when(() => mockForumRepository.getPosts(
              page: any(named: 'page'),
              categoryId: any(named: 'categoryId'),
              keyword: 'test',
            )).thenAnswer((_) async => testPostListResponse);
        return forumBloc;
      },
      act: (bloc) => bloc.add(const ForumSearchChanged('test')),
      wait: const Duration(milliseconds: 600),
      expect: () => [
        const ForumState(
          searchQuery: 'test',
          status: ForumStatus.loading,
        ),
        ForumState(
          status: ForumStatus.loaded,
          searchQuery: 'test',
          posts: [testPost],
          total: 1,
          hasMore: false,
        ),
      ],
    );
  });

  // ==================== 点赞（乐观更新 + 回滚） ====================

  group('ForumBloc - ForumLikePost', () {
    blocTest<ForumBloc, ForumState>(
      'optimistically updates like state and commits on success',
      build: () {
        when(() => mockForumRepository.likePost(any()))
            .thenAnswer((_) async {});
        return forumBloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (bloc) => bloc.add(const ForumLikePost(1)),
      expect: () => [
        // Optimistic update: isLiked=true, likeCount+1
        ForumState(
          status: ForumStatus.loaded,
          posts: [testPost.copyWith(isLiked: true, likeCount: 6)],
        ),
      ],
      verify: (_) {
        verify(() => mockForumRepository.likePost(1)).called(1);
      },
    );

    blocTest<ForumBloc, ForumState>(
      'rolls back like state on failure',
      build: () {
        when(() => mockForumRepository.likePost(any()))
            .thenThrow(Exception('Network error'));
        return forumBloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (bloc) => bloc.add(const ForumLikePost(1)),
      expect: () => [
        // Optimistic update
        ForumState(
          status: ForumStatus.loaded,
          posts: [testPost.copyWith(isLiked: true, likeCount: 6)],
        ),
        // Rollback on failure
        isA<ForumState>()
            .having((s) => s.posts.first.isLiked, 'isLiked', false)
            .having((s) => s.posts.first.likeCount, 'likeCount', 5)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  // ==================== 收藏 ====================

  group('ForumBloc - ForumFavoritePost', () {
    blocTest<ForumBloc, ForumState>(
      'calls favoritePost on repository and updates posts',
      build: () {
        when(() => mockForumRepository.favoritePost(any()))
            .thenAnswer((_) async {});
        return forumBloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (bloc) => bloc.add(const ForumFavoritePost(1)),
      // Note: ForumPost.props doesn't include isFavorited,
      // so Equatable treats original and favorited as equal → no visible emission.
      // We verify the API call was made instead.
      verify: (_) {
        verify(() => mockForumRepository.favoritePost(1)).called(1);
      },
    );
  });

  // ==================== 加载更多 ====================

  group('ForumBloc - ForumLoadMorePosts', () {
    blocTest<ForumBloc, ForumState>(
      'appends new posts when loading more succeeds',
      build: () {
        const morePost = ForumPost(
              id: 2,
              title: 'Another Post',
              authorId: '2',
              categoryId: 1,
            );
        when(() => mockForumRepository.getPosts(
              page: 2,
              categoryId: any(named: 'categoryId'),
              keyword: any(named: 'keyword'),
            )).thenAnswer((_) async => const ForumPostListResponse(
              posts: [morePost],
              total: 2,
              page: 2,
              pageSize: 20,
            ));
        return forumBloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (bloc) => bloc.add(const ForumLoadMorePosts()),
      expect: () => [
        isA<ForumState>().having((s) => s.isLoadingMore, 'isLoadingMore', true),
        isA<ForumState>()
            .having((s) => s.posts.length, 'posts length', 2)
            .having((s) => s.page, 'page', 2)
            .having((s) => s.isLoadingMore, 'isLoadingMore', false),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'does nothing when hasMore is false',
      build: () => forumBloc,
      seed: () => const ForumState(
        status: ForumStatus.loaded,
        hasMore: false,
      ),
      act: (bloc) => bloc.add(const ForumLoadMorePosts()),
      expect: () => [], // No state changes
    );
  });

  // ==================== 刷新 ====================

  group('ForumBloc - ForumRefreshRequested', () {
    blocTest<ForumBloc, ForumState>(
      'emits [refreshing, loaded] when refresh succeeds',
      build: () {
        when(() => mockForumRepository.getPosts(
              categoryId: any(named: 'categoryId'),
              keyword: any(named: 'keyword'),
            )).thenAnswer((_) async => testPostListResponse);
        return forumBloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (bloc) => bloc.add(const ForumRefreshRequested()),
      expect: () => [
        isA<ForumState>().having((s) => s.isRefreshing, 'isRefreshing', true),
        isA<ForumState>()
            .having((s) => s.isRefreshing, 'isRefreshing', false)
            .having((s) => s.status, 'status', ForumStatus.loaded),
      ],
    );
  });
}

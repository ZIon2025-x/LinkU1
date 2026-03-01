import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/forum/bloc/forum_bloc.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/models/forum.dart';

class MockForumRepository extends Mock implements ForumRepository {}

void main() {
  late MockForumRepository mockRepo;
  late ForumBloc bloc;

  const testAttachment = ForumPostAttachment(
    url: 'https://example.com/test.pdf',
    filename: 'test.pdf',
    size: 1024,
    contentType: 'application/pdf',
  );

  final testPost = ForumPost(
    id: 1,
    title: 'Test Post',
    content: 'Test content',
    authorId: '1',
    categoryId: 1,
    createdAt: DateTime(2025),
  );

  final testPostWithPdf = ForumPost(
    id: 1,
    title: 'Test Post',
    content: 'Test content',
    authorId: '1',
    categoryId: 1,
    attachments: const [testAttachment],
    createdAt: DateTime(2025),
  );

  final updatedPost = ForumPost(
    id: 1,
    title: 'Updated Title',
    content: 'Test content',
    authorId: '1',
    categoryId: 1,
    createdAt: DateTime(2025),
  );

  const createRequest = CreatePostRequest(
    title: 'New Post',
    content: 'New content',
    categoryId: 1,
  );

  const createRequestWithPdf = CreatePostRequest(
    title: 'Post with PDF',
    content: 'Has a PDF',
    categoryId: 1,
    attachments: [testAttachment],
  );

  setUp(() {
    mockRepo = MockForumRepository();
    bloc = ForumBloc(forumRepository: mockRepo);
  });

  tearDown(() => bloc.close());

  setUpAll(() {
    registerFallbackValue(createRequest);
  });

  group('ForumCreatePost', () {
    blocTest<ForumBloc, ForumState>(
      'emits [creating, created] on success',
      build: () {
        when(() => mockRepo.createPost(any()))
            .thenAnswer((_) async => testPost);
        return bloc;
      },
      act: (b) => b.add(const ForumCreatePost(createRequest)),
      expect: () => [
        const ForumState(isCreatingPost: true),
        ForumState(posts: [testPost]),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'emits error when create fails',
      build: () {
        when(() => mockRepo.createPost(any()))
            .thenThrow(Exception('Server error'));
        return bloc;
      },
      act: (b) => b.add(const ForumCreatePost(createRequest)),
      expect: () => [
        const ForumState(isCreatingPost: true),
        isA<ForumState>()
            .having((s) => s.isCreatingPost, 'isCreatingPost', false)
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );

    blocTest<ForumBloc, ForumState>(
      'creates post with PDF attachment - passes attachment to repo',
      build: () {
        when(() => mockRepo.createPost(any()))
            .thenAnswer((_) async => testPostWithPdf);
        return bloc;
      },
      act: (b) => b.add(const ForumCreatePost(createRequestWithPdf)),
      expect: () => [
        const ForumState(isCreatingPost: true),
        ForumState(posts: [testPostWithPdf]),
      ],
      verify: (_) {
        final captured =
            verify(() => mockRepo.createPost(captureAny())).captured.single
                as CreatePostRequest;
        expect(captured.attachments, hasLength(1));
        expect(captured.attachments.first.filename, 'test.pdf');
        expect(captured.attachments.first.contentType, 'application/pdf');
      },
    );
  });

  group('ForumEditPost', () {
    blocTest<ForumBloc, ForumState>(
      'updates post title via repository',
      build: () {
        when(() => mockRepo.updatePost(any(), any()))
            .thenAnswer((_) async => updatedPost);
        return bloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
        selectedPost: testPost,
      ),
      act: (b) => b.add(const ForumEditPost(1, title: 'Updated Title')),
      expect: () => [
        isA<ForumState>()
            .having((s) => s.posts.first.title, 'title', 'Updated Title')
            .having((s) => s.selectedPost?.title, 'selectedPost.title', 'Updated Title'),
      ],
      verify: (_) {
        final captured =
            verify(() => mockRepo.updatePost(1, captureAny())).captured.single
                as Map<String, dynamic>;
        expect(captured, containsPair('title', 'Updated Title'));
        expect(captured, isNot(contains('content')));
        expect(captured, isNot(contains('images')));
      },
    );

    blocTest<ForumBloc, ForumState>(
      'sends attachment data to repository when adding PDF',
      build: () {
        // Return post with different title so Equatable detects a change
        when(() => mockRepo.updatePost(any(), any()))
            .thenAnswer((_) async => ForumPost(
                  id: 1,
                  title: 'Updated',
                  content: 'Test content',
                  authorId: '1',
                  categoryId: 1,
                  attachments: const [testAttachment],
                  createdAt: DateTime(2025),
                ));
        return bloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
        selectedPost: testPost,
      ),
      act: (b) => b.add(const ForumEditPost(1, attachments: [testAttachment])),
      verify: (_) {
        final captured =
            verify(() => mockRepo.updatePost(1, captureAny())).captured.single
                as Map<String, dynamic>;
        expect(captured['attachments'], isList);
        expect(captured['attachments'], hasLength(1));
      },
    );

    blocTest<ForumBloc, ForumState>(
      'sends empty attachment list to repository when removing PDF',
      build: () {
        when(() => mockRepo.updatePost(any(), any()))
            .thenAnswer((_) async => ForumPost(
                  id: 1,
                  title: 'Cleared',
                  content: 'Test content',
                  authorId: '1',
                  categoryId: 1,
                  createdAt: DateTime(2025),
                ));
        return bloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPostWithPdf],
        selectedPost: testPostWithPdf,
      ),
      act: (b) => b.add(const ForumEditPost(1, attachments: [])),
      verify: (_) {
        final captured =
            verify(() => mockRepo.updatePost(1, captureAny())).captured.single
                as Map<String, dynamic>;
        expect(captured['attachments'], isEmpty);
      },
    );

    blocTest<ForumBloc, ForumState>(
      'does nothing when all fields are null',
      build: () => bloc,
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (b) => b.add(const ForumEditPost(1)),
      expect: () => [],
    );

    blocTest<ForumBloc, ForumState>(
      'emits error when edit fails',
      build: () {
        when(() => mockRepo.updatePost(any(), any()))
            .thenThrow(Exception('Forbidden'));
        return bloc;
      },
      seed: () => ForumState(
        status: ForumStatus.loaded,
        posts: [testPost],
      ),
      act: (b) => b.add(const ForumEditPost(1, title: 'X')),
      expect: () => [
        isA<ForumState>()
            .having((s) => s.errorMessage, 'errorMessage', isNotNull),
      ],
    );
  });

  group('ForumPostAttachment model', () {
    test('fromJson parses correctly', () {
      final json = {
        'url': 'https://example.com/doc.pdf',
        'filename': 'doc.pdf',
        'size': 2048,
        'content_type': 'application/pdf',
      };
      final att = ForumPostAttachment.fromJson(json);
      expect(att.url, 'https://example.com/doc.pdf');
      expect(att.filename, 'doc.pdf');
      expect(att.size, 2048);
      expect(att.contentType, 'application/pdf');
    });

    test('toJson produces correct map', () {
      final json = testAttachment.toJson();
      expect(json['url'], testAttachment.url);
      expect(json['filename'], testAttachment.filename);
      expect(json['size'], testAttachment.size);
      expect(json['content_type'], testAttachment.contentType);
    });

    test('isPdf detects PDF by content type', () {
      expect(testAttachment.isPdf, isTrue);
      const docAtt = ForumPostAttachment(
        url: 'https://x.com/a.docx',
        filename: 'a.docx',
        size: 100,
        contentType: 'application/msword',
      );
      expect(docAtt.isPdf, isFalse);
    });

    test('formattedSize formats bytes correctly', () {
      const tiny = ForumPostAttachment(
          url: '', filename: '', size: 512);
      expect(tiny.formattedSize, equals('512 B'));

      const small = ForumPostAttachment(
          url: '', filename: '', size: 2048);
      expect(small.formattedSize, contains('KB'));

      const large = ForumPostAttachment(
          url: '', filename: '', size: 2 * 1024 * 1024);
      expect(large.formattedSize, contains('MB'));
    });

    test('Equatable equality', () {
      const a = ForumPostAttachment(
        url: 'u',
        filename: 'f',
        size: 1,
        contentType: 'application/pdf',
      );
      const b = ForumPostAttachment(
        url: 'u',
        filename: 'f',
        size: 1,
        contentType: 'application/pdf',
      );
      expect(a, equals(b));
    });
  });

  group('CreatePostRequest.toJson', () {
    test('omits empty images and attachments', () {
      final json = createRequest.toJson();
      expect(json, isNot(contains('images')));
      expect(json, isNot(contains('attachments')));
    });

    test('includes non-empty attachments', () {
      final json = createRequestWithPdf.toJson();
      expect(json['attachments'], isList);
      expect(json['attachments'], hasLength(1));
    });
  });
}

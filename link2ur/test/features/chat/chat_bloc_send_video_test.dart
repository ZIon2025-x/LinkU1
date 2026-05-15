import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/message.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/features/chat/bloc/chat_bloc.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepo extends Mock implements MessageRepository {}

void main() {
  late _MockRepo repo;
  final videoBytes = Uint8List.fromList(List.filled(100, 0));
  final thumbBytes = Uint8List.fromList(List.filled(50, 0));

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockRepo();
  });

  group('ChatSendVideo', () {
    blocTest<ChatBloc, ChatState>(
      '上传视频+缩略图 → 发消息 → 用真实消息替换 pending',
      build: () {
        when(() => repo.uploadChatVideo(any(), any(), any())).thenAnswer(
          (_) async => (
            url: 'signed-v',
            blobId: 'v_blob',
            size: 8000000,
            originalName: 'v.mp4',
          ),
        );
        // 缩略图走既有 uploadImage(私密图片)
        when(() => repo.uploadImage(any(), any()))
            .thenAnswer((_) async => 'thumb_url');
        when(() => repo.sendTaskChatMessage(
              any(),
              content: any(named: 'content'),
              messageType: any(named: 'messageType'),
              attachments: any(named: 'attachments'),
            )).thenAnswer((_) async => const Message(
              id: 999,
              senderId: 'u1',
              content: '[视频]',
              messageType: 'video',
            ));
        return ChatBloc(messageRepository: repo);
      },
      seed: () => const ChatState(taskId: 1, userId: 'u1'),
      act: (bloc) => bloc.add(ChatSendVideo(
        videoBytes: videoBytes,
        videoFilename: 'v.mp4',
        videoDurationMs: 28000,
        videoWidth: 1080,
        videoHeight: 1920,
        thumbnailBytes: thumbBytes,
        thumbnailFilename: 'v_thumb.jpg',
        senderId: 'u1',
      )),
      verify: (_) {
        verify(() => repo.uploadChatVideo(videoBytes, 'v.mp4', 1)).called(1);
        verify(() => repo.uploadImage(thumbBytes, 'v_thumb.jpg')).called(1);
        // sendTaskChatMessage 接收 2 个 attachment(video + image-thumbnail)
        final captured = verify(() => repo.sendTaskChatMessage(
              1,
              content: '[视频]',
              messageType: 'video',
              attachments: captureAny(named: 'attachments'),
            )).captured.single as List<Map<String, dynamic>>;
        expect(captured.length, 2);
        expect(captured[0]['attachment_type'], 'video');
        expect(captured[0]['blob_id'], 'v_blob');
        expect(captured[1]['attachment_type'], 'image');
        expect((captured[1]['meta'] as Map)['role'], 'thumbnail');
      },
    );

    blocTest<ChatBloc, ChatState>(
      '上传视频失败 → 发出 chat_upload_failed 错误',
      build: () {
        when(() => repo.uploadChatVideo(any(), any(), any())).thenThrow(
          const MessageException('chat_upload_failed', code: 'chat_upload_failed'),
        );
        when(() => repo.uploadImage(any(), any()))
            .thenAnswer((_) async => 'thumb_url');
        return ChatBloc(messageRepository: repo);
      },
      seed: () => const ChatState(taskId: 1, userId: 'u1'),
      act: (bloc) => bloc.add(ChatSendVideo(
        videoBytes: videoBytes,
        videoFilename: 'v.mp4',
        videoDurationMs: 28000,
        videoWidth: 1080,
        videoHeight: 1920,
        thumbnailBytes: thumbBytes,
        thumbnailFilename: 'v_thumb.jpg',
      )),
      expect: () => [
        isA<ChatState>().having((s) => s.isSending, 'isSending', true),
        isA<ChatState>()
            .having((s) => s.isSending, 'isSending', false)
            .having((s) => s.errorMessage, 'errorMessage', 'chat_upload_failed'),
      ],
    );
  });
}

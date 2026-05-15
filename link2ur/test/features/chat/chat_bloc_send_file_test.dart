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
  final pdfBytes = Uint8List.fromList(
      [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]);

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = _MockRepo();
  });

  blocTest<ChatBloc, ChatState>(
    'ChatSendFile 上传 PDF → 发消息 → 替换 pending',
    build: () {
      when(() => repo.uploadChatPdf(any(), any(), any())).thenAnswer(
        (_) async => (
          url: 'signed-p',
          blobId: 'p_blob',
          size: 5000,
          originalName: 'report.pdf',
        ),
      );
      when(() => repo.sendTaskChatMessage(
            any(),
            content: any(named: 'content'),
            messageType: any(named: 'messageType'),
            attachments: any(named: 'attachments'),
          )).thenAnswer((_) async => const Message(
            id: 1001,
            senderId: 'u1',
            content: '[文件:report.pdf]',
            messageType: 'file',
          ));
      return ChatBloc(messageRepository: repo);
    },
    seed: () => const ChatState(taskId: 1, userId: 'u1'),
    act: (bloc) => bloc.add(ChatSendFile(
      bytes: pdfBytes,
      filename: 'report.pdf',
      contentType: 'application/pdf',
      senderId: 'u1',
    )),
    verify: (_) {
      verify(() => repo.uploadChatPdf(pdfBytes, 'report.pdf', 1)).called(1);
      final captured = verify(() => repo.sendTaskChatMessage(
            1,
            content: '[文件:report.pdf]',
            messageType: 'file',
            attachments: captureAny(named: 'attachments'),
          )).captured.single as List<Map<String, dynamic>>;
      expect(captured.length, 1);
      expect(captured[0]['attachment_type'], 'file');
      expect(captured[0]['blob_id'], 'p_blob');
      expect(captured[0]['meta']['original_filename'], 'report.pdf');
      expect(captured[0]['meta']['content_type'], 'application/pdf');
    },
  );
}

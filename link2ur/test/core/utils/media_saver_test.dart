import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/core/utils/media_saver.dart';

void main() {
  group('MediaSaver', () {
    late _FakeGal fakeGal;

    setUp(() {
      fakeGal = _FakeGal();
    });

    test('权限通过 + 写入成功 → 返回 success', () async {
      fakeGal.hasAccessReturn = true;
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.success);
      expect(fakeGal.putVideoCalled, true);
    });

    test('权限缺失 + 请求被拒 → permissionDenied', () async {
      fakeGal.hasAccessReturn = false;
      fakeGal.requestAccessReturn = false;
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.permissionDenied);
      expect(fakeGal.putVideoCalled, false);
    });

    test('写入抛异常 → failed', () async {
      fakeGal.hasAccessReturn = true;
      fakeGal.putVideoThrows = Exception('disk full');
      final result = await MediaSaver.saveVideo('/tmp/v.mp4', galClient: fakeGal);
      expect(result, SaveResult.failed);
    });
  });
}

class _FakeGal implements GalClient {
  bool hasAccessReturn = true;
  bool requestAccessReturn = false;
  Object? putVideoThrows;
  bool putVideoCalled = false;
  bool putImageCalled = false;

  @override
  Future<bool> hasAccess({bool toAlbum = false}) async => hasAccessReturn;

  @override
  Future<bool> requestAccess({bool toAlbum = false}) async => requestAccessReturn;

  @override
  Future<void> putVideo(String path) async {
    putVideoCalled = true;
    if (putVideoThrows != null) throw putVideoThrows!;
  }

  @override
  Future<void> putImageBytes(List<int> bytes) async {
    putImageCalled = true;
  }
}

import 'package:nextcue/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MediaItem model', () {
    test('serializes and deserializes video item correctly', () {
      const item = MediaItem(
        id: 'test-video-id',
        filePath: '/path/to/media.mp4',
        type: MediaType.video,
        thumbnailPath: '/path/to/media_thumb.jpg',
      );

      final json = item.toJson();
      expect(json['id'], 'test-video-id');
      expect(json['filePath'], '/path/to/media.mp4');
      expect(json['type'], 'video');
      expect(json['imageDurationMs'], isNull);
      expect(json['thumbnailPath'], '/path/to/media_thumb.jpg');

      final deserialized = MediaItem.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.filePath, item.filePath);
      expect(deserialized.type, MediaType.video);
      expect(deserialized.isVideo, isTrue);
      expect(deserialized.isImage, isFalse);
      expect(deserialized.imageDuration, isNull);
      expect(deserialized.thumbnailPath, item.thumbnailPath);
      expect(deserialized, equals(item));
    });

    test('serializes and deserializes image item correctly', () {
      const item = MediaItem(
        id: 'test-image-id',
        filePath: '/path/to/stretch.jpg',
        type: MediaType.image,
        imageDuration: Duration(seconds: 15),
        thumbnailPath: '/path/to/stretch.jpg',
      );

      final json = item.toJson();
      expect(json['id'], 'test-image-id');
      expect(json['filePath'], '/path/to/stretch.jpg');
      expect(json['type'], 'image');
      expect(json['imageDurationMs'], 15000);

      final deserialized = MediaItem.fromJson(json);
      expect(deserialized.id, item.id);
      expect(deserialized.type, MediaType.image);
      expect(deserialized.isImage, isTrue);
      expect(deserialized.isVideo, isFalse);
      expect(deserialized.imageDuration, const Duration(seconds: 15));
      expect(deserialized, equals(item));
    });

    test('copyWith creates modified copy', () {
      const item = MediaItem(
        id: 'orig-id',
        filePath: '/path/orig.jpg',
        type: MediaType.image,
        imageDuration: Duration(seconds: 5),
      );

      final modified = item.copyWith(
        imageDuration: const Duration(seconds: 20),
      );

      expect(modified.id, 'orig-id');
      expect(modified.imageDuration, const Duration(seconds: 20));
      expect(item.imageDuration, const Duration(seconds: 5));
    });
  });
}

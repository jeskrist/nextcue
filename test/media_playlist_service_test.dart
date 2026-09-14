import 'dart:convert';
import 'dart:io';

import 'package:nextcue/models/media_item.dart';
import 'package:nextcue/services/media_playlist_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaPlaylistService', () {
    late MediaPlaylistService service;

    setUp(() {
      service = MediaPlaylistService();
    });

    test('detectMediaType detects videos correctly', () {
      expect(service.detectMediaType('/storage/media.mp4'), MediaType.video);
      expect(service.detectMediaType('video.MOV'), MediaType.video);
      expect(service.detectMediaType('exercise.MKV'), MediaType.video);
      expect(service.detectMediaType('clip.webm'), MediaType.video);
    });

    test('detectMediaType detects images correctly', () {
      expect(service.detectMediaType('/storage/plank.jpg'), MediaType.image);
      expect(service.detectMediaType('photo.png'), MediaType.image);
      expect(service.detectMediaType('guide.webp'), MediaType.image);
      expect(service.detectMediaType('chart.jpeg'), MediaType.image);
    });

    test('savePlaylist writes valid JSON to SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      const items = [
        MediaItem(
          id: 'item-1',
          filePath: '/test/video.mp4',
          type: MediaType.video,
        ),
        MediaItem(
          id: 'item-2',
          filePath: '/test/image.jpg',
          type: MediaType.image,
          imageDuration: Duration(seconds: 10),
        ),
      ];

      await service.savePlaylist(items);

      final saved = prefs.getString('nextcue_playlist');
      expect(saved, isNotNull);

      final decoded = jsonDecode(saved!) as List<dynamic>;
      expect(decoded.length, 2);
      expect(decoded[0]['id'], 'item-1');
      expect(decoded[0]['type'], 'video');
      expect(decoded[1]['id'], 'item-2');
      expect(decoded[1]['imageDurationMs'], 10000);
    });

    test('keepPlaybackProgress setting persists and loads correctly', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await service.getKeepPlaybackProgress(), isTrue);
      await service.setKeepPlaybackProgress(false);
      await service.savePlaybackProgress({
        'item-1': const Duration(seconds: 17),
        'item-2': const Duration(minutes: 1, seconds: 3),
      });

      expect(await service.getKeepPlaybackProgress(), isFalse);
      expect(await service.loadPlaybackProgress(), {
        'item-1': const Duration(seconds: 17),
        'item-2': const Duration(minutes: 1, seconds: 3),
      });
    });

    test('loadPlaylist rewrites legacy workout_media thumbnail paths', () async {
      final tempFile = File('${Directory.systemTemp.path}/test_migrated.mp4')
        ..createSync();
      addTearDown(() {
        if (tempFile.existsSync()) tempFile.deleteSync();
      });

      SharedPreferences.setMockInitialValues({
        'nextcue_playlist': jsonEncode([
          {
            'id': 'legacy-item',
            'filePath': tempFile.path,
            'type': 'video',
            'thumbnailPath': '/app/documents/workout_media/legacy-item_thumb.jpg',
          }
        ]),
      });

      final loaded = await service.loadPlaylist();
      expect(loaded.length, 1);
      expect(loaded.first.thumbnailPath, isNotNull);
      expect(loaded.first.thumbnailPath!.contains('/workout_media/'), isFalse);
      expect(loaded.first.thumbnailPath!.contains('/nextcue_media/'), isTrue);
    });
  });
}

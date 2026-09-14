import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

import '../models/media_item.dart';

class MediaPlaylistService {
  static const _playlistKey = 'nextcue_playlist';
  static const _legacyVideoKey = 'nextcue_video_path';
  static const _keepPlaybackProgressKey = 'nextcue_keep_playback_progress';
  static const _playbackProgressKey = 'nextcue_playback_progress';
  static const _uuid = Uuid();

  static const _videoExtensions = {
    '.mp4',
    '.mov',
    '.mkv',
    '.avi',
    '.webm',
    '.3gp',
    '.flv',
    '.m4v',
    '.wmv',
  };

  /// Returns the permanent folder where media thumbnails and cache are stored.
  /// Automatically migrates any legacy `workout_media` folder if found.
  Future<Directory> getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/nextcue_media');
    final legacyDir = Directory('${appDir.path}/workout_media');

    if (await legacyDir.exists()) {
      if (!await mediaDir.exists()) {
        try {
          await legacyDir.rename(mediaDir.path);
        } catch (_) {
          await mediaDir.create(recursive: true);
          await _copyDirectory(legacyDir, mediaDir);
          try {
            await legacyDir.delete(recursive: true);
          } catch (_) {}
        }
      } else {
        await _copyDirectory(legacyDir, mediaDir);
        try {
          await legacyDir.delete(recursive: true);
        } catch (_) {}
      }
    } else if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await for (final entity in source.list(recursive: false)) {
      if (entity is File) {
        final newPath = '${destination.path}/${entity.uri.pathSegments.last}';
        try {
          await entity.copy(newPath);
        } catch (_) {}
      }
    }
  }

  /// Loads the saved playlist.
  /// Filters out items whose files no longer exist on disk.
  /// Automatically migrates any legacy single-video path or thumbnail folder if present.
  Future<List<MediaItem>> loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_playlistKey);

    List<MediaItem> items = [];

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr) as List<dynamic>;
        items = decoded
            .map((e) => MediaItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        items = [];
      }
    } else {
      // Migrate legacy single video if it exists
      final legacyPath = prefs.getString(_legacyVideoKey);
      if (legacyPath != null && await File(legacyPath).exists()) {
        final id = _uuid.v4();
        items.add(
          MediaItem(
            id: id,
            filePath: legacyPath,
            type: MediaType.video,
          ),
        );
        await prefs.remove(_legacyVideoKey);
      }
    }

    // Check and migrate legacy thumbnail paths in items
    bool itemsMigrated = false;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.thumbnailPath != null &&
          item.thumbnailPath!.contains('/workout_media/')) {
        final updatedThumbnailPath = item.thumbnailPath!
            .replaceAll('/workout_media/', '/nextcue_media/');
        items[i] = item.copyWith(thumbnailPath: updatedThumbnailPath);
        itemsMigrated = true;
      }
    }

    // Verify files exist on disk; clean up orphaned thumbnails for stale entries
    final validItems = <MediaItem>[];
    for (final item in items) {
      if (await File(item.filePath).exists()) {
        validItems.add(item);
      } else {
        // Original file was deleted externally — clean up the thumbnail only
        await _deleteThumbnail(item);
      }
    }

    // If any items were removed due to missing files or paths migrated, update persistent storage
    if (validItems.length != items.length || jsonStr == null || itemsMigrated) {
      await savePlaylist(validItems);
    }

    return validItems;
  }

  /// Saves the ordered list of items to persistent storage.
  Future<void> savePlaylist(List<MediaItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => e.toJson()).toList();
    await prefs.setString(_playlistKey, jsonEncode(jsonList));
  }

  Future<bool> getKeepPlaybackProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepPlaybackProgressKey) ?? true;
  }

  Future<void> setKeepPlaybackProgress(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepPlaybackProgressKey, value);
  }

  Future<Map<String, Duration>> loadPlaybackProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_playbackProgressKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return decoded.map((key, value) {
        final ms = value is int ? value : int.tryParse(value.toString()) ?? 0;
        return MapEntry(key, Duration(milliseconds: ms));
      });
    } catch (_) {
      return {};
    }
  }

  Future<void> savePlaybackProgress(Map<String, Duration> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, int>{
      for (final entry in progress.entries) entry.key: entry.value.inMilliseconds,
    };
    await prefs.setString(_playbackProgressKey, jsonEncode(encoded));
  }

  Future<void> clearPlaybackProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playbackProgressKey);
  }

  /// Detects whether [sourcePath] is a video or image.
  MediaType detectMediaType(String sourcePath) {
    final dotIndex = sourcePath.lastIndexOf('.');
    if (dotIndex != -1) {
      final ext = sourcePath.substring(dotIndex).toLowerCase();
      if (_videoExtensions.contains(ext)) {
        return MediaType.video;
      }
    }
    return MediaType.image;
  }

  /// Registers a picked file into the playlist by referencing its original
  /// location. Only a thumbnail is written to app-private storage.
  /// The original file is never copied or moved.
  Future<MediaItem> importMediaFile(String sourcePath) async {
    final mediaDir = await getMediaDirectory();
    final id = _uuid.v4();

    final type = detectMediaType(sourcePath);
    String? thumbnailPath;
    Duration? imageDuration;

    if (type == MediaType.video) {
      try {
        final thumbFile = '${mediaDir.path}/${id}_thumb.jpg';
        final plugin = FcNativeVideoThumbnail();
        final success = await plugin.saveThumbnailToFile(
          srcFile: sourcePath,
          destFile: thumbFile,
          width: 300,
          height: 300,
          quality: 80,
        );
        if (success && await File(thumbFile).exists()) {
          thumbnailPath = thumbFile;
        }
      } catch (_) {
        // Thumbnail generation is best-effort
        thumbnailPath = null;
      }
    } else {
      // Images default to 5s duration; the original file doubles as the thumbnail
      imageDuration = const Duration(seconds: 5);
      thumbnailPath = sourcePath;
    }

    return MediaItem(
      id: id,
      filePath: sourcePath, // original location — no copy made
      type: type,
      imageDuration: imageDuration,
      thumbnailPath: thumbnailPath,
    );
  }

  /// Removes the cached thumbnail for [item] from app-private storage.
  /// The original media file is never touched.
  Future<void> deleteMediaFile(MediaItem item) async {
    await _deleteThumbnail(item);
  }

  /// Internal helper: deletes the thumbnail for [item] if it is stored inside
  /// the app's media directory (i.e. not the original file itself).
  Future<void> _deleteThumbnail(MediaItem item) async {
    if (item.thumbnailPath != null && item.thumbnailPath != item.filePath) {
      try {
        final thumb = File(item.thumbnailPath!);
        if (await thumb.exists()) {
          await thumb.delete();
        }
      } catch (_) {}
    }
  }

  /// Clears the entire playlist and deletes all stored media files.
  Future<void> clearPlaylist() async {
    final items = await loadPlaylist();
    for (final item in items) {
      await deleteMediaFile(item);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playlistKey);
  }
}

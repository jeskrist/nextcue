enum MediaType { video, image }

class MediaItem {
  final String id;
  final String filePath;
  final MediaType type;
  final Duration? imageDuration;
  final String? thumbnailPath;

  const MediaItem({
    required this.id,
    required this.filePath,
    required this.type,
    this.imageDuration,
    this.thumbnailPath,
  });

  bool get isVideo => type == MediaType.video;
  bool get isImage => type == MediaType.image;

  MediaItem copyWith({
    String? id,
    String? filePath,
    MediaType? type,
    Duration? imageDuration,
    String? thumbnailPath,
  }) {
    return MediaItem(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      type: type ?? this.type,
      imageDuration: imageDuration ?? this.imageDuration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'type': type.name,
      'imageDurationMs': imageDuration?.inMilliseconds,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'video';
    final type = typeStr == 'image' ? MediaType.image : MediaType.video;
    final durationMs = json['imageDurationMs'] as int?;

    return MediaItem(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      type: type,
      imageDuration: durationMs != null ? Duration(milliseconds: durationMs) : null,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          filePath == other.filePath &&
          type == other.type &&
          imageDuration == other.imageDuration &&
          thumbnailPath == other.thumbnailPath;

  @override
  int get hashCode =>
      id.hashCode ^
      filePath.hashCode ^
      type.hashCode ^
      imageDuration.hashCode ^
      thumbnailPath.hashCode;
}

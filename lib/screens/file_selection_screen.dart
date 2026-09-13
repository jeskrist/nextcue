import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/media_item.dart';
import '../services/media_playlist_service.dart';
import '../widgets/duration_picker_sheet.dart';
import 'playlist_player_screen.dart';

class FileSelectionScreen extends StatefulWidget {
  const FileSelectionScreen({super.key});

  @override
  State<FileSelectionScreen> createState() => _FileSelectionScreenState();
}

class _FileSelectionScreenState extends State<FileSelectionScreen> {
  final _service = MediaPlaylistService();
  List<MediaItem> _items = [];
  bool _loading = true;
  bool _importing = false;
  bool _isNavigating = false;
  double _horizontalDragDelta = 0;

  // Drag-reorder state
  int? _draggingIndex;
  int? _hoverIndex;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    final loaded = await _service.loadPlaylist();
    if (mounted) {
      setState(() {
        _items = loaded;
        _loading = false;
      });
    }
  }

  Future<void> _pickMediaFiles() async {
    if (_items.length >= 10) return;
    final remainingSlots = 10 - _items.length;

    setState(() => _importing = true);

    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.media,
      );

      if (pickedFiles.isNotEmpty) {
        final validPaths =
            pickedFiles.map((f) => f.path).whereType<String>().toList();

        if (validPaths.isNotEmpty) {
          final filesToImport = validPaths.take(remainingSlots).toList();
          if (validPaths.length > remainingSlots && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Only $remainingSlots more ${remainingSlots == 1 ? "file" : "files"} could be added (10 max).',
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }

          final newItems = <MediaItem>[];
          for (final path in filesToImport) {
            final item = await _service.importMediaFile(path);
            newItems.add(item);
          }

          if (mounted) {
            setState(() {
              _items.addAll(newItems);
            });
            await _service.savePlaylist(_items);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick files: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _importing = false);
      }
    }
  }

  Future<void> _deleteItem(int index) async {
    final item = _items[index];
    setState(() {
      _items.removeAt(index);
    });
    await _service.deleteMediaFile(item);
    await _service.savePlaylist(_items);
  }

  Future<void> _openDurationPicker(int index) async {
    final item = _items[index];
    final currentDuration = item.imageDuration ?? const Duration(seconds: 5);
    final selectedDuration = await showDurationPickerSheet(
      context: context,
      initialDuration: currentDuration,
    );

    if (selectedDuration != null && mounted) {
      setState(() {
        _items[index] = item.copyWith(imageDuration: selectedDuration);
      });
      await _service.savePlaylist(_items);
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  void _startWorkout() {
    if (_items.isEmpty || _isNavigating) return;
    _isNavigating = true;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => PlaylistPlayerScreen(
          playlist: List.unmodifiable(_items),
        ),
      ),
    )
        .then((_) {
      _isNavigating = false;
      _loadPlaylist();
    });
  }

  void _onDragAccept(int fromIndex, int toIndex) {
    if (fromIndex == toIndex) return;
    setState(() {
      final item = _items.removeAt(fromIndex);
      _items.insert(toIndex, item);
      _draggingIndex = null;
      _hoverIndex = null;
    });
    _service.savePlaylist(_items);
  }

  Widget _buildAddTile() {
    return GestureDetector(
      onTap: _importing ? null : _pickMediaFiles,
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: const Color(0xFF1E143C).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF2ECC71).withValues(alpha: 0.5),
            width: 1.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_importing)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF2ECC71),
                ),
              )
            else ...[
              const Icon(
                Icons.add_rounded,
                size: 38,
                color: Color(0xFF2ECC71),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add media',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Thumbnail content reused for both the live tile and the drag feedback widget.
  Widget _buildThumbnailContent(int index, MediaItem item,
      {bool isDragging = false}) {
    final isImage = item.isImage;
    final thumbPath = item.thumbnailPath ?? item.filePath;
    final thumbFile = File(thumbPath);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image or placeholder
          Container(
            color: const Color(0xFF1E143C),
            child: thumbFile.existsSync()
                ? Image.file(
                    thumbFile,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildFallbackThumbnail(item),
                  )
                : _buildFallbackThumbnail(item),
          ),

          // Green border + white tint while being dragged
          if (isDragging)
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                border: Border.all(
                  color: const Color(0xFF2ECC71),
                  width: 2.5,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),

          // Video play glyph
          if (!isImage)
            Center(
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),

          // Delete button — hidden while dragging
          if (!isDragging)
            Positioned(
              top: 5,
              right: 5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _deleteItem(index),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

          // Timer badge — hidden while dragging
          if (isImage && !isDragging)
            Positioned(
              bottom: 5,
              right: 5,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openDurationPicker(index),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white24,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatDuration(
                          item.imageDuration ?? const Duration(seconds: 5),
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Order number badge
          Positioned(
            top: 5,
            left: 5,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailTile(int index, MediaItem item) {
    final isImage = item.isImage;
    final isDraggingThis = _draggingIndex == index;
    final isHoverTarget = _hoverIndex == index &&
        _draggingIndex != null &&
        _draggingIndex != index;

    return DragTarget<int>(
      key: ValueKey(item.id),
      onWillAcceptWithDetails: (details) {
        if (details.data != index) {
          setState(() => _hoverIndex = index);
        }
        return details.data != index;
      },
      onLeave: (_) {
        if (_hoverIndex == index) {
          setState(() => _hoverIndex = null);
        }
      },
      onAcceptWithDetails: (details) {
        _onDragAccept(details.data, index);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedScale(
          scale: isDraggingThis ? 0.85 : (isHoverTarget ? 1.06 : 1.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: isDraggingThis ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              decoration: isHoverTarget
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2ECC71).withValues(alpha: 0.55),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: LongPressDraggable<int>(
                data: index,
                delay: const Duration(milliseconds: 300),
                onDragStarted: () {
                  setState(() {
                    _draggingIndex = index;
                    _hoverIndex = null;
                  });
                },
                onDraggableCanceled: (_, __) {
                  setState(() {
                    _draggingIndex = null;
                    _hoverIndex = null;
                  });
                },
                onDragEnd: (_) {
                  setState(() {
                    _draggingIndex = null;
                    _hoverIndex = null;
                  });
                },
                // Floating drag feedback: 1.15x bigger with green glow
                feedback: Transform.scale(
                  scale: 1.15,
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 112,
                      height: 112,
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2ECC71)
                                      .withValues(alpha: 0.65),
                                  blurRadius: 22,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                          ),
                          _buildThumbnailContent(index, item, isDragging: true),
                        ],
                      ),
                    ),
                  ),
                ),
                // While dragging, leave an empty placeholder slot
                childWhenDragging: const SizedBox(width: 112, height: 112),
                child: GestureDetector(
                  onTap: isImage ? () => _openDurationPicker(index) : null,
                  child: SizedBox(
                    width: 112,
                    height: 112,
                    child: _buildThumbnailContent(index, item),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackThumbnail(MediaItem item) {
    return Center(
      child: Icon(
        item.isVideo ? Icons.videocam : Icons.photo,
        color: Colors.white38,
        size: 36,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF2ECC71);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: accent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Playlist',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E143C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              '${_items.length} / 10',
              style: TextStyle(
                color: _items.length >= 10 ? accent : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) {
          _horizontalDragDelta = 0;
        },
        onHorizontalDragUpdate: (details) {
          _horizontalDragDelta += details.delta.dx;
        },
        onHorizontalDragEnd: (details) {
          // Only fire swipe-to-start when not dragging a tile
          if (_items.isNotEmpty && _draggingIndex == null) {
            final velocity = details.primaryVelocity ?? 0;
            if (_horizontalDragDelta < -40 || velocity < -150) {
              _startWorkout();
            }
          }
          _horizontalDragDelta = 0;
        },
        onHorizontalDragCancel: () {
          _horizontalDragDelta = 0;
        },
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Build your Cue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add up to 10 videos or images. Tap an image to adjust its timer. Hold to drag and reorder.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white60,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Thumbnail grid with drag-reorder
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (int i = 0; i < _items.length; i++)
                            _buildThumbnailTile(i, _items[i]),
                          if (_items.length < 10) _buildAddTile(),
                        ],
                      ),

                      const SizedBox(height: 28),

                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E143C)
                                .withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.fitness_center_rounded,
                                size: 52,
                                color: Colors.white38,
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Your workout is empty',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tap the + button above to pick videos or photos from your gallery.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white60,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _importing ? null : _pickMediaFiles,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.add),
                                label: const Text('Add Media Files'),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E143C)
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 20,
                                color: Colors.white54,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your playlist currently has ${_items.length} ${_items.length == 1 ? "step" : "steps"}. Auto-advances to the next step when each video or timer finishes.',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Start Cue bottom bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  border: Border(
                    top: BorderSide(color: Colors.white10, width: 1),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _items.isNotEmpty ? _startWorkout : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      disabledBackgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white30,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 28),
                    label: const Text('Start Cue'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

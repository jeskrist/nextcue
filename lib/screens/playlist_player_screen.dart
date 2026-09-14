import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/media_item.dart';
import '../widgets/single_image_viewer.dart';
import '../widgets/single_video_player_view.dart';

/// Custom scroll physics that calls callbacks on overscroll:
/// - [onOverscrollStart] when user drags right at start of list
/// - [onOverscrollEnd] when user drags left at end of list
class _BackOverscrollPhysics extends PageScrollPhysics {
  final VoidCallback onOverscrollStart;
  final VoidCallback? onOverscrollEnd;

  const _BackOverscrollPhysics({
    required this.onOverscrollStart,
    this.onOverscrollEnd,
    super.parent,
  });

  @override
  _BackOverscrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _BackOverscrollPhysics(
        onOverscrollStart: onOverscrollStart,
        onOverscrollEnd: onOverscrollEnd,
        parent: buildParent(ancestor),
      );

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final result = super.applyBoundaryConditions(position, value);
    // Detect dragging right at the start of the list.
    if (position.pixels <= position.minScrollExtent &&
        value < position.pixels) {
      onOverscrollStart();
    }
    // Detect dragging left at the end of the list.
    if (position.pixels >= position.maxScrollExtent &&
        value > position.pixels) {
      onOverscrollEnd?.call();
    }
    return result;
  }
}

class PlaylistPlayerScreen extends StatefulWidget {
  static final Map<String, Duration> _playbackProgress = {};

  final List<MediaItem> playlist;
  final int initialIndex;

  const PlaylistPlayerScreen({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
  });

  static void clearPlaybackState() {
    _playbackProgress.clear();
  }

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen>
    with WidgetsBindingObserver {
  late PageController _pageController;
  late int _currentIndex;

  // Controllers mapped by page index
  final Map<int, VideoPlayerController> _videoControllers = {};

  // GlobalKey to access SingleImageViewerState for image pages
  final Map<int, GlobalKey<SingleImageViewerState>> _imageViewerKeys = {};

  bool _isAutoAdvancing = false;
  bool _isNextAutoStart = false;
  bool _wakelockEnabled = false;
  bool _isFinished = false;
  bool _hasPopped = false;
  bool _videoWasPlaying = false;
  bool _isScrubbing = false;
  final Map<String, Duration> _savedPositions = {};

  void _handleBackSwipe() {
    if (_currentIndex == 0 && !_hasPopped && mounted) {
      _hasPopped = true;
      _saveCurrentProgress(_currentIndex);
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _savedPositions.addAll(PlaylistPlayerScreen._playbackProgress);
    _currentIndex = widget.initialIndex.clamp(0, widget.playlist.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    _initControllersForIndex(_currentIndex);
  }

  @override
  void dispose() {
    _saveCurrentProgress(_currentIndex);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _disposeAllControllers();
    if (_wakelockEnabled) {
      WakelockPlus.disable();
      _wakelockEnabled = false;
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pauseCurrentMedia();
    }
  }

  void _disposeAllControllers() {
    for (final controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
  }

  Future<void> _initControllersForIndex(int index,
      {bool autoPlay = false}) async {
    // Clean up controllers that are far from index
    final keysToRemove = _videoControllers.keys
        .where((i) => i < index - 1 || i > index + 1)
        .toList();
    for (final key in keysToRemove) {
      _videoControllers[key]?.dispose();
      _videoControllers.remove(key);
    }

    // Initialize current page if video
    if (index < widget.playlist.length && widget.playlist[index].isVideo) {
      await _ensureVideoController(index, autoPlay: autoPlay);
    }

    // Pre-warm next page if video
    final nextIndex = index + 1;
    if (nextIndex < widget.playlist.length &&
        widget.playlist[nextIndex].isVideo &&
        !_videoControllers.containsKey(nextIndex)) {
      _ensureVideoController(nextIndex, autoPlay: false);
    }
  }

  Future<VideoPlayerController> _ensureVideoController(
    int index, {
    bool autoPlay = false,
  }) async {
    if (_videoControllers.containsKey(index)) {
      final controller = _videoControllers[index]!;
      if (autoPlay && !controller.value.isPlaying) {
        final pos = controller.value.position;
        final dur = controller.value.duration;
        if (dur > Duration.zero &&
            (controller.value.isCompleted ||
                pos >= dur ||
                (dur - pos).inMilliseconds < 250)) {
          await controller.seekTo(Duration.zero);
        }
        _videoWasPlaying = true;
        controller.play();
      }
      return controller;
    }

    final item = widget.playlist[index];
    final controller = VideoPlayerController.file(File(item.filePath));
    _videoControllers[index] = controller;

    try {
      await controller.initialize();
      controller.setLooping(false);
      controller.addListener(() => _onVideoControllerUpdate(index));

      if (mounted && autoPlay && _currentIndex == index) {
        _videoWasPlaying = true;
        controller.play();
      }
      if (mounted) setState(() {});
    } catch (_) {
      // In case video initialization fails
    }

    return controller;
  }

  void _onVideoControllerUpdate(int index) {
    if (!mounted) return;
    if (index != _currentIndex) return;

    final controller = _videoControllers[index];
    if (controller == null || !controller.value.isInitialized) return;

    final isPlaying = controller.value.isPlaying;
    _updateWakelock(isPlaying);

    if (isPlaying) {
      _videoWasPlaying = true;
    }

    // Check natural finish: only trigger if playback was active and naturally reached the end
    final position = controller.value.position;
    final duration = controller.value.duration;

    if (!_isScrubbing &&
        duration > Duration.zero &&
        (controller.value.isCompleted || position >= duration) &&
        !isPlaying &&
        _videoWasPlaying &&
        !_isAutoAdvancing) {
      _videoWasPlaying = false;
      _handleItemNaturalFinish(index);
    }

    if (mounted) setState(() {});
  }

  void _updateWakelock(bool isPlaying) {
    if (_wakelockEnabled != isPlaying) {
      _wakelockEnabled = isPlaying;
      if (isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    }
  }

  Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (max > Duration.zero && value > max) return max;
    return value;
  }

  void _saveCurrentProgress(int index) {
    if (index < 0 || index >= widget.playlist.length) return;

    final item = widget.playlist[index];
    if (item.isVideo) {
      final controller = _videoControllers[index];
      if (controller != null && controller.value.isInitialized) {
        final duration = controller.value.duration;
        final position = controller.value.position;
        final saved = _clampDuration(position, duration);
        _savedPositions[item.id] = saved;
        PlaylistPlayerScreen._playbackProgress[item.id] = saved;
      }
      return;
    }

    final imageState = _imageViewerKeys[index]?.currentState;
    if (imageState != null) {
      _savedPositions[item.id] = imageState.elapsed;
      PlaylistPlayerScreen._playbackProgress[item.id] = imageState.elapsed;
    }
  }

  void _pauseCurrentMedia() {
    _saveCurrentProgress(_currentIndex);
    _videoWasPlaying = false;
    if (_currentIndex < widget.playlist.length) {
      final currentItem = widget.playlist[_currentIndex];
      if (currentItem.isVideo) {
        _videoControllers[_currentIndex]?.pause();
      } else {
        _imageViewerKeys[_currentIndex]?.currentState?.pause();
      }
    }
    _updateWakelock(false);
  }

  void _handleItemNaturalFinish(int finishedIndex) {
    if (finishedIndex != _currentIndex || _isAutoAdvancing) return;

    if (_currentIndex < widget.playlist.length - 1) {
      _isAutoAdvancing = true;
      _isNextAutoStart = true;
      final nextIndex = _currentIndex + 1;

      _pageController
          .animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      )
          .then((_) {
        _isAutoAdvancing = false;
      });
    } else {
      // Reached the end of playlist
      setState(() => _isFinished = true);
      _pauseCurrentMedia();
    }
  }

  Future<void> _restoreSavedProgress(int index, {bool autoPlay = false}) async {
    if (index < 0 || index >= widget.playlist.length) return;

    final item = widget.playlist[index];
    final saved = _savedPositions[item.id] ??
        PlaylistPlayerScreen._playbackProgress[item.id];

    if (item.isVideo) {
      final controller =
          await _ensureVideoController(index, autoPlay: autoPlay);
      if (!controller.value.isInitialized) return;

      final duration = controller.value.duration;
      if (saved != null && duration > Duration.zero) {
        final target = _clampDuration(saved, duration);
        await controller.seekTo(target);
      }
      if (autoPlay && !controller.value.isPlaying) {
        controller.play();
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = _imageViewerKeys[index]?.currentState;
      if (state == null) return;

      if (saved != null) {
        state.seekTo(saved);
      } else {
        state.seekTo(Duration.zero);
      }

      if (autoPlay) {
        state.play();
      }
    });
  }

  void _onPageChanged(int index) {
    _pauseCurrentMedia();

    final shouldAutoPlay = _isNextAutoStart;
    _isNextAutoStart = false;
    _videoWasPlaying = shouldAutoPlay;
    _isScrubbing = false;

    setState(() {
      _currentIndex = index;
    });

    _initControllersForIndex(index, autoPlay: shouldAutoPlay);
    unawaited(_restoreSavedProgress(index, autoPlay: shouldAutoPlay));

    if (shouldAutoPlay && widget.playlist[index].isImage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _imageViewerKeys[index]?.currentState?.play();
      });
    }
  }

  void _resetCue() {
    _savedPositions.clear();
    PlaylistPlayerScreen.clearPlaybackState();
    for (final controller in _videoControllers.values) {
      controller.pause();
      controller.seekTo(Duration.zero);
    }
    for (final state in _imageViewerKeys.values) {
      state.currentState?.pause();
      state.currentState?.seekTo(Duration.zero);
    }

    setState(() {
      _currentIndex = 0;
      _isFinished = false;
      _isNextAutoStart = false;
      _videoWasPlaying = false;
      _isScrubbing = false;
    });

    _pageController.jumpToPage(0);
    _onPageChanged(0);
  }

  void _restartPlaylist() {
    _savedPositions.clear();
    PlaylistPlayerScreen.clearPlaybackState();
    setState(() {
      _isFinished = false;
      _isNextAutoStart = false;
      _videoWasPlaying = false;
      _isScrubbing = false;
    });
    for (final c in _videoControllers.values) {
      c.seekTo(Duration.zero);
    }
    _pageController.jumpToPage(0);
    _onPageChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Scaffold(
      backgroundColor: secondary,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (!_isAutoAdvancing &&
                          ((notification is ScrollStartNotification &&
                                  notification.dragDetails != null) ||
                              (notification is UserScrollNotification &&
                                  notification.direction !=
                                      ScrollDirection.idle))) {
                        _pauseCurrentMedia();
                      }
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: widget.playlist.length,
                      onPageChanged: _onPageChanged,
                      physics: _BackOverscrollPhysics(
                        onOverscrollStart: _handleBackSwipe,
                        onOverscrollEnd: widget.playlist.length == 1
                            ? _handleBackSwipe
                            : null,
                      ),
                      itemBuilder: (context, index) {
                        final item = widget.playlist[index];
                        if (item.isVideo) {
                          final controller = _videoControllers[index];
                          if (controller == null ||
                              !controller.value.isInitialized) {
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white70),
                            );
                          }
                          return SingleVideoPlayerView(
                            controller: controller,
                            onTogglePlayPause: () async {
                              if (controller.value.isPlaying) {
                                _videoWasPlaying = false;
                                await controller.pause();
                              } else {
                                final pos = controller.value.position;
                                final dur = controller.value.duration;
                                if (dur > Duration.zero &&
                                    (controller.value.isCompleted ||
                                        pos >= dur ||
                                        (dur - pos).inMilliseconds < 250)) {
                                  await controller.seekTo(Duration.zero);
                                }
                                _videoWasPlaying = true;
                                await controller.play();
                              }
                              if (mounted) setState(() {});
                            },
                            onRestart: () async {
                              await controller.seekTo(Duration.zero);
                              if (mounted) setState(() {});
                            },
                            onSkip: (sec) async {
                              final target = controller.value.position +
                                  Duration(seconds: sec);
                              final dur = controller.value.duration;
                              final clamped = target < Duration.zero
                                  ? Duration.zero
                                  : (target > dur ? dur : target);
                              await controller.seekTo(clamped);
                              if (mounted) setState(() {});
                            },
                            onSeek: (_) {
                              // The seek was already fully awaited inside
                              // SingleVideoPlayerView.onChangeEnd before play() is
                              // called. Calling controller.seekTo here again would
                              // fire an unawaited seek that races with play() and
                              // intermittently leaves the video stuck paused.
                            },
                            onPauseOnTap: () {
                              if (controller.value.isPlaying) {
                                _videoWasPlaying = false;
                                setState(() => controller.pause());
                              }
                            },
                            onScrubbingChanged: (scrubbing) {
                              _isScrubbing = scrubbing;
                              if (scrubbing) {
                                _videoWasPlaying = false;
                              }
                            },
                          );
                        } else {
                          // Image page
                          final key = _imageViewerKeys.putIfAbsent(
                            index,
                            () => GlobalKey<SingleImageViewerState>(),
                          );

                          return SingleImageViewer(
                            key: key,
                            item: item,
                            autoStart: false,
                            initialElapsed:
                                _savedPositions[item.id] ?? Duration.zero,
                            onPlayingChanged: (playing) =>
                                _updateWakelock(playing),
                            onFinish: () => _handleItemNaturalFinish(index),
                          );
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Cue Completed Overlay
            if (_isFinished)
              Container(
                color: secondary.withValues(alpha: 0.88),
                child: Stack(
                  children: [
                    Positioned(
                      top: 8,
                      left: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white),
                        tooltip: 'Exit to playlist',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 56,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Cue Complete!',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Welcome to the end of Your Cue... Thank you for playing.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton.icon(
                              onPressed: _restartPlaylist,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.replay),
                              label: const Text('Restart'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;
    final total = widget.playlist.length;
    final current = _currentIndex + 1;
    final item =
        widget.playlist.isNotEmpty ? widget.playlist[_currentIndex] : null;

    return Container(
      color: secondary,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            tooltip: 'Exit to playlist',
            onPressed: () => Navigator.of(context).pop(),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: secondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item?.isVideo ?? false ? Icons.videocam : Icons.photo,
                    size: 15,
                    color: primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$current of $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: 'Reset cue',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _resetCue,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restart_alt_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'Reset cue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

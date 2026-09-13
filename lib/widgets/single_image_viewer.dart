import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/media_item.dart';

class SingleImageViewer extends StatefulWidget {
  final MediaItem item;
  final bool autoStart;
  final VoidCallback onFinish;
  final ValueChanged<bool>? onPlayingChanged;

  const SingleImageViewer({
    super.key,
    required this.item,
    this.autoStart = false,
    required this.onFinish,
    this.onPlayingChanged,
  });

  @override
  State<SingleImageViewer> createState() => SingleImageViewerState();
}

class SingleImageViewerState extends State<SingleImageViewer> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _isPlaying = false;

  Duration get _totalDuration =>
      widget.item.imageDuration ?? const Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      play();
    }
  }

  @override
  void didUpdateWidget(covariant SingleImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _stopTimer();
      _elapsed = Duration.zero;
      _isPlaying = false;
      if (widget.autoStart) {
        play();
      }
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void play() {
    if (_isPlaying) return;
    if (_elapsed >= _totalDuration) {
      _elapsed = Duration.zero;
    }
    setState(() {
      _isPlaying = true;
    });
    widget.onPlayingChanged?.call(true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) return;
      final next = _elapsed + const Duration(milliseconds: 50);
      if (next >= _totalDuration) {
        _stopTimer();
        setState(() {
          _elapsed = _totalDuration;
          _isPlaying = false;
        });
        widget.onPlayingChanged?.call(false);
        widget.onFinish();
      } else {
        setState(() {
          _elapsed = next;
        });
      }
    });
  }

  void pause() {
    if (!_isPlaying) return;
    _stopTimer();
    setState(() {
      _isPlaying = false;
    });
    widget.onPlayingChanged?.call(false);
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void restart() {
    pause();
    setState(() {
      _elapsed = Duration.zero;
    });
  }

  void seekTo(Duration target) {
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _totalDuration ? _totalDuration : target);
    setState(() {
      _elapsed = clamped;
    });
  }

  void skip(int seconds) {
    seekTo(_elapsed + Duration(seconds: seconds));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _circleButton({
    required IconData icon,
    required double size,
    required VoidCallback? onPressed,
    String? tooltip,
    bool filled = false,
    Color? fillColor,
  }) {
    final bg = filled
        ? (fillColor ?? Theme.of(context).colorScheme.primary)
        : Colors.white24;
    final button = Material(
      color: onPressed != null ? bg : Colors.white10,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: size * 0.55,
            color: onPressed != null ? Colors.white : Colors.white38,
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: button) : button;
  }

  Widget _buildPausedControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          icon: Icons.play_arrow,
          size: 92,
          tooltip: 'Resume',
          filled: true,
          fillColor: const Color(0xFF387FCF),
          onPressed: togglePlayPause,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleButton(
              icon: Icons.replay,
              size: 56,
              tooltip: 'Start from beginning',
              onPressed: restart,
            ),
            const SizedBox(width: 16),
            _circleButton(
              icon: Icons.replay_5,
              size: 56,
              tooltip: 'Back 5 seconds',
              onPressed: () => skip(-5),
            ),
            const SizedBox(width: 16),
            _circleButton(
              icon: Icons.forward_5,
              size: 56,
              tooltip: 'Forward 5 seconds',
              onPressed: () => skip(5),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final maxMs = _totalDuration.inMilliseconds.toDouble();
    final posMs = _elapsed.inMilliseconds
        .clamp(0, maxMs > 0 ? maxMs.toInt() : 0)
        .toDouble();

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            ),
            child: Slider(
              min: 0,
              max: maxMs > 0 ? maxMs : 1,
              value: posMs,
              onChanged: (v) => seekTo(Duration(milliseconds: v.toInt())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_elapsed),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  _formatDuration(_totalDuration),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isPlaying) {
                pause();
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.black),
                Center(
                  child: Image.file(
                    File(widget.item.filePath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image, size: 64, color: Colors.white38),
                    ),
                  ),
                ),
                AnimatedOpacity(
                  opacity: _isPlaying ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: _isPlaying,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: _buildPausedControls(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class SingleVideoPlayerView extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onRestart;
  final ValueChanged<int> onSkip;
  final ValueChanged<Duration> onSeek;
  final VoidCallback? onPauseOnTap;
  final ValueChanged<bool>? onScrubbingChanged;

  const SingleVideoPlayerView({
    super.key,
    required this.controller,
    required this.onTogglePlayPause,
    required this.onRestart,
    required this.onSkip,
    required this.onSeek,
    this.onPauseOnTap,
    this.onScrubbingChanged,
  });

  @override
  State<SingleVideoPlayerView> createState() => _SingleVideoPlayerViewState();
}

class _SingleVideoPlayerViewState extends State<SingleVideoPlayerView> {
  bool _isDragging = false;
  double? _dragValue;
  bool _wasPlayingBeforeDrag = false;
  DateTime _lastSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool _isSeeking = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerUpdate);
  }

  @override
  void didUpdateWidget(covariant SingleVideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleControllerUpdate);
      widget.controller.addListener(_handleControllerUpdate);
      _isDragging = false;
      _dragValue = null;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerUpdate);
    super.dispose();
  }

  void _handleControllerUpdate() {
    if (!mounted || _isDragging) return;
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  Widget _circleButton(
    BuildContext context, {
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

  Widget _buildPausedControls(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _circleButton(
          context,
          icon: Icons.play_arrow,
          size: 92,
          tooltip: 'Resume',
          filled: true,
          fillColor: const Color(0xFF387FCF),
          onPressed: widget.onTogglePlayPause,
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _circleButton(
              context,
              icon: Icons.replay,
              size: 56,
              tooltip: 'Start from beginning',
              onPressed: widget.onRestart,
            ),
            const SizedBox(width: 16),
            _circleButton(
              context,
              icon: Icons.replay_10,
              size: 56,
              tooltip: 'Back 10 seconds',
              onPressed: () => widget.onSkip(-10),
            ),
            const SizedBox(width: 16),
            _circleButton(
              context,
              icon: Icons.forward_10,
              size: 56,
              tooltip: 'Forward 10 seconds',
              onPressed: () => widget.onSkip(10),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final controller = widget.controller;
    final value = controller.value;
    final duration = value.duration;
    final maxMs = duration.inMilliseconds.toDouble();
    final posMs = value.position.inMilliseconds
        .clamp(0, maxMs > 0 ? maxMs.toInt() : 0)
        .toDouble();

    final currentSliderVal = _isDragging && _dragValue != null
        ? _dragValue!.clamp(0.0, maxMs > 0 ? maxMs : 1.0)
        : posMs;

    final displayPos = _isDragging && _dragValue != null
        ? Duration(milliseconds: _dragValue!.toInt())
        : value.position;

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
              value: maxMs > 0 ? currentSliderVal.clamp(0.0, maxMs) : 0.0,
              onChangeStart: maxMs > 0
                  ? (v) {
                      setState(() {
                        _isDragging = true;
                        _dragValue = v;
                        _wasPlayingBeforeDrag = controller.value.isPlaying;
                      });
                      if (_wasPlayingBeforeDrag) {
                        controller.pause();
                      }
                      widget.onScrubbingChanged?.call(true);
                    }
                  : null,
              onChanged: maxMs > 0
                  ? (v) {
                      setState(() {
                        _dragValue = v;
                      });
                      final now = DateTime.now();
                      if (now.difference(_lastSeekTime).inMilliseconds > 150 &&
                          !_isSeeking) {
                        _lastSeekTime = now;
                        _isSeeking = true;
                        final seekTarget = Duration(milliseconds: v.toInt());
                        controller.seekTo(seekTarget).whenComplete(() {
                          _isSeeking = false;
                        });
                      }
                    }
                  : null,
              onChangeEnd: maxMs > 0
                  ? (v) async {
                      final target = Duration(milliseconds: v.toInt());
                      await controller.seekTo(target);
                      widget.onSeek(target);
                      widget.onScrubbingChanged?.call(false);
                      if (_wasPlayingBeforeDrag) {
                        if (target < duration) {
                          await controller.play();
                        }
                      }
                      if (mounted) {
                        setState(() {
                          _isDragging = false;
                          _dragValue = null;
                        });
                      }
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(displayPos),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  _formatDuration(duration),
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
    final controller = widget.controller;
    final isInitialized = controller.value.isInitialized;
    final isPlaying = controller.value.isPlaying;

    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
      );
    }

    final showControls = !isPlaying && !_isDragging;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPauseOnTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: Colors.black),
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio == 0
                        ? 16 / 9
                        : controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                AnimatedOpacity(
                  opacity: showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !showControls,
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.35),
                      child: _buildPausedControls(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _buildBottomBar(context),
      ],
    );
  }
}

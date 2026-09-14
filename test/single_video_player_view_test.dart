import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcue/widgets/single_video_player_view.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final StreamController<VideoEvent> _eventStreamController =
      StreamController<VideoEvent>.broadcast();

  Duration currentPosition = Duration.zero;
  bool isPlaying = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> dispose(int textureId) async {
    if (!_eventStreamController.isClosed) {
      _eventStreamController.close();
    }
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    _eventStreamController.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(1920, 1080),
      ),
    );
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _eventStreamController.stream;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {
    isPlaying = true;
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: true,
        ),
      );
    }
  }

  @override
  Future<void> pause(int textureId) async {
    isPlaying = false;
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(
        VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: false,
        ),
      );
    }
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    currentPosition = position;
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    return currentPosition;
  }

  // Provide a simple placeholder widget so VideoPlayer renders without
  // crashing in tests (no native texture available in the VM runner).
  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const SizedBox.expand();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeVideoPlayerPlatform fakePlatform;

  setUp(() {
    fakePlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakePlatform;
  });

  testWidgets(
      'SingleVideoPlayerView renders play button when paused and allows seeking',
      (WidgetTester tester) async {
    final controller = VideoPlayerController.file(File('dummy.mp4'));
    await controller.initialize();

    bool playToggled = false;
    Duration? onSeekTarget;
    bool scrubbingState = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleVideoPlayerView(
            controller: controller,
            onTogglePlayPause: () {
              playToggled = true;
            },
            onRestart: () {},
            onSkip: (_) {},
            onSeek: (target) {
              onSeekTarget = target;
            },
            onScrubbingChanged: (s) {
              scrubbingState = s;
            },
          ),
        ),
      ),
    );
    await tester.pump();

    // Play button should be visible when paused
    final playBtn = find.byIcon(Icons.play_arrow);
    expect(playBtn, findsOneWidget);

    // Tapping play button fires the callback
    await tester.tap(playBtn);
    await tester.pump();
    expect(playToggled, isTrue);

    // Slider should be present
    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);

    // Drag slider - onSeek should be called with the seeked position
    await tester.drag(sliderFinder, const Offset(100, 0));
    await tester.pump();
    expect(onSeekTarget, isNotNull);

    await controller.dispose();
  });

  // Regression test: play button must remain functional after a slider scrub.
  // Previously, the parent's onSeek handler fired a second unawaited seekTo that
  // raced with play(), leaving the video stuck paused on some devices.
  testWidgets(
      'play button works after scrubbing slider (regression: unawaited seekTo race)',
      (WidgetTester tester) async {
    final controller = VideoPlayerController.file(File('dummy.mp4'));
    await controller.initialize();

    int playCallCount = 0;
    int seekCallCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleVideoPlayerView(
            controller: controller,
            onTogglePlayPause: () {
              playCallCount++;
            },
            onRestart: () {},
            onSkip: (_) {},
            onSeek: (_) {
              // Parent intentionally does NOT call controller.seekTo again:
              // the seek is already done inside the widget. Calling seekTo
              // here a second time (unawaited) is the bug.
              seekCallCount++;
            },
            onScrubbingChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    // Play button visible while paused
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    // Simulate scrub: drag the slider right then release
    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);
    await tester.drag(sliderFinder, const Offset(80, 0));
    await tester.pump();

    // After the scrub, onSeek callback should have fired exactly once
    expect(seekCallCount, 1);

    // The play button must still be tappable and fire the callback
    final playBtn = find.byIcon(Icons.play_arrow);
    expect(playBtn, findsOneWidget,
        reason: 'Play button must still be visible and not hidden after seek');
    await tester.tap(playBtn);
    await tester.pump();
    expect(playCallCount, 1,
        reason: 'Tapping play after seek must fire onTogglePlayPause');

    await controller.dispose();
  });
}

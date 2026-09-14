import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'screens/file_selection_screen.dart';
import 'screens/playlist_player_screen.dart';
import 'services/media_playlist_service.dart';

void main() {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const NextCueApp());
}

class NextCueApp extends StatelessWidget {
  const NextCueApp({super.key});

  // Primary accent color
  static const Color accent = Color.fromARGB(255, 150, 192, 240);
  static const Color deepIndigo = Color.fromARGB(255, 19, 13, 37);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextCue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: deepIndigo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          primary: accent,
          secondary: deepIndigo,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: deepIndigo,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: accent,
          inactiveTrackColor: Colors.white24,
          thumbColor: accent,
          overlayColor: accent.withValues(alpha: 0.2),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      home: const _StartupRouter(),
    );
  }
}

/// Loads the saved playlist on startup and routes to the appropriate screen.
/// FileSelectionScreen is always placed at the base of the navigation stack.
/// If files are already saved, PlaylistPlayerScreen is pushed on top, so that
/// pressing Close/back from the player always returns to FileSelectionScreen
/// rather than revealing the defunct splash screen (black screen).
class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  static const Duration _minimumSplashDuration = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final service = MediaPlaylistService();
    final itemsFuture = service.loadPlaylist();
    final minimumDelay = Future<void>.delayed(_minimumSplashDuration);

    final items = await itemsFuture;
    await minimumDelay;

    if (!mounted) return;

    // Always land on FileSelectionScreen as the stack base.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const FileSelectionScreen()),
    );

    if (items.isNotEmpty && mounted) {
      // Push the player on top so back/close returns to FileSelectionScreen.
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PlaylistPlayerScreen(playlist: List.unmodifiable(items)),
        ),
      );
    }

    FlutterNativeSplash.remove();
  }

  @override
  Widget build(BuildContext context) {
    // Shown briefly while we check saved files, matching the native splash.
    return Scaffold(
      backgroundColor: NextCueApp.deepIndigo,
      body: Center(
        child: Image.asset(
          'assets/splash/splash.png',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}

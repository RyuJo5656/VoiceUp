import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/amplifier/amplifier_screen.dart';
import 'features/onboarding/permissions_screen.dart';
import 'features/phrase_pad/phrase_pad_screen.dart';
import 'features/voice_journal/voice_journal_screen.dart';
import 'features/voice_to_speech/voice_to_speech_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env is optional: the app runs on free system STT/TTS without any keys.
  // Clova credentials, if present, enable higher-quality Korean recognition.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env bundled — fall back to system speech engines.
  }
  runApp(const VoiceUpApp());
}

class VoiceUpApp extends StatelessWidget {
  const VoiceUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppRoot(),
    );
  }
}

/// Decides whether to show the first-run permissions screen or the main app.
/// The onboarding appears until the user has seen it once *and* granted the
/// essential microphone permission.
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  static const _seenKey = 'voiceup_onboarding_seen';

  bool? _showOnboarding; // null while deciding

  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_seenKey) ?? false;
    final micGranted = await Permission.microphone.isGranted;
    if (!mounted) return;
    setState(() => _showOnboarding = !(seen && micGranted));
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    if (mounted) setState(() => _showOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    final show = _showOnboarding;
    if (show == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return show
        ? PermissionsScreen(onContinue: _finishOnboarding)
        : const RootShell();
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Most-used features first: speak (STT→TTS) and quick phrases.
  static const _tabs = <Widget>[
    VoiceToSpeechScreen(),
    PhrasePadScreen(),
    AmplifierScreen(),
    VoiceJournalScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.record_voice_over),
            label: '말하기',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: '문장',
          ),
          NavigationDestination(
            icon: Icon(Icons.graphic_eq),
            label: '증폭',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline),
            label: '일지',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/theme/app_theme.dart';
import 'features/amplifier/amplifier_screen.dart';
import 'features/phrase_pad/phrase_pad_screen.dart';
import 'features/voice_journal/voice_journal_screen.dart';
import 'features/voice_to_speech/voice_to_speech_screen.dart';
import 'overlay/call_overlay.dart';

/// Entry point for the floating call-assist overlay, rendered in a separate
/// Flutter engine by `flutter_overlay_window`. Must stay top-level and
/// annotated so the compiler keeps it reachable.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const CallOverlayApp());
}

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
      home: const RootShell(),
    );
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

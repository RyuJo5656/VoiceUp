import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  static String get csrClientId => dotenv.env['CLOVA_CSR_CLIENT_ID'] ?? '';
  static String get csrClientSecret =>
      dotenv.env['CLOVA_CSR_CLIENT_SECRET'] ?? '';

  static String get ttsClientId => dotenv.env['CLOVA_TTS_CLIENT_ID'] ?? '';
  static String get ttsClientSecret =>
      dotenv.env['CLOVA_TTS_CLIENT_SECRET'] ?? '';

  static String get ttsSpeaker => dotenv.env['CLOVA_TTS_SPEAKER'] ?? 'nara';
  static int get ttsSpeed =>
      int.tryParse(dotenv.env['CLOVA_TTS_SPEED'] ?? '0') ?? 0;
  static int get ttsPitch =>
      int.tryParse(dotenv.env['CLOVA_TTS_PITCH'] ?? '0') ?? 0;
  static int get ttsVolume =>
      int.tryParse(dotenv.env['CLOVA_TTS_VOLUME'] ?? '5') ?? 5;

  static bool get hasCsrCreds =>
      csrClientId.isNotEmpty && csrClientSecret.isNotEmpty;
  static bool get hasTtsCreds =>
      ttsClientId.isNotEmpty && ttsClientSecret.isNotEmpty;
}

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/env.dart';

/// Naver Clova Voice Premium (TTS).
///
/// Docs: https://api.ncloud-docs.com/docs/ai-naver-clovavoice-ttspremium
/// - POST with x-www-form-urlencoded.
/// - Returns audio bytes (mp3 by default).
/// - Speakers: nara (female, default), vara, mijin, jinho, ...
class ClovaTtsException implements Exception {
  ClovaTtsException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ClovaTtsException(${statusCode ?? '-'}): $message';
}

class ClovaTtsService {
  ClovaTtsService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  static const _endpoint =
      'https://naveropenapi.apigw.ntruss.com/tts-premium/v1/tts';

  final Dio _dio;

  /// Synthesizes [text] with current env settings and writes the resulting
  /// mp3 to a temp file. Returns the file path.
  Future<String> synthesizeToFile(String text) async {
    final bytes = await synthesize(text);
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/voiceup_tts_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Future<List<int>> synthesize(String text) async {
    if (!Env.hasTtsCreds) {
      throw ClovaTtsException('Clova Voice API 키가 .env에 없습니다.');
    }
    if (text.trim().isEmpty) {
      throw ClovaTtsException('합성할 텍스트가 비어있습니다.');
    }
    try {
      final res = await _dio.post<List<int>>(
        _endpoint,
        options: Options(
          headers: {
            'X-NCP-APIGW-API-KEY-ID': Env.ttsClientId,
            'X-NCP-APIGW-API-KEY': Env.ttsClientSecret,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'speaker': Env.ttsSpeaker,
          'speed': Env.ttsSpeed,
          'pitch': Env.ttsPitch,
          'volume': Env.ttsVolume,
          'format': 'mp3',
          'text': text,
        },
      );
      final data = res.data;
      if (data == null || data.isEmpty) {
        throw ClovaTtsException('빈 응답을 받았습니다.');
      }
      return data;
    } on DioException catch (e) {
      throw ClovaTtsException(
        e.response?.data?.toString() ?? e.message ?? '네트워크 오류',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

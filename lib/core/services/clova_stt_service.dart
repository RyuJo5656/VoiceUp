import 'dart:io';
import 'package:dio/dio.dart';

import '../config/env.dart';

/// Naver Clova Speech Recognition (CSR) - Korean only.
///
/// Docs: https://api.ncloud-docs.com/docs/ai-naver-clovaspeechrecognition
/// - Send raw audio bytes (PCM WAV / MP3 / FLAC / OGG / AAC).
/// - Returns plain JSON: `{"text": "인식된 결과"}`.
/// - Free quota: 15,000 calls/month at the time of writing.
class ClovaSttException implements Exception {
  ClovaSttException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'ClovaSttException(${statusCode ?? '-'}): $message';
}

class ClovaSttService {
  ClovaSttService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  static const _endpoint =
      'https://naveropenapi.apigw.ntruss.com/recog/v1/stt';

  final Dio _dio;

  Future<String> recognizeFile(File audioFile) async {
    if (!Env.hasCsrCreds) {
      throw ClovaSttException('Clova CSR API 키가 .env에 없습니다.');
    }
    final bytes = await audioFile.readAsBytes();
    return recognizeBytes(bytes);
  }

  Future<String> recognizeBytes(List<int> audioBytes) async {
    if (!Env.hasCsrCreds) {
      throw ClovaSttException('Clova CSR API 키가 .env에 없습니다.');
    }
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        queryParameters: const {'lang': 'Kor'},
        options: Options(
          headers: {
            'X-NCP-APIGW-API-KEY-ID': Env.csrClientId,
            'X-NCP-APIGW-API-KEY': Env.csrClientSecret,
            'Content-Type': 'application/octet-stream',
          },
          responseType: ResponseType.json,
        ),
        data: Stream.fromIterable([audioBytes]),
      );
      final text = res.data?['text'];
      if (text is String) return text;
      throw ClovaSttException('응답 형식이 올바르지 않습니다: ${res.data}');
    } on DioException catch (e) {
      throw ClovaSttException(
        e.response?.data?.toString() ?? e.message ?? '네트워크 오류',
        statusCode: e.response?.statusCode,
      );
    }
  }
}

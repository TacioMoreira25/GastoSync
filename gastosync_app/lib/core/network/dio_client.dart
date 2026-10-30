import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../security/owasp_prompt_sanitizer.dart';

/// Provedor Riverpod para a instância do Dio conectada à Core API em Go (Auth e Sync)
final coreApiDioProvider = Provider<Dio>((ref) {
  final baseOptions = BaseOptions(
    baseUrl: ApiConstants.coreApiBaseUrl,
    connectTimeout: ApiConstants.coreApiTimeout,
    receiveTimeout: ApiConstants.coreApiTimeout,
    sendTimeout: ApiConstants.coreApiTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    responseType: ResponseType.json,
  );

  return Dio(baseOptions);
});

/// Provedor Riverpod para a instância configurada do Dio (Serviço de IA)
final dioProvider = Provider<Dio>((ref) {
  final baseOptions = BaseOptions(
    baseUrl: ApiConstants.defaultBaseUrl,
    connectTimeout: ApiConstants.connectTimeout,
    receiveTimeout: ApiConstants.receiveTimeout,
    sendTimeout: ApiConstants.sendTimeout,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    responseType: ResponseType.json,
  );

  final dio = Dio(baseOptions);

  // Interceptor de Segurança e Auditoria (OWASP MASVS compliance)
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        // Sanitização automática contra Prompt Injection em payloads JSON (OWASP MASVS)
        final data = options.data;
        if (data is Map<String, dynamic>) {
          final sanitizedMap = Map<String, dynamic>.from(data);
          for (final key in const ['description', 'prompt', 'message', 'text']) {
            final value = sanitizedMap[key];
            if (value is String) {
              sanitizedMap[key] = OwaspPromptSanitizer.sanitize(value);
            }
          }
          options.data = sanitizedMap;
        }

        // Sanitização de logs em ambiente de produção para evitar vazamento de PII/Tokens
        if (kDebugMode) {
          debugPrint('🌐 [DIO REQ] [${options.method}] => ${options.uri}');
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) {
          debugPrint('✅ [DIO RESP] [${response.statusCode}] <= ${response.requestOptions.uri}');
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) {
        if (kDebugMode) {
          debugPrint('❌ [DIO ERR] [${e.response?.statusCode}] <= ${e.requestOptions.uri}: ${e.message}');
        }
        return handler.next(e);
      },
    ),
  );

  return dio;
});

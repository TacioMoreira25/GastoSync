import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/security/owasp_prompt_sanitizer.dart';
import '../../domain/models/agent_prediction_models.dart';

class BudgetAgentService {
  BudgetAgentService(this._dio);

  final Dio _dio;

  static const List<String> _fallbackAgentBaseUrls = <String>[
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  bool get _usesRealHttpAdapter {
    final adapterName = _dio.httpClientAdapter.runtimeType.toString();
    return !adapterName.contains('Mock');
  }

  /// Aciona `POST /api/v1/predict/categorize` com timeout resiliente e sanitização OWASP MASVS (T021)
  Future<AgentPredictionResponse> predictCategory(
    AgentPredictionRequest request,
  ) async {
    final sanitizedRequest = request.copyWith(
      description: OwaspPromptSanitizer.sanitize(request.description),
    );
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.predictCategorizeEndpoint,
        data: sanitizedRequest.toJson(),
        options: Options(
          sendTimeout: ApiConstants.textPredictionTimeout,
          receiveTimeout: ApiConstants.textPredictionTimeout,
        ),
      );

      final data = response.data;
      if (data == null) {
        throw DioException(
          requestOptions: response.requestOptions,
          message: 'Resposta vazia do serviço preditivo.',
        );
      }

      return AgentPredictionResponse.fromJson(data);
    } on DioException {
      if (_usesRealHttpAdapter) {
        for (final baseUrl in _fallbackAgentBaseUrls) {
          if (baseUrl == _dio.options.baseUrl) continue;
          try {
            final fallbackRes = await _dio.post<Map<String, dynamic>>(
              '$baseUrl${ApiConstants.predictCategorizeEndpoint}',
              data: sanitizedRequest.toJson(),
              options: Options(
                sendTimeout: ApiConstants.textPredictionTimeout,
                receiveTimeout: ApiConstants.textPredictionTimeout,
              ),
            );
            final data = fallbackRes.data;
            if (data != null) {
              return AgentPredictionResponse.fromJson(data);
            }
          } catch (_) {
            continue;
          }
        }
      }
      rethrow;
    }
  }

  /// Aciona `POST /api/v1/predict/categorize` com fallback gracioso para modo offline/timeout (T024)
  Future<AgentPredictionResponse> predictCategoryWithFallback({
    required String rawInput,
    double? explicitAmount,
    String? userId,
  }) async {
    final sanitizedInput = OwaspPromptSanitizer.sanitize(rawInput);
    final parsed = InformalExpenseParser.parse(sanitizedInput);
    final effectiveAmount = explicitAmount ?? parsed.extractedAmount;
    final request = AgentPredictionRequest(
      description: sanitizedInput,
      amount: effectiveAmount,
      userId: userId,
    );

    try {
      final result = await predictCategory(request);
      final resolvedType = parsed.inferredType == 'income' ||
              result.inferredType == 'income'
          ? 'income'
          : (parsed.inferredType == 'bill' || result.inferredType == 'bill'
              ? 'bill'
              : 'expense');
      final resolvedCategory = resolvedType == 'income'
          ? 'Renda'
          : ((result.category == 'Outros' || result.category.trim().isEmpty) &&
                  parsed.inferredCategory != 'Outros'
              ? parsed.inferredCategory
              : result.category);
      final resolvedAmount = result.estimatedAmount > 0
          ? result.estimatedAmount
          : (effectiveAmount ?? 0.0);
      final cleanedRemoteDesc = InformalExpenseParser.cleanDescriptionText(
        result.normalizedDescription,
      );
      final resolvedDescription = cleanedRemoteDesc.isNotEmpty
          ? cleanedRemoteDesc
          : (parsed.cleanDescription.isNotEmpty
              ? parsed.cleanDescription
              : sanitizedInput);
      final hasExplicitPaymentInInput = RegExp(
        r'\b(d[eé]bito|cr[eé]dito|cart[aã]o|parcelado|\d+\s*x|dinheiro|esp[eé]cie|boleto|transfer[eê]ncia|ted|doc|pix)\b',
        caseSensitive: false,
      ).hasMatch(sanitizedInput);
      final resolvedPaymentMethod = hasExplicitPaymentInInput
          ? parsed.inferredPaymentMethod
          : (result.paymentMethod.isEmpty
              ? parsed.inferredPaymentMethod
              : result.paymentMethod);

      return result.copyWith(
        inferredType: resolvedType,
        category: resolvedCategory,
        estimatedAmount: resolvedAmount,
        normalizedDescription: resolvedDescription,
        paymentMethod: resolvedPaymentMethod,
        inferredDate: result.inferredDate ?? parsed.inferredDate,
        isRecurring: result.isRecurring || parsed.isRecurring,
        isCreditCardCharge:
            result.isCreditCardCharge || parsed.isCreditCardCharge,
      );
    } on DioException catch (e) {
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      final reason = isTimeout
          ? 'Tempo limite (10s) excedido na resposta da IA.'
          : 'Assistente indisponível offline.';
      return AgentPredictionResponse.offlineFallback(
        rawInput: sanitizedInput,
        initialAmount: effectiveAmount,
        reason: reason,
      );
    } catch (_) {
      return AgentPredictionResponse.offlineFallback(
        rawInput: sanitizedInput,
        initialAmount: effectiveAmount,
        reason: 'Assistente indisponível no momento.',
      );
    }
  }

  /// Aciona `POST /api/v1/predict/ocr` via multipart/form-data com timeout de 20s (T027)
  Future<AgentPredictionResponse> extractReceiptFromOcr({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
      ),
    });

    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.predictOcrEndpoint,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: ApiConstants.ocrPredictionTimeout,
        receiveTimeout: ApiConstants.ocrPredictionTimeout,
      ),
    );

    final data = response.data;
    if (data == null) {
      throw DioException(
        requestOptions: response.requestOptions,
        message: 'Resposta vazia do OCR de comprovantes.',
      );
    }

    return AgentPredictionResponse.fromOcrJson(data);
  }

  /// Aciona OCR com fallback gracioso em caso de timeout de 20s ou falha de rede
  Future<AgentPredictionResponse> extractReceiptFromOcrWithFallback({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      return await extractReceiptFromOcr(
        imageBytes: imageBytes,
        fileName: fileName,
      );
    } on DioException catch (e) {
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      final reason = isTimeout
          ? 'Tempo limite (20s) excedido na leitura do comprovante.'
          : 'OCR indisponível offline.';
      return AgentPredictionResponse.offlineFallback(
        rawInput: 'Comprovante ($fileName)',
        initialAmount: null,
        reason: reason,
      );
    } catch (_) {
      return AgentPredictionResponse.offlineFallback(
        rawInput: 'Comprovante ($fileName)',
        initialAmount: null,
        reason: 'Não foi possível ler o comprovante automaticamente.',
      );
    }
  }
  /// Consulta telemetria pública e cotas da IA via `GET /api/v1/agent/status`,
  /// medindo a latência real em milissegundos via Stopwatch.
  Future<AgentQuotaStatus> fetchAgentQuotaStatus() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.agentStatusEndpoint,
        options: Options(
          sendTimeout: ApiConstants.textPredictionTimeout,
          receiveTimeout: ApiConstants.textPredictionTimeout,
        ),
      );
      stopwatch.stop();
      final data = response.data;
      if (data == null) {
        return AgentQuotaStatus.offline(stopwatch.elapsedMilliseconds);
      }
      return AgentQuotaStatus.fromJson(
        data,
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    } catch (_) {
      if (_usesRealHttpAdapter) {
        for (final baseUrl in _fallbackAgentBaseUrls) {
          if (baseUrl == _dio.options.baseUrl) continue;
          try {
            final fallbackRes = await _dio.get<Map<String, dynamic>>(
              '$baseUrl${ApiConstants.agentStatusEndpoint}',
              options: Options(
                sendTimeout: ApiConstants.connectTimeout,
                receiveTimeout: ApiConstants.connectTimeout,
              ),
            );
            stopwatch.stop();
            final data = fallbackRes.data;
            if (data != null) {
              return AgentQuotaStatus.fromJson(
                data,
                latencyMs: stopwatch.elapsedMilliseconds,
              );
            }
          } catch (_) {
            continue;
          }
        }
      }
      stopwatch.stop();
      return AgentQuotaStatus.offline(stopwatch.elapsedMilliseconds);
    }
  }
}

final budgetAgentServiceProvider = Provider<BudgetAgentService>((ref) {
  final dio = ref.watch(dioProvider);
  return BudgetAgentService(dio);
});

final agentQuotaStatusProvider =
    FutureProvider.autoDispose<AgentQuotaStatus>((ref) async {
  final service = ref.watch(budgetAgentServiceProvider);
  return service.fetchAgentQuotaStatus();
});

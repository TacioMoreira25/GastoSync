import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/models/agent_prediction_models.dart';

class BudgetAgentService {
  BudgetAgentService(this._dio);

  final Dio _dio;

  /// Aciona `POST /api/v1/predict/categorize` com timeout de 10s (T021)
  Future<AgentPredictionResponse> predictCategory(
    AgentPredictionRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiConstants.predictCategorizeEndpoint,
      data: request.toJson(),
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
  }

  /// Aciona `POST /api/v1/predict/categorize` com fallback gracioso para modo offline/timeout (T024)
  Future<AgentPredictionResponse> predictCategoryWithFallback({
    required String rawInput,
    double? explicitAmount,
    String? userId,
  }) async {
    final parsed = InformalExpenseParser.parse(rawInput);
    final effectiveAmount = explicitAmount ?? parsed.extractedAmount;
    final request = AgentPredictionRequest(
      description: rawInput.trim(),
      amount: effectiveAmount,
      userId: userId,
    );

    try {
      return await predictCategory(request);
    } on DioException catch (e) {
      final isTimeout = e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout;
      final reason = isTimeout
          ? 'Tempo limite (10s) excedido na resposta da IA.'
          : 'Assistente indisponível offline.';
      return AgentPredictionResponse.offlineFallback(
        rawInput: rawInput,
        initialAmount: effectiveAmount,
        reason: reason,
      );
    } catch (_) {
      return AgentPredictionResponse.offlineFallback(
        rawInput: rawInput,
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
}

final budgetAgentServiceProvider = Provider<BudgetAgentService>((ref) {
  final dio = ref.watch(dioProvider);
  return BudgetAgentService(dio);
});

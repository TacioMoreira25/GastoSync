import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/constants/api_constants.dart';
import 'package:gastosync_app/features/budget_agent/data/services/budget_agent_service.dart';
import 'package:gastosync_app/features/budget_agent/domain/models/agent_prediction_models.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('BudgetAgentService Dio HTTP Tests (US2 & US3)', () {
    test('Deve categorizar despesa vaga com sucesso via POST /api/v1/predict/categorize', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, equals(ApiConstants.predictCategorizeEndpoint));
        expect(options.method, equals('POST'));

        final payload = jsonEncode({
          'category': 'Alimentação',
          'confidence': 0.94,
          'normalized_description': "Almoço com equipe no Habib's",
          'estimated_amount': 85.0,
          'budget_tip':
              'Seus gastos com refeições fora de casa atingiram 72% do teto mensal previsto.',
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = BudgetAgentService(dio);
      final response = await service.predictCategory(
        const AgentPredictionRequest(
          description: 'almoco com equipe no habibs 85',
          amount: 85.0,
        ),
      );

      expect(response.category, equals('Alimentação'));
      expect(response.confidence, closeTo(0.94, 0.001));
      expect(response.normalizedDescription, equals("Almoço com equipe no Habib's"));
      expect(response.estimatedAmount, equals(85.0));
      expect(response.isLowConfidence, isFalse);
      expect(response.isOfflineFallback, isFalse);
    });

    test('Deve acionar fallback gracioso em caso de timeout de 10s sem travar o fluxo', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        throw DioException.connectionTimeout(
          timeout: const Duration(seconds: 10),
          requestOptions: options,
        );
      });

      final service = BudgetAgentService(dio);
      final response = await service.predictCategoryWithFallback(
        rawInput: 'lanche tarde 25',
      );

      expect(response.isOfflineFallback, isTrue);
      expect(response.estimatedAmount, equals(25.0));
      expect(response.category, equals('Alimentação'));
      expect(response.fallbackReason, contains('Tempo limite'));
    });

    test('Deve extrair dados de comprovante via POST /api/v1/predict/ocr', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, equals(ApiConstants.predictOcrEndpoint));
        expect(options.method, equals('POST'));

        final payload = jsonEncode({
          'merchant': 'Posto Ipiranga',
          'amount': 220.50,
          'date': '2026-10-20T14:32:00Z',
          'category': 'Transporte',
          'confidence': 0.89,
          'budget_tip': 'Combustível está alinhado com o seu histórico quinzenal.',
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = BudgetAgentService(dio);
      final response = await service.extractReceiptFromOcr(
        imageBytes: Uint8List.fromList([137, 80, 78, 71]),
        fileName: 'comprovante.png',
      );

      expect(response.isFromOcr, isTrue);
      expect(response.normalizedDescription, equals('Posto Ipiranga'));
      expect(response.estimatedAmount, equals(220.50));
      expect(response.category, equals('Transporte'));
      expect(response.confidence, closeTo(0.89, 0.001));
    });

    test('Deve consultar telemetria e status da IA via GET /api/v1/agent/status', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        expect(options.path, equals(ApiConstants.agentStatusEndpoint));
        expect(options.method, equals('GET'));

        final payload = jsonEncode({
          'status': 'ok',
          'provider': 'Groq Cloud',
          'active_text_model': 'openai/gpt-oss-120b',
          'fallback_text_models': ['llama-3.3-70b-versatile'],
          'active_ocr_model': 'llama-4-scout-17b',
          'fallback_ocr_models': ['meta-llama/llama-4-scout-17b'],
          'total_requests': 42,
          'daily_request_limit': 1000,
          'total_tokens_used': 3500,
          'minute_token_limit': 12000,
          'fallback_triggers': 2,
          'last_model_used': 'openai/gpt-oss-120b',
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = BudgetAgentService(dio);
      final status = await service.fetchAgentQuotaStatus();

      expect(status.isOnline, isTrue);
      expect(status.provider, equals('Groq Cloud'));
      expect(status.activeTextModel, equals('openai/gpt-oss-120b'));
      expect(status.fallbackTextModels, contains('llama-3.3-70b-versatile'));
      expect(status.activeOcrModel, equals('llama-4-scout-17b'));
      expect(status.totalRequests, equals(42));
      expect(status.dailyRequestLimit, equals(1000));
      expect(status.requestUsagePercent, closeTo(4.2, 0.01));
      expect(status.totalTokensUsed, equals(3500));
      expect(status.minuteTokenLimit, equals(12000));
      expect(status.tokenUsagePercent, closeTo((3500 / 12000) * 100, 0.01));
      expect(status.fallbackTriggers, equals(2));
      expect(status.lastModelUsed, equals('openai/gpt-oss-120b'));
    });

    test('Deve retornar AgentQuotaStatus.offline() em caso de falha de conexão com o Render', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockHttpClientAdapter((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Cold start ou serviço Render offline',
        );
      });

      final service = BudgetAgentService(dio);
      final status = await service.fetchAgentQuotaStatus();

      expect(status.isOnline, isFalse);
      expect(status.provider, contains('Offline'));
      expect(status.totalRequests, equals(0));
      expect(status.dailyRequestLimit, equals(1000));
      expect(status.requestUsageRatio, equals(0.0));
      expect(status.tokenUsageRatio, equals(0.0));
    });
  });
}

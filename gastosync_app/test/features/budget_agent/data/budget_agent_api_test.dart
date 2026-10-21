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
  });
}

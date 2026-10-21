class ApiConstants {
  ApiConstants._();

  // URL padrão do backend de orquestração Python (gastosync_agent)
  static const String defaultBaseUrl = String.fromEnvironment(
    'GASTOSYNC_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  // Timeouts de resiliência conforme especificação (10s texto / 20s OCR)
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration textPredictionTimeout = Duration(seconds: 10);
  static const Duration ocrPredictionTimeout = Duration(seconds: 20);

  // Endpoints do Agente Preditivo e Orçamentário (Contratos v1)
  static const String predictCategorizeEndpoint = '/api/v1/predict/categorize';
  static const String predictOcrEndpoint = '/api/v1/predict/ocr';
  static const String agentBudgetBurnRateEndpoint = '/api/v1/agent/budget-burn-rate';

  // Endpoints legados / auxiliares
  static const String agentPredictEndpoint = '/api/v1/agent/predict';
  static const String agentBudgetOptimizationEndpoint = '/api/v1/agent/optimize-budget';
  static const String agentChatEndpoint = '/api/v1/agent/chat';

  // Endpoints de Transações
  static const String transactionsEndpoint = '/api/v1/transactions';
  static const String syncEndpoint = '/api/v1/sync';
}

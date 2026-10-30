class ApiConstants {
  ApiConstants._();

  // URL padrão do backend de orquestração Python (gastosync_agent)
  static const String defaultBaseUrl = String.fromEnvironment(
    'GASTOSYNC_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  // URL padrão do backend Core Go (gastosync_api)
  static const String coreApiBaseUrl = String.fromEnvironment(
    'GASTOSYNC_CORE_API_URL',
    defaultValue: 'http://localhost:8080',
  );

  // Timeouts de resiliência conforme especificação (10s texto / 20s OCR)
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration textPredictionTimeout = Duration(seconds: 10);
  static const Duration ocrPredictionTimeout = Duration(seconds: 20);

  // Endpoints do Backend Core Go (Auth & Sync)
  static const String authRegisterEndpoint = '/api/v1/auth/register';
  static const String authLoginEndpoint = '/api/v1/auth/login';
  static const String authMeEndpoint = '/api/v1/auth/me';
  static const String syncPushEndpoint = '/api/v1/sync/push';
  static const String syncPullEndpoint = '/api/v1/sync/pull';

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

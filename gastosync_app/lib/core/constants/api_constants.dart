class ApiConstants {
  ApiConstants._();

  // URL oficial de produção do microsserviço Core em Go (Auth, Perfil e Sync)
  static const String coreApiBaseUrl = String.fromEnvironment(
    'GASTOSYNC_CORE_API_URL',
    defaultValue: 'https://gastosync-api.onrender.com',
  );

  // URL padrão do serviço satélite de IA (gastosync_agent)
  static const String defaultBaseUrl = String.fromEnvironment(
    'GASTOSYNC_API_URL',
    defaultValue: 'http://localhost:8000',
  );

  // Timeouts de resiliência (10s texto / 20s OCR / 25s Core API para suportar cold-start do Render Free)
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);
  static const Duration coreApiTimeout = Duration(seconds: 25);
  static const Duration textPredictionTimeout = Duration(seconds: 10);
  static const Duration ocrPredictionTimeout = Duration(seconds: 20);

  // Endpoints da Core API em Go (https://gastosync-api.onrender.com)
  static const String healthEndpoint = '/health';
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

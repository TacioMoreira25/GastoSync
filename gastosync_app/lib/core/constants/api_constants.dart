class ApiConstants {
  ApiConstants._();

  // URL padrão do backend de orquestração Python (gastosync_agent)
  static const String defaultBaseUrl = 'http://localhost:8000';
  
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 15);

  // Endpoints do Agente Preditivo e Orçamentário
  static const String agentPredictEndpoint = '/api/v1/agent/predict';
  static const String agentBudgetOptimizationEndpoint = '/api/v1/agent/optimize-budget';
  static const String agentChatEndpoint = '/api/v1/agent/chat';

  // Endpoints de Transações
  static const String transactionsEndpoint = '/api/v1/transactions';
  static const String syncEndpoint = '/api/v1/sync';
}

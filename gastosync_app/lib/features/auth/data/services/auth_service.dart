import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_constants.dart';

/// Resultado encapsulado de operações de autenticação remota
class AuthResult {
  const AuthResult({
    this.token,
    this.userId,
    this.name,
    this.email,
    this.error,
    this.isOffline = false,
  });

  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final String? error;
  final bool isOffline;

  bool get isSuccess => error == null && !isOffline;
}

/// Serviço de integração com os endpoints de autenticação em Go (`gastosync_api`)
class AuthService {
  AuthService([Dio? dio])
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConstants.coreApiBaseUrl,
                connectTimeout: ApiConstants.coreApiTimeout,
                receiveTimeout: ApiConstants.coreApiTimeout,
                sendTimeout: ApiConstants.coreApiTimeout,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
                responseType: ResponseType.json,
              ),
            );

  final Dio _dio;

  /// Registra novo usuário no backend PostgreSQL remoto
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.authRegisterEndpoint,
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      return AuthResult(
        token: data['token'] as String?,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: user['email'] as String?,
      );
    } on DioException catch (e) {
      if (_isNetworkFailure(e)) {
        return const AuthResult(isOffline: true);
      }
      final serverMsg = _extractErrorMessage(e);
      return AuthResult(error: serverMsg);
    } catch (e) {
      return AuthResult(error: e.toString());
    }
  }

  /// Autentica usuário no backend PostgreSQL remoto e adquire token JWT
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.authLoginEndpoint,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password.trim(),
        },
      );

      final data = response.data as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;

      return AuthResult(
        token: data['token'] as String?,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: user['email'] as String?,
      );
    } on DioException catch (e) {
      if (_isNetworkFailure(e)) {
        return const AuthResult(isOffline: true);
      }
      final serverMsg = _extractErrorMessage(e);
      return AuthResult(error: serverMsg);
    } catch (e) {
      return AuthResult(error: e.toString());
    }
  }

  /// Consulta dados cadastrais do perfil autenticado
  Future<Map<String, dynamic>?> fetchMe(String token) async {
    try {
      final response = await _dio.get(
        ApiConstants.authMeEndpoint,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      return response.data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  bool _isNetworkFailure(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.error is FormatException;
  }

  String _extractErrorMessage(DioException e) {
    final statusCode = e.response?.statusCode;
    final responseData = e.response?.data;

    if (responseData is Map<String, dynamic>) {
      final rawMsg =
          (responseData['message'] ?? responseData['error'])?.toString().trim();
      if (rawMsg != null && rawMsg.isNotEmpty) {
        return _localizeServerError(rawMsg);
      }
    }

    if (statusCode == 401) {
      return 'E-mail ou senha incorretos. Verifique seus dados e tente novamente.';
    }
    if (statusCode == 409) {
      return 'Este e-mail já está cadastrado. Acesse a aba Entrar para fazer login.';
    }
    if (statusCode == 429) {
      return 'Muitas tentativas seguidas. Aguarde 1 minuto antes de tentar novamente.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'O servidor está temporariamente indisponível. Tente novamente em instantes.';
    }

    return 'Não foi possível concluir a comunicação com o servidor. Verifique sua conexão.';
  }

  String _localizeServerError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid email or password')) {
      return 'E-mail ou senha incorretos. Verifique seus dados e tente novamente.';
    }
    if (lower.contains('already exists') || lower.contains('unique')) {
      return 'Este e-mail já está cadastrado. Acesse a aba Entrar para fazer login.';
    }
    if (lower.contains('invalid or expired token') ||
        lower.contains('missing or malformed authorization')) {
      return 'Sua sessão expirou. Por favor, faça login novamente.';
    }
    if (lower.contains('invalid request payload')) {
      return 'Não foi possível ler os dados enviados. Verifique os campos preenchidos.';
    }
    if (lower.contains('email and password are required') ||
        lower.contains('password (min 6 chars) are required')) {
      return 'Preencha todos os campos obrigatórios corretamente.';
    }
    return message;
  }
}

/// Provedor Riverpod para a instância do AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

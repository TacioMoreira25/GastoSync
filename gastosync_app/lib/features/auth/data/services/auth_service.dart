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
                connectTimeout: ApiConstants.connectTimeout,
                receiveTimeout: ApiConstants.receiveTimeout,
                sendTimeout: ApiConstants.sendTimeout,
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
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final err = responseData['error'] as String?;
      if (err != null && err.isNotEmpty) return err;
    }
    return e.message ?? 'Falha na comunicação com o servidor de autenticação.';
  }
}

/// Provedor Riverpod para a instância do AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

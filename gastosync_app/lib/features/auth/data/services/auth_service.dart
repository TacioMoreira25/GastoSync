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
    this.emailVerified = false,
    this.requiresVerification = false,
    this.devPreviewCode,
    this.deliveryMode,
    this.monthlyIncome,
    this.savingsGoalPercent,
    this.reminderTime1,
    this.reminderTime2,
    this.emailBillNotifications,
    this.error,
    this.errorCode,
    this.isOffline = false,
  });

  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final bool emailVerified;
  final bool requiresVerification;
  final String? devPreviewCode;
  final String? deliveryMode;
  final double? monthlyIncome;
  final double? savingsGoalPercent;
  final String? reminderTime1;
  final String? reminderTime2;
  final bool? emailBillNotifications;
  final String? error;
  final String? errorCode;
  final bool isOffline;

  bool get isSuccess => error == null && !isOffline;
}

/// Resultado do disparo de código de recuperação ou verificação de e-mail
class PasswordResetDispatchResult {
  const PasswordResetDispatchResult({
    this.message,
    this.deliveryMode,
    this.devPreviewCode,
    this.error,
    this.isOffline = false,
  });

  final String? message;
  final String? deliveryMode;
  final String? devPreviewCode;
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
  final Dio _localFallbackDio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:8080',
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 6),
      sendTimeout: const Duration(seconds: 4),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      responseType: ResponseType.json,
    ),
  );

  bool _isRouteMissingOnServer(DioException e) {
    if (e.response?.statusCode != 404) return false;
    final data = e.response?.data;
    return data is Map<String, dynamic> && data['code'] == 'ROUTE_NOT_FOUND';
  }

  Future<Response<Map<String, dynamic>>> _postWithLocalFallback(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      return await _dio.post<Map<String, dynamic>>(path, data: data);
    } on DioException catch (e) {
      if ((_isNetworkError(e) || _isRouteMissingOnServer(e)) &&
          _dio.options.baseUrl != 'http://localhost:8080') {
        return await _localFallbackDio.post<Map<String, dynamic>>(
          path,
          data: data,
        );
      }
      rethrow;
    }
  }

  /// Registra um novo usuário remotamente (`POST /api/v1/auth/register`)
  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authRegisterEndpoint,
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response.data ?? const <String, dynamic>{};
      final user =
          data['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};

      return AuthResult(
        token: data['token'] as String?,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: user['email'] as String?,
        emailVerified: user['email_verified'] as bool? ?? false,
        requiresVerification: data['requires_verification'] as bool? ?? false,
        devPreviewCode: data['dev_preview_code'] as String?,
        deliveryMode: data['delivery_mode'] as String?,
        monthlyIncome: (user['monthly_income'] as num?)?.toDouble(),
        savingsGoalPercent: (user['savings_goal_percent'] as num?)?.toDouble(),
        reminderTime1: user['reminder_time_1'] as String?,
        reminderTime2: user['reminder_time_2'] as String?,
        emailBillNotifications: user['email_bill_notifications'] as bool?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        return const AuthResult(isOffline: true);
      }
      final msg =
          _extractErrorMessage(e) ?? 'Falha ao registrar conta na nuvem.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  /// Autentica um usuário remotamente (`POST /api/v1/auth/login`)
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.authLoginEndpoint,
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response.data ?? const <String, dynamic>{};
      final user =
          data['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};

      return AuthResult(
        token: data['token'] as String?,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: user['email'] as String?,
        emailVerified: user['email_verified'] as bool? ?? true,
        monthlyIncome: (user['monthly_income'] as num?)?.toDouble(),
        savingsGoalPercent: (user['savings_goal_percent'] as num?)?.toDouble(),
        reminderTime1: user['reminder_time_1'] as String?,
        reminderTime2: user['reminder_time_2'] as String?,
        emailBillNotifications: user['email_bill_notifications'] as bool?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        return const AuthResult(isOffline: true);
      }
      final responseData = e.response?.data;
      if (e.response?.statusCode == 403 &&
          responseData is Map<String, dynamic> &&
          (responseData['code'] == 'EMAIL_NOT_VERIFIED' ||
              responseData['requires_verification'] == true)) {
        final msg = _extractErrorMessage(e) ??
            'Seu e-mail ainda não foi verificado. Digite o código de 6 dígitos enviado para o seu e-mail.';
        return AuthResult(
          email: email.trim().toLowerCase(),
          emailVerified: false,
          requiresVerification: true,
          devPreviewCode: responseData['dev_preview_code'] as String?,
          deliveryMode: responseData['delivery_mode'] as String?,
          errorCode: 'EMAIL_NOT_VERIFIED',
          error: msg,
        );
      }
      final msg = _extractErrorMessage(e) ?? 'Credenciais inválidas.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  /// Solicita o envio do código OTP de 6 dígitos por e-mail (`POST /api/v1/auth/forgot-password`)
  Future<PasswordResetDispatchResult> requestPasswordReset({
    required String email,
  }) async {
    try {
      final response = await _postWithLocalFallback(
        ApiConstants.authForgotPasswordEndpoint,
        {
          'email': email.trim().toLowerCase(),
        },
      );

      final data = response.data ?? const <String, dynamic>{};
      return PasswordResetDispatchResult(
        message: data['message'] as String?,
        deliveryMode: data['delivery_mode'] as String?,
        devPreviewCode: data['dev_preview_code'] as String?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e) || _isRouteMissingOnServer(e)) {
        return const PasswordResetDispatchResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ??
          'Não foi possível enviar o código de verificação.';
      return PasswordResetDispatchResult(error: msg);
    } catch (_) {
      return const PasswordResetDispatchResult(isOffline: true);
    }
  }

  /// Verifica se o código OTP de 6 dígitos enviado por e-mail é válido (`POST /api/v1/auth/verify-reset-code`)
  Future<AuthResult> verifyResetCode({
    required String email,
    required String code,
  }) async {
    try {
      await _postWithLocalFallback(
        ApiConstants.authVerifyResetCodeEndpoint,
        {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
        },
      );
      return const AuthResult();
    } on DioException catch (e) {
      if (_isNetworkError(e) || _isRouteMissingOnServer(e)) {
        return const AuthResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ?? 'Código de verificação inválido.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  /// Conclui a redefinição de senha na nuvem (`POST /api/v1/auth/reset-password`)
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _postWithLocalFallback(
        ApiConstants.authResetPasswordEndpoint,
        {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
          'new_password': newPassword.trim(),
        },
      );
      return const AuthResult();
    } on DioException catch (e) {
      if (_isNetworkError(e) || _isRouteMissingOnServer(e)) {
        return const AuthResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ?? 'Falha ao redefinir a senha.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  /// Solicita/reenvia o código OTP de 6 dígitos para verificar o e-mail da conta (`POST /api/v1/auth/resend-verification`)
  Future<PasswordResetDispatchResult> resendVerificationEmail({
    required String email,
    String? name,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim().toLowerCase(),
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
    };
    try {
      Response<Map<String, dynamic>> response;
      try {
        response = await _postWithLocalFallback(
          ApiConstants.authResendVerificationEndpoint,
          payload,
        );
      } on DioException catch (e) {
        if (_isRouteMissingOnServer(e)) {
          response = await _postWithLocalFallback(
            ApiConstants.authSendVerificationEndpoint,
            payload,
          );
        } else {
          rethrow;
        }
      }

      final data = response.data ?? const <String, dynamic>{};
      return PasswordResetDispatchResult(
        message: data['message'] as String?,
        deliveryMode: data['delivery_mode'] as String?,
        devPreviewCode: data['dev_preview_code'] as String?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e) || _isRouteMissingOnServer(e)) {
        return const PasswordResetDispatchResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ??
          'Não foi possível enviar o código de verificação.';
      return PasswordResetDispatchResult(error: msg);
    } catch (_) {
      return const PasswordResetDispatchResult(isOffline: true);
    }
  }

  /// Alias compatível para disparo de código OTP de verificação de e-mail
  Future<PasswordResetDispatchResult> sendEmailVerification({
    required String email,
    String? name,
  }) {
    return resendVerificationEmail(email: email, name: name);
  }

  /// Valida o código OTP de 6 dígitos, marca o e-mail da conta como verificado e retorna o token JWT (`POST /api/v1/auth/verify-email`)
  Future<AuthResult> verifyEmail({
    required String email,
    required String code,
  }) async {
    try {
      final response = await _postWithLocalFallback(
        ApiConstants.authVerifyEmailEndpoint,
        {
          'email': email.trim().toLowerCase(),
          'code': code.trim(),
        },
      );
      final data = response.data ?? const <String, dynamic>{};
      final user =
          data['user'] as Map<String, dynamic>? ?? const <String, dynamic>{};

      return AuthResult(
        token: data['token'] as String?,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: (user['email'] as String?) ?? email.trim().toLowerCase(),
        emailVerified: true,
        monthlyIncome: (user['monthly_income'] as num?)?.toDouble(),
        savingsGoalPercent: (user['savings_goal_percent'] as num?)?.toDouble(),
        reminderTime1: user['reminder_time_1'] as String?,
        reminderTime2: user['reminder_time_2'] as String?,
        emailBillNotifications: user['email_bill_notifications'] as bool?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e) || _isRouteMissingOnServer(e)) {
        return const AuthResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ?? 'Código de verificação inválido.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  /// Alias compatível para validação de código OTP de verificação de e-mail
  Future<AuthResult> verifyEmailCode({
    required String email,
    required String code,
  }) {
    return verifyEmail(email: email, code: code);
  }

  /// Valida o token JWT atual e retorna os dados do perfil (`GET /api/v1/auth/me`)
  Future<AuthResult> getProfile(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.authMeEndpoint,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      final user = response.data ?? const <String, dynamic>{};
      return AuthResult(
        token: token,
        userId: user['id'] as String?,
        name: user['name'] as String?,
        email: user['email'] as String?,
        emailVerified: user['email_verified'] as bool? ?? false,
        monthlyIncome: (user['monthly_income'] as num?)?.toDouble(),
        savingsGoalPercent: (user['savings_goal_percent'] as num?)?.toDouble(),
        reminderTime1: user['reminder_time_1'] as String?,
        reminderTime2: user['reminder_time_2'] as String?,
        emailBillNotifications: user['email_bill_notifications'] as bool?,
      );
    } on DioException catch (e) {
      if (_isNetworkError(e)) {
        return const AuthResult(isOffline: true);
      }
      final msg = _extractErrorMessage(e) ?? 'Sessão expirada.';
      return AuthResult(error: msg);
    } catch (_) {
      return const AuthResult(isOffline: true);
    }
  }

  bool _isNetworkError(DioException e) {
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  String? _extractErrorMessage(DioException e) {
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

    return null;
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

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

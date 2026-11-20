import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Credenciais e metadados de perfil armazenados no cofre seguro do dispositivo
/// (Android Keystore / iOS Keychain) para desbloqueio biométrico instantâneo.
@immutable
class BiometricStoredSession {
  const BiometricStoredSession({
    required this.email,
    required this.password,
    required this.fullName,
    this.jwtToken,
    this.monthlyBaseIncome = 0.0,
    this.savingsRateTarget = 0.0,
    this.reminderTime1 = '09:00',
    this.reminderTime2 = '18:00',
    this.emailBillNotifications = true,
  });

  final String email;
  final String password;
  final String fullName;
  final String? jwtToken;
  final double monthlyBaseIncome;
  final double savingsRateTarget;
  final String reminderTime1;
  final String reminderTime2;
  final bool emailBillNotifications;

  BiometricStoredSession copyWith({
    String? email,
    String? password,
    String? fullName,
    String? jwtToken,
    double? monthlyBaseIncome,
    double? savingsRateTarget,
    String? reminderTime1,
    String? reminderTime2,
    bool? emailBillNotifications,
  }) {
    return BiometricStoredSession(
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      jwtToken: jwtToken ?? this.jwtToken,
      monthlyBaseIncome: monthlyBaseIncome ?? this.monthlyBaseIncome,
      savingsRateTarget: savingsRateTarget ?? this.savingsRateTarget,
      reminderTime1: reminderTime1 ?? this.reminderTime1,
      reminderTime2: reminderTime2 ?? this.reminderTime2,
      emailBillNotifications:
          emailBillNotifications ?? this.emailBillNotifications,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'password': password,
        'full_name': fullName,
        'jwt_token': jwtToken,
        'monthly_base_income': monthlyBaseIncome,
        'savings_rate_target': savingsRateTarget,
        'reminder_time_1': reminderTime1,
        'reminder_time_2': reminderTime2,
        'email_bill_notifications': emailBillNotifications,
      };

  static BiometricStoredSession? fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String? ?? '').trim().toLowerCase();
    final password = (json['password'] as String? ?? '').trim();
    if (email.isEmpty || password.isEmpty) return null;
    return BiometricStoredSession(
      email: email,
      password: password,
      fullName: (json['full_name'] as String? ?? '').trim(),
      jwtToken: json['jwt_token'] as String?,
      monthlyBaseIncome: (json['monthly_base_income'] as num?)?.toDouble() ?? 0.0,
      savingsRateTarget: (json['savings_rate_target'] as num?)?.toDouble() ?? 0.0,
      reminderTime1: json['reminder_time_1'] as String? ?? '09:00',
      reminderTime2: json['reminder_time_2'] as String? ?? '18:00',
      emailBillNotifications: json['email_bill_notifications'] as bool? ?? true,
    );
  }
}

/// Serviço isolado para autenticação biométrica nativa (digital / FaceID / PIN do aparelho)
/// e cofre seguro de sessão. Opera de forma segura como no-op no Flutter Web.
class BiometricAuthService {
  BiometricAuthService({
    LocalAuthentication? localAuth,
    FlutterSecureStorage? secureStorage,
  })  : _localAuth = localAuth ?? LocalAuthentication(),
        _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _sessionKey = 'gastosync_biometric_session_v1';

  final LocalAuthentication _localAuth;
  final FlutterSecureStorage _secureStorage;

  /// Retorna true se a plataforma atual suporta autenticação biométrica/dispositivo.
  Future<bool> isDeviceSupported() async {
    if (kIsWeb) return false;
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported || canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Aciona o prompt nativo de biometria com fallback para PIN/padrão do aparelho.
  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveSession(BiometricStoredSession session) async {
    if (kIsWeb) return;
    try {
      await _secureStorage.write(
        key: _sessionKey,
        value: jsonEncode(session.toJson()),
      );
    } catch (_) {}
  }

  Future<BiometricStoredSession?> readSession() async {
    if (kIsWeb) return null;
    try {
      final raw = await _secureStorage.read(key: _sessionKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return BiometricStoredSession.fromJson(decoded);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() async {
    if (kIsWeb) return;
    try {
      await _secureStorage.delete(key: _sessionKey);
    } catch (_) {}
  }
}

final biometricAuthServiceProvider = Provider<BiometricAuthService>(
  (ref) => BiometricAuthService(),
);

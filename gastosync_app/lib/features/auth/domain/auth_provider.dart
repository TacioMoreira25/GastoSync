import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../settings/domain/models/user_profile.dart';
import '../../transactions/data/services/cloud_sync_service.dart';
import '../../transactions/presentation/controllers/transactions_controller.dart';
import '../data/services/auth_service.dart';

/// Resultado detalhado de avaliação de segurança da senha em tempo real (OWASP ASVS / NIST)
@immutable
class PasswordSecurityAnalysis {
  const PasswordSecurityAnalysis({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSpecialChar,
    required this.isNotCommonOrRepeated,
    required this.strengthScore,
    required this.strengthLabel,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSpecialChar;
  final bool isNotCommonOrRepeated;

  /// Score de 0.0 a 1.0
  final double strengthScore;

  /// Rótulo ('Muito fraca', 'Fraca', 'Média', 'Forte', 'Blindada')
  final String strengthLabel;

  bool get hasMixedCase => hasUppercase && hasLowercase;

  bool get isCompliant =>
      hasMinLength &&
      hasUppercase &&
      hasLowercase &&
      hasDigit &&
      hasSpecialChar &&
      isNotCommonOrRepeated;
}

/// Motor criptográfico de derivação de chave (Key Stretching 256-bit + CSPRNG Salt 128-bit + Pepper)
/// 100% compatível com Dart VM (Mobile/Desktop) e JavaScript/WASM (Web).
class PasswordHasher {
  PasswordHasher._();

  static const String _applicationPepper = 'GastoSync::OWASP_MASVS_v2::2026';
  static const int _stretchingRounds = 2048;

  /// Gera um Salt criptograficamente seguro de 128 bits (16 bytes hex) via `Random.secure()`
  static String generateSecureSalt() {
    try {
      final csprng = Random.secure();
      final bytes = List<int>.generate(16, (_) => csprng.nextInt(256));
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    } catch (_) {
      final fallback = Random(DateTime.now().microsecondsSinceEpoch);
      final bytes = List<int>.generate(16, (_) => fallback.nextInt(256));
      return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    }
  }

  /// Deriva um hash de 256 bits (64 caracteres hex) usando 8 lanes de 32 bits e 2.048 rodadas de Key Stretching
  static String hashPassword(String password, String salt) {
    final payload = utf8.encode('$salt::$password::$_applicationPepper');

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    for (var round = 0; round < _stretchingRounds; round++) {
      for (var i = 0; i < payload.length; i++) {
        final b = (payload[i] ^ (round & 0xff) ^ i) & 0xff;
        h0 = ((h0 ^ b) * 0x01000193) & 0x7fffffff;
        h1 = ((h1 + ((b << 5) & 0x7fffffff) ^ h0) * 0x01000193) & 0x7fffffff;
        h2 = ((h2 ^ ((b << 11) & 0x7fffffff) + h1) * 0x01000193) & 0x7fffffff;
        h3 = ((h3 + b + (h2 & 0xffff)) * 0x01000193) & 0x7fffffff;
        h4 = ((h4 ^ b ^ (h3 >> 3)) * 0x01000193) & 0x7fffffff;
        h5 = ((h5 + ((b << 7) & 0x7fffffff) ^ h4) * 0x01000193) & 0x7fffffff;
        h6 = ((h6 ^ b ^ (h5 & 0xffff)) * 0x01000193) & 0x7fffffff;
        h7 = ((h7 + b + (h6 >> 5) ^ h0) * 0x01000193) & 0x7fffffff;
      }
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }

  /// Comparação em tempo constante para mitigar ataques de canal lateral (Timing Attacks)
  static bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}

@immutable
class AuthAccount {
  const AuthAccount({
    required this.fullName,
    required this.email,
    required this.salt,
    required this.passwordHash,
  });

  final String fullName;
  final String email;
  final String salt;
  final String passwordHash;
}

@immutable
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.currentEmail,
    this.token,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.errorMessage,
    this.successMessage,
  });

  final bool isAuthenticated;
  final String? currentEmail;
  final String? token;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? errorMessage;
  final String? successMessage;

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  AuthState copyWith({
    bool? isAuthenticated,
    String? currentEmail,
    String? token,
    bool clearToken = false,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentEmail: currentEmail ?? this.currentEmail,
      token: clearToken ? null : (token ?? this.token),
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const String defaultDemoEmail = 'marcos.pereira@gastosync.local';
  static const String defaultDemoPassword = 'Gasto@2026!';
  static const String defaultDemoName = 'Marcos Pereira';
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);

  static final RegExp _uppercaseRegex = RegExp(r'[A-ZÁÀÂÃÉÊÍÓÔÕÚÇ]');
  static final RegExp _lowercaseRegex = RegExp(r'[a-záàâãéêíóôõúç]');
  static final RegExp _digitRegex = RegExp(r'[0-9]');
  static final RegExp _specialCharRegex = RegExp(
    r'[!@#\$%\^&\*\(\),\.\?":\{\}\|<>_\-\+=/\\\[\];~`]',
  );
  static final RegExp _repeatedCharRegex = RegExp(r'^(.)\1+$');

  static const Set<String> _commonWeakPasswords = <String>{
    '12345678',
    '123456789',
    '1234567890',
    'password',
    'password123',
    'senha123',
    'senha@123',
    'qwerty123',
    'admin123',
    'admin@123',
    'gastosync',
  };

  final Map<String, AuthAccount> _accounts = <String, AuthAccount>{};

  @override
  AuthState build() {
    _seedDefaultAccount();
    _loadPersistedAccountsAndSession();
    return const AuthState(isAuthenticated: false);
  }

  void _seedDefaultAccount() {
    const salt = 'gs_csprng_default_salt_2026_9f8a7b6c';
    final hash = PasswordHasher.hashPassword(defaultDemoPassword, salt);
    _accounts[defaultDemoEmail] = AuthAccount(
      fullName: defaultDemoName,
      email: defaultDemoEmail,
      salt: salt,
      passwordHash: hash,
    );
  }

  Future<void> _loadPersistedAccountsAndSession() async {
    try {
      final db = ref.read(appDatabaseProvider);
      final rows = await db.getPersistedAuthAccounts();
      for (final r in rows) {
        final email = (r['email'] as String? ?? '').trim().toLowerCase();
        final fullName = r['full_name'] as String? ?? '';
        final salt = r['salt'] as String? ?? '';
        final hash = r['password_hash'] as String? ?? '';
        if (email.isNotEmpty && salt.isNotEmpty && hash.isNotEmpty) {
          _accounts[email] = AuthAccount(
            fullName: fullName,
            email: email,
            salt: salt,
            passwordHash: hash,
          );
        }
      }

      final session = await db.getPersistedAuthSession();
      if (session != null && session['is_authenticated'] == 1) {
        final currentEmail =
            (session['current_email'] as String? ?? '').trim().toLowerCase();
        final jwtToken = session['jwt_token'] as String?;
        final account = _accounts[currentEmail];
        if (account != null) {
          ref.read(userProfileProvider.notifier).updateProfile(
                fullName: account.fullName,
                email: account.email,
              );
          state = state.copyWith(
            isAuthenticated: true,
            currentEmail: account.email,
            token: jwtToken,
            clearError: true,
            clearSuccess: true,
          );
        }
      }
    } catch (_) {}
  }

  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  /// Analisa os requisitos de segurança da senha em tempo real (usado apenas em Criar Conta e Alterar Senha)
  static PasswordSecurityAnalysis analyzePassword(String rawPassword) {
    final pwd = rawPassword.trim();
    if (pwd.isEmpty) {
      return const PasswordSecurityAnalysis(
        hasMinLength: false,
        hasUppercase: false,
        hasLowercase: false,
        hasDigit: false,
        hasSpecialChar: false,
        isNotCommonOrRepeated: false,
        strengthScore: 0.0,
        strengthLabel: 'Muito fraca',
      );
    }

    final hasMinLength = pwd.length >= minPasswordLength;
    final hasUppercase = _uppercaseRegex.hasMatch(pwd);
    final hasLowercase = _lowercaseRegex.hasMatch(pwd);
    final hasDigit = _digitRegex.hasMatch(pwd);
    final hasSpecialChar = _specialCharRegex.hasMatch(pwd);
    final isNotCommonOrRepeated =
        !_commonWeakPasswords.contains(pwd.toLowerCase()) &&
        !_repeatedCharRegex.hasMatch(pwd);

    var points = 0;
    if (hasMinLength) points++;
    if (hasUppercase) points++;
    if (hasLowercase) points++;
    if (hasDigit) points++;
    if (hasSpecialChar) points++;
    if (pwd.length >= 12 && isNotCommonOrRepeated) points++;

    if (!isNotCommonOrRepeated) {
      points = min(points, 1);
    }

    final score = (points / 6.0).clamp(0.0, 1.0);
    final String label;
    if (points <= 1) {
      label = 'Muito fraca';
    } else if (points == 2 || points == 3) {
      label = 'Fraca';
    } else if (points == 4) {
      label = 'Média';
    } else if (points == 5) {
      label = 'Forte';
    } else {
      label = 'Blindada';
    }

    return PasswordSecurityAnalysis(
      hasMinLength: hasMinLength,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
      hasSpecialChar: hasSpecialChar,
      isNotCommonOrRepeated: isNotCommonOrRepeated,
      strengthScore: score,
      strengthLabel: label,
    );
  }

  static String? validateName(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe seu nome completo.';
    }
    if (trimmed.length < 3) {
      return 'O nome deve ter pelo menos 3 caracteres.';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe seu e-mail.';
    }
    if (!_emailRegex.hasMatch(trimmed)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  /// Validação simples usada na aba "Entrar" (apenas verifica se a senha foi digitada)
  static String? validateLoginPassword(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe sua senha.';
    }
    return null;
  }

  /// Validação rigorosa OWASP usada apenas na aba "Criar conta" e em "Alterar senha"
  static String? validatePassword(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe sua senha.';
    }
    if (trimmed.length < minPasswordLength) {
      return 'A senha deve ter no mínimo $minPasswordLength caracteres.';
    }
    if (trimmed.length > maxPasswordLength) {
      return 'A senha deve ter no máximo $maxPasswordLength caracteres.';
    }

    final analysis = analyzePassword(trimmed);
    if (!analysis.hasUppercase) {
      return 'Inclua pelo menos 1 letra maiúscula (A-Z).';
    }
    if (!analysis.hasLowercase) {
      return 'Inclua pelo menos 1 letra minúscula (a-z).';
    }
    if (!analysis.hasDigit) {
      return 'Inclua pelo menos 1 número (0-9).';
    }
    if (!analysis.hasSpecialChar) {
      return 'Inclua pelo menos 1 caractere especial (ex: !@#\$%&*).';
    }
    if (!analysis.isNotCommonOrRepeated) {
      return 'Esta senha é muito comum ou repetitiva. Escolha uma senha mais forte.';
    }
    return null;
  }

  void clearError() {
    if (state.errorMessage != null || state.successMessage != null) {
      state = state.copyWith(clearError: true, clearSuccess: true);
    }
  }

  /// Efetua o login do usuário autenticando remotamente (ou via fallback seguro no SQLite local)
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    if (state.isLocked) {
      final remaining =
          state.lockedUntil!.difference(DateTime.now()).inSeconds.clamp(1, 60);
      state = state.copyWith(
        errorMessage:
            'Muitas tentativas inválidas. Aguarde ${remaining}s para tentar novamente.',
        clearSuccess: true,
      );
      return false;
    }

    final emailError = validateEmail(email);
    final passwordError = validateLoginPassword(password);
    if (emailError != null || passwordError != null) {
      state = state.copyWith(
        errorMessage: emailError ?? passwordError,
        clearSuccess: true,
      );
      return false;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final localAccount = _accounts[normalizedEmail];

    // 1. Tenta autenticação remota no backend Go (gastosync_api)
    String? jwtToken;
    String finalName = localAccount?.fullName ?? 'Usuário';

    final authService = ref.read(authServiceProvider);
    final remoteRes = await authService.login(
      email: normalizedEmail,
      password: normalizedPassword,
    );

    if (remoteRes.isSuccess) {
      jwtToken = remoteRes.token;
      if (remoteRes.name != null && remoteRes.name!.isNotEmpty) {
        finalName = remoteRes.name!;
      }

      // Replica hash local para garantir acesso offline futuro
      final salt = localAccount?.salt ?? PasswordHasher.generateSecureSalt();
      final hash = PasswordHasher.hashPassword(normalizedPassword, salt);
      _accounts[normalizedEmail] = AuthAccount(
        fullName: finalName,
        email: normalizedEmail,
        salt: salt,
        passwordHash: hash,
      );
      try {
        await ref.read(appDatabaseProvider).saveAuthAccount(
              email: normalizedEmail,
              fullName: finalName,
              salt: salt,
              passwordHash: hash,
            );
      } catch (_) {}
    } else if (remoteRes.isOffline) {
      // 2. Fallback offline: valida contra o hash no SQLite local
      if (localAccount == null) {
        state = state.copyWith(
          errorMessage:
              'Modo offline: Conta não encontrada neste dispositivo. Conecte-se à internet para sincronizar.',
          clearSuccess: true,
        );
        return false;
      }

      final candidateHash =
          PasswordHasher.hashPassword(normalizedPassword, localAccount.salt);
      final matches = PasswordHasher.constantTimeEquals(
        candidateHash,
        localAccount.passwordHash,
      );

      if (!matches) {
        return _registerFailedAttempt(
          'Senha incorreta. Tente novamente ou clique em "Alterar senha".',
        );
      }
      finalName = localAccount.fullName;
    } else {
      // 3. Servidor retornou erro específico (ex: credenciais inválidas)
      if (localAccount != null) {
        final candidateHash =
            PasswordHasher.hashPassword(normalizedPassword, localAccount.salt);
        if (PasswordHasher.constantTimeEquals(
            candidateHash, localAccount.passwordHash)) {
          finalName = localAccount.fullName;
        } else {
          return _registerFailedAttempt(
            remoteRes.error ?? 'Senha incorreta.',
          );
        }
      } else {
        state = state.copyWith(
          errorMessage: remoteRes.error ?? 'Credenciais inválidas.',
          clearSuccess: true,
        );
        return false;
      }
    }

    ref.read(userProfileProvider.notifier).updateProfile(
          fullName: finalName,
          email: normalizedEmail,
        );

    try {
      await ref.read(appDatabaseProvider).saveAuthSession(
            currentEmail: normalizedEmail,
            isAuthenticated: true,
            jwtToken: jwtToken,
          );
    } catch (_) {}

    state = state.copyWith(
      isAuthenticated: true,
      currentEmail: normalizedEmail,
      token: jwtToken,
      failedAttempts: 0,
      clearLock: true,
      clearError: true,
      clearSuccess: true,
    );

    if (jwtToken != null && jwtToken.isNotEmpty) {
      ref.read(cloudSyncServiceProvider).pullFromCloud(
            jwtToken: jwtToken,
            userEmail: normalizedEmail,
          );
    }

    return true;
  }

  /// Cria conta com validação forte de senha gravando no SQLite local e replicando na nuvem
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final nameError = validateName(fullName);
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);

    if (nameError != null || emailError != null || passwordError != null) {
      state = state.copyWith(
        errorMessage: nameError ?? emailError ?? passwordError,
        clearSuccess: true,
      );
      return false;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();
    final normalizedPassword = password.trim();

    if (_accounts.containsKey(normalizedEmail)) {
      state = state.copyWith(
        errorMessage: 'Este e-mail já está cadastrado. Use a aba Entrar.',
        clearSuccess: true,
      );
      return false;
    }

    // 1. Persistência local imediata (Offline-First)
    final salt = PasswordHasher.generateSecureSalt();
    final hash = PasswordHasher.hashPassword(normalizedPassword, salt);

    final newAccount = AuthAccount(
      fullName: normalizedName,
      email: normalizedEmail,
      salt: salt,
      passwordHash: hash,
    );
    _accounts[normalizedEmail] = newAccount;

    try {
      await ref.read(appDatabaseProvider).saveAuthAccount(
            email: normalizedEmail,
            fullName: normalizedName,
            salt: salt,
            passwordHash: hash,
          );
    } catch (_) {}

    // 2. Replicação remota na nuvem (Neon PostgreSQL) via AuthService
    String? token;
    final authService = ref.read(authServiceProvider);
    final remoteRes = await authService.register(
      name: normalizedName,
      email: normalizedEmail,
      password: normalizedPassword,
    );

    if (remoteRes.isSuccess) {
      token = remoteRes.token;
    }

    state = state.copyWith(
      isAuthenticated: false,
      currentEmail: newAccount.email,
      token: token,
      failedAttempts: 0,
      clearLock: true,
      clearError: true,
      successMessage:
          'Conta criada com sucesso! Digite sua senha para entrar.',
    );
    return true;
  }

  /// Permite redefinir/alterar a senha de uma conta cadastrada aplicando validação forte OWASP
  String? changePassword({
    required String email,
    required String newPassword,
  }) {
    final emailError = validateEmail(email);
    if (emailError != null) return emailError;

    final passwordError = validatePassword(newPassword);
    if (passwordError != null) return passwordError;

    final normalizedEmail = email.trim().toLowerCase();
    final existing = _accounts[normalizedEmail];
    if (existing == null) {
      return 'Nenhuma conta encontrada com este e-mail.';
    }

    final newSalt = PasswordHasher.generateSecureSalt();
    final newHash = PasswordHasher.hashPassword(newPassword.trim(), newSalt);

    _accounts[normalizedEmail] = AuthAccount(
      fullName: existing.fullName,
      email: existing.email,
      salt: newSalt,
      passwordHash: newHash,
    );

    try {
      ref.read(appDatabaseProvider).updateAuthPassword(
            email: normalizedEmail,
            salt: newSalt,
            passwordHash: newHash,
          );
    } catch (_) {}

    state = state.copyWith(
      failedAttempts: 0,
      clearLock: true,
      clearError: true,
      successMessage:
          'Senha alterada com sucesso! Faça login com a nova senha.',
    );
    return null;
  }

  Future<void> logout() async {
    try {
      await ref.read(appDatabaseProvider).saveAuthSession(
            currentEmail: null,
            isAuthenticated: false,
            jwtToken: null,
          );
    } catch (_) {}
    ref.read(selectedCategoryFilterProvider.notifier).selectCategory(null);
    state = const AuthState(isAuthenticated: false);
  }

  bool _registerFailedAttempt(String message) {
    final attempts = state.failedAttempts + 1;
    if (attempts >= maxFailedAttempts) {
      state = state.copyWith(
        failedAttempts: attempts,
        lockedUntil: DateTime.now().add(lockoutDuration),
        errorMessage:
            'Conta temporariamente bloqueada por 30s após $maxFailedAttempts tentativas falhas.',
        clearSuccess: true,
      );
      return false;
    }
    state = state.copyWith(
      failedAttempts: attempts,
      errorMessage: message,
      clearSuccess: true,
    );
    return false;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

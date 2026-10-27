import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/domain/models/user_profile.dart';

/// Hash seguro determinístico e 100% compatível com Dart VM (Mobile/Desktop) e JavaScript/WASM (Web)
class PasswordHasher {
  PasswordHasher._();

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password::gastosync_2026');
    // 4 lanes independentes de 32 bits (seguro para números de 53 bits do JS na Web)
    var h0 = 0x811c9dc5;
    var h1 = 0x9e3779b9;
    var h2 = 0x6a09e667;
    var h3 = 0xbb67ae85;

    for (var round = 0; round < 64; round++) {
      for (var i = 0; i < bytes.length; i++) {
        final b = (bytes[i] + round + i) & 0xff;
        h0 = ((h0 ^ b) * 0x01000193) & 0x7fffffff;
        h1 = ((h1 ^ ((b << 3) & 0xff)) * 0x01000193) & 0x7fffffff;
        h2 = ((h2 + b + (h0 & 0xffff)) * 0x01000193) & 0x7fffffff;
        h3 = ((h3 ^ b ^ (h1 & 0xffff)) * 0x01000193) & 0x7fffffff;
      }
    }

    return [h0, h1, h2, h3]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }

  /// Comparação em tempo constante para evitar ataques de timing
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
    this.failedAttempts = 0,
    this.lockedUntil,
    this.errorMessage,
  });

  final bool isAuthenticated;
  final String? currentEmail;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? errorMessage;

  bool get isLocked =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  AuthState copyWith({
    bool? isAuthenticated,
    String? currentEmail,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      currentEmail: currentEmail ?? this.currentEmail,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const String defaultDemoEmail = 'marcos.pereira@gastosync.local';
  static const String defaultDemoPassword = '12345678';
  static const String defaultDemoName = 'Marcos Pereira';
  static const int minPasswordLength = 8;
  static const int maxFailedAttempts = 5;
  static const Duration lockoutDuration = Duration(seconds: 30);

  final Map<String, AuthAccount> _accounts = <String, AuthAccount>{};

  @override
  AuthState build() {
    _seedDefaultAccount();
    return const AuthState(isAuthenticated: false);
  }

  void _seedDefaultAccount() {
    const salt = 'gs_default_salt_2026';
    final hash = PasswordHasher.hashPassword(defaultDemoPassword, salt);
    _accounts[defaultDemoEmail] = AuthAccount(
      fullName: defaultDemoName,
      email: defaultDemoEmail,
      salt: salt,
      passwordHash: hash,
    );
  }

  static final RegExp _emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

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

  static String? validatePassword(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Informe sua senha.';
    }
    if (trimmed.length < minPasswordLength) {
      return 'A senha deve ter no mínimo $minPasswordLength caracteres.';
    }
    return null;
  }

  void clearError() {
    if (state.errorMessage != null) {
      state = state.copyWith(clearError: true);
    }
  }

  static String _nameFromEmail(String email) {
    final local = email.split('@').first;
    final words = local
        .split(RegExp(r'[._\-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    return words.isEmpty ? 'Usuário GastoSync' : words.join(' ');
  }

  bool login({
    required String email,
    required String password,
  }) {
    if (state.isLocked) {
      final remaining =
          state.lockedUntil!.difference(DateTime.now()).inSeconds.clamp(1, 30);
      state = state.copyWith(
        errorMessage:
            'Muitas tentativas inválidas. Aguarde ${remaining}s para tentar novamente.',
      );
      return false;
    }

    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);
    if (emailError != null || passwordError != null) {
      state = state.copyWith(
        errorMessage: emailError ?? passwordError,
      );
      return false;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    var account = _accounts[normalizedEmail];

    if (account == null) {
      // Primeiro acesso local deste e-mail: registra automaticamente a credencial com hash
      final salt = 'gs_salt_${normalizedEmail.hashCode}';
      final hash = PasswordHasher.hashPassword(normalizedPassword, salt);
      account = AuthAccount(
        fullName: _nameFromEmail(normalizedEmail),
        email: normalizedEmail,
        salt: salt,
        passwordHash: hash,
      );
      _accounts[normalizedEmail] = account;
    } else {
      final candidateHash =
          PasswordHasher.hashPassword(normalizedPassword, account.salt);
      final matches = PasswordHasher.constantTimeEquals(
        candidateHash,
        account.passwordHash,
      );

      if (!matches) {
        return _registerFailedAttempt('Senha incorreta para este e-mail.');
      }
    }

    ref.read(userProfileProvider.notifier).updateProfile(
          fullName: account.fullName,
          email: account.email,
        );

    state = state.copyWith(
      isAuthenticated: true,
      currentEmail: account.email,
      failedAttempts: 0,
      clearLock: true,
      clearError: true,
    );
    return true;
  }

  bool register({
    required String fullName,
    required String email,
    required String password,
  }) {
    final nameError = validateName(fullName);
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);

    if (nameError != null || emailError != null || passwordError != null) {
      state = state.copyWith(
        errorMessage: nameError ?? emailError ?? passwordError,
      );
      return false;
    }

    final normalizedEmail = email.trim().toLowerCase();
    final normalizedName = fullName.trim();
    final normalizedPassword = password.trim();

    if (_accounts.containsKey(normalizedEmail)) {
      state = state.copyWith(
        errorMessage: 'Este e-mail já está cadastrado. Use a aba Entrar.',
      );
      return false;
    }

    final salt = 'gs_salt_${normalizedEmail.hashCode}';
    final hash = PasswordHasher.hashPassword(normalizedPassword, salt);

    final newAccount = AuthAccount(
      fullName: normalizedName,
      email: normalizedEmail,
      salt: salt,
      passwordHash: hash,
    );
    _accounts[normalizedEmail] = newAccount;

    ref.read(userProfileProvider.notifier).updateProfile(
          fullName: newAccount.fullName,
          email: newAccount.email,
        );

    state = state.copyWith(
      isAuthenticated: true,
      currentEmail: newAccount.email,
      failedAttempts: 0,
      clearLock: true,
      clearError: true,
    );
    return true;
  }

  void logout() {
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
      );
      return false;
    }
    state = state.copyWith(
      failedAttempts: attempts,
      errorMessage: message,
    );
    return false;
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

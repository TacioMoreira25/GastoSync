import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/data/services/auth_service.dart';

@immutable
class UserProfile {
  const UserProfile({
    this.fullName = 'Marcos Pereira',
    this.email = 'marcos.pereira@gastosync.local',
    this.accountLabel = 'Conta pessoal',
    this.monthlyBaseIncome = 8500.0,
    this.savingsRateTarget = 20.0,
    this.reminderTime1 = '09:00',
    this.reminderTime2 = '18:00',
    this.emailBillNotifications = true,
    this.jwtToken,
  });

  final String fullName;
  final String email;
  final String accountLabel;
  final double monthlyBaseIncome;
  final double savingsRateTarget;
  final String reminderTime1;
  final String reminderTime2;
  final bool emailBillNotifications;
  final String? jwtToken;

  /// Teto mensal recomendado de despesas considerando a meta de poupança
  double get monthlyExpenseCeiling =>
      monthlyBaseIncome * (1.0 - (savingsRateTarget.clamp(0.0, 100.0) / 100.0));

  /// Retorna o primeiro nome para saudação dinâmica ("Olá, {nome}") com fallback seguro
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Investidor';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.first;
  }

  /// Calcula dinamicamente as iniciais do usuário (ex: "Marcos Pereira" -> "MP")
  String get initials {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'GS';
    final parts = trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'GS';
    if (parts.length == 1) {
      final word = parts.first.toUpperCase();
      return word.length >= 2 ? word.substring(0, 2) : word;
    }
    final firstInitial = parts.first[0].toUpperCase();
    final lastInitial = parts.last[0].toUpperCase();
    return '$firstInitial$lastInitial';
  }

  UserProfile copyWith({
    String? fullName,
    String? email,
    String? accountLabel,
    double? monthlyBaseIncome,
    double? savingsRateTarget,
    String? reminderTime1,
    String? reminderTime2,
    bool? emailBillNotifications,
    String? jwtToken,
    bool clearToken = false,
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      accountLabel: accountLabel ?? this.accountLabel,
      monthlyBaseIncome: monthlyBaseIncome ?? this.monthlyBaseIncome,
      savingsRateTarget: savingsRateTarget ?? this.savingsRateTarget,
      reminderTime1: reminderTime1 ?? this.reminderTime1,
      reminderTime2: reminderTime2 ?? this.reminderTime2,
      emailBillNotifications:
          emailBillNotifications ?? this.emailBillNotifications,
      jwtToken: clearToken ? null : (jwtToken ?? this.jwtToken),
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => const UserProfile();

  Future<bool> updateProfile({
    String? fullName,
    String? email,
    String? accountLabel,
    double? monthlyBaseIncome,
    double? savingsRateTarget,
    String? reminderTime1,
    String? reminderTime2,
    bool? emailBillNotifications,
    String? jwtToken,
    bool syncToCloud = true,
  }) async {
    state = state.copyWith(
      fullName: fullName,
      email: email,
      accountLabel: accountLabel,
      monthlyBaseIncome: monthlyBaseIncome,
      savingsRateTarget: savingsRateTarget,
      reminderTime1: reminderTime1,
      reminderTime2: reminderTime2,
      emailBillNotifications: emailBillNotifications,
      jwtToken: jwtToken,
    );

    final activeToken = state.jwtToken;
    if (!syncToCloud || activeToken == null || activeToken.trim().isEmpty) {
      return true;
    }

    final res = await ref.read(authServiceProvider).updateRemoteProfile(
          token: activeToken,
          name: state.fullName,
          monthlyIncome: state.monthlyBaseIncome,
          savingsGoalPercent: state.savingsRateTarget,
          reminderTime1: state.reminderTime1,
          reminderTime2: state.reminderTime2,
          emailBillNotifications: state.emailBillNotifications,
        );

    if (res.isSuccess) {
      state = state.copyWith(
        fullName: res.name,
        monthlyBaseIncome: res.monthlyIncome,
        savingsRateTarget: res.savingsGoalPercent,
        reminderTime1: res.reminderTime1,
        reminderTime2: res.reminderTime2,
        emailBillNotifications: res.emailBillNotifications,
      );
      return true;
    }

    return false;
  }

  Future<bool> updateBillNotificationPreferences({
    String? reminderTime1,
    String? reminderTime2,
    bool? emailBillNotifications,
  }) {
    return updateProfile(
      reminderTime1: reminderTime1,
      reminderTime2: reminderTime2,
      emailBillNotifications: emailBillNotifications,
      syncToCloud: true,
    );
  }

  void clearSessionToken() {
    state = state.copyWith(clearToken: true);
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

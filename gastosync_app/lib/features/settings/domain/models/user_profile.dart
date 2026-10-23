import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class UserProfile {
  const UserProfile({
    this.fullName = 'Marcos Pereira',
    this.email = 'marcos.pereira@gastosync.local',
    this.accountLabel = 'Conta pessoal',
    this.monthlyBaseIncome = 8500.0,
    this.savingsRateTarget = 20.0,
  });

  final String fullName;
  final String email;
  final String accountLabel;
  final double monthlyBaseIncome;
  final double savingsRateTarget;

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
  }) {
    return UserProfile(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      accountLabel: accountLabel ?? this.accountLabel,
      monthlyBaseIncome: monthlyBaseIncome ?? this.monthlyBaseIncome,
      savingsRateTarget: savingsRateTarget ?? this.savingsRateTarget,
    );
  }
}

class UserProfileNotifier extends Notifier<UserProfile> {
  @override
  UserProfile build() => const UserProfile();

  void updateProfile({
    String? fullName,
    String? email,
    String? accountLabel,
    double? monthlyBaseIncome,
    double? savingsRateTarget,
  }) {
    state = state.copyWith(
      fullName: fullName,
      email: email,
      accountLabel: accountLabel,
      monthlyBaseIncome: monthlyBaseIncome,
      savingsRateTarget: savingsRateTarget,
    );
  }
}

final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

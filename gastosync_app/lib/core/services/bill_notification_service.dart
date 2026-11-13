import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/settings/domain/models/user_profile.dart';
import '../../features/transactions/domain/models/bill.dart';
import '../../features/transactions/presentation/controllers/transactions_controller.dart';
import '../widgets/gastosync_notifications_modal.dart';

/// Representa uma janela de turno diário de lembrete de boletos (1º ou 2º turno).
@immutable
class BillReminderShiftWindow {
  const BillReminderShiftWindow({
    required this.dateKey,
    required this.shiftNumber,
    required this.configuredTime,
    required this.scheduledMinutes,
  });

  /// Data civil no formato `YYYY-MM-DD`
  final String dateKey;

  /// Número do turno no dia (`1` ou `2`)
  final int shiftNumber;

  /// Horário configurado pelo usuário (`HH:MM`)
  final String configuredTime;

  /// Minutos desde `00:00`
  final int scheduledMinutes;

  /// Chave única de deduplicação por usuário, dia e turno
  String deduplicationKey(String userEmail) =>
      '${userEmail.trim().toLowerCase()}|$dateKey|shift_$shiftNumber|$configuredTime';
}

/// Resumo dos boletos acionáveis em uma verificação de turno.
@immutable
class BillAlertSummary {
  const BillAlertSummary({
    required this.overdueBills,
    required this.dueTodayBills,
    required this.upcomingBills,
    required this.totalRealPayable,
    required this.creditCardChargeCount,
  });

  final List<Bill> overdueBills;
  final List<Bill> dueTodayBills;
  final List<Bill> upcomingBills;
  final double totalRealPayable;
  final int creditCardChargeCount;

  int get totalActionableCount =>
      overdueBills.length + dueTodayBills.length + upcomingBills.length;

  bool get hasActionableBills => totalActionableCount > 0;

  bool get hasUrgentBills =>
      overdueBills.isNotEmpty || dueTodayBills.isNotEmpty;
}

/// Estado reativo do serviço de notificações de boletos 2x ao dia (`T021`).
@immutable
class BillNotificationState {
  const BillNotificationState({
    this.dispatchedShiftKeys = const <String>{},
    this.lastTriggeredShift,
    this.lastTriggeredAt,
    this.lastAlertTitle,
    this.lastAlertMessage,
  });

  final Set<String> dispatchedShiftKeys;
  final BillReminderShiftWindow? lastTriggeredShift;
  final DateTime? lastTriggeredAt;
  final String? lastAlertTitle;
  final String? lastAlertMessage;

  BillNotificationState copyWith({
    Set<String>? dispatchedShiftKeys,
    BillReminderShiftWindow? lastTriggeredShift,
    DateTime? lastTriggeredAt,
    String? lastAlertTitle,
    String? lastAlertMessage,
  }) {
    return BillNotificationState(
      dispatchedShiftKeys: dispatchedShiftKeys ?? this.dispatchedShiftKeys,
      lastTriggeredShift: lastTriggeredShift ?? this.lastTriggeredShift,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      lastAlertTitle: lastAlertTitle ?? this.lastAlertTitle,
      lastAlertMessage: lastAlertMessage ?? this.lastAlertMessage,
    );
  }
}

/// Serviço responsável por avaliar as duas janelas diárias de lembretes de boletos
/// (`reminderTime1` e `reminderTime2`), controlar o estado de envio por turno para
/// impedir alertas duplicados na mesma janela e acionar alertas locais no dispositivo/navegador (`T021`).
class BillNotificationService extends Notifier<BillNotificationState> {
  Timer? _periodicTimer;

  @override
  BillNotificationState build() {
    // Observa mudanças no perfil (horários configurados) e na lista de boletos locais
    final profile = ref.watch(userProfileProvider);
    final billsAsync = ref.watch(watchBillsProvider);

    ref.onDispose(() {
      _periodicTimer?.cancel();
      _periodicTimer = null;
    });

    _startPeriodicChecker();

    final bills = billsAsync.value;
    if (bills != null && bills.isNotEmpty) {
      Future.microtask(() {
        evaluateAndDispatchIfDue(
          profile: profile,
          bills: bills,
        );
      });
    }

    return const BillNotificationState();
  }

  void _startPeriodicChecker() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final profile = ref.read(userProfileProvider);
      final bills = ref.read(watchBillsProvider).value ?? const <Bill>[];
      if (bills.isEmpty) return;
      evaluateAndDispatchIfDue(
        profile: profile,
        bills: bills,
      );
    });
  }

  /// Converte uma string `HH:MM` (24h) para minutos desde a meia-noite (`0`..`1439`).
  static int? parseMinutesFromMidnight(String rawTime) {
    final trimmed = rawTime.trim();
    final parts = trimmed.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour * 60) + minute;
  }

  /// Normaliza um horário `HH:MM`, usando `fallback` caso inválido.
  static String normalizeTimeOrFallback(String rawTime, String fallback) {
    final minutes = parseMinutesFromMidnight(rawTime);
    if (minutes == null) return fallback;
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Determina qual janela diária (`1º turno` ou `2º turno`) está ativa no momento `now`.
  /// Retorna `null` caso o horário atual ainda seja anterior ao 1º turno do dia.
  static BillReminderShiftWindow? resolveActiveShiftWindow(
    DateTime now, {
    required String reminderTime1,
    required String reminderTime2,
  }) {
    final norm1 = normalizeTimeOrFallback(reminderTime1, '09:00');
    final norm2 = normalizeTimeOrFallback(reminderTime2, '18:00');
    final min1 = parseMinutesFromMidnight(norm1) ?? (9 * 60);
    final min2 = parseMinutesFromMidnight(norm2) ?? (18 * 60);

    // Ordena os dois turnos cronologicamente no dia
    final firstTime = min1 <= min2 ? norm1 : norm2;
    final firstMin = min1 <= min2 ? min1 : min2;
    final secondTime = min1 <= min2 ? norm2 : norm1;
    final secondMin = min1 <= min2 ? min2 : min1;

    final currentMinutes = (now.hour * 60) + now.minute;
    final dateKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    if (currentMinutes >= secondMin) {
      return BillReminderShiftWindow(
        dateKey: dateKey,
        shiftNumber: 2,
        configuredTime: secondTime,
        scheduledMinutes: secondMin,
      );
    }

    if (currentMinutes >= firstMin) {
      return BillReminderShiftWindow(
        dateKey: dateKey,
        shiftNumber: 1,
        configuredTime: firstTime,
        scheduledMinutes: firstMin,
      );
    }

    return null;
  }

  /// Retorna uma descrição amigável do próximo horário de lembrete programado.
  static String describeNextReminderWindow(
    DateTime now, {
    required String reminderTime1,
    required String reminderTime2,
  }) {
    final norm1 = normalizeTimeOrFallback(reminderTime1, '09:00');
    final norm2 = normalizeTimeOrFallback(reminderTime2, '18:00');
    final min1 = parseMinutesFromMidnight(norm1) ?? (9 * 60);
    final min2 = parseMinutesFromMidnight(norm2) ?? (18 * 60);

    final firstTime = min1 <= min2 ? norm1 : norm2;
    final firstMin = min1 <= min2 ? min1 : min2;
    final secondTime = min1 <= min2 ? norm2 : norm1;
    final secondMin = min1 <= min2 ? min2 : min1;

    final currentMinutes = (now.hour * 60) + now.minute;
    if (currentMinutes < firstMin) {
      return 'Hoje às $firstTime (1º turno)';
    }
    if (currentMinutes < secondMin) {
      return 'Hoje às $secondTime (2º turno)';
    }
    return 'Amanhã às $firstTime (1º turno)';
  }

  /// Classifica todos os boletos não pagos com vencimento `<= hoje + 3 dias` (vencidos, hoje e próximos).
  static BillAlertSummary summarizeActionableBills(
    List<Bill> bills, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final overdue = <Bill>[];
    final dueToday = <Bill>[];
    final upcoming = <Bill>[];
    double totalRealPayable = 0.0;
    int creditCardCount = 0;

    for (final bill in bills) {
      if (bill.isPaid || bill.deletedAt != null) continue;
      final diffDays = bill.daysUntilDue(reference);
      if (diffDays > 3) continue;

      if (diffDays < 0) {
        overdue.add(bill);
      } else if (diffDays == 0) {
        dueToday.add(bill);
      } else {
        upcoming.add(bill);
      }

      if (bill.isCreditCardCharge) {
        creditCardCount++;
      } else {
        totalRealPayable += bill.amount;
      }
    }

    overdue.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    dueToday.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    upcoming.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return BillAlertSummary(
      overdueBills: overdue,
      dueTodayBills: dueToday,
      upcomingBills: upcoming,
      totalRealPayable: totalRealPayable,
      creditCardChargeCount: creditCardCount,
    );
  }

  /// Avalia se o turno atual já foi notificado e, caso haja boletos vencidos/vencendo,
  /// dispara o alerta local/navegador exatamente uma vez por janela de turno.
  bool evaluateAndDispatchIfDue({
    UserProfile? profile,
    List<Bill>? bills,
    DateTime? now,
    bool forceDispatch = false,
  }) {
    final UserProfile effectiveProfile =
        profile ?? ref.read(userProfileProvider);
    final List<Bill> effectiveBills =
        bills ?? ref.read(watchBillsProvider).value ?? const <Bill>[];
    final DateTime referenceNow = now ?? DateTime.now();

    final summary = summarizeActionableBills(
      effectiveBills,
      now: referenceNow,
    );
    if (!summary.hasActionableBills) {
      return false;
    }

    final activeWindow = resolveActiveShiftWindow(
      referenceNow,
      reminderTime1: effectiveProfile.reminderTime1,
      reminderTime2: effectiveProfile.reminderTime2,
    );

    if (activeWindow == null && !forceDispatch) {
      return false;
    }

    final effectiveWindow = activeWindow ??
        BillReminderShiftWindow(
          dateKey:
              '${referenceNow.year.toString().padLeft(4, '0')}-${referenceNow.month.toString().padLeft(2, '0')}-${referenceNow.day.toString().padLeft(2, '0')}',
          shiftNumber: 1,
          configuredTime: normalizeTimeOrFallback(
            effectiveProfile.reminderTime1,
            '09:00',
          ),
          scheduledMinutes:
              parseMinutesFromMidnight(effectiveProfile.reminderTime1) ?? 540,
        );

    final dedupKey = effectiveWindow.deduplicationKey(effectiveProfile.email);
    if (!forceDispatch && state.dispatchedShiftKeys.contains(dedupKey)) {
      return false;
    }

    final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final title = _buildAlertTitle(summary, effectiveWindow);
    final message = _buildAlertMessage(summary, currencyFmt);

    // Registra o turno como disparado antes de emitir efeitos colaterais para evitar reentrância
    state = state.copyWith(
      dispatchedShiftKeys: {...state.dispatchedShiftKeys, dedupKey},
      lastTriggeredShift: effectiveWindow,
      lastTriggeredAt: referenceNow,
      lastAlertTitle: title,
      lastAlertMessage: message,
    );

    // Aciona feedback sonoro/háptico nativo do dispositivo/navegador
    _triggerDeviceAlertSound();

    // Publica o alerta de turno na Central de Notificações do GastoSync
    ref.read(notificationsControllerProvider.notifier).pushCustomNotification(
          id: 'bill-shift-${effectiveWindow.dateKey}-s${effectiveWindow.shiftNumber}',
          title: title,
          message: message,
          severity: summary.hasUrgentBills
              ? NotificationSeverity.critical
              : NotificationSeverity.warning,
          categoryLabel:
              'Boletos • ${effectiveWindow.shiftNumber}º Turno (${effectiveWindow.configuredTime})',
          icon: summary.hasUrgentBills
              ? Icons.notification_important_rounded
              : Icons.receipt_long_rounded,
          actionLabel: 'Ver Boletos a Pagar',
          actionType: NotificationActionType.goTransactions,
        );

    return true;
  }

  String _buildAlertTitle(
    BillAlertSummary summary,
    BillReminderShiftWindow window,
  ) {
    if (summary.overdueBills.isNotEmpty && summary.dueTodayBills.isNotEmpty) {
      return 'Atenção (${window.configuredTime}): ${summary.overdueBills.length} vencido(s) e ${summary.dueTodayBills.length} vence(m) hoje!';
    }
    if (summary.overdueBills.isNotEmpty) {
      final count = summary.overdueBills.length;
      return count == 1
          ? 'Boleto em atraso: "${summary.overdueBills.first.description}"'
          : 'Atenção: $count boletos estão em atraso!';
    }
    if (summary.dueTodayBills.isNotEmpty) {
      final count = summary.dueTodayBills.length;
      return count == 1
          ? 'Vence hoje: "${summary.dueTodayBills.first.description}"'
          : 'Lembrete (${window.configuredTime}): $count boletos vencem hoje!';
    }
    final count = summary.upcomingBills.length;
    return count == 1
        ? 'Próximo vencimento: "${summary.upcomingBills.first.description}"'
        : 'Lembrete (${window.configuredTime}): $count boletos vencem nos próximos 3 dias';
  }

  String _buildAlertMessage(
    BillAlertSummary summary,
    NumberFormat currencyFmt,
  ) {
    final parts = <String>[];
    if (summary.overdueBills.isNotEmpty) {
      parts.add('${summary.overdueBills.length} em atraso');
    }
    if (summary.dueTodayBills.isNotEmpty) {
      parts.add('${summary.dueTodayBills.length} vencendo hoje');
    }
    if (summary.upcomingBills.isNotEmpty) {
      parts.add('${summary.upcomingBills.length} em até 3 dias');
    }

    final statusSummary = parts.join(', ');
    if (summary.totalRealPayable > 0 && summary.creditCardChargeCount > 0) {
      return 'Você possui $statusSummary. Total líquido a pagar: ${currencyFmt.format(summary.totalRealPayable)} (+ ${summary.creditCardChargeCount} cobrança(s) no cartão — lembre-se de liberar o limite).';
    }
    if (summary.totalRealPayable > 0) {
      return 'Você possui $statusSummary, somando ${currencyFmt.format(summary.totalRealPayable)} em boletos pendentes. Toque para copiar o código ou dar baixa.';
    }
    return 'Você possui $statusSummary (${summary.creditCardChargeCount} cobrança(s) agendadas na fatura do cartão). Verifique o limite disponível no seu cartão.';
  }

  void _triggerDeviceAlertSound() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      // Ignora silenciosamente caso a plataforma não suporte alerta sonoro de sistema
    }
  }
}

final billNotificationServiceProvider =
    NotifierProvider<BillNotificationService, BillNotificationState>(
  BillNotificationService.new,
);

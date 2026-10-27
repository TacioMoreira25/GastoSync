import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/dashboard/domain/services/financial_health_engine.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/settings/domain/models/user_profile.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../../features/transactions/presentation/controllers/transactions_controller.dart';
import '../database/app_database.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';
import 'gastosync_top_header.dart';

enum NotificationSeverity {
  critical,
  warning,
  success,
  info,
  ai,
}

enum NotificationActionType {
  syncNow,
  goDashboard,
  goTransactions,
  goPlanning,
  goMore,
  openAiChat,
}

class GastoSyncNotificationItem {
  const GastoSyncNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.severity,
    required this.categoryLabel,
    required this.icon,
    required this.isRead,
    this.actionLabel,
    this.actionType,
  });

  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationSeverity severity;
  final String categoryLabel;
  final IconData icon;
  final bool isRead;
  final String? actionLabel;
  final NotificationActionType? actionType;
}

class NotificationsQuickState {
  const NotificationsQuickState({
    this.readIds = const <String>{},
    this.dismissedIds = const <String>{},
    this.customItems = const <GastoSyncNotificationItem>[],
  });

  final Set<String> readIds;
  final Set<String> dismissedIds;
  final List<GastoSyncNotificationItem> customItems;

  NotificationsQuickState copyWith({
    Set<String>? readIds,
    Set<String>? dismissedIds,
    List<GastoSyncNotificationItem>? customItems,
  }) {
    return NotificationsQuickState(
      readIds: readIds ?? this.readIds,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      customItems: customItems ?? this.customItems,
    );
  }
}

class NotificationsController extends Notifier<NotificationsQuickState> {
  @override
  NotificationsQuickState build() => const NotificationsQuickState();

  void markAsRead(String id) {
    if (state.readIds.contains(id)) return;
    state = state.copyWith(readIds: {...state.readIds, id});
  }

  void markAllAsRead(Iterable<String> ids) {
    state = state.copyWith(readIds: {...state.readIds, ...ids});
  }

  void dismiss(String id) {
    state = state.copyWith(
      dismissedIds: {...state.dismissedIds, id},
      customItems: state.customItems.where((item) => item.id != id).toList(),
    );
  }

  void clearAll(Iterable<String> ids) {
    state = state.copyWith(
      dismissedIds: {...state.dismissedIds, ...ids},
      customItems: const [],
    );
  }

  void restoreDismissed() {
    state = state.copyWith(
      dismissedIds: const <String>{},
      readIds: const <String>{},
    );
  }

  void pushCustomNotification({
    required String id,
    required String title,
    required String message,
    required NotificationSeverity severity,
    required String categoryLabel,
    required IconData icon,
    String? actionLabel,
    NotificationActionType? actionType,
  }) {
    final item = GastoSyncNotificationItem(
      id: id,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      severity: severity,
      categoryLabel: categoryLabel,
      icon: icon,
      isRead: false,
      actionLabel: actionLabel,
      actionType: actionType,
    );
    final updatedCustom = [
      item,
      ...state.customItems.where((e) => e.id != id),
    ];
    final updatedDismissed = {...state.dismissedIds}..remove(id);
    final updatedRead = {...state.readIds}..remove(id);
    state = state.copyWith(
      customItems: updatedCustom,
      dismissedIds: updatedDismissed,
      readIds: updatedRead,
    );
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsQuickState>(
  NotificationsController.new,
);

/// Provedor reativo que sintetiza alertas financeiros, status de sincronia e insights da IA em tempo real
final gastoSyncNotificationsProvider =
    Provider<List<GastoSyncNotificationItem>>((ref) {
  final quickState = ref.watch(notificationsControllerProvider);
  final transactions =
      ref.watch(watchTransactionsProvider).value ?? const <Transaction>[];
  final budgets =
      ref.watch(watchBudgetsProvider).value ?? const <LocalBudget>[];
  final deletedCategories =
      ref.watch(watchDeletedBudgetCategoriesProvider).value ?? const <String>{};
  final metrics = ref.watch(financialMetricsStreamProvider).value ??
      FinancialHealthEngine.calculate(transactions);
  final latestInsight = ref.watch(latestAgentInsightStreamProvider).value;
  final profile = ref.watch(userProfileProvider);

  final currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  final now = DateTime.now();
  final items = <GastoSyncNotificationItem>[];

  // 0. Notificações disparadas por ações recentes na sessão
  for (final custom in quickState.customItems) {
    if (!quickState.dismissedIds.contains(custom.id)) {
      items.add(
        GastoSyncNotificationItem(
          id: custom.id,
          title: custom.title,
          message: custom.message,
          timestamp: custom.timestamp,
          severity: custom.severity,
          categoryLabel: custom.categoryLabel,
          icon: custom.icon,
          isRead: quickState.readIds.contains(custom.id),
          actionLabel: custom.actionLabel,
          actionType: custom.actionType,
        ),
      );
    }
  }

  // 1. Transações pendentes de sincronização local (Offline-First)
  final pendingTxs = transactions.where((t) => !t.isSynced).toList();
  if (pendingTxs.isNotEmpty) {
    final id = 'sync_pending_${pendingTxs.length}';
    if (!quickState.dismissedIds.contains(id)) {
      final latestPendingDate = pendingTxs.first.date;
      items.add(
        GastoSyncNotificationItem(
          id: id,
          title:
              '${pendingTxs.length} lançamento${pendingTxs.length > 1 ? "s" : ""} pendente${pendingTxs.length > 1 ? "s" : ""} de sincronia',
          message:
              'Salvo com segurança no SQLite local (Offline-First). Toque para sincronizar agora com a nuvem.',
          timestamp: latestPendingDate.isAfter(now) ? now : latestPendingDate,
          severity: NotificationSeverity.warning,
          categoryLabel: 'Offline-First',
          icon: Icons.sync_rounded,
          isRead: quickState.readIds.contains(id),
          actionLabel: 'Sincronizar agora',
          actionType: NotificationActionType.syncNow,
        ),
      );
    }
  }

  // 2. Alertas de Orçamento Mensal por Categoria
  final spentByCategory = <String, double>{};
  for (final tx in transactions) {
    if (tx.isExpense &&
        tx.date.year == now.year &&
        tx.date.month == now.month) {
      final key = tx.category.trim().toLowerCase();
      spentByCategory[key] = (spentByCategory[key] ?? 0.0) + tx.amount;
    }
  }

  for (final budget in budgets) {
    final key = budget.category.trim().toLowerCase();
    if (deletedCategories.contains(key) || budget.limitAmount <= 0) continue;
    final spent = spentByCategory[key] ?? 0.0;
    if (spent <= 0) continue;

    final ratio = spent / budget.limitAmount;
    final percent = (ratio * 100).round();

    if (ratio >= 1.0) {
      final id = 'budget_exceeded_${key}_${now.month}_${now.year}';
      if (!quickState.dismissedIds.contains(id)) {
        items.add(
          GastoSyncNotificationItem(
            id: id,
            title: 'Teto excedido em ${budget.category} ($percent%)',
            message:
                'Você acumulou ${currencyFmt.format(spent)} em despesas neste mês, acima do limite de ${currencyFmt.format(budget.limitAmount)}.',
            timestamp: now.subtract(const Duration(minutes: 5)),
            severity: NotificationSeverity.critical,
            categoryLabel: 'Orçamento',
            icon: Icons.error_outline_rounded,
            isRead: quickState.readIds.contains(id),
            actionLabel: 'Ajustar teto',
            actionType: NotificationActionType.goPlanning,
          ),
        );
      }
    } else if (ratio >= 0.75) {
      final id = 'budget_warning_${key}_${now.month}_${now.year}';
      if (!quickState.dismissedIds.contains(id)) {
        final remaining = math.max(0.0, budget.limitAmount - spent);
        items.add(
          GastoSyncNotificationItem(
            id: id,
            title: '${budget.category} atingiu $percent% da meta',
            message:
                'Restam ${currencyFmt.format(remaining)} disponíveis no orçamento mensal de ${budget.category}.',
            timestamp: now.subtract(const Duration(minutes: 18)),
            severity: NotificationSeverity.warning,
            categoryLabel: 'Orçamento',
            icon: Icons.warning_amber_rounded,
            isRead: quickState.readIds.contains(id),
            actionLabel: 'Ver Planejamento',
            actionType: NotificationActionType.goPlanning,
          ),
        );
      }
    }
  }

  // 3. Alerta de Burn Rate Diário / Projeção de Fim de Mês
  final effectiveIncome = metrics.totalIncome > 0
      ? metrics.totalIncome
      : profile.monthlyBaseIncome;
  final monthlyCeiling =
      effectiveIncome * (1.0 - (profile.savingsRateTarget / 100.0));

  if (metrics.totalExpense > 0 && metrics.monthEndProjection > monthlyCeiling) {
    const id = 'burn_rate_ceiling_warning';
    if (!quickState.dismissedIds.contains(id)) {
      items.add(
        GastoSyncNotificationItem(
          id: id,
          title: 'Ritmo de gastos (Burn Rate) em alerta',
          message:
              'Ao ritmo de ${currencyFmt.format(metrics.dailyBurnRate)}/dia, sua projeção (${currencyFmt.format(metrics.monthEndProjection)}) supera o teto mensal (${currencyFmt.format(monthlyCeiling)}).',
          timestamp: now.subtract(const Duration(minutes: 32)),
          severity: NotificationSeverity.warning,
          categoryLabel: 'Burn Rate',
          icon: Icons.local_fire_department_rounded,
          isRead: quickState.readIds.contains(id),
          actionLabel: 'Ver curva no Dashboard',
          actionType: NotificationActionType.goDashboard,
        ),
      );
    }
  }

  // 4. Último Insight Preditivo salvo pelo Llama 3.3
  if (latestInsight != null) {
    final id = 'ai_insight_${latestInsight.id}';
    if (!quickState.dismissedIds.contains(id)) {
      final confidencePct = (latestInsight.confidenceScore * 100).round();
      items.add(
        GastoSyncNotificationItem(
          id: id,
          title: 'Insight IA • ${latestInsight.categorySuggested}',
          message:
              '${latestInsight.budgetTip} (Confiança preditiva: $confidencePct%).',
          timestamp: latestInsight.createdAt,
          severity: NotificationSeverity.ai,
          categoryLabel: 'Llama 3.3',
          icon: Icons.auto_awesome_rounded,
          isRead: quickState.readIds.contains(id),
          actionLabel: 'Conversar com IA',
          actionType: NotificationActionType.openAiChat,
        ),
      );
    }
  }

  // 5. Status da Meta de Poupança quando há movimentações
  if (metrics.totalIncome > 0) {
    final metGoal = metrics.savingsRate >= profile.savingsRateTarget;
    final id = metGoal ? 'savings_goal_achieved' : 'savings_goal_below';
    if (!quickState.dismissedIds.contains(id)) {
      items.add(
        GastoSyncNotificationItem(
          id: id,
          title: metGoal
              ? 'Meta de poupança atingida (${metrics.savingsRate.toStringAsFixed(1)}%)'
              : 'Poupança abaixo da meta (${metrics.savingsRate.toStringAsFixed(1)}%)',
          message: metGoal
              ? 'Excelente, ${profile.firstName}! Você superou sua meta configurada de ${profile.savingsRateTarget.toStringAsFixed(0)}% da renda.'
              : 'Sua meta é poupar ${profile.savingsRateTarget.toStringAsFixed(0)}% da renda. Peça dicas práticas ao Assistente IA.',
          timestamp: now.subtract(const Duration(hours: 1)),
          severity: metGoal
              ? NotificationSeverity.success
              : NotificationSeverity.info,
          categoryLabel: 'Poupança',
          icon: metGoal ? Icons.savings_rounded : Icons.trending_up_rounded,
          isRead: quickState.readIds.contains(id),
          actionLabel: metGoal ? 'Ver indicadores' : 'Pedir plano à IA',
          actionType: metGoal
              ? NotificationActionType.goPlanning
              : NotificationActionType.openAiChat,
        ),
      );
    }
  }

  // 6. Card de Status de Saúde Financeira & Motor Local
  const healthId = 'financial_health_overview';
  if (!quickState.dismissedIds.contains(healthId)) {
    final displayScore =
        transactions.isEmpty ? 82 : metrics.healthScore.round().clamp(0, 100);
    final statusLabel = displayScore >= 60 ? 'Saudável' : 'Em atenção';
    items.add(
      GastoSyncNotificationItem(
        id: healthId,
        title: 'Score Financeiro: $displayScore/100 · $statusLabel',
        message: transactions.isEmpty
            ? 'Olá, ${profile.firstName}! O motor SQLite Offline-First está pronto. Adicione transações para acompanhar suas 9 métricas em tempo real.'
            : 'Reserva de emergência em ${metrics.emergencyMonths.toStringAsFixed(1)} meses e comprometimento de renda em ${metrics.incomeCommitment.toStringAsFixed(1)}%.',
        timestamp: now.subtract(const Duration(hours: 2)),
        severity: displayScore >= 60
            ? NotificationSeverity.success
            : NotificationSeverity.warning,
        categoryLabel: 'Saúde Financeira',
        icon: Icons.shield_outlined,
        isRead: quickState.readIds.contains(healthId),
        actionLabel:
            transactions.isEmpty ? 'Ver Transações' : 'Ver Saúde Financeira',
        actionType: transactions.isEmpty
            ? NotificationActionType.goTransactions
            : NotificationActionType.goPlanning,
      ),
    );
  }

  // 7. Assistente GastoSync IA disponível
  const aiReadyId = 'ai_assistant_ready_tip';
  if (!quickState.dismissedIds.contains(aiReadyId)) {
    items.add(
      GastoSyncNotificationItem(
        id: aiReadyId,
        title: 'Assistente GastoSync IA (Llama 3.3)',
        message:
            'Analise seu Burn Rate diário, tire dúvidas sobre metas ou simule economia mensal no chat inteligente.',
        timestamp: now.subtract(const Duration(hours: 4)),
        severity: NotificationSeverity.ai,
        categoryLabel: 'Assistente IA',
        icon: Icons.psychology_outlined,
        isRead: quickState.readIds.contains(aiReadyId),
        actionLabel: 'Abrir Assistente IA',
        actionType: NotificationActionType.openAiChat,
      ),
    );
  }

  return items;
});

/// Provedor da contagem de notificações não lidas para o badge do sino
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final list = ref.watch(gastoSyncNotificationsProvider);
  return list.where((n) => !n.isRead).length;
});

/// Central de Notificações responsiva (Dialog na Web / ModalBottomSheet no Mobile)
class GastoSyncNotificationsModal extends ConsumerStatefulWidget {
  const GastoSyncNotificationsModal({
    this.isBottomSheet = false,
    super.key,
  });

  final bool isBottomSheet;

  static Future<void> show(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final barrierColor = AppTheme.navyDark.withValues(alpha: 0.45);

    if (size.width >= 600) {
      return showDialog<void>(
        context: context,
        barrierColor: barrierColor,
        builder: (ctx) => Theme(
          data: AppTheme.lightTheme,
          child: Dialog(
            backgroundColor: AppTheme.cardSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 24,
            shadowColor: Colors.black.withValues(alpha: 0.35),
            clipBehavior: Clip.antiAlias,
            insetPadding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SizedBox(
              width: 460,
              height: math.min(640.0, size.height - 48),
              child: const GastoSyncNotificationsModal(),
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: barrierColor,
      backgroundColor: AppTheme.cardSurface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final mq = MediaQuery.of(ctx);
        final height = math.max(
          320.0,
          math.min(mq.size.height * 0.86, mq.size.height - mq.padding.top - 12),
        );
        return Theme(
          data: AppTheme.lightTheme,
          child: SizedBox(
            height: height,
            child: const GastoSyncNotificationsModal(isBottomSheet: true),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<GastoSyncNotificationsModal> createState() =>
      _GastoSyncNotificationsModalState();
}

class _GastoSyncNotificationsModalState
    extends ConsumerState<GastoSyncNotificationsModal> {
  bool _onlyUnread = false;
  bool _isSyncing = false;

  Future<void> _handleAction(
    BuildContext context,
    GastoSyncNotificationItem item,
  ) async {
    final notifier = ref.read(notificationsControllerProvider.notifier);
    notifier.markAsRead(item.id);

    final action = item.actionType;
    if (action == null) return;

    if (action == NotificationActionType.syncNow) {
      if (_isSyncing) return;
      setState(() => _isSyncing = true);
      try {
        final db = ref.read(appDatabaseProvider);
        final txs =
            ref.read(watchTransactionsProvider).value ?? const <Transaction>[];
        final pending = txs.where((t) => !t.isSynced).toList();
        var syncedCount = 0;
        for (final tx in pending) {
          if (tx.id != null) {
            final ok = await db.markAsSynced(tx.id!);
            if (ok) syncedCount++;
          }
        }
        notifier.dismiss(item.id);
        notifier.pushCustomNotification(
          id: 'sync_completed_feedback',
          title: 'Sincronização concluída com sucesso',
          message: syncedCount > 0
              ? '$syncedCount transação(ões) foram sincronizadas com o banco local.'
              : 'Todos os registros já estão 100% sincronizados.',
          severity: NotificationSeverity.success,
          categoryLabel: 'Offline-First',
          icon: Icons.check_circle_outline_rounded,
        );
      } finally {
        if (mounted) setState(() => _isSyncing = false);
      }
      return;
    }

    final navigator = Navigator.of(context);
    final rootContext = navigator.context;
    navigator.pop();

    switch (action) {
      case NotificationActionType.goDashboard:
        ref.read(goRouterProvider).go('/dashboard');
      case NotificationActionType.goTransactions:
        ref.read(goRouterProvider).go('/transactions');
      case NotificationActionType.goPlanning:
        ref.read(goRouterProvider).go('/planning');
      case NotificationActionType.goMore:
        ref.read(goRouterProvider).go('/more');
      case NotificationActionType.openAiChat:
        if (rootContext.mounted) {
          await GastoSyncAiChatModal.show(rootContext);
        }
      case NotificationActionType.syncNow:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allItems = ref.watch(gastoSyncNotificationsProvider);
    final unreadCount = allItems.where((e) => !e.isRead).length;
    final visibleItems = _onlyUnread
        ? allItems.where((e) => !e.isRead).toList()
        : allItems;
    final notifier = ref.read(notificationsControllerProvider.notifier);

    return ColoredBox(
      key: const Key('gastosync_notifications_modal'),
      color: AppTheme.backgroundLight,
      child: Column(
        children: [
          _NotificationsHeader(
            showDragHandle: widget.isBottomSheet,
            unreadCount: unreadCount,
            onMarkAllRead: unreadCount > 0
                ? () => notifier.markAllAsRead(allItems.map((e) => e.id))
                : null,
            onClose: () => Navigator.of(context).pop(),
          ),
          _NotificationsFilterBar(
            totalCount: allItems.length,
            unreadCount: unreadCount,
            onlyUnread: _onlyUnread,
            onFilterChanged: (val) => setState(() => _onlyUnread = val),
            onClearAll: allItems.isNotEmpty
                ? () => notifier.clearAll(allItems.map((e) => e.id))
                : null,
          ),
          Expanded(
            child: visibleItems.isEmpty
                ? _EmptyNotificationsView(
                    onlyUnread: _onlyUnread,
                    onShowAll: _onlyUnread
                        ? () => setState(() => _onlyUnread = false)
                        : null,
                    onRestore: () => notifier.restoreDismissed(),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return _NotificationCard(
                        item: item,
                        isBusy: _isSyncing &&
                            item.actionType == NotificationActionType.syncNow,
                        onTap: () => notifier.markAsRead(item.id),
                        onActionTap: item.actionLabel != null
                            ? () => _handleAction(context, item)
                            : null,
                        onDismiss: () => notifier.dismiss(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.showDragHandle,
    required this.unreadCount,
    required this.onMarkAllRead,
    required this.onClose,
  });

  final bool showDragHandle;
  final int unreadCount;
  final VoidCallback? onMarkAllRead;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, showDragHandle ? 10 : 18, 12, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.navyDark, AppTheme.navySurface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.emeraldPrimary.withValues(alpha: 0.45),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppTheme.emeraldPrimary,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Notificações',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unreadCount nova${unreadCount > 1 ? "s" : ""}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Alertas de metas, sincronia SQLite e insights da IA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onMarkAllRead != null)
                TextButton.icon(
                  key: const Key('notifications_mark_all_read_button'),
                  onPressed: onMarkAllRead,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF34D399),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text(
                    'Ler todas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Fechar',
                onPressed: onClose,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  fixedSize: const Size(36, 36),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsFilterBar extends StatelessWidget {
  const _NotificationsFilterBar({
    required this.totalCount,
    required this.unreadCount,
    required this.onlyUnread,
    required this.onFilterChanged,
    required this.onClearAll,
  });

  final int totalCount;
  final int unreadCount;
  final bool onlyUnread;
  final ValueChanged<bool> onFilterChanged;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Todas ($totalCount)',
                    selected: !onlyUnread,
                    onTap: () => onFilterChanged(false),
                  ),
                  const SizedBox(width: 8),
                  _FilterPill(
                    label: 'Não lidas ($unreadCount)',
                    selected: onlyUnread,
                    onTap: () => onFilterChanged(true),
                  ),
                ],
              ),
            ),
          ),
          if (onClearAll != null) ...[
            const SizedBox(width: 8),
            TextButton.icon(
              key: const Key('notifications_clear_all_button'),
              onPressed: onClearAll,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.clear_all_rounded, size: 16),
              label: const Text(
                'Limpar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.navyDark : AppTheme.subtleSurface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isBusy,
    required this.onTap,
    required this.onActionTap,
    required this.onDismiss,
  });

  final GastoSyncNotificationItem item;
  final bool isBusy;
  final VoidCallback onTap;
  final VoidCallback? onActionTap;
  final VoidCallback onDismiss;

  ({Color iconBg, Color iconFg, Color badgeBg, Color badgeFg}) _palette() {
    switch (item.severity) {
      case NotificationSeverity.critical:
        return (
          iconBg: const Color(0xFFFEE2E2),
          iconFg: AppTheme.errorColor,
          badgeBg: const Color(0xFFFEE2E2),
          badgeFg: AppTheme.errorColor,
        );
      case NotificationSeverity.warning:
        return (
          iconBg: AppTheme.warningBadgeBg,
          iconFg: AppTheme.warningDark,
          badgeBg: AppTheme.warningBadgeBg,
          badgeFg: AppTheme.warningDark,
        );
      case NotificationSeverity.success:
        return (
          iconBg: AppTheme.emeraldSoftBg,
          iconFg: AppTheme.emeraldDeep,
          badgeBg: AppTheme.emeraldBadgeBg,
          badgeFg: AppTheme.emeraldDeep,
        );
      case NotificationSeverity.ai:
        return (
          iconBg: AppTheme.navyDark,
          iconFg: AppTheme.emeraldPrimary,
          badgeBg: AppTheme.subtleSurface,
          badgeFg: AppTheme.navyDark,
        );
      case NotificationSeverity.info:
        return (
          iconBg: AppTheme.subtleSurface,
          iconFg: AppTheme.textSecondary,
          badgeBg: AppTheme.subtleSurface,
          badgeFg: AppTheme.textSecondary,
        );
    }
  }

  static String _formatRelative(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 2) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours} h';
    return DateFormat('dd/MM').format(time);
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palette();
    final unread = !item.isRead;

    return Dismissible(
      key: ValueKey('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.errorColor,
        ),
      ),
      child: Material(
        color: unread
            ? AppTheme.cardSurface
            : AppTheme.cardSurface.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: unread
                ? AppTheme.emeraldPrimary.withValues(alpha: 0.45)
                : AppTheme.cardBorder,
            width: unread ? 1.2 : 1.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: colors.iconFg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.categoryLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.badgeFg,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _formatRelative(item.timestamp),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: AppTheme.emeraldPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          InkWell(
                            onTap: onDismiss,
                            borderRadius: BorderRadius.circular(999),
                            child: const Padding(
                              padding: EdgeInsets.all(2),
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                      if (item.actionLabel != null && onActionTap != null) ...[
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: isBusy ? null : onActionTap,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.emeraldSoftBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.emeraldPrimary
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isBusy) ...[
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.emeraldDeep,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Text(
                                    item.actionLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.emeraldDeep,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 14,
                                  color: AppTheme.emeraldDeep,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotificationsView extends StatelessWidget {
  const _EmptyNotificationsView({
    required this.onlyUnread,
    required this.onShowAll,
    required this.onRestore,
  });

  final bool onlyUnread;
  final VoidCallback? onShowAll;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppTheme.emeraldSoftBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 28,
                color: AppTheme.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              onlyUnread
                  ? 'Nenhuma notificação não lida'
                  : 'Tudo em dia por aqui!',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              onlyUnread
                  ? 'Você já leu todos os alertas recentes de orçamento e sincronia.'
                  : 'Seus alertas de Burn Rate, metas por categoria e sincronia SQLite aparecerão aqui.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            if (onShowAll != null)
              OutlinedButton.icon(
                onPressed: onShowAll,
                icon: const Icon(Icons.list_rounded, size: 17),
                label: const Text('Ver todas as notificações'),
              )
            else
              OutlinedButton.icon(
                key: const Key('notifications_restore_button'),
                onPressed: onRestore,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Recarregar alertas de status'),
              ),
          ],
        ),
      ),
    );
  }
}

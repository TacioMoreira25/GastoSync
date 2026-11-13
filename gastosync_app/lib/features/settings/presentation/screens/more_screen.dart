import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/bill_notification_service.dart';
import '../../../../core/services/csv_export_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gastosync_top_header.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../planning/domain/models/credit_card_model.dart';
import '../../../transactions/data/services/cloud_sync_service.dart';
import '../../../transactions/domain/models/bill.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';
import '../../domain/models/user_profile.dart';
import '../../../budget_agent/data/services/budget_agent_service.dart';
import '../../../budget_agent/domain/models/agent_prediction_models.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  bool _isSyncing = false;

  Future<void> _syncPendingTransactions(List<Transaction> pendingList) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final authState = ref.read(authProvider);
      final db = ref.read(appDatabaseProvider);
      final syncService = ref.read(cloudSyncServiceProvider);
      final budgets = await db.watchAllBudgets().first;

      final pushResult = await syncService.pushPendingTransactions(
        pendingTransactions: pendingList,
        jwtToken: authState.token,
        budgets: budgets,
      );

      if (authState.token != null &&
          authState.token!.isNotEmpty &&
          authState.currentEmail != null) {
        await syncService.pullFromCloud(
          jwtToken: authState.token,
          userEmail: authState.currentEmail!,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pushResult.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileProvider);
    final quotaAsync = ref.watch(agentQuotaStatusProvider);
    final transactionsAsync = ref.watch(watchTransactionsProvider);
    final transactions = transactionsAsync.value ?? const <Transaction>[];
    final pendingTransactions =
        transactions.where((t) => !t.isSynced).toList();
    final pendingCount = pendingTransactions.length;
    final syncedCount = transactions.length - pendingCount;

    final currencyFormatter =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final isDesktop = MediaQuery.sizeOf(context).width >= 800;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 28.0 : 16.0,
          isDesktop ? 24.0 : 16.0,
          isDesktop ? 28.0 : 16.0,
          96.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho CONTA
            _buildHeader(isDesktop: isDesktop),
            const SizedBox(height: 16),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildProfileCard(context, profile),
                        const SizedBox(height: 18),
                        _buildOfflineStatusCard(
                          totalCount: transactions.length,
                          syncedCount: syncedCount,
                          pendingCount: pendingCount,
                          pendingTransactions: pendingTransactions,
                        ),
                        const SizedBox(height: 18),
                        _buildAiAgentQuotaCard(context, quotaAsync),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBillRemindersSection(
                          context: context,
                          profile: profile,
                        ),
                        const SizedBox(height: 22),
                        _buildFinancialSettingsSection(
                          context: context,
                          profile: profile,
                          transactions: transactions,
                          currencyFormatter: currencyFormatter,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              // 1. Card de perfil (Marcos Pereira + badge Conta local ativa)
              _buildProfileCard(context, profile),
              const SizedBox(height: 18),

              // 2. Card Status Offline-First (SQLite Local) com contagem real de pendentes + Sincronizar agora
              _buildOfflineStatusCard(
                totalCount: transactions.length,
                syncedCount: syncedCount,
                pendingCount: pendingCount,
                pendingTransactions: pendingTransactions,
              ),
              const SizedBox(height: 18),

              // Card Status da IA & Limites da Cota (Groq Cloud no Render)
              _buildAiAgentQuotaCard(context, quotaAsync),
              const SizedBox(height: 22),

              // 3. Alertas & Notificações de Boletos (2x/dia) (T023)
              _buildBillRemindersSection(
                context: context,
                profile: profile,
              ),
              const SizedBox(height: 22),

              // 4. Lista Configurações financeiras
              _buildFinancialSettingsSection(
                context: context,
                profile: profile,
                transactions: transactions,
                currencyFormatter: currencyFormatter,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required bool isDesktop}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CONTA',
          style: TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Mais',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isDesktop ? 22 : 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(BuildContext context, UserProfile profile) {
    final authState = ref.watch(authProvider);
    final isVerified = authState.isEmailVerified;

    return Container(
      key: const Key('more_profile_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Row(
        children: [
          GastoSyncUserAvatar(
            initials: profile.initials,
            size: 52,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      key: const Key('more_active_local_account_badge'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: AppTheme.emeraldBadgeDecoration,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.emeraldDeep,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Conta local ativa',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.emeraldDeep,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        key: const Key('more_email_verification_badge'),
                        borderRadius: BorderRadius.circular(999),
                        onTap: isVerified
                            ? null
                            : () async {
                                final messenger =
                                    ScaffoldMessenger.of(context);
                                final ok = await EmailVerificationDialog.show(
                                  context,
                                  email: profile.email,
                                  fullName: profile.fullName,
                                );
                                if (ok && mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'E-mail verificado com sucesso!',
                                      ),
                                      backgroundColor: AppTheme.emeraldDeep,
                                    ),
                                  );
                                }
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: isVerified
                              ? AppTheme.emeraldBadgeDecoration
                              : AppTheme.warningBadgeDecoration,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isVerified
                                    ? Icons.verified_rounded
                                    : Icons.mark_email_unread_outlined,
                                size: 13,
                                color: isVerified
                                    ? AppTheme.emeraldDeep
                                    : AppTheme.warningDark,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  isVerified
                                      ? 'E-mail verificado'
                                      : 'Verificar e-mail',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isVerified
                                        ? AppTheme.emeraldDeep
                                        : AppTheme.warningDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('more_edit_profile_button'),
            tooltip: 'Editar perfil',
            onPressed: () => _showEditProfileDialog(context, profile),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineStatusCard({
    required int totalCount,
    required int syncedCount,
    required int pendingCount,
    required List<Transaction> pendingTransactions,
  }) {
    final hasPending = pendingCount > 0;

    return Container(
      key: const Key('more_offline_status_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.heroNavyCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storage_rounded,
                  color: AppTheme.emeraldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Offline-First (SQLite Local)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasPending
                          ? '$pendingCount transação(ões) pendente(s) de sincronização'
                          : 'Banco íntegro · $syncedCount sincronizada(s) ($totalCount total)',
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.navyBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: hasPending
                              ? AppTheme.warningAmber
                              : AppTheme.emeraldPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          hasPending
                              ? '$pendingCount pendente(s) local'
                              : '0 pendentes · Tudo sincronizado',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$totalCount no SQLite',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const Key('more_sync_now_button'),
              onPressed: _isSyncing
                  ? null
                  : () => _syncPendingTransactions(pendingTransactions),
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(
                _isSyncing ? 'Sincronizando...' : 'Sincronizar agora',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.emeraldPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiAgentQuotaCard(
    BuildContext context,
    AsyncValue<AgentQuotaStatus> quotaAsync,
  ) {
    final status = quotaAsync.value ?? AgentQuotaStatus.offline();
    final isLoading = quotaAsync.isLoading;
    final isOnline = status.isOnline;

    final badgeBg =
        isOnline ? AppTheme.emeraldBadgeBg : AppTheme.warningBadgeBg;
    final badgeDotColor =
        isOnline ? AppTheme.emeraldDeep : AppTheme.warningAmber;
    final badgeTextColor =
        isOnline ? AppTheme.emeraldDeep : AppTheme.warningDark;
    final badgeText = isOnline
        ? 'Groq Online • ${status.latencyMs}ms'
        : 'IA Offline • Fallback Local Ativo';

    return Container(
      key: const Key('more_ai_agent_quota_card'),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.whiteCardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho + Badge de Status em Tempo Real
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isOnline
                      ? AppTheme.emeraldPrimary.withValues(alpha: 0.12)
                      : AppTheme.warningAmber.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology_outlined,
                  color: isOnline
                      ? AppTheme.emeraldPrimary
                      : AppTheme.warningDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status da IA & Limites da Cota (Groq)',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Render Cloud · ${status.provider}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Badge de status em tempo real
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: badgeDotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    badgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Barras de Progresso Didáticas de Limites da Cota
          // Requisições Diárias (RPD)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Requisições Diárias (RPD)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${status.totalRequests} / ${status.dailyRequestLimit} req (${status.requestUsagePercent.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: status.requestUsageRatio,
              minHeight: 6,
              backgroundColor: AppTheme.subtleSurface,
              color: status.requestUsageRatio > 0.8
                  ? AppTheme.warningAmber
                  : AppTheme.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 14),

          // Tokens Processados (TPM)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Tokens Processados (Teto 12.000 TPM)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${status.totalTokensUsed} / ${status.minuteTokenLimit} TPM',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: status.tokenUsageRatio,
              minHeight: 6,
              backgroundColor: AppTheme.subtleSurface,
              color: AppTheme.emeraldPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // 3. Chips de Modelos e Fallback
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuotaChip(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'Texto: ${status.activeTextModel}',
              ),
              _buildQuotaChip(
                icon: Icons.document_scanner_outlined,
                label: 'OCR: ${status.activeOcrModel}',
              ),
              if (status.lastModelUsed.isNotEmpty)
                _buildQuotaChip(
                  icon: Icons.history_rounded,
                  label: 'Último: ${status.lastModelUsed}',
                ),
              _buildQuotaChip(
                icon: Icons.alt_route_rounded,
                label: 'Fallbacks ativados: ${status.fallbackTriggers}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. Botão "Atualizar Status da IA"
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('more_refresh_ai_quota_button'),
              onPressed: isLoading
                  ? null
                  : () => ref.invalidate(agentQuotaStatusProvider),
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.emeraldPrimary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                isLoading ? 'Consultando...' : 'Atualizar Status da IA',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.emeraldPrimary,
                side: const BorderSide(color: AppTheme.cardBorder),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRemindersSection({
    required BuildContext context,
    required UserProfile profile,
  }) {
    final nextWindowLabel = BillNotificationService.describeNextReminderWindow(
      DateTime.now(),
      reminderTime1: profile.reminderTime1,
      reminderTime2: profile.reminderTime2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            const Text(
              'Alertas de Boletos (2x ao dia)',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: AppTheme.emeraldBadgeDecoration,
              child: Text(
                'Próximo: $nextWindowLabel',
                style: const TextStyle(
                  color: AppTheme.emeraldDeep,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('more_bill_reminders_card'),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            children: [
              _SettingsTile(
                key: const Key('more_setting_reminder_time_1'),
                icon: Icons.wb_sunny_outlined,
                title: '1º Horário de Lembrete Diário',
                subtitle:
                    'Notificação matinal às ${profile.reminderTime1} (toque para alterar)',
                onTap: () => _pickReminderTime(
                  context: context,
                  slot: 1,
                  currentTime: profile.reminderTime1,
                ),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_setting_reminder_time_2'),
                icon: Icons.nights_stay_outlined,
                title: '2º Horário de Lembrete Diário',
                subtitle:
                    'Notificação vespertina/noturna às ${profile.reminderTime2} (toque para alterar)',
                onTap: () => _pickReminderTime(
                  context: context,
                  slot: 2,
                  currentTime: profile.reminderTime2,
                ),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  key: const Key('more_setting_email_bill_notifications'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.subtleSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppTheme.textSecondary,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Receber Lembretes por E-mail',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    profile.emailBillNotifications
                        ? 'Envia resumo 2x/dia (${profile.reminderTime1} e ${profile.reminderTime2}) para ${profile.email}'
                        : 'Alertas por e-mail desativados (apenas notificações no app)',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  value: profile.emailBillNotifications,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.emeraldPrimary,
                  inactiveThumbColor: AppTheme.textMuted,
                  inactiveTrackColor: AppTheme.cardBorder,
                  onChanged: (enabled) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await ref
                        .read(userProfileProvider.notifier)
                        .updateBillNotificationPreferences(
                          emailBillNotifications: enabled,
                        );
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          enabled
                              ? 'Lembretes de boletos por e-mail ativados!'
                              : 'Lembretes de boletos por e-mail pausados.',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickReminderTime({
    required BuildContext context,
    required int slot,
    required String currentTime,
  }) async {
    final parts = currentTime.split(':');
    final initialHour =
        parts.length == 2 ? (int.tryParse(parts[0]) ?? (slot == 1 ? 9 : 18)) : (slot == 1 ? 9 : 18);
    final initialMinute =
        parts.length == 2 ? (int.tryParse(parts[1]) ?? 0) : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: initialHour.clamp(0, 23),
        minute: initialMinute.clamp(0, 59),
      ),
      helpText: 'SELECIONE O $slotº HORÁRIO DIÁRIO (24H)',
      cancelText: 'Cancelar',
      confirmText: 'Salvar Horário',
      builder: (ctx, child) {
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked == null || !mounted) return;

    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';

    final messenger = ScaffoldMessenger.of(this.context);
    if (slot == 1) {
      await ref
          .read(userProfileProvider.notifier)
          .updateBillNotificationPreferences(reminderTime1: formatted);
    } else {
      await ref
          .read(userProfileProvider.notifier)
          .updateBillNotificationPreferences(reminderTime2: formatted);
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$slotº horário diário de alerta de boletos atualizado para $formatted!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildFinancialSettingsSection({
    required BuildContext context,
    required UserProfile profile,
    required List<Transaction> transactions,
    required NumberFormat currencyFormatter,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Configurações financeiras',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('more_financial_settings_card'),
          decoration: AppTheme.whiteCardDecoration,
          child: Column(
            children: [
              _SettingsTile(
                key: const Key('more_setting_base_income'),
                icon: Icons.payments_outlined,
                title: 'Renda Base Mensal',
                subtitle: currencyFormatter.format(profile.monthlyBaseIncome),
                onTap: () => _showEditBaseIncomeDialog(context, profile),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_setting_savings_target'),
                icon: Icons.savings_outlined,
                title: 'Meta de Taxa de Poupança',
                subtitle:
                    '${profile.savingsRateTarget.toStringAsFixed(0)}% da renda mensal',
                onTap: () => _showEditSavingsTargetDialog(context, profile),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_setting_manage_categories'),
                icon: Icons.category_outlined,
                title: 'Gerenciar Categorias',
                subtitle: 'Editar tetos e categorias em Planejamento',
                onTap: () => context.go('/planning'),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_setting_export_csv'),
                icon: Icons.download_rounded,
                title: 'Exportar Relatório CSV',
                subtitle:
                    'Exportar transações (${transactions.length}), boletos e cartões em RFC-4180',
                onTap: () => _exportCsvReport(context, transactions),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_logout_button'),
                icon: Icons.logout_rounded,
                title: 'Sair da conta',
                subtitle: 'Encerrar sessão atual neste dispositivo',
                onTap: () {
                  context.go('/dashboard');
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    UserProfile profile,
  ) async {
    final nameController = TextEditingController(text: profile.fullName);
    final emailController = TextEditingController(text: profile.email);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          title: const Text('Editar Perfil Local'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome completo'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newEmail = emailController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(userProfileProvider.notifier).updateProfile(
                        fullName: newName,
                        email: newEmail.isEmpty ? profile.email : newEmail,
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditBaseIncomeDialog(
    BuildContext context,
    UserProfile profile,
  ) async {
    final controller = TextEditingController(
      text: profile.monthlyBaseIncome.toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          title: const Text('Renda Base Mensal'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor mensal (R\$)',
              hintText: 'Ex: 8500.00',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (parsed != null && parsed > 0) {
                  ref.read(userProfileProvider.notifier).updateProfile(
                        monthlyBaseIncome: parsed,
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditSavingsTargetDialog(
    BuildContext context,
    UserProfile profile,
  ) async {
    final controller = TextEditingController(
      text: profile.savingsRateTarget.toStringAsFixed(0),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.cardSurface,
          title: const Text('Meta de Taxa de Poupança'),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Percentual da renda (%)',
              hintText: 'Ex: 20',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'),
                );
                if (parsed != null && parsed > 0 && parsed <= 90) {
                  ref.read(userProfileProvider.notifier).updateProfile(
                        savingsRateTarget: parsed,
                      );
                }
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportCsvReport(
    BuildContext context,
    List<Transaction> transactions,
  ) async {
    final profile = ref.read(userProfileProvider);
    final bills = (ref.read(watchBillsProvider).value ?? const <Bill>[])
        .where((b) => !b.isDeleted)
        .toList();
    final creditCards =
        (ref.read(watchCreditCardsProvider).value ?? const <LocalCreditCard>[])
            .map(CreditCard.fromLocal)
            .toList();

    await CsvExportService.showExportModal(
      context,
      transactions: transactions,
      bills: bills,
      creditCards: creditCards,
      userEmail: profile.email,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

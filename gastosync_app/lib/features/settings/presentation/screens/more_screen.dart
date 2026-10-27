import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/gastosync_top_header.dart';
import '../../../auth/domain/auth_provider.dart';
import '../../../transactions/domain/models/transaction.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';
import '../../domain/models/user_profile.dart';

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
      final db = ref.read(appDatabaseProvider);
      var syncedNow = 0;
      for (final tx in pendingList) {
        if (tx.id != null) {
          final updated = await db.markAsSynced(tx.id!);
          if (updated) syncedNow++;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncedNow > 0
                ? 'Sincronização concluída: $syncedNow transação(ões) sincronizada(s).'
                : 'Banco local já está 100% sincronizado.',
          ),
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
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildFinancialSettingsSection(
                      context: context,
                      profile: profile,
                      transactions: transactions,
                      currencyFormatter: currencyFormatter,
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
              const SizedBox(height: 22),

              // 3. Lista Configurações financeiras
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
                    'Exportar ${transactions.length} transação(ões) do banco local',
                onTap: () => _exportCsvReport(context, transactions),
              ),
              const Divider(color: AppTheme.cardBorder, height: 1),
              _SettingsTile(
                key: const Key('more_logout_button'),
                icon: Icons.logout_rounded,
                title: 'Sair da conta',
                subtitle: 'Encerrar sessão atual neste dispositivo',
                onTap: () => ref.read(authProvider.notifier).logout(),
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
    final buffer = StringBuffer(
      'id,descricao,categoria,tipo,valor,data,sincronizado\n',
    );
    final dateFmt = DateFormat('yyyy-MM-dd');
    for (final tx in transactions) {
      final safeDesc = tx.description.replaceAll(',', ' ');
      final safeCat = tx.category.replaceAll(',', ' ');
      buffer.writeln(
        '${tx.id ?? ""},$safeDesc,$safeCat,${tx.type.name},${tx.amount.toStringAsFixed(2)},${dateFmt.format(tx.date)},${tx.isSynced}',
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Relatório CSV (${transactions.length} registros) copiado para a área de transferência!',
        ),
        behavior: SnackBarBehavior.floating,
      ),
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

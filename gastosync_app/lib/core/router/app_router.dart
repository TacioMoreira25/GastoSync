import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/domain/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/planning/presentation/screens/planning_screen.dart';
import '../../features/settings/domain/models/user_profile.dart';
import '../../features/settings/presentation/screens/more_screen.dart';
import '../../features/transactions/presentation/controllers/transactions_controller.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/widgets/manual_transaction_form_modal.dart';
import '../theme/app_theme.dart';
import '../widgets/gastosync_top_header.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _dashboardNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'dashboardNav');
final _transactionsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'transactionsNav');
final _planningNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'planningNav');
final _moreNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'moreNav');

/// Provedor Riverpod do GoRouter (goRouterProvider) com guarda de autenticação e as 4 abas do protótipo Figma v2
final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/dashboard',
    debugLogDiagnostics: true,
    errorBuilder: (context, state) => const LoginScreen(),
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        redirect: (context, state) => '/dashboard',
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithAdaptiveNavigation(navigationShell: navigationShell);
        },
        branches: [
          // Aba 1: Início (Dashboard)
          StatefulShellBranch(
            navigatorKey: _dashboardNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Aba 2: Transações (100% Offline-First via Drift)
          StatefulShellBranch(
            navigatorKey: _transactionsNavigatorKey,
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),

          // Aba 3: Planejamento (Orçamentos & Metas e Saúde Financeira)
          StatefulShellBranch(
            navigatorKey: _planningNavigatorKey,
            routes: [
              GoRoute(
                path: '/planning',
                name: 'planning',
                builder: (context, state) => const PlanningScreen(),
              ),
            ],
          ),

          // Aba 4: Mais (Conta, Status Offline-First e Configurações Financeiras)
          StatefulShellBranch(
            navigatorKey: _moreNavigatorKey,
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _NavTabItem {
  const _NavTabItem({
    required this.label,
    required this.eyebrow,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String eyebrow;
  final String? headerTitle;
  final String headerSubtitle;
  final IconData icon;
  final IconData selectedIcon;
}

const List<_NavTabItem> _navTabs = [
  _NavTabItem(
    label: 'Início',
    eyebrow: 'VISÃO GERAL',
    headerTitle: null, // Usa saudação dinâmica "Olá, {nome}"
    headerSubtitle: 'Resumo consolidado de patrimônio, metas e Burn Rate mensal',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_outlined,
  ),
  _NavTabItem(
    label: 'Transações',
    eyebrow: 'MOVIMENTAÇÕES',
    headerTitle: 'Transações',
    headerSubtitle: 'Histórico completo e categorização 100% local via SQLite',
    icon: Icons.read_more_rounded,
    selectedIcon: Icons.read_more_rounded,
  ),
  _NavTabItem(
    label: 'Planejamento',
    eyebrow: 'PLANEJAMENTO',
    headerTitle: 'Orçamentos & Metas',
    headerSubtitle: 'Tetos mensais por categoria e indicadores de saúde financeira',
    icon: Icons.adjust_rounded,
    selectedIcon: Icons.adjust_rounded,
  ),
  _NavTabItem(
    label: 'Mais',
    eyebrow: 'CONTA',
    headerTitle: 'Conta & Ajustes',
    headerSubtitle: 'Status do banco local Offline-First e preferências financeiras',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_outline_rounded,
  ),
];

class ScaffoldWithAdaptiveNavigation extends ConsumerWidget {
  const ScaffoldWithAdaptiveNavigation({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(
      authProvider.select((state) => state.isAuthenticated),
    );
    if (!isAuthenticated) {
      return const LoginScreen();
    }

    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 800;
    final currentIndex = navigationShell.currentIndex.clamp(0, _navTabs.length - 1);
    final activeTab = _navTabs[currentIndex];
    final profile = ref.watch(userProfileProvider);
    final transactions = ref.watch(watchTransactionsProvider).value ?? const [];
    final pendingCount = transactions.where((t) => !t.isSynced).length;
    final syncLabel = pendingCount == 0
        ? 'Local sincronizado'
        : '$pendingCount pendente${pendingCount > 1 ? "s" : ""} local';

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        body: Row(
          children: [
            _GastoSyncWebSidebar(
              selectedIndex: currentIndex,
              onDestinationSelected: _onDestinationSelected,
              onNewTransactionTap: () => ManualTransactionFormModal.show(context),
              onLogoutTap: () {
                navigationShell.goBranch(0);
                ref.read(authProvider.notifier).logout();
              },
              profile: profile,
              pendingCount: pendingCount,
            ),
            Expanded(
              child: Column(
                children: [
                  GastoSyncWebTopBar(
                    title: activeTab.headerTitle ?? 'Olá, ${profile.firstName}',
                    subtitle: activeTab.headerSubtitle,
                    syncStatusLabel: syncLabel,
                    onAvatarTap: () => _onDestinationSelected(3),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(child: navigationShell),
                        const Positioned(
                          right: 24,
                          bottom: 24,
                          child: GastoSyncAiFloatingButton(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Column(
        children: [
          GastoSyncMobileHeader(
            eyebrow: activeTab.eyebrow,
            title: activeTab.headerTitle,
            onAvatarTap: () => _onDestinationSelected(3),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: navigationShell),
                const Positioned(
                  right: 16,
                  bottom: 16,
                  child: GastoSyncAiFloatingButton(),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _GastoSyncMobileBottomBar(
        selectedIndex: currentIndex,
        onDestinationSelected: _onDestinationSelected,
        onAddPressed: () => ManualTransactionFormModal.show(context),
      ),
    );
  }
}

/// Botão `+` verde circular central com anel branco e ícone escuro (`#0F172A`) conforme modelo do Figma
class _MobileCenterAddButton extends StatelessWidget {
  const _MobileCenterAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Adicionar transação',
      child: GestureDetector(
        key: const Key('mobile_center_add_button'),
        onTap: onPressed,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: AppTheme.emeraldPrimary.withValues(alpha: 0.25),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.emeraldPrimary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.add_rounded,
                color: AppTheme.navyDark,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra inferior Mobile com as 4 abas (`Início`, `Transações`, `Planejamento`, `Mais`) e botão `+` sobreposto na borda
class _GastoSyncMobileBottomBar extends StatelessWidget {
  const _GastoSyncMobileBottomBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onAddPressed,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          key: const Key('gastosync_mobile_bottom_bar'),
          decoration: const BoxDecoration(
            color: AppTheme.cardSurface,
            border: Border(
              top: BorderSide(color: AppTheme.cardBorder, width: 1),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  _MobileTabButton(
                    tab: _navTabs[0],
                    isSelected: selectedIndex == 0,
                    onTap: () => onDestinationSelected(0),
                  ),
                  _MobileTabButton(
                    tab: _navTabs[1],
                    isSelected: selectedIndex == 1,
                    onTap: () => onDestinationSelected(1),
                  ),
                  // Espaço central para o botão `+` elevado
                  const SizedBox(width: 68),
                  _MobileTabButton(
                    tab: _navTabs[2],
                    isSelected: selectedIndex == 2,
                    onTap: () => onDestinationSelected(2),
                  ),
                  _MobileTabButton(
                    tab: _navTabs[3],
                    isSelected: selectedIndex == 3,
                    onTap: () => onDestinationSelected(3),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -18,
          child: _MobileCenterAddButton(onPressed: onAddPressed),
        ),
      ],
    );
  }
}

class _MobileTabButton extends StatelessWidget {
  const _MobileTabButton({
    required this.tab,
    required this.isSelected,
    required this.onTap,
  });

  final _NavTabItem tab;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppTheme.emeraldPrimary : AppTheme.textMuted;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? tab.selectedIcon : tab.icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sidebar esquerda escura (`#0F172A`) para Web / Desktop (>= 800dp) conforme protótipo Figma v2
class _GastoSyncWebSidebar extends StatelessWidget {
  const _GastoSyncWebSidebar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onNewTransactionTap,
    required this.onLogoutTap,
    required this.profile,
    required this.pendingCount,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onNewTransactionTap;
  final VoidCallback onLogoutTap;
  final UserProfile profile;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('gastosync_web_sidebar'),
      width: 256,
      color: AppTheme.navyDark,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: GastoSyncBrandLogo(
              iconSize: 28,
              fontSize: 17,
              textColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // Botão verde "+ Nova Transação"
          FilledButton.icon(
            key: const Key('web_sidebar_new_transaction_button'),
            onPressed: onNewTransactionTap,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Nova Transação'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.emeraldPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Menu lateral de 4 abas
          ...List.generate(_navTabs.length, (index) {
            final tab = _navTabs[index];
            final isSelected = selectedIndex == index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: isSelected
                    ? AppTheme.emeraldPrimary.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onDestinationSelected(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? tab.selectedIcon : tab.icon,
                          size: 20,
                          color: isSelected
                              ? AppTheme.emeraldPrimary
                              : const Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tab.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                              fontSize: 14,
                              fontWeight:
                                  isSelected ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          const Spacer(),

          // Box "Modo Offline-First · Sincronizado"
          Container(
            key: const Key('web_sidebar_offline_box'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.navySurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.navyBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: pendingCount == 0
                            ? AppTheme.emeraldPrimary
                            : AppTheme.warningAmber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Modo Offline-First',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pendingCount == 0
                      ? 'SQLite Local · Sincronizado'
                      : 'SQLite Local · $pendingCount pendente(s)',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.navyBorder, height: 1),
          const SizedBox(height: 14),

          // Rodapé de perfil dinâmico "{iniciais} · {nome}" + botão Sair
          Row(
            children: [
              Expanded(
                child: InkWell(
                  key: const Key('web_sidebar_user_profile'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onDestinationSelected(3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        GastoSyncUserAvatar(
                          initials: profile.initials,
                          size: 36,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                profile.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                profile.accountLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('web_sidebar_logout_button'),
                tooltip: 'Sair da conta',
                onPressed: onLogoutTap,
                icon: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFF94A3B8),
                  size: 19,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mantido para compatibilidade com Hot Reload de sessões ativas do GoRouter em memória
// ignore: unused_element
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.subtitle,
  });

  final String title;
  final IconData icon;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    // Usa os campos para evitar warning de unused_field e redireciona para as telas reais
    if (title.toLowerCase().contains('planejamento') ||
        icon == Icons.pie_chart_outline_rounded ||
        subtitle.toLowerCase().contains('orçamentos')) {
      return const PlanningScreen();
    }
    return const MoreScreen();
  }
}

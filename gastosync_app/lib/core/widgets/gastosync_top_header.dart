import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/settings/domain/models/user_profile.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';
import '../theme/app_theme.dart';

/// Widget isolado do logotipo GastoSync (ícone verde 'G' + texto 'GastoSync')
class GastoSyncBrandLogo extends StatelessWidget {
  const GastoSyncBrandLogo({
    this.iconSize = 24,
    this.fontSize = 14,
    this.textColor = Colors.white,
    super.key,
  });

  final double iconSize;
  final double fontSize;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: iconSize,
          height: iconSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.emeraldPrimary,
            borderRadius: BorderRadius.circular(iconSize * 0.28),
          ),
          child: Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: iconSize * 0.58,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'GastoSync',
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Avatar circular/arredondado com as iniciais dinâmicas do usuário
class GastoSyncUserAvatar extends StatelessWidget {
  const GastoSyncUserAvatar({
    required this.initials,
    this.size = 36,
    this.backgroundColor = AppTheme.emeraldPrimary,
    this.textColor = Colors.white,
    this.onTap,
    super.key,
  });

  final String initials;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: textColor,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
    );

    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}

/// Cabeçalho superior escuro para dispositivos móveis (< 800dp) conforme protótipo Figma v2 (FR-012)
class GastoSyncMobileHeader extends ConsumerWidget {
  const GastoSyncMobileHeader({
    this.eyebrow,
    this.title,
    this.trailingBadge,
    this.onNotificationTap,
    this.onAvatarTap,
    super.key,
  });

  final String? eyebrow;
  final String? title;
  final Widget? trailingBadge;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final effectiveTitle = title ?? 'Olá, ${profile.firstName}';

    return Container(
      key: const Key('gastosync_mobile_header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: AppTheme.navyDark,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const GastoSyncBrandLogo(
                  iconSize: 22,
                  fontSize: 13,
                  textColor: Colors.white,
                ),
                ?trailingBadge,
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                        Text(
                          eyebrow!.toUpperCase(),
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        effectiveTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                _NotificationBellButton(
                  iconColor: Colors.white,
                  backgroundColor: AppTheme.navySurface,
                  onTap: onNotificationTap,
                ),
                const SizedBox(width: 10),
                GastoSyncUserAvatar(
                  key: const Key('mobile_header_user_avatar'),
                  initials: profile.initials,
                  size: 36,
                  onTap: onAvatarTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior clara para Web / Desktop (>= 800dp) com badge "Local sincronizado", sino e avatar dinâmico (FR-013)
class GastoSyncWebTopBar extends ConsumerWidget {
  const GastoSyncWebTopBar({
    this.title,
    this.subtitle,
    this.syncStatusLabel = 'Local sincronizado',
    this.onNotificationTap,
    this.onAvatarTap,
    super.key,
  });

  final String? title;
  final String? subtitle;
  final String syncStatusLabel;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final effectiveTitle = title ?? 'Olá, ${profile.firstName}';

    return Container(
      key: const Key('gastosync_web_top_bar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorder, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  effectiveTitle,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            key: const Key('web_top_bar_sync_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: AppTheme.emeraldBadgeDecoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppTheme.emeraldPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  syncStatusLabel,
                  style: const TextStyle(
                    color: AppTheme.emeraldDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _NotificationBellButton(
            iconColor: AppTheme.textSecondary,
            backgroundColor: AppTheme.subtleSurface,
            onTap: onNotificationTap,
          ),
          const SizedBox(width: 12),
          GastoSyncUserAvatar(
            key: const Key('web_top_bar_user_avatar'),
            initials: profile.initials,
            size: 38,
            onTap: onAvatarTap,
          ),
        ],
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.iconColor,
    required this.backgroundColor,
    this.onTap,
  });

  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 20,
              color: iconColor,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget reutilizável com a logo oficial da IA GastoSync (`assets/images/ai_logo.png`)
class GastoSyncAiLogo extends StatelessWidget {
  const GastoSyncAiLogo({
    this.size = 28,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/ai_logo.png',
      width: size,
      height: size,
      color: Colors.white,
      colorBlendMode: BlendMode.srcIn,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, _, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.58,
              fontWeight: FontWeight.w800,
            ),
          ),
          Icon(
            Icons.auto_awesome_rounded,
            size: size * 0.5,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

/// Botão flutuante escuro com a logo da IA que abre o assistente conversacional (FR-006)
class GastoSyncAiFloatingButton extends StatelessWidget {
  const GastoSyncAiFloatingButton({
    this.onPressed,
    super.key,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.navyDark,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      shape: const CircleBorder(),
      child: InkWell(
        key: const Key('gastosync_ai_fab_button'),
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () => GastoSyncAiChatModal.show(context),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Center(
            child: GastoSyncAiLogo(size: 30),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

/// Modal / BottomSheet conversacional do botão `G✨` para dúvidas e análises financeiras (FR-006)
class GastoSyncAiChatModal extends ConsumerStatefulWidget {
  const GastoSyncAiChatModal({super.key});

  static Future<void> show(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= 600) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: const GastoSyncAiChatModal(),
          ),
        ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: const SizedBox(
          height: 540,
          child: GastoSyncAiChatModal(),
        ),
      ),
    );
  }

  @override
  ConsumerState<GastoSyncAiChatModal> createState() =>
      _GastoSyncAiChatModalState();
}

class _GastoSyncAiChatModalState extends ConsumerState<GastoSyncAiChatModal> {
  final _inputController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  static const List<String> _quickPrompts = [
    'Como está meu Burn Rate este mês?',
    'Como atingir 20% de taxa de poupança?',
    'Avaliar minha reserva de emergência',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text:
            'Olá! Sou o assistente financeiro GastoSync (Llama 3.3). Posso analisar seu ritmo de gastos (Burn Rate), sugerir cortes orçamentários ou tirar dúvidas sobre suas 9 métricas de saúde financeira.',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt([String? presetPrompt]) async {
    final text = (presetPrompt ?? _inputController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (presetPrompt == null) {
      _inputController.clear();
    }

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _isSending = true;
    });

    String replyText;
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post<Map<String, dynamic>>(
        ApiConstants.agentChatEndpoint,
        data: {'message': text},
        options: Options(
          sendTimeout: ApiConstants.textPredictionTimeout,
          receiveTimeout: ApiConstants.textPredictionTimeout,
        ),
      );
      final data = response.data;
      replyText = (data?['reply'] ??
              data?['response'] ??
              data?['recommendation'] ??
              _buildLocalContextualReply(text))
          .toString();
    } catch (_) {
      replyText = _buildLocalContextualReply(text);
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: replyText,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _isSending = false;
    });
  }

  String _buildLocalContextualReply(String prompt) {
    final metrics = ref.read(financialMetricsStreamProvider).value;
    final profile = ref.read(userProfileProvider);

    if (metrics == null) {
      return '${profile.firstName}, operando em modo local Offline-First: mantenha os lançamentos atualizados para calcular seu Burn Rate diário e sua meta de ${profile.savingsRateTarget.toStringAsFixed(0)}% de poupança.';
    }

    final lower = prompt.toLowerCase();
    if (lower.contains('burn') || lower.contains('ritmo')) {
      return 'Seu Burn Rate diário atual é de R\$ ${metrics.dailyBurnRate.toStringAsFixed(2)}/dia, com projeção de fim de mês em R\$ ${metrics.monthEndProjection.toStringAsFixed(2)}.';
    }
    if (lower.contains('poupan') || lower.contains('economia')) {
      return 'Sua Taxa de Poupança atual está em ${metrics.savingsRate.toStringAsFixed(1)}% (meta configurada: ${profile.savingsRateTarget.toStringAsFixed(0)}%).';
    }
    return 'Resumo local (${profile.firstName}): Score Financeiro ${metrics.healthScore.toStringAsFixed(0)}/100 • Reserva de ${metrics.emergencyMonths.toStringAsFixed(1)} meses • Comprometimento da renda em ${metrics.incomeCommitment.toStringAsFixed(1)}%.';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('gastosync_ai_chat_modal'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho escuro do modal G✨
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          decoration: const BoxDecoration(
            color: AppTheme.navyDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppTheme.navySurface,
                  shape: BoxShape.circle,
                ),
                child: const GastoSyncAiLogo(size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assistente GastoSync IA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Dúvidas e análises financeiras • Llama 3.3',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ),

        // Sugestões rápidas
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: _quickPrompts
                .map(
                  (prompt) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(
                        prompt,
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _sendPrompt(prompt),
                    ),
                  ),
                )
                .toList(),
          ),
        ),

        // Lista de mensagens
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Align(
                alignment:
                    msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? AppTheme.navyDark
                        : AppTheme.subtleSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: msg.isUser
                        ? null
                        : Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color:
                          msg.isUser ? Colors.white : AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Barra de envio
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.cardBorder)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('ai_chat_input_field'),
                  controller: _inputController,
                  onSubmitted: (_) => _sendPrompt(),
                  decoration: InputDecoration(
                    hintText: 'Pergunte sobre seus gastos ou metas...',
                    isDense: true,
                    filled: true,
                    fillColor: AppTheme.backgroundLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('ai_chat_send_button'),
                onPressed: _isSending ? null : () => _sendPrompt(),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

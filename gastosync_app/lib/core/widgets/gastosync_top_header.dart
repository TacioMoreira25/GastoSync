import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/settings/domain/models/user_profile.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';
import '../theme/app_theme.dart';
import 'gastosync_notifications_modal.dart';

export 'gastosync_notifications_modal.dart';

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

class _NotificationBellButton extends ConsumerWidget {
  const _NotificationBellButton({
    required this.iconColor,
    required this.backgroundColor,
    this.onTap,
  });

  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final hasUnread = unreadCount > 0;
    final badgeLabel = unreadCount > 9 ? '9+' : '$unreadCount';

    return Tooltip(
      message: hasUnread
          ? 'Notificações ($unreadCount não lida${unreadCount > 1 ? "s" : ""})'
          : 'Notificações',
      child: InkWell(
        key: const Key('gastosync_notification_bell_button'),
        onTap: onTap ?? () => GastoSyncNotificationsModal.show(context),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                hasUnread
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
                size: 20,
                color: iconColor,
              ),
              if (hasUnread)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Container(
                    key: const Key('notification_bell_unread_badge'),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: backgroundColor,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      badgeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

class _QuickPrompt {
  const _QuickPrompt(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// Paleta auxiliar do chat (independente do ThemeMode do sistema)
class _ChatColors {
  _ChatColors._();

  static const Color onlineGreen = Color(0xFF34D399); // Emerald 400
  static const Color headerMuted = Color(0xFF94A3B8); // Slate 400
  static const Color bubbleShadow = Color(0x0F0F172A);
}

/// Modal / BottomSheet conversacional do botão `G✨` para dúvidas e análises financeiras (FR-006)
class GastoSyncAiChatModal extends ConsumerStatefulWidget {
  const GastoSyncAiChatModal({this.isBottomSheet = false, super.key});

  /// Quando `true`, renderiza a alça de arraste do layout mobile (BottomSheet)
  final bool isBottomSheet;

  static Future<void> show(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final barrierColor = AppTheme.navyDark.withValues(alpha: 0.45);

    // Web / Tablet: diálogo centralizado
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
              height: math.min(680.0, size.height - 48),
              child: const GastoSyncAiChatModal(),
            ),
          ),
        ),
      );
    }

    // Mobile: BottomSheet ocupando ~88% da tela e respeitando o teclado
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
        final keyboard = mq.viewInsets.bottom;
        final height = math.max(
          280.0,
          math.min(
            mq.size.height * 0.88,
            mq.size.height - keyboard - mq.padding.top - 8,
          ),
        );
        return Theme(
          data: AppTheme.lightTheme,
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: SizedBox(
              height: height,
              child: const GastoSyncAiChatModal(isBottomSheet: true),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<GastoSyncAiChatModal> createState() =>
      _GastoSyncAiChatModalState();
}

class _GastoSyncAiChatModalState extends ConsumerState<GastoSyncAiChatModal> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  static const List<_QuickPrompt> _quickPrompts = [
    _QuickPrompt(
      Icons.local_fire_department_rounded,
      'Como está meu Burn Rate este mês?',
    ),
    _QuickPrompt(
      Icons.savings_rounded,
      'Como atingir 20% de taxa de poupança?',
    ),
    _QuickPrompt(
      Icons.shield_rounded,
      'Avaliar minha reserva de emergência',
    ),
  ];

  bool get _hasUserMessages => _messages.any((m) => m.isUser);

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChanged);
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
    _inputFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
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
    _scrollToBottom();

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
    _scrollToBottom();
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
    final items = <Widget>[
      for (var i = 0; i < _messages.length; i++)
        Padding(
          padding: EdgeInsets.only(
            top: i == 0
                ? 0
                : (_messages[i].isUser == _messages[i - 1].isUser ? 6 : 16),
          ),
          child: _MessageBubble(message: _messages[i]),
        ),
      if (!_hasUserMessages) ...[
        const SizedBox(height: 20),
        _SuggestionList(
          prompts: _quickPrompts,
          enabled: !_isSending,
          onSelected: _sendPrompt,
        ),
      ],
      if (_isSending) ...[
        const SizedBox(height: 16),
        const _TypingBubble(),
      ],
    ];

    return ColoredBox(
      key: const Key('gastosync_ai_chat_modal'),
      color: AppTheme.backgroundLight,
      child: Column(
        children: [
          _ChatHeader(
            showDragHandle: widget.isBottomSheet,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: items,
            ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    final focused = _inputFocusNode.hasFocus;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                decoration: BoxDecoration(
                  color: focused
                      ? AppTheme.cardSurface
                      : AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: focused
                        ? AppTheme.emeraldPrimary
                        : AppTheme.cardBorder,
                    width: focused ? 1.5 : 1,
                  ),
                  boxShadow: focused
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.emeraldPrimary.withValues(alpha: 0.12),
                            blurRadius: 0,
                            spreadRadius: 3,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('ai_chat_input_field'),
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _sendPrompt(),
                        cursorColor: AppTheme.emeraldPrimary,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Pergunte sobre seus gastos ou metas...',
                          hintStyle: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 14,
                          ),
                          filled: false,
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _inputController,
                      builder: (context, value, _) {
                        final canSend =
                            value.text.trim().isNotEmpty && !_isSending;
                        return SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton.filled(
                            key: const Key('ai_chat_send_button'),
                            tooltip: 'Enviar',
                            onPressed: canSend ? () => _sendPrompt() : null,
                            padding: EdgeInsets.zero,
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.emeraldPrimary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.cardBorder,
                              disabledForegroundColor: AppTheme.textMuted,
                            ),
                            icon: _isSending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.textMuted,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                  ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A IA pode cometer erros. Confira informações importantes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho escuro do chat com avatar da IA, status online e botão fechar
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.showDragHandle,
    required this.onClose,
  });

  final bool showDragHandle;
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppTheme.emeraldPrimary, AppTheme.emeraldDeep],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppTheme.emeraldPrimary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const GastoSyncAiLogo(size: 24),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: _ChatColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.navyDark, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Assistente GastoSync IA',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Online',
                          style: TextStyle(
                            color: _ChatColors.onlineGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '  •  Análises financeiras • Llama 3.3',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _ChatColors.headerMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

/// Avatar circular pequeno da IA exibido ao lado das respostas
class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppTheme.navyDark,
        shape: BoxShape.circle,
      ),
      child: const GastoSyncAiLogo(size: 16),
    );
  }
}

/// Bolha de mensagem (usuário à direita em verde, IA à esquerda em branco)
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = math.min(360.0, MediaQuery.sizeOf(context).width * 0.74);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 7),
      decoration: BoxDecoration(
        color: isUser ? null : AppTheme.cardSurface,
        gradient: isUser
            ? const LinearGradient(
                colors: [AppTheme.emeraldPrimary, AppTheme.emeraldDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: isUser ? null : Border.all(color: AppTheme.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: _ChatColors.bubbleShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: isUser ? Colors.white : AppTheme.textPrimary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: isUser
                  ? Colors.white.withValues(alpha: 0.75)
                  : AppTheme.textMuted,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _AiAvatar(),
        const SizedBox(width: 8),
        Flexible(child: bubble),
      ],
    );
  }
}

/// Indicador "digitando..." exibido enquanto a IA responde
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const _AiAvatar(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final phase = (_controller.value - i * 0.18) * 2 * math.pi;
                final wave = (math.sin(phase) + 1) / 2; // 0..1
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                  child: Transform.translate(
                    offset: Offset(0, -3 * wave),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted
                            .withValues(alpha: 0.35 + 0.65 * wave),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// Lista de sugestões rápidas exibida antes da primeira pergunta
class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.prompts,
    required this.onSelected,
    required this.enabled,
  });

  final List<_QuickPrompt> prompts;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUGESTÕES',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          for (final prompt in prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: AppTheme.cardSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppTheme.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: enabled ? () => onSelected(prompt.label) : null,
                  hoverColor: AppTheme.emeraldSoftBg,
                  splashColor: AppTheme.emeraldBadgeBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldSoftBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            prompt.icon,
                            size: 16,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            prompt.label,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

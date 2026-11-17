import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/domain/services/financial_health_engine.dart';
import '../../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../../features/planning/domain/models/credit_card_model.dart';
import '../../features/settings/domain/models/user_profile.dart';
import '../../features/transactions/domain/models/bill.dart';
import '../../features/transactions/domain/models/transaction.dart';
import '../../features/transactions/presentation/controllers/transactions_controller.dart';
import '../constants/api_constants.dart';
import '../database/app_database.dart';
import '../network/dio_client.dart';
import '../security/owasp_prompt_sanitizer.dart';
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
                const Flexible(
                  child: GastoSyncBrandLogo(
                    iconSize: 22,
                    fontSize: 13,
                    textColor: Colors.white,
                  ),
                ),
                if (trailingBadge != null) ...[
                  const SizedBox(width: 8),
                  Flexible(child: trailingBadge!),
                ],
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra superior clara para Web / Desktop (>= 800dp) com sino de notificações (FR-013)
class GastoSyncWebTopBar extends ConsumerWidget {
  const GastoSyncWebTopBar({
    this.title,
    this.subtitle,
    this.syncStatusLabel = '',
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
          if (syncStatusLabel.trim().isNotEmpty) ...[
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
          ],
          _NotificationBellButton(
            iconColor: AppTheme.textSecondary,
            backgroundColor: AppTheme.subtleSurface,
            onTap: onNotificationTap,
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

/// Logo vetorial oficial da IA GastoSync: "G" estilizado em anel + faísca de IA.
///
/// Desenhada via [CustomPainter] para ficar nítida em qualquer tamanho/DPI
/// (Mobile, Web e Desktop), sem depender de assets rasterizados.
/// - [glyphColor]: cor do "G" (branco por padrão, para fundos escuros).
/// - [monochrome]: quando `true`, a faísca usa a mesma cor do "G"
///   (útil sobre fundos esmeralda, onde o gradiente verde perderia contraste).
class GastoSyncAiLogo extends StatelessWidget {
  const GastoSyncAiLogo({
    this.size = 28,
    this.glyphColor = Colors.white,
    this.monochrome = false,
    super.key,
  });

  final double size;
  final Color glyphColor;
  final bool monochrome;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Assistente de IA GastoSync',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GastoSyncAiLogoPainter(
            glyphColor: glyphColor,
            monochrome: monochrome,
          ),
        ),
      ),
    );
  }
}

class _GastoSyncAiLogoPainter extends CustomPainter {
  const _GastoSyncAiLogoPainter({
    required this.glyphColor,
    required this.monochrome,
  });

  final Color glyphColor;
  final bool monochrome;

  static const Color _sparkStart = Color(0xFF6EE7B7); // Emerald 300
  static const Color _sparkEnd = Color(0xFF10B981); // Emerald 500

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height);

    // 1. Anel do "G" (arco aberto no quadrante superior direito)
    final ringCenter = Offset(s * 0.44, s * 0.56);
    final ringRadius = s * 0.31;
    final strokeWidth = s * 0.125;

    final glyphPaint = Paint()
      ..color = glyphColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    const startAngle = 0.0; // ponto à direita, na linha central
    const sweepAngle = 2 * math.pi * (310 / 360); // deixa a abertura para a faísca
    canvas.drawArc(
      Rect.fromCircle(center: ringCenter, radius: ringRadius),
      startAngle,
      sweepAngle,
      false,
      glyphPaint,
    );

    // 2. Barra horizontal interna do "G"
    canvas.drawLine(
      Offset(ringCenter.dx + s * 0.04, ringCenter.dy),
      Offset(ringCenter.dx + ringRadius, ringCenter.dy),
      glyphPaint,
    );

    // 3. Faísca principal de IA (estrela de 4 pontas côncava)
    final sparkCenter = Offset(s * 0.80, s * 0.21);
    final sparkRadius = s * 0.19;
    final sparkPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (monochrome) {
      sparkPaint.color = glyphColor;
    } else {
      sparkPaint.shader = const LinearGradient(
        colors: [_sparkStart, _sparkEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromCircle(center: sparkCenter, radius: sparkRadius),
      );
    }
    canvas.drawPath(_sparkPath(sparkCenter, sparkRadius), sparkPaint);

    // 4. Micro-faísca secundária (dá sensação de "inteligência" em movimento)
    final miniPaint = Paint()
      ..color = (monochrome ? glyphColor : _sparkStart).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(
      _sparkPath(Offset(s * 0.95, s * 0.47), s * 0.065),
      miniPaint,
    );
  }

  Path _sparkPath(Offset c, double r) {
    final k = r * 0.16;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _GastoSyncAiLogoPainter oldDelegate) =>
      oldDelegate.glyphColor != glyphColor ||
      oldDelegate.monochrome != monochrome;
}

/// Selo da IA: fundo navy em gradiente com borda esmeralda sutil + logo vetorial.
/// Use [circular] para avatar redondo ou deixe `false` para cantos arredondados.
class GastoSyncAiBadge extends StatelessWidget {
  const GastoSyncAiBadge({
    this.size = 32,
    this.circular = false,
    this.showGlow = false,
    super.key,
  });

  final double size;
  final bool circular;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: [AppTheme.navySurface, AppTheme.navyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppTheme.emeraldPrimary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppTheme.emeraldPrimary.withValues(alpha: 0.22),
                  blurRadius: size * 0.4,
                  spreadRadius: -size * 0.04,
                  offset: Offset(0, size * 0.04),
                ),
              ]
            : null,
      ),
      child: GastoSyncAiLogo(size: size * 0.6),
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
    return Tooltip(
      message: 'Falar com o assistente de IA',
      child: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: AppTheme.emeraldPrimary.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('gastosync_ai_fab_button'),
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => GastoSyncAiChatModal.show(context),
          child: const GastoSyncAiBadge(
            size: 54,
            circular: true,
            showGlow: true,
          ),
        ),
      ),
    );
  }
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

@immutable
class ChatMessage {
  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  final String text;
  final bool isUser;
  final DateTime timestamp;
}

@immutable
class FiboChatState {
  const FiboChatState({
    this.messages = const <ChatMessage>[],
    this.isSending = false,
    this.isAgentOnline = true,
  });

  final List<ChatMessage> messages;
  final bool isSending;
  final bool isAgentOnline;

  bool get hasUserMessages => messages.any((m) => m.isUser);

  FiboChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isAgentOnline,
  }) {
    return FiboChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isAgentOnline: isAgentOnline ?? this.isAgentOnline,
    );
  }
}

class FiboChatNotifier extends Notifier<FiboChatState> {
  static const String _initialGreeting =
      'Olá! Sou o **Fibo**. Como posso ajudar nas suas finanças hoje?';

  static const String _clearedGreeting =
      'Conversa reiniciada. Como posso ajudar com suas finanças hoje?';

  static const List<String> _fallbackAgentBaseUrls = <String>[
    'http://10.0.2.2:8000',
    'http://localhost:8000',
  ];

  @override
  FiboChatState build() {
    return FiboChatState(
      messages: [
        ChatMessage(
          text: _initialGreeting,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }

  void clearConversation() {
    state = FiboChatState(
      messages: [
        ChatMessage(
          text: _clearedGreeting,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
      isSending: false,
      isAgentOnline: true,
    );
    checkAgentStatus();
  }

  /// Verifica se o serviço de IA está acessível (nuvem Render ou servidor local emulador/host)
  /// e atualiza o indicador Online/Offline do cabeçalho do chat.
  Future<bool> checkAgentStatus() async {
    final dio = ref.read(dioProvider);
    final candidateUrls = <String>[
      dio.options.baseUrl,
      for (final fallback in _fallbackAgentBaseUrls)
        if (fallback != dio.options.baseUrl) fallback,
    ];

    for (final baseUrl in candidateUrls) {
      if (baseUrl.trim().isEmpty) continue;
      try {
        final response = await dio.get<Map<String, dynamic>>(
          '$baseUrl${ApiConstants.agentStatusEndpoint}',
          options: Options(
            sendTimeout: ApiConstants.connectTimeout,
            receiveTimeout: ApiConstants.connectTimeout,
          ),
        );
        if (response.statusCode != null && response.statusCode! < 300) {
          state = state.copyWith(isAgentOnline: true);
          return true;
        }
      } catch (_) {
        try {
          final healthRes = await dio.get<dynamic>(
            '$baseUrl${ApiConstants.healthEndpoint}',
            options: Options(
              sendTimeout: ApiConstants.connectTimeout,
              receiveTimeout: ApiConstants.connectTimeout,
            ),
          );
          if (healthRes.statusCode != null && healthRes.statusCode! < 300) {
            state = state.copyWith(isAgentOnline: true);
            return true;
          }
        } catch (_) {}
      }
    }

    return state.isAgentOnline;
  }

  Future<String?> _postAgentChatWithFallback({
    required String message,
    required List<Map<String, String>> historyPayload,
    required String? financialContext,
  }) async {
    final dio = ref.read(dioProvider);
    final payload = <String, dynamic>{
      'message': message,
      'history': historyPayload,
      'financial_context': ?financialContext,
    };

    final candidateUrls = <String>[
      dio.options.baseUrl,
      dio.options.baseUrl, // 2ª tentativa na URL oficial (suporta wake-up / cold start do Render no Mobile)
      for (final fallback in _fallbackAgentBaseUrls)
        if (fallback != dio.options.baseUrl) fallback,
    ];

    for (final baseUrl in candidateUrls) {
      if (baseUrl.trim().isEmpty) continue;
      try {
        final response = await dio.post<Map<String, dynamic>>(
          '$baseUrl${ApiConstants.agentChatEndpoint}',
          data: payload,
          options: Options(
            sendTimeout: ApiConstants.agentChatTimeout,
            receiveTimeout: ApiConstants.agentChatTimeout,
          ),
        );
        final data = response.data;
        final remoteReply =
            data?['reply'] ?? data?['response'] ?? data?['recommendation'];
        if (remoteReply != null && remoteReply.toString().trim().isNotEmpty) {
          return remoteReply.toString().trim();
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Future<void> sendMessage(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final hasInjection = OwaspPromptSanitizer.containsInjectionAttempt(trimmed);
    final sanitizedText = OwaspPromptSanitizer.sanitize(trimmed);

    // Prepara payload de histórico com até as últimas 8 mensagens anteriores (sem saudação estática nem duplicar a mensagem atual)
    final priorMessages = state.messages
        .where(
          (m) =>
              m.text.isNotEmpty &&
              m.text != _initialGreeting &&
              m.text != _clearedGreeting,
        )
        .toList();
    final recent = priorMessages.length > 8
        ? priorMessages.sublist(priorMessages.length - 8)
        : priorMessages;
    final historyPayload = recent
        .map((m) => <String, String>{
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: sanitizedText,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      ],
      isSending: true,
    );

    if (hasInjection) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            text:
                'Proteção OWASP MASVS ativa: entrada bloqueada por conter padrões suspeitos de Prompt Injection. Envie apenas dúvidas ou lançamentos financeiros.',
            isUser: false,
            timestamp: DateTime.now(),
          ),
        ],
        isSending: false,
      );
      return;
    }

    // Contexto financeiro completo do usuário local (Renda, Despesas, Boletos, Cartões, Poupança, Reserva e Score)
    final metrics = ref.read(financialMetricsStreamProvider).value;
    final profile = ref.read(userProfileProvider);
    final transactions =
        ref.read(watchTransactionsProvider).value ?? const <Transaction>[];
    final bills = (ref.read(watchBillsProvider).value ?? const <Bill>[])
        .where((b) => !b.isDeleted)
        .toList();
    final creditCards =
        (ref.read(watchCreditCardsProvider).value ?? const <LocalCreditCard>[])
            .map(CreditCard.fromLocal)
            .toList();

    final effectiveIncome = (metrics != null && metrics.totalIncome > 0)
        ? metrics.totalIncome
        : profile.monthlyBaseIncome;
    final pendingCashBills =
        BillCalculations.calculateTotalPendingCashOutflow(bills);
    final cardSummaries = CreditCardUsageSummary.calculateAll(
      cards: creditCards,
      transactions: transactions,
      bills: bills,
    );

    String? financialContext;
    if (metrics != null) {
      final realisticProj = metrics.realisticMonthEndProjection(
        pendingMonthCashBills: pendingCashBills,
      );
      final cardsInfo = cardSummaries.isEmpty
          ? 'Sem cartões cadastrados'
          : cardSummaries
              .map(
                (s) =>
                    '${s.card.name}: usado R\$ ${s.totalUsedAmount.toStringAsFixed(2)} de R\$ ${s.card.limitAmount.toStringAsFixed(2)} (${s.utilizationPercent.toStringAsFixed(1)}%, teto saudável R\$ ${s.card.healthyMaxAmount.toStringAsFixed(2)})',
              )
              .join('; ');

      financialContext =
          '[Contexto silencioso da conta de ${profile.firstName} — cite apenas os números que tiverem relação direta com a pergunta, sem listar indicadores fixos]\n'
          'Renda mensal: R\$ ${effectiveIncome.toStringAsFixed(2)} | '
          'Despesas no mês: R\$ ${metrics.totalExpense.toStringAsFixed(2)} (Fixas: R\$ ${metrics.fixedExpenses.toStringAsFixed(2)}, Variáveis: R\$ ${metrics.variableExpenses.toStringAsFixed(2)}) | '
          'Saldo disponível: R\$ ${metrics.currentBalance.toStringAsFixed(2)} | '
          'Boletos pendentes: R\$ ${pendingCashBills.toStringAsFixed(2)} | '
          'Poupança atual: ${metrics.savingsRate.toStringAsFixed(1)}% (Meta: ${profile.savingsRateTarget.toStringAsFixed(0)}%) | '
          'Comprometimento: ${metrics.incomeCommitment.toStringAsFixed(1)}% | '
          'Reserva: ${metrics.formattedEmergencyMonths} | '
          'Score: ${metrics.roundedScore}/100 (${metrics.scoreStatusLabel}) | '
          'Ritmo diário: R\$ ${metrics.dailyBurnRate.toStringAsFixed(2)}/dia | '
          'Projeção fim do mês: R\$ ${realisticProj.toStringAsFixed(2)} | '
          'Cartões: $cardsInfo\n'
          'ESTILO DE ATENDIMENTO: Seja ultra-curto, intuitivo e direto ao ponto (no máximo 2 frases curtas, até 35 palavras). '
          'Passe apenas a informação essencial para responder à pergunta, sem textos longos e sem listar dados que não foram perguntados. '
          'Só dê explicações longas se o usuário pedir explicitamente para detalhar.';
    }

    final remoteReply = await _postAgentChatWithFallback(
      message: sanitizedText,
      historyPayload: historyPayload,
      financialContext: financialContext,
    );

    final bool isOnline = remoteReply != null;
    final String replyText = remoteReply ??
        _buildLocalFallbackReply(
          sanitizedText,
          metrics,
          profile,
          bills: bills,
          cardSummaries: cardSummaries,
        );

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          text: replyText,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
      isSending: false,
      isAgentOnline: isOnline,
    );
  }

  static String _fmtBrl(double value) {
    final abs = value.abs();
    final parts = abs.toStringAsFixed(2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    final prefix = value < 0 ? '-R\$ ' : 'R\$ ';
    return '$prefix$intPart,${parts[1]}';
  }

  static String _buildLocalFallbackReply(
    String prompt,
    FinancialMetrics? metrics,
    UserProfile profile, {
    List<Bill> bills = const <Bill>[],
    List<CreditCardUsageSummary> cardSummaries =
        const <CreditCardUsageSummary>[],
  }) {
    final lower = prompt.trim().toLowerCase();

    if (RegExp(
      r'^(oi+|ol[aá]+|opa|e\s*a[ií]|bom\s+dia|boa\s+tarde|boa\s+noite|tudo\s+bem|quem\s+[eé]\s+voc[eê]|o\s+que\s+voc[eê]\s+faz|como\s+funciona)\b',
    ).hasMatch(lower)) {
      return 'Olá, **${profile.firstName}**! Sou o **Fibo**. Qual dúvida financeira vamos resolver agora?';
    }

    if (metrics == null || !metrics.hasTransactions) {
      return 'Você ainda não tem lançamentos registrados. Adicione sua renda ou despesa no botão **+** para eu analisar!';
    }

    final effectiveIncome = metrics.totalIncome > 0
        ? metrics.totalIncome
        : profile.monthlyBaseIncome;
    final pendingCashBills =
        BillCalculations.calculateTotalPendingCashOutflow(bills);
    final realisticProj = metrics.realisticMonthEndProjection(
      pendingMonthCashBills: pendingCashBills,
    );
    final now = DateTime.now();
    final totalDays = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = math.max(1, totalDays - now.day);
    final ceiling =
        effectiveIncome * (1.0 - (profile.savingsRateTarget / 100.0));
    final remainingAllowance = math.max(
      0.0,
      ceiling - metrics.totalExpense - pendingCashBills,
    );
    final dailySuggested = remainingAllowance / remainingDays;

    // 1. Pedido explícito de detalhes
    if (lower.contains('complet') ||
        lower.contains('detalh') ||
        lower.contains('passo a passo')) {
      return '• **Saldo:** ${_fmtBrl(metrics.currentBalance)} | **Score:** ${metrics.roundedScore}/100\n'
          '• **Mês:** ${_fmtBrl(effectiveIncome)} (renda) vs. ${_fmtBrl(metrics.totalExpense)} (gastos)\n'
          '• **Meta diária:** até **${_fmtBrl(dailySuggested)}/dia** nos próximos $remainingDays dias.';
    }

    // 2. Simulação de compra ("posso gastar X?")
    final numberMatch = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(lower);
    if ((lower.contains('gastar') ||
            lower.contains('comprar') ||
            lower.contains('compra') ||
            lower.contains('cabe')) &&
        numberMatch != null) {
      final simulatedValue =
          double.tryParse(numberMatch.group(1)!.replaceAll(',', '.')) ?? 0.0;
      if (simulatedValue > 0 && simulatedValue != 20.0) {
        final balanceAfter = metrics.currentBalance - simulatedValue;
        final fits =
            simulatedValue <= remainingAllowance && balanceAfter >= 0;
        return fits
            ? '✅ **Cabe no orçamento!** Seu saldo ficará em **${_fmtBrl(balanceAfter)}** (meta restante: **${_fmtBrl((remainingAllowance - simulatedValue) / remainingDays)}/dia**).'
            : '⚠️ **Pesa no mês.** Sua folga atual é de **${_fmtBrl(remainingAllowance)}** e seu saldo cairia para **${_fmtBrl(balanceAfter)}**.';
      }
    }

    // 3. Cartões
    if (lower.contains('cartão') ||
        lower.contains('cartao') ||
        lower.contains('limite') ||
        lower.contains('fatura')) {
      if (cardSummaries.isEmpty) {
        return 'Nenhum cartão cadastrado ainda. Adicione o seu em **Planejamento > Cartões** para monitorar o limite.';
      }
      final main = cardSummaries.first;
      return '💳 **${main.card.name}:** usado **${_fmtBrl(main.totalUsedAmount)}** de **${_fmtBrl(main.card.limitAmount)}** (**${main.utilizationPercent.toStringAsFixed(0)}%**).\n'
          '${main.isAboveHealthyCeiling ? "⚠️ Acima do teto saudável de ${main.card.targetMaxPercent.toStringAsFixed(0)}%." : "✅ Restam **${_fmtBrl(main.remainingHealthyMargin)}** dentro da faixa saudável."}';
    }

    // 4. Boletos
    if (lower.contains('boleto') ||
        lower.contains('vencimento') ||
        lower.contains('conta')) {
      final openBills = bills.where((b) => !b.isPaid).toList();
      if (openBills.isEmpty) {
        return '✅ **Nenhum boleto pendente** no momento.';
      }
      return '📄 Você tem **${openBills.length} boleto(s)** em aberto somando **${_fmtBrl(pendingCashBills)}** (saldo atual: **${_fmtBrl(metrics.currentBalance)}**).';
    }

    // 5. Burn Rate / Ritmo
    if (lower.contains('burn') || lower.contains('ritmo')) {
      final withinCeiling = ceiling > 0 && realisticProj <= ceiling;
      return '${withinCeiling ? "✅ **Ritmo controlado:**" : "⚠️ **Ritmo elevado:**"} **${_fmtBrl(metrics.dailyBurnRate)}/dia** (projeção de **${_fmtBrl(realisticProj)}** no mês).\n'
          '${effectiveIncome > 0 ? "💡 Gaste até **${_fmtBrl(dailySuggested)}/dia** nos próximos $remainingDays dias." : "💡 Defina sua Renda Base na aba Mais para ver seu limite diário."}';
    }

    // 6. Poupança
    if (lower.contains('poupan') ||
        lower.contains('economia') ||
        lower.contains('economizar')) {
      final targetPct =
          profile.savingsRateTarget > 0 ? profile.savingsRateTarget : 20.0;
      final targetValue = effectiveIncome * (targetPct / 100.0);
      final currentSaved =
          math.max(0.0, effectiveIncome - metrics.totalExpense);
      final displaySavingsPct = math.max(0.0, metrics.savingsRate);

      if (effectiveIncome <= 0) {
        return 'Cadastre sua receita ou **Renda Base** na aba **Mais** para calcular sua meta de **${targetPct.toStringAsFixed(0)}%**.';
      }
      return '💰 **Poupança atual:** **${_fmtBrl(currentSaved)}** (**${displaySavingsPct.toStringAsFixed(0)}%** da renda · meta: **${_fmtBrl(targetValue)}**).\n'
          '💡 Limite gastos variáveis a **${_fmtBrl(dailySuggested)}/dia** para bater a meta.';
    }

    // 7. Reserva de Emergência
    if (lower.contains('reserva') || lower.contains('emerg')) {
      return '🛡️ **Reserva atual:** **${_fmtBrl(metrics.currentBalance)}**, cobrindo **${metrics.formattedEmergencyMonths}** dos seus custos (meta ideal: **6 meses**).';
    }

    // 8. Resumo curto padrão
    return '📊 **Saldo:** **${_fmtBrl(metrics.currentBalance)}** | **Gastos no mês:** **${_fmtBrl(metrics.totalExpense)}** (${effectiveIncome > 0 ? "limite seguro: **${_fmtBrl(dailySuggested)}/dia**" : "Score **${metrics.roundedScore}/100**"}).';
  }
}

final fiboChatControllerProvider =
    NotifierProvider<FiboChatNotifier, FiboChatState>(FiboChatNotifier.new);

class _GastoSyncAiChatModalState extends ConsumerState<GastoSyncAiChatModal> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

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

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(fiboChatControllerProvider.notifier).checkAgentStatus();
    });
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
    final rawText = (presetPrompt ?? _inputController.text).trim();
    if (rawText.isEmpty) return;

    final chatState = ref.read(fiboChatControllerProvider);
    if (chatState.isSending) return;

    if (presetPrompt == null) {
      _inputController.clear();
    }

    _scrollToBottom();
    await ref.read(fiboChatControllerProvider.notifier).sendMessage(rawText);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(fiboChatControllerProvider);
    final messages = chatState.messages;
    final isSending = chatState.isSending;
    final hasUserMessages = chatState.hasUserMessages;

    final items = <Widget>[
      for (var i = 0; i < messages.length; i++)
        Padding(
          padding: EdgeInsets.only(
            top: i == 0
                ? 0
                : (messages[i].isUser == messages[i - 1].isUser ? 6 : 16),
          ),
          child: _MessageBubble(message: messages[i]),
        ),
      if (!hasUserMessages) ...[
        const SizedBox(height: 20),
        _SuggestionList(
          prompts: _quickPrompts,
          enabled: !isSending,
          onSelected: _sendPrompt,
        ),
      ] else if (!isSending &&
          messages.isNotEmpty &&
          !messages.last.isUser) ...[
        Padding(
          padding: const EdgeInsets.only(left: 36, top: 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FollowUpChip(
                label: 'Quero uma análise mais completa',
                icon: Icons.auto_awesome_outlined,
                onTap: () => _sendPrompt(
                  'Me dê uma análise mais completa e passo a passo sobre isso.',
                ),
              ),
              _FollowUpChip(
                label: 'Posso gastar R\$ 100 hoje?',
                icon: Icons.shopping_bag_outlined,
                onTap: () => _sendPrompt('Posso gastar R\$ 100 hoje?'),
              ),
              _FollowUpChip(
                label: 'Analisar meus cartões',
                icon: Icons.credit_card_rounded,
                onTap: () => _sendPrompt('Como está o uso dos meus cartões?'),
              ),
            ],
          ),
        ),
      ],
      if (isSending) ...[
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
            isOnline: chatState.isAgentOnline,
            onClear: () {
              ref.read(fiboChatControllerProvider.notifier).clearConversation();
              _scrollToBottom();
            },
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: items,
            ),
          ),
          _buildComposer(isSending),
        ],
      ),
    );
  }

  Widget _buildComposer(bool isSending) {
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
                            value.text.trim().isNotEmpty && !isSending;
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
                            icon: isSending
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

/// Cabeçalho escuro do chat com avatar da IA, status Online/Offline e botão fechar
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.showDragHandle,
    required this.isOnline,
    required this.onClose,
    this.onClear,
  });

  final bool showDragHandle;
  final bool isOnline;
  final VoidCallback onClose;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        isOnline ? _ChatColors.onlineGreen : AppTheme.warningAmber;
    final statusLabel = isOnline ? 'Online' : 'Offline';

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
                    child: const GastoSyncAiLogo(size: 26, monochrome: true),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.navyDark, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
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
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Flexible(
                          child: Text(
                            '  •  Análise Financeira • Llama 3.3',
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
              if (onClear != null) ...[
                IconButton(
                  tooltip: 'Nova conversa',
                  onPressed: onClear,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    fixedSize: const Size(36, 36),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                ),
                const SizedBox(width: 6),
              ],
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
    return const GastoSyncAiBadge(size: 28, circular: true);
  }
}

/// Bolha de mensagem (usuário à direita em verde ajustada ao texto, IA à esquerda em card elegante)
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth >= 600
        ? 440.0
        : math.min(380.0, screenWidth * 0.82);

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.emeraldPrimary, AppTheme.emeraldDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w500,
                  height: 1.42,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: _AiAvatar(),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 10),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(color: AppTheme.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: _ChatColors.bubbleShadow,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _AiStructuredMessageView(rawText: message.text),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 11,
                      color: AppTheme.emeraldPrimary.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fibo · ${_formatTime(message.timestamp)}',
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Renderizador estruturado para respostas da IA:
/// - Quebra automaticamente listas inline (`1) ... 2) ...` ou `1. ... 2. ...`) em itens visuais separados;
/// - Aplica tipografia leve e legível no texto corrido e destaca automaticamente valores `R$` e `%`;
/// - Exibe cards numerados e marcadores esmeralda limpos no Mobile e no Web.
class _AiStructuredMessageView extends StatefulWidget {
  const _AiStructuredMessageView({required this.rawText});

  final String rawText;

  @override
  State<_AiStructuredMessageView> createState() =>
      _AiStructuredMessageViewState();
}

class _AiStructuredMessageViewState extends State<_AiStructuredMessageView> {
  bool _isExpanded = false;

  /// Normaliza textos corridos enviados pela IA (ex: "Passo a passo: 1) ... 2) ...")
  /// em linhas estruturadas para apresentação visual limpa.
  static String _normalizeStructure(String raw) {
    var text = raw.replaceAll('\r\n', '\n').trim();

    // Separa prefixos como "Passo a passo:" ou "Resumo:" em sua própria linha de título
    text = text.replaceAllMapped(
      RegExp(
        r'^(passo a passo|resumo|an[aá]lise|como funciona|detalhamento)\s*:\s*',
        caseSensitive: false,
      ),
      (m) => '### ${m[1]![0].toUpperCase()}${m[1]!.substring(1)}\n',
    );

    // Quebra itens numerados inline "1) ... 2) ..." ou "1. ... 2. ..." em linhas próprias
    text = text.replaceAllMapped(
      RegExp(r'(?:(?<=\s)|^)(\d{1,2})\)\s+'),
      (m) => '\n${m[1]}. ',
    );
    text = text.replaceAllMapped(
      RegExp(r'(?<=[.;!])\s+(\d{1,2})\.\s+'),
      (m) => '\n${m[1]}. ',
    );

    // Quebra bullets inline " • " em linhas próprias
    text = text.replaceAll(RegExp(r'\s+•\s+'), '\n• ');

    // Garante espaço após "R$" quando vier colado ("R$0,00" -> "R$ 0,00")
    text = text.replaceAllMapped(
      RegExp(r'R\$(\d)'),
      (m) => 'R\$ ${m[1]}',
    );

    return text.trim();
  }

  ({String summary, String? details}) _splitSummaryAndDetails(String text) {
    final normalized = _normalizeStructure(text);

    // Divisor explícito ---DETALHES---
    final separatorRegex = RegExp(
      r'\n*\s*---+\s*DETALHES\s*---+\s*\n*',
      caseSensitive: false,
    );
    if (separatorRegex.hasMatch(normalized)) {
      final parts = normalized.split(separatorRegex);
      final summary = parts.first.trim();
      final details = parts.skip(1).join('\n\n').trim();
      return (
        summary: summary.isNotEmpty ? summary : normalized,
        details: details.isNotEmpty ? details : null,
      );
    }

    return (summary: normalized, details: null);
  }

  /// Destaca `**negrito**`, valores monetários (`R$ 1.500,00`) e percentuais (`20%`)
  /// mantendo o restante do texto em peso regular suave e confortável de ler.
  List<InlineSpan> _parseRichSpans(
    String line, {
    Color baseColor = const Color(0xFF334155),
    double fontSize = 13.6,
    FontWeight defaultWeight = FontWeight.w400,
  }) {
    final tokenRegex = RegExp(
      r'\*\*(.+?)\*\*|(R\$\s*\d+(?:[.,]\d+)*(?:/dia|/m[eê]s)?)|(\b\d+(?:[.,]\d+)?%)',
    );
    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in tokenRegex.allMatches(line)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: line.substring(currentIndex, match.start),
            style: TextStyle(
              color: baseColor,
              fontSize: fontSize,
              fontWeight: defaultWeight,
              height: 1.48,
            ),
          ),
        );
      }

      if (match.group(1) != null) {
        // **Negrito explícito**
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.48,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // Valor monetário R$ ...
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              color: AppTheme.emeraldDeep,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.48,
            ),
          ),
        );
      } else if (match.group(3) != null) {
        // Percentual ...%
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.48,
            ),
          ),
        );
      }
      currentIndex = match.end;
    }

    if (currentIndex < line.length) {
      spans.add(
        TextSpan(
          text: line.substring(currentIndex),
          style: TextStyle(
            color: baseColor,
            fontSize: fontSize,
            fontWeight: defaultWeight,
            height: 1.48,
          ),
        ),
      );
    }

    return spans;
  }

  Widget _buildFormattedSection(String content) {
    final rawLines = content.split('\n');
    final widgets = <Widget>[];

    for (var i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) continue;

      // 1. Cabeçalhos (### Título)
      if (line.startsWith('#')) {
        final cleanHeader = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: widgets.isEmpty ? 0 : 8, bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(right: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldPrimary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: Text(
                    cleanHeader.replaceAll('**', ''),
                    style: const TextStyle(
                      color: AppTheme.navyDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 2. Callout de Ação Recomendada / Alerta (💡, ⚠️)
      if (line.startsWith('💡') || line.startsWith('⚠️')) {
        final isWarning = line.startsWith('⚠️');
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6, bottom: 2),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: isWarning
                  ? AppTheme.warningBadgeBg.withValues(alpha: 0.65)
                  : AppTheme.emeraldSoftBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isWarning
                    ? AppTheme.warningBorder
                    : AppTheme.emeraldBadgeBg,
              ),
            ),
            child: RichText(
              text: TextSpan(
                children: _parseRichSpans(
                  line,
                  baseColor:
                      isWarning ? AppTheme.warningDark : AppTheme.emeraldDeep,
                  fontSize: 13,
                  defaultWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
        continue;
      }

      // 3. Item de lista com bullet (•, -, *)
      if (line.startsWith('•') ||
          line.startsWith('- ') ||
          line.startsWith('* ')) {
        final cleanBullet =
            line.replaceFirst(RegExp(r'^[•\-*]\s*'), '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 7, right: 9),
                  decoration: const BoxDecoration(
                    color: AppTheme.emeraldPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _parseRichSpans(
                        cleanBullet,
                        fontSize: 13.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 4. Item numerado (1., 2., 3.) renderizado como mini-card organizado
      final numMatch = RegExp(r'^(\d+)\.\s+(.+)$').firstMatch(line);
      if (numMatch != null) {
        final stepNum = numMatch.group(1)!;
        final stepText = numMatch.group(2)!;
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.subtleSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.emeraldSoftBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    stepNum,
                    style: const TextStyle(
                      color: AppTheme.emeraldDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: _parseRichSpans(
                        stepText,
                        fontSize: 13.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // 5. Parágrafo padrão (peso regular suave, destacando apenas valores e negritos)
      widgets.add(
        Padding(
          padding: EdgeInsets.only(bottom: i < rawLines.length - 1 ? 6 : 0),
          child: RichText(
            text: TextSpan(
              children: _parseRichSpans(
                line,
                fontSize: 13.8,
                defaultWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parts = _splitSummaryAndDetails(widget.rawText);
    final hasDetails = parts.details != null && parts.details!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFormattedSection(parts.summary),
        if (hasDetails) ...[
          const SizedBox(height: 8),
          if (_isExpanded) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: _buildFormattedSection(parts.details!),
            ),
          ],
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppTheme.emeraldDeep,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isExpanded ? 'Mostrar menos' : 'Ver mais',
                    style: const TextStyle(
                      color: AppTheme.emeraldDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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

class _FollowUpChip extends StatelessWidget {
  const _FollowUpChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: AppTheme.emeraldBadgeBg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTheme.emeraldSoftBg,
        splashColor: AppTheme.emeraldBadgeBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppTheme.emeraldDeep),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.emeraldDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

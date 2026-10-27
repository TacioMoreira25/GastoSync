import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_provider.dart';

/// Paleta auxiliar da tela de login (fundo escuro destacado)
class _LoginColors {
  _LoginColors._();

  static const Color bgTop = Color(0xFF0B1220);
  static const Color bgBottom = Color(0xFF0F2027);
  static const Color mutedOnDark = Color(0xFF94A3B8); // Slate 400
  static const Color errorBg = Color(0xFFFEF2F2); // Red 50
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submittedOnce = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleMode(bool registerMode) {
    if (_isRegisterMode == registerMode) return;
    ref.read(authProvider.notifier).clearError();
    setState(() {
      _isRegisterMode = registerMode;
      _submittedOnce = false;
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).clearError();

    setState(() => _submittedOnce = true);

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final authNotifier = ref.read(authProvider.notifier);
    if (_isRegisterMode) {
      authNotifier.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      authNotifier.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
      prefixIcon: Icon(prefixIcon, size: 19, color: AppTheme.textMuted),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppTheme.backgroundLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border(AppTheme.cardBorder),
      enabledBorder: border(AppTheme.cardBorder),
      focusedBorder: border(AppTheme.emeraldPrimary, 1.5),
      errorBorder: border(AppTheme.errorColor),
      focusedErrorBorder: border(AppTheme.errorColor, 1.5),
      errorStyle: const TextStyle(fontSize: 12),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
    Key? key,
  }) {
    return IconButton(
      key: key,
      tooltip: obscured ? 'Mostrar senha' : 'Ocultar senha',
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        size: 19,
        color: AppTheme.textMuted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        key: const Key('login_screen'),
        backgroundColor: _LoginColors.bgTop,
        body: Stack(
          children: [
            // Fundo escuro em degradê com brilhos esmeralda sutis
            const Positioned.fill(child: _LoginBackground()),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 28),
                        _buildCard(),
                        const SizedBox(height: 22),
                        const _SecurityNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    final authState = ref.watch(authProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 48,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: _submittedOnce
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isRegisterMode ? 'Crie sua conta' : 'Bem-vindo de volta',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isRegisterMode
                  ? 'Leva menos de um minuto.'
                  : 'Entre para acessar seu painel financeiro.',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 20),

            // Seletor Entrar | Criar conta
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.subtleSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTabButton(
                      key: const Key('login_tab_signin'),
                      label: 'Entrar',
                      selected: !_isRegisterMode,
                      onTap: () => _toggleMode(false),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _ModeTabButton(
                      key: const Key('login_tab_register'),
                      label: 'Criar conta',
                      selected: _isRegisterMode,
                      onTap: () => _toggleMode(true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Banner de erro de autenticação
            if (authState.errorMessage != null) ...[
              Container(
                key: const Key('login_error_banner'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _LoginColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppTheme.errorColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppTheme.errorColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.errorMessage!,
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Campo Nome (apenas no cadastro)
            if (_isRegisterMode) ...[
              _fieldLabel('Nome completo'),
              TextFormField(
                key: const Key('login_name_input'),
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                validator: (_) =>
                    AuthNotifier.validateName(_nameController.text),
                decoration: _inputDecoration(
                  hint: 'Ex: Marcos Pereira',
                  prefixIcon: Icons.person_outline_rounded,
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Campo E-mail
            _fieldLabel('E-mail'),
            TextFormField(
              key: const Key('login_email_input'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              validator: (_) =>
                  AuthNotifier.validateEmail(_emailController.text),
              decoration: _inputDecoration(
                hint: 'seu.email@exemplo.com',
                prefixIcon: Icons.mail_outline_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // Campo Senha
            _fieldLabel('Senha'),
            TextFormField(
              key: const Key('login_password_input'),
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction:
                  _isRegisterMode ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _isRegisterMode ? null : (_) => _submit(),
              validator: (_) =>
                  AuthNotifier.validatePassword(_passwordController.text),
              decoration: _inputDecoration(
                hint: 'Mínimo de 8 caracteres',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: _visibilityToggle(
                  key: const Key('login_toggle_password_visibility'),
                  obscured: _obscurePassword,
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),

            // Campo Confirmar Senha (apenas no cadastro)
            if (_isRegisterMode) ...[
              const SizedBox(height: 14),
              _fieldLabel('Confirmar senha'),
              TextFormField(
                key: const Key('login_confirm_password_input'),
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (_) {
                  final confirm = _confirmPasswordController.text.trim();
                  if (confirm.isEmpty) return 'Confirme sua senha.';
                  if (confirm != _passwordController.text.trim()) {
                    return 'As senhas não coincidem.';
                  }
                  return null;
                },
                decoration: _inputDecoration(
                  hint: 'Repita sua senha',
                  prefixIcon: Icons.verified_user_outlined,
                  suffixIcon: _visibilityToggle(
                    obscured: _obscureConfirmPassword,
                    onPressed: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Botão principal Entrar / Criar conta
            SizedBox(
              height: 50,
              child: FilledButton(
                key: const Key('login_submit_button'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.emeraldPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRegisterMode ? 'Criar conta' : 'Entrar',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fundo escuro em degradê com dois brilhos radiais esmeralda
class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_LoginColors.bgTop, _LoginColors.bgBottom],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160,
            right: -120,
            child: _Glow(
              size: 460,
              color: AppTheme.emeraldPrimary.withValues(alpha: 0.22),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -140,
            child: _Glow(
              size: 520,
              color: const Color(0xFF14B8A6).withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// Logo + nome + slogan exibidos acima do card, sobre o fundo escuro
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.emeraldPrimary, AppTheme.emeraldDeep],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emeraldPrimary.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Text(
            'G',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'GastoSync',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Seu dinheiro sob controle, mesmo offline.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _LoginColors.mutedOnDark,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Nota de segurança discreta abaixo do card
class _SecurityNote extends StatelessWidget {
  const _SecurityNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.lock_outline_rounded,
          size: 13,
          color: _LoginColors.mutedOnDark,
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Dados protegidos localmente com hash e bloqueio de tentativas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _LoginColors.mutedOnDark,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppTheme.cardSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppTheme.navyDark.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

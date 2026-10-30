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

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submittedOnce = false;

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();

    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_passwordFocusNode.canRequestFocus) {
        _passwordFocusNode.requestFocus();
      }
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_confirmPasswordFocusNode.canRequestFocus) {
        _confirmPasswordFocusNode.requestFocus();
      }
    });
  }

  void _toggleMode(bool registerMode) {
    if (_isRegisterMode == registerMode) return;
    ref.read(authProvider.notifier).clearError();
    _formKey.currentState?.reset();
    setState(() {
      _isRegisterMode = registerMode;
      _submittedOnce = false;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    ref.read(authProvider.notifier).clearError();

    setState(() => _submittedOnce = true);

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final authNotifier = ref.read(authProvider.notifier);
    if (_isRegisterMode) {
      final created = await authNotifier.register(
        fullName: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (created && mounted) {
        _formKey.currentState?.reset();
        setState(() {
          _isRegisterMode = false;
          _submittedOnce = false;
          _passwordController.clear();
          _confirmPasswordController.clear();
        });
      }
    } else {
      await authNotifier.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
  }

  Future<void> _showResetPasswordModal() async {
    ref.read(authProvider.notifier).clearError();
    await showDialog<void>(
      context: context,
      builder: (ctx) => Theme(
        data: AppTheme.lightTheme,
        child: _ResetPasswordDialog(
          initialEmail: _emailController.text.trim(),
          onEmailUpdated: (email) {
            if (_emailController.text.trim().isEmpty) {
              _emailController.text = email;
            }
          },
        ),
      ),
    );
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
                    constraints: const BoxConstraints(maxWidth: 420),
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
                  ? 'Cadastre seus dados e uma senha forte para criar sua conta.'
                  : 'Entre com seu e-mail e senha para acessar o painel.',
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

            // Banner verde de sucesso (conta criada ou senha alterada)
            if (authState.successMessage != null) ...[
              Container(
                key: const Key('login_success_banner'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSoftBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.emeraldBadgeBg),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      color: AppTheme.emeraldDeep,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authState.successMessage!,
                        style: const TextStyle(
                          color: AppTheme.emeraldDeep,
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

            // Banner vermelho de erro de autenticação
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

            // Campo Nome (apenas na aba Criar conta)
            if (_isRegisterMode) ...[
              _fieldLabel('Nome completo'),
              TextFormField(
                key: const Key('login_name_input'),
                focusNode: _nameFocusNode,
                controller: _nameController,
                cursorColor: AppTheme.emeraldPrimary,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
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
              focusNode: _emailFocusNode,
              controller: _emailController,
              cursorColor: AppTheme.emeraldPrimary,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (_) =>
                  AuthNotifier.validateEmail(_emailController.text),
              decoration: _inputDecoration(
                hint: 'seu.email@exemplo.com',
                prefixIcon: Icons.mail_outline_rounded,
              ),
            ),
            const SizedBox(height: 14),

            // Rótulo Senha + botão "Alterar senha" (apenas na aba Entrar)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _fieldLabel('Senha'),
                if (!_isRegisterMode)
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        key: const Key('login_forgot_password_button'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: _showResetPasswordModal,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text(
                            'Esqueceu / Alterar senha?',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppTheme.emeraldDeep,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Campo Senha (validação simples no Login vs validação forte no Cadastro)
            TextFormField(
              key: const Key('login_password_input'),
              focusNode: _passwordFocusNode,
              controller: _passwordController,
              cursorColor: AppTheme.emeraldPrimary,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction:
                  _isRegisterMode ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _isRegisterMode ? null : (_) => _submit(),
              validator: (_) => _isRegisterMode
                  ? AuthNotifier.validatePassword(_passwordController.text)
                  : AuthNotifier.validateLoginPassword(_passwordController.text),
              decoration: _inputDecoration(
                hint: _isRegisterMode
                    ? 'Crie uma senha forte (8+ caracteres)'
                    : 'Digite sua senha',
                prefixIcon: Icons.lock_outline_rounded,
                suffixIcon: _visibilityToggle(
                  key: const Key('login_toggle_password_visibility'),
                  obscured: _obscurePassword,
                  onPressed: _togglePasswordVisibility,
                ),
              ),
            ),

            // Medidor de Segurança e Confirmar Senha: APENAS na aba Criar conta
            if (_isRegisterMode) ...[
              const SizedBox(height: 10),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _passwordController,
                builder: (context, value, _) {
                  final analysis = AuthNotifier.analyzePassword(value.text);
                  return _PasswordSecurityMeter(
                    analysis: analysis,
                    hasInput: value.text.trim().isNotEmpty,
                  );
                },
              ),
              const SizedBox(height: 14),
              _fieldLabel('Confirmar senha'),
              TextFormField(
                key: const Key('login_confirm_password_input'),
                focusNode: _confirmPasswordFocusNode,
                controller: _confirmPasswordController,
                cursorColor: AppTheme.emeraldPrimary,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                obscureText: _obscureConfirmPassword,
                enableSuggestions: false,
                autocorrect: false,
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
                    onPressed: _toggleConfirmPasswordVisibility,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 22),

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

/// Modal para redefinir/alterar senha de uma conta cadastrada
class _ResetPasswordDialog extends ConsumerStatefulWidget {
  const _ResetPasswordDialog({
    required this.initialEmail,
    required this.onEmailUpdated,
  });

  final String initialEmail;
  final ValueChanged<String> onEmailUpdated;

  @override
  ConsumerState<_ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends ConsumerState<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmFocusNode.dispose();

    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSaveNewPassword() {
    setState(() => _dialogError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final err = ref.read(authProvider.notifier).changePassword(
          email: _emailController.text,
          newPassword: _newPasswordController.text,
        );
    if (err != null) {
      setState(() => _dialogError = err);
      return;
    }

    widget.onEmailUpdated(_emailController.text.trim());
    Navigator.of(context).pop();
  }

  void _toggleNewPasswordVisibility() {
    setState(() => _obscureNew = !_obscureNew);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_newPasswordFocusNode.canRequestFocus) {
        _newPasswordFocusNode.requestFocus();
      }
    });
  }

  void _toggleConfirmNewPasswordVisibility() {
    setState(() => _obscureConfirm = !_obscureConfirm);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_confirmFocusNode.canRequestFocus) {
        _confirmFocusNode.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.cardSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Alterar senha',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Informe o e-mail da sua conta e defina uma nova senha forte.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 16),
                if (_dialogError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _LoginColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppTheme.errorColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _dialogError!,
                      style: const TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'E-mail da conta',
                    prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: AuthNotifier.validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPasswordController,
                  focusNode: _newPasswordFocusNode,
                  obscureText: _obscureNew,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      onPressed: _toggleNewPasswordVisibility,
                      icon: Icon(
                        _obscureNew
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                  validator: AuthNotifier.validatePassword,
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _newPasswordController,
                  builder: (context, value, _) {
                    final analysis = AuthNotifier.analyzePassword(value.text);
                    return _PasswordSecurityMeter(
                      analysis: analysis,
                      hasInput: value.text.trim().isNotEmpty,
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmFocusNode,
                  obscureText: _obscureConfirm,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Confirmar nova senha',
                    prefixIcon:
                        const Icon(Icons.verified_user_outlined, size: 18),
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      onPressed: _toggleConfirmNewPasswordVisibility,
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                    ),
                  ),
                  validator: (val) {
                    if ((val ?? '').trim() !=
                        _newPasswordController.text.trim()) {
                      return 'As senhas não coincidem.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.emeraldPrimary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _handleSaveNewPassword,
                      child: const Text('Salvar nova senha'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Medidor visual de força da senha + Checklist OWASP ASVS em tempo real (exibido apenas em Criar conta / Alterar senha)
class _PasswordSecurityMeter extends StatelessWidget {
  const _PasswordSecurityMeter({
    required this.analysis,
    required this.hasInput,
  });

  final PasswordSecurityAnalysis analysis;
  final bool hasInput;

  Color _resolveStrengthColor() {
    if (!hasInput) return AppTheme.cardBorder;
    if (analysis.strengthScore < 0.5) return AppTheme.errorColor;
    if (analysis.strengthScore < 0.8) return AppTheme.warningAmber;
    return AppTheme.emeraldPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _resolveStrengthColor();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.subtleSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 13,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Segurança da senha',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Flexible(
                child: Text(
                  hasInput ? analysis.strengthLabel : 'Requisitos obrigatórios',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasInput ? activeColor : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: hasInput ? analysis.strengthScore : 0.0,
              minHeight: 5,
              backgroundColor: AppTheme.cardBorder,
              valueColor: AlwaysStoppedAnimation<Color>(activeColor),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _RequirementPill(
                label: '8+ caracteres',
                met: analysis.hasMinLength,
              ),
              _RequirementPill(
                label: 'Maiúscula/minúscula (Aa)',
                met: analysis.hasMixedCase,
              ),
              _RequirementPill(
                label: 'Número (0-9)',
                met: analysis.hasDigit,
              ),
              _RequirementPill(
                label: 'Símbolo (!@#\$%)',
                met: analysis.hasSpecialChar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequirementPill extends StatelessWidget {
  const _RequirementPill({
    required this.label,
    required this.met,
  });

  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: met ? AppTheme.emeraldSoftBg : AppTheme.cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: met ? AppTheme.emeraldBadgeBg : AppTheme.cardBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 12,
            color: met ? AppTheme.emeraldDeep : AppTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: met ? AppTheme.emeraldDeep : AppTheme.textSecondary,
              fontSize: 10.5,
              fontWeight: met ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
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
            'Proteção OWASP: Key Stretching 256-bit (2.048 rounds), Salt CSPRNG 128-bit e bloqueio anti-força bruta',
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
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

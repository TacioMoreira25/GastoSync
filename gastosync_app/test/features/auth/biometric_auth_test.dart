import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/features/auth/data/services/auth_service.dart';
import 'package:gastosync_app/features/auth/data/services/biometric_auth_service.dart';
import 'package:gastosync_app/features/auth/domain/auth_provider.dart';

class _FakeBiometricAuthService extends BiometricAuthService {
  _FakeBiometricAuthService({
    this.supported = true,
    this.authResult = true,
    BiometricStoredSession? initialSession,
  }) : storedSession = initialSession;

  bool supported;
  bool authResult;
  BiometricStoredSession? storedSession;
  final Set<String> dismissedEmails = <String>{};
  int authenticateCalls = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls++;
    return authResult;
  }

  @override
  Future<void> saveSession(BiometricStoredSession session) async {
    storedSession = session;
  }

  @override
  Future<BiometricStoredSession?> readSession() async => storedSession;

  @override
  Future<void> clearSession() async {
    storedSession = null;
  }

  @override
  Future<bool> hasDismissedPrompt(String email) async =>
      dismissedEmails.contains(email.trim().toLowerCase());

  @override
  Future<void> markPromptDismissed(String email) async {
    dismissedEmails.add(email.trim().toLowerCase());
  }

  @override
  Future<void> clearPromptDismissed(String email) async {
    dismissedEmails.remove(email.trim().toLowerCase());
  }
}

class _OfflineAuthService extends AuthService {
  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return const AuthResult(
      isOffline: true,
      error: 'Sem conexão com o servidor.',
    );
  }

  @override
  Future<AuthResult> deleteAccount({
    required String token,
    String? password,
  }) async {
    return const AuthResult(
      isOffline: true,
      error: 'Sem conexão com o servidor.',
    );
  }
}

void main() {
  group('BiometricAuthService & AuthNotifier integration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Login com senha oferece ativar biometria e recusa permanente evita novo convite para o mesmo e-mail', () async {
      final fakeBio = _FakeBiometricAuthService(supported: true, authResult: true);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricAuthServiceProvider.overrideWithValue(fakeBio),
          authServiceProvider.overrideWithValue(_OfflineAuthService()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loggedIn = await container.read(authProvider.notifier).login(
            email: AuthNotifier.defaultDemoEmail,
            password: AuthNotifier.defaultDemoPassword,
          );
      expect(loggedIn, isTrue);
      expect(container.read(authProvider).shouldOfferBiometricEnrollment, isTrue);

      await container.read(authProvider.notifier).dismissBiometricEnrollmentPrompt();
      expect(container.read(authProvider).shouldOfferBiometricEnrollment, isFalse);

      await container.read(authProvider.notifier).logout();
      await container.read(authProvider.notifier).login(
            email: AuthNotifier.defaultDemoEmail,
            password: AuthNotifier.defaultDemoPassword,
          );
      expect(container.read(authProvider).shouldOfferBiometricEnrollment, isFalse);
    });

    test('Ativar biometria exige confirmação biométrica e salva sessão no cofre', () async {
      final fakeBio = _FakeBiometricAuthService(supported: true, authResult: true);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricAuthServiceProvider.overrideWithValue(fakeBio),
          authServiceProvider.overrideWithValue(_OfflineAuthService()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final loggedIn = await container.read(authProvider.notifier).login(
            email: AuthNotifier.defaultDemoEmail,
            password: AuthNotifier.defaultDemoPassword,
          );
      expect(loggedIn, isTrue);

      final err = await container.read(authProvider.notifier).enableBiometricAuth();
      expect(err, isNull);
      expect(fakeBio.authenticateCalls, equals(1));
      expect(fakeBio.storedSession, isNotNull);
      expect(fakeBio.storedSession!.email, equals(AuthNotifier.defaultDemoEmail));
      expect(container.read(authProvider).biometricEnabled, isTrue);
      expect(container.read(authProvider).shouldOfferBiometricEnrollment, isFalse);
    });

    test('Cancelar prompt biométrico ao ativar mantém biometria desativada', () async {
      final fakeBio = _FakeBiometricAuthService(supported: true, authResult: false);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricAuthServiceProvider.overrideWithValue(fakeBio),
          authServiceProvider.overrideWithValue(_OfflineAuthService()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await container.read(authProvider.notifier).login(
            email: AuthNotifier.defaultDemoEmail,
            password: AuthNotifier.defaultDemoPassword,
          );

      final err = await container.read(authProvider.notifier).enableBiometricAuth();
      expect(err, isNotNull);
      expect(fakeBio.storedSession, isNull);
      expect(container.read(authProvider).biometricEnabled, isFalse);
    });

    test('Sair da conta mantém biometria ativa sem auto-prompt; excluir conta limpa o cofre', () async {
      final fakeBio = _FakeBiometricAuthService(
        supported: true,
        authResult: true,
        initialSession: const BiometricStoredSession(
          email: AuthNotifier.defaultDemoEmail,
          password: AuthNotifier.defaultDemoPassword,
          fullName: AuthNotifier.defaultDemoName,
          jwtToken: 'fake-jwt-token',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricAuthServiceProvider.overrideWithValue(fakeBio),
          authServiceProvider.overrideWithValue(_OfflineAuthService()),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final ok = await container.read(authProvider.notifier).loginWithBiometrics();
      expect(ok, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Sair da conta mantém a biometria ativa, mas suprime o popup imediato na LoginScreen
      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).biometricEnabled, isTrue);
      expect(container.read(authProvider).suppressBiometricAutoPrompt, isTrue);
      expect(fakeBio.storedSession, isNotNull);

      // Entra novamente pela biometria e exclui a conta -> limpa o cofre completamente
      await container.read(authProvider.notifier).loginWithBiometrics();
      final deleteErr = await container.read(authProvider.notifier).deleteAccount(
            password: AuthNotifier.defaultDemoPassword,
          );
      expect(deleteErr, isNull);
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).biometricEnabled, isFalse);
      expect(fakeBio.storedSession, isNull);
    });
  });
}

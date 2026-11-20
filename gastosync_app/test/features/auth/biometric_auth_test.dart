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

      // Aguarda inicialização assíncrona do notifier
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

    test('Login por biometria entra instantaneamente e logout limpa o cofre (padrão bancário)', () async {
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

      expect(container.read(authProvider).biometricSupported, isTrue);
      expect(container.read(authProvider).biometricEnabled, isTrue);

      final ok = await container.read(authProvider.notifier).loginWithBiometrics();
      expect(ok, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);
      expect(container.read(authProvider).currentEmail, equals(AuthNotifier.defaultDemoEmail));

      // Ao clicar em "Sair da conta", limpa o cofre seguro e desativa biometria
      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(authProvider).biometricEnabled, isFalse);
      expect(container.read(authProvider).biometricSupported, isTrue);
      expect(fakeBio.storedSession, isNull);
    });
  });
}

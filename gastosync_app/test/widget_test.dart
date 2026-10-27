import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/main.dart';

void main() {
  testWidgets(
    'GastoSyncApp v2 smoke test: valida as 4 abas (Início, Transações, Planejamento, Mais) e componentes do Figma',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const GastoSyncApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 0. Tela de Login: valida campos obrigatórios e realiza login seguro
      expect(find.byKey(const Key('login_screen')), findsOneWidget);
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();
      expect(find.text('Informe seu e-mail.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('login_email_input')),
        'marcos.pereira@gastosync.local',
      );
      await tester.enterText(
        find.byKey(const Key('login_password_input')),
        '12345678',
      );
      await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
      await tester.tap(find.byKey(const Key('login_submit_button')));
      await tester.pumpAndSettle();

      // 1. Aba Início (Dashboard v2)
      expect(find.text('Início'), findsOneWidget);
      expect(find.text('Transações'), findsOneWidget);
      expect(find.text('Planejamento'), findsOneWidget);
      expect(find.text('Mais'), findsOneWidget);

      expect(find.text('SALDO DISPONÍVEL'), findsOneWidget);
      expect(find.text('Resumo do Mês'), findsOneWidget);
      expect(find.text('Burn Rate Mensal'), findsOneWidget);
      expect(find.text('Últimas Transações & Insights'), findsOneWidget);

      // 2. Navega para a Aba 2: Transações
      await tester.tap(find.text('Transações'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('transactions_synced_badge')), findsOneWidget);
      expect(find.byKey(const Key('transactions_search_input')), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);

      // 3. Navega para a Aba 3: Planejamento
      await tester.tap(find.text('Planejamento'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('planning_health_score_badge')), findsOneWidget);
      expect(find.text('+ Nova Categoria / Meta'), findsOneWidget);
      expect(find.text('Alimentação'), findsOneWidget);

      // 4. Navega para a Aba 4: Mais
      await tester.tap(find.text('Mais'));
      await tester.pumpAndSettle();

      expect(find.text('Marcos Pereira'), findsOneWidget);
      expect(find.text('Conta local ativa'), findsOneWidget);
      expect(find.text('Status Offline-First (SQLite Local)'), findsOneWidget);
      expect(find.text('Sincronizar agora'), findsOneWidget);
      expect(find.text('Configurações financeiras'), findsOneWidget);

      // 5. Abre a Central de Notificações pelo sino e marca todas como lidas
      expect(find.byKey(const Key('notification_bell_unread_badge')), findsOneWidget);
      await tester.tap(find.byKey(const Key('gastosync_notification_bell_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('gastosync_notifications_modal')), findsOneWidget);
      expect(find.text('Notificações'), findsOneWidget);

      await tester.tap(find.byKey(const Key('notifications_mark_all_read_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('notification_bell_unread_badge')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

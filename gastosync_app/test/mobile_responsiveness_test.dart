import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/main.dart';

void main() {
  const viewports = <String, (Size, double)>{
    'compacto 320x640': (Size(320, 640), 1.0),
    'padrão 360x800 com fonte 1.2x': (Size(360, 800), 1.2),
    'grande 412x915': (Size(412, 915), 1.0),
  };

  for (final entry in viewports.entries) {
    testWidgets(
      'Mobile sem overflow em todas as abas — ${entry.key}',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(() => db.close());

        tester.view.physicalSize = entry.value.$1;
        tester.view.devicePixelRatio = 1.0;
        tester.platformDispatcher.textScaleFactorTestValue = entry.value.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(db)],
            child: const GastoSyncApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('login_email_input')),
          'marcos.pereira@gastosync.local',
        );
        await tester.enterText(
          find.byKey(const Key('login_password_input')),
          'Gasto@2026!',
        );
        await tester.ensureVisible(find.byKey(const Key('login_submit_button')));
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        for (final label in ['Transações', 'Planejamento', 'Mais', 'Início']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'Overflow na aba $label em ${entry.key}',
          );
        }

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  }
}

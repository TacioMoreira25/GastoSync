import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/main.dart';

void main() {
  testWidgets('GastoSyncApp smoke test', (WidgetTester tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(() => db.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const GastoSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visão Geral'), findsOneWidget);
    expect(find.text('1. Saldo Líquido'), findsOneWidget);
    expect(find.text('9. Score Saúde Financeira'), findsOneWidget);
  });
}

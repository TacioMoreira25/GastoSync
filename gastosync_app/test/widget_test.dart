import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/main.dart';

void main() {
  testWidgets('GastoSyncApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GastoSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visão Geral'), findsOneWidget);
  });
}

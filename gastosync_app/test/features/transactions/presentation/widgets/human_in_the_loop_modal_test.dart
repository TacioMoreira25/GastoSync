import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastosync_app/core/database/app_database.dart';
import 'package:gastosync_app/features/budget_agent/domain/models/agent_prediction_models.dart';
import 'package:gastosync_app/features/transactions/presentation/widgets/human_in_the_loop_modal.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'HumanInTheLoopModal permite editar sugestão da IA e grava em LocalTransactions e LocalAgentInsights (US2)',
    (tester) async {
      const prediction = AgentPredictionResponse(
        category: 'Alimentação',
        confidence: 0.92,
        normalizedDescription: 'Lanche da tarde',
        estimatedAmount: 25.0,
        budgetTip: 'Dentro da meta diária de alimentação.',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: HumanInTheLoopModal(prediction: prediction),
            ),
          ),
        ),
      );

      expect(find.text('Revisão Human-in-the-Loop (IA)'), findsOneWidget);
      expect(find.text('Dentro da meta diária de alimentação.'), findsOneWidget);

      // Edita a descrição e valor antes de confirmar
      await tester.enterText(
        find.byKey(const Key('hitl_description_field')),
        'Padaria Artesanal',
      );
      await tester.enterText(
        find.byKey(const Key('hitl_amount_field')),
        '32.50',
      );

      await tester.tap(find.byKey(const Key('hitl_confirm_button')));
      await tester.pump(const Duration(milliseconds: 500));

      final transactions = await database.select(database.localTransactions).get();
      expect(transactions.length, equals(1));
      expect(transactions.first.description, equals('Padaria Artesanal'));
      expect(transactions.first.amount, equals(32.50));
      expect(transactions.first.category, equals('Alimentação'));
      expect(transactions.first.isSynced, isFalse);

      final insights = await database.select(database.localAgentInsights).get();
      expect(insights.length, equals(1));
      final latestInsight = insights.first;
      expect(latestInsight, isNotNull);
      expect(latestInsight.transactionId, equals(transactions.first.id));
      expect(latestInsight.categorySuggested, equals('Alimentação'));
      expect(latestInsight.confidenceScore, closeTo(0.92, 0.001));
      expect(
        latestInsight.budgetTip,
        equals('Dentro da meta diária de alimentação.'),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    },
  );
}

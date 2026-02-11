import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gym_logbook/data/app_database.dart';
import 'package:gym_logbook/main.dart';

void main() {
  testWidgets('renders app shell', (WidgetTester tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(MyApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Gym Logbook'), findsOneWidget);
    expect(find.text('Start Workout'), findsWidgets);
  });
}

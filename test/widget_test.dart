import 'package:flutter_test/flutter_test.dart';
import 'package:duel_multiplayer_quiz/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const DuelApp());
    expect(find.text('DUEL'), findsOneWidget);
  });
}

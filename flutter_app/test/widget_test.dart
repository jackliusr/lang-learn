import 'package:flutter_test/flutter_test.dart';
import 'package:lang_learn_app/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const LangLearnApp());
    expect(find.text('LangLearn'), findsOneWidget);
  });
}

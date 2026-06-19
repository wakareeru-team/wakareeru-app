import 'package:flutter_test/flutter_test.dart';
import 'package:wakareeru_app/main.dart';

void main() {
  testWidgets('shows inference home page', (WidgetTester tester) async {
    await tester.pumpWidget(const WakareeruApp());

    expect(find.text(appDisplayName), findsWidgets);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Start Recognition'), findsOneWidget);
    expect(find.text('Recognize'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}

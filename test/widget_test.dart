import 'package:flutter_test/flutter_test.dart';
import 'package:wakareeru_app/main.dart';

void main() {
  testWidgets('shows inference home page', (WidgetTester tester) async {
    await tester.pumpWidget(const WakareeruApp());

    expect(find.text(appDisplayName), findsWidgets);
    expect(find.text('拍照'), findsOneWidget);
    expect(find.text('相册'), findsOneWidget);
    expect(find.text('开始识别'), findsOneWidget);
    expect(find.text('识别'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}

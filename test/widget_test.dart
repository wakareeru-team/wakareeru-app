import 'package:flutter_test/flutter_test.dart';
import 'package:wakareeru_app/main.dart';

void main() {
  test('parses localized prediction fields and API wikipedia title', () {
    final entry = PredictionEntry.fromJson({
      'label_id': 0,
      'label': {'ja': '101系', 'en': '101 series', 'zh': '101系'},
      'operator': {
        'ja': ['国鉄'],
        'en': ['Japanese National Railways'],
        'zh': ['日本国有铁道'],
      },
      'wiki_title_ja': '国鉄101系電車',
      'probability': 0.8,
    });

    expect(entry, isNotNull);
    expect(entry!.label, '101系');
    expect(entry.labelFor('en'), '101 series');
    expect(entry.operatorFor('zh'), '日本国有铁道');
    expect(
      entry.wikiUrl,
      'https://ja.wikipedia.org/wiki/%E5%9B%BD%E9%89%84101%E7%B3%BB%E9%9B%BB%E8%BB%8A',
    );
  });

  test('does not synthesize wikipedia URL without API metadata', () {
    final entry = PredictionEntry.fromJson({
      'label': {'ja': '101系', 'en': '101 series', 'zh': '101系'},
      'probability': 0.8,
    });

    expect(entry, isNotNull);
    expect(entry!.wikiUrl, isNull);
  });

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

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:translator_app/features/history/translation_history_provider.dart';
import 'package:translator_app/features/settings/theme_provider.dart';
import 'package:translator_app/features/translation/translation_provider.dart';
import 'package:translator_app/main.dart';

void main() {
  testWidgets('App renders translator screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final translationProvider = TranslationProvider();
    final themeProvider = ThemeProvider();
    final historyProvider = TranslationHistoryProvider();

    await translationProvider.init();
    await themeProvider.load();
    await historyProvider.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: translationProvider),
          ChangeNotifierProvider.value(value: themeProvider),
          ChangeNotifierProvider.value(value: historyProvider),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Translator'), findsOneWidget);
    expect(find.text('Translate'), findsOneWidget);
    expect(find.text('Fix & Gramma'), findsOneWidget);
  });
}

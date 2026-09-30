import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:larisai_mobile/main.dart';
import 'package:larisai_mobile/providers/pos_provider.dart';
import 'package:larisai_mobile/providers/ai_provider.dart';
import 'package:larisai_mobile/providers/theme_provider.dart';

void main() {
  testWidgets('LarisAi app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => PosProvider()),
          ChangeNotifierProvider(create: (_) => AiProvider()),
        ],
        child: const LarisAiApp(),
      ),
    );

    expect(find.byType(LarisAiApp), findsOneWidget);
  });
}

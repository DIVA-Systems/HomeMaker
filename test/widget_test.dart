import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:homemaker/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeMaker boots to welcome or home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomeMakerApp()));
    await tester.pumpAndSettle();
    // Loading indicator or HomeMaker brand text
    expect(find.textContaining('HomeMaker'), findsWidgets);
  });
}

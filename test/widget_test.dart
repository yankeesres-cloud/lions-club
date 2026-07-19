import 'package:flutter_test/flutter_test.dart';
import 'package:lions_club_pro/main.dart';

void main() {
  testWidgets('Shows role login', (tester) async {
    await tester.pumpWidget(const LionsClubProApp(loggedIn: false));
    expect(find.text('Lions Club Pro'), findsOneWidget);
  });
}

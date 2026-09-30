import 'package:flutter_test/flutter_test.dart';
import 'package:ap_vision_care_staff/main.dart';

void main() {
  testWidgets('StaffMobileApp splash and login smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StaffMobileApp());
    // Initial frame shows Splash branding
    expect(find.text('Govt. of Andhra Pradesh'), findsOneWidget);

    // Wait for splash transition to settle
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:donish_app/main.dart';

void main() {
  testWidgets('Donish app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const DonishApp());
    await tester.pump();
    expect(find.text('Donish'), findsWidgets);
  });
}

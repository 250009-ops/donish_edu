import 'package:flutter_test/flutter_test.dart';



import 'package:donish_app/main.dart';



void main() {

  testWidgets('Gotcha app shows splash then loads', (WidgetTester tester) async {

    await tester.pumpWidget(const DonishApp());



    // Title appears partway through the splash timeline.

    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Master Uzbek Through Reading'), findsOneWidget);



    // Let splash finish and transition to login or home.

    await tester.pump(const Duration(milliseconds: 2000));

    await tester.pump(const Duration(milliseconds: 500));

    await tester.pump();

  });

}



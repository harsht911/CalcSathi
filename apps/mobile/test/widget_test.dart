import 'package:flutter_test/flutter_test.dart';

import 'package:calcsathi_mobile/main.dart';

void main() {
  testWidgets('CalcSathiApp builds without error and shows the app bar title', (tester) async {
    await tester.pumpWidget(const CalcSathiApp());

    expect(find.text('CalcSathi'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:calcsathi_admin/main.dart';

void main() {
  testWidgets('CalcSathiAdminApp builds without error and shows the app bar title', (tester) async {
    await tester.pumpWidget(const CalcSathiAdminApp());

    expect(find.text('CalcSathi Admin'), findsOneWidget);
  });
}

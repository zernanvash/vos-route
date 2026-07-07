import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/main.dart';

void main() {
  testWidgets('App builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const VOSRouteApp());
    expect(find.byType(VOSRouteApp), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_key_manager/app.dart';

void main() {
  testWidgets('App starts and shows title', (WidgetTester tester) async {
    await tester.pumpWidget(const SSHKeyManagerApp());
    await tester.pumpAndSettle();

    expect(find.text('SSH密钥管理器'), findsOneWidget);
  });
}

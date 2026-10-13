import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giveflow/donation.dart';
import 'package:giveflow/main.dart';

Future<void> render(
  WidgetTester tester,
  DonationController controller, {
  Size size = const Size(1240, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('capture'),
      child: GiveFlowApp(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  testWidgets('desktop amount screen renders cleanly', (tester) async {
    await render(
      tester,
      DonationController(DemoGateway(), delay: Duration.zero),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/home_desktop.png'),
    );
  });
  testWidgets('mobile amount screen has no layout exception', (tester) async {
    await render(
      tester,
      DonationController(DemoGateway(), delay: Duration.zero),
      size: const Size(390, 1100),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/home_mobile.png'),
    );
  });
  testWidgets('invalid amount blocks review', (tester) async {
    await render(
      tester,
      DonationController(DemoGateway(), delay: Duration.zero),
    );
    await tester.enterText(find.byKey(const Key('amount_input')), '0.50');
    await tester.tap(find.byKey(const Key('review_button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error')), findsOneWidget);
    expect(find.text('Review your donation'), findsNothing);
  });
  testWidgets('valid donation reaches confirmation and success', (
    tester,
  ) async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    await render(
      tester,
      c,
    );
    await tester.tap(find.byKey(const Key('review_button')));
    await tester.pumpAndSettle();
    expect(find.text('Review your donation'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/review_desktop.png'),
    );
    c.active = const DonationRequest('request_demo_receipt', 'kitchen', 1000);
    await tester.tap(find.byKey(const Key('confirm_button')));
    await tester.pumpAndSettle();
    expect(find.text('Donation recorded'), findsOneWidget);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/success_desktop.png'),
    );
  });
  testWidgets('timeout screen exposes reconciliation rather than resubmit', (
    tester,
  ) async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('10');
    c.scenario = 'timeout';
    c.active = const DonationRequest('request_demo_timeout', 'kitchen', 1000);
    await c.submit();
    await render(tester, c);
    expect(find.text('Check donation status'), findsOneWidget);
    expect(find.byKey(const Key('confirm_button')), findsNothing);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/timeout_desktop.png'),
    );
    await tester.tap(find.text('Check donation status'));
    await tester.pumpAndSettle();
    expect(find.text('Donation recorded'), findsOneWidget);
  });
  testWidgets('mobile review remains usable with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('20');
    await render(tester, c, size: const Size(390, 1100));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const Key('capture')),
      matchesGoldenFile('goldens/review_mobile.png'),
    );
  });
  testWidgets('compact mobile screen scrolls to the donation action', (tester) async {
    await render(tester, DonationController(DemoGateway(), delay: Duration.zero), size: const Size(320, 568));
    await tester.ensureVisible(find.byKey(const Key('review_button')));
    await tester.tap(find.byKey(const Key('review_button')));
    await tester.pumpAndSettle();
    expect(find.text('Review your donation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sample code import updates amount and cause', (tester) async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    await render(tester, c);
    await tester.tap(find.text('Import demo donation code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();
    expect(c.amountCents, 1000);
    expect(c.campaignId, 'kitchen');
    expect(find.text('10.00'), findsOneWidget);
  });
  testWidgets('completed donation appears in activity', (tester) async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('10');
    c.active = const DonationRequest('request_history_demo', 'kitchen', 1000);
    await c.submit();
    await render(tester, c);
    await tester.tap(find.text('View demo activity'));
    await tester.pumpAndSettle();
    expect(find.text('Demo activity'), findsOneWidget);
    expect(find.textContaining('request_history_demo'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

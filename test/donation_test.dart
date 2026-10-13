import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:giveflow/donation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Money validation', () {
    for (final pair in {
      '1': 100,
      '1.01': 101,
      '10.5': 1050,
      '500': 50000,
      ' 10.00 ': 1000,
    }.entries) {
      test(
        'parses ${pair.key} into integer cents',
        () => expect(parseAmount(pair.key), pair.value),
      );
    }
    for (final input in [
      '0',
      '0.99',
      '500.01',
      '-1',
      '1.234',
      'NaN',
      '1e2',
      '1,00',
      '',
    ]) {
      test(
        'rejects $input',
        () => expect(() => parseAmount(input), throwsFormatException),
      );
    }
  });
  test('sample donation payload validates campaign and amount', () {
    final r = parseDemoCode('giveflow://donate?campaign=kitchen&amount=10.01');
    expect(r.campaignId, 'kitchen');
    expect(r.amountCents, 1001);
  });
  test('rejects foreign, duplicate and unexpected payload fields', () {
    for (final code in [
      'https://evil.test/?campaign=kitchen&amount=10',
      'giveflow://donate?campaign=other&amount=10',
      'giveflow://donate?campaign=kitchen&amount=10&amount=20',
      'giveflow://donate?campaign=kitchen&amount=10&currency=USD',
    ]) {
      expect(() => parseDemoCode(code), throwsFormatException);
    }
  });
  test('duplicate request returns original receipt', () async {
    final gateway = DemoGateway();
    const r = DonationRequest('request_1234', 'kitchen', 1000);
    final one = await gateway.submit(r, 'success');
    final two = await gateway.submit(r, 'success');
    expect(one.id, two.id);
    expect((await gateway.history()).length, 1);
  });
  test('same key with different amount is rejected', () async {
    final g = DemoGateway();
    await g.submit(
      const DonationRequest('request_1234', 'kitchen', 1000),
      'success',
    );
    expect(
      () => g.submit(
        const DonationRequest('request_1234', 'kitchen', 2000),
        'success',
      ),
      throwsStateError,
    );
  });
  test('timeout reconciles original donation without duplicate', () async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('10');
    c.scenario = 'timeout';
    await c.submit();
    expect(c.stage, Stage.uncertain);
    final key = c.active!.key;
    c.edit();
    expect(c.stage, Stage.uncertain);
    await c.submit();
    expect(c.active!.key, key);
    await c.reconcile();
    expect(c.stage, Stage.succeeded);
    expect(c.receipts.length, 1);
  });
  test('double confirmation creates one request', () async {
    final c = DonationController(
      DemoGateway(),
      delay: const Duration(milliseconds: 1),
    );
    c.review('10');
    await Future.wait([c.submit(), c.submit()]);
    expect(c.receipts.length, 1);
  });
  test('offline does not record and retry retains request key', () async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('10');
    c.scenario = 'offline';
    await c.submit();
    final key = c.active!.key;
    expect(c.stage, Stage.offline);
    expect(c.receipts, isEmpty);
    c.scenario = 'success';
    await c.submit();
    expect(c.stage, Stage.succeeded);
    expect(c.active!.key, key);
  });
  test('decline is recorded distinctly from success', () async {
    final c = DonationController(DemoGateway(), delay: Duration.zero);
    c.review('10');
    c.scenario = 'declined';
    await c.submit();
    expect(c.stage, Stage.declined);
    expect(c.receipts.single.status, 'declined');
  });
  test('restart restores unresolved request and stored receipt', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final one = DonationController(
      DemoGateway(prefs: prefs),
      prefs: prefs,
      delay: Duration.zero,
    );
    one.review('10');
    one.scenario = 'timeout';
    await one.submit();
    final two = DonationController(
      DemoGateway(prefs: prefs),
      prefs: prefs,
      delay: Duration.zero,
    );
    await two.initialise();
    expect(two.stage, Stage.uncertain);
    await two.reconcile();
    expect(two.stage, Stage.succeeded);
    expect(two.receipts.length, 1);
  });
  test('HTTP adapter sends cents and idempotency header', () async {
    final api = ApiGateway(
      'http://localhost',
      client: MockClient((request) async {
        expect(request.headers['Idempotency-Key'], 'request_1234');
        expect(jsonDecode(request.body)['amount_cents'], 1000);
        return http.Response(
          jsonEncode({
            'id': 'r1',
            'key': 'request_1234',
            'campaign_id': 'kitchen',
            'status': 'succeeded',
            'amount_cents': 1000,
            'created_at': 1,
          }),
          200,
        );
      }),
    );
    expect(
      (await api.submit(
        const DonationRequest('request_1234', 'kitchen', 1000),
        'success',
      )).status,
      'succeeded',
    );
  });
  test('HTTP 504 is an uncertain outcome', () async {
    final api = ApiGateway(
      'http://localhost',
      client: MockClient((_) async => http.Response('{}', 504)),
    );
    expect(
      () => api.submit(
        const DonationRequest('request_1234', 'kitchen', 1000),
        'timeout',
      ),
      throwsA(isA<PaymentUncertain>()),
    );
  });
}

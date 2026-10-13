import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const campaigns = {
  'kitchen': 'Community Kitchen',
  'learning': 'Learning Kits',
  'coast': 'Coastal Care',
};

int parseAmount(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
      'Enter an amount with up to two decimal places.',
    );
  }
  final pieces = value.split('.');
  final cents =
      int.parse(pieces[0]) * 100 +
      (pieces.length == 2 ? int.parse(pieces[1].padRight(2, '0')) : 0);
  if (cents < 100 || cents > 50000) {
    throw const FormatException('Choose an amount from €1 to €500.');
  }
  return cents;
}

String money(int cents) => '€${(cents / 100).toStringAsFixed(2)}';

class DonationRequest {
  final String key, campaignId;
  final int amountCents;
  const DonationRequest(this.key, this.campaignId, this.amountCents);
  Map<String, dynamic> toJson() => {
    'key': key,
    'campaign_id': campaignId,
    'amount_cents': amountCents,
  };
  factory DonationRequest.fromJson(Map<String, dynamic> json) =>
      DonationRequest(
        json['key'] as String,
        json['campaign_id'] as String,
        json['amount_cents'] as int,
      );
}

DonationRequest parseDemoCode(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null ||
      uri.scheme != 'giveflow' ||
      uri.host != 'donate' ||
      uri.path.isNotEmpty ||
      uri.fragment.isNotEmpty) {
    throw const FormatException('Use a GiveFlow demo code.');
  }
  final params = uri.queryParametersAll;
  if (params.length != 2 ||
      params['campaign']?.length != 1 ||
      params['amount']?.length != 1 ||
      !campaigns.containsKey(params['campaign']!.first)) {
    throw const FormatException(
      'The demo code has an invalid campaign or amount.',
    );
  }
  return DonationRequest(
    '',
    params['campaign']!.first,
    parseAmount(params['amount']!.first),
  );
}

class Receipt {
  final String id, key, campaignId, status;
  final int amountCents, createdAt;
  const Receipt({
    required this.id,
    required this.key,
    required this.campaignId,
    required this.status,
    required this.amountCents,
    required this.createdAt,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'campaign_id': campaignId,
    'status': status,
    'amount_cents': amountCents,
    'created_at': createdAt,
  };
  factory Receipt.fromJson(Map<String, dynamic> j) => Receipt(
    id: j['id'],
    key: j['key'],
    campaignId: j['campaign_id'],
    status: j['status'],
    amountCents: j['amount_cents'],
    createdAt: j['created_at'],
  );
}

class PaymentUncertain implements Exception {}

class PaymentOffline implements Exception {}

abstract class Gateway {
  Future<Receipt> submit(DonationRequest request, String scenario);
  Future<Receipt?> lookup(String key);
  Future<List<Receipt>> history();
}

class DemoGateway implements Gateway {
  final SharedPreferences? prefs;
  final Map<String, Receipt> _receipts = {};
  DemoGateway({this.prefs}) {
    final raw = prefs?.getString('giveflow_receipts_v1');
    if (raw != null) {
      try {
        for (final j in jsonDecode(raw) as List) {
          final receipt = Receipt.fromJson(Map<String, dynamic>.from(j));
          _receipts[receipt.key] = receipt;
        }
      } catch (_) {
        /* A malformed demo cache is discarded. No payment is made. */
      }
    }
  }
  @override
  Future<Receipt> submit(DonationRequest r, String scenario) async {
    if (!campaigns.containsKey(r.campaignId) ||
        r.amountCents < 100 ||
        r.amountCents > 50000) {
      throw const FormatException('Invalid donation.');
    }
    if (_receipts.containsKey(r.key)) {
      final old = _receipts[r.key]!;
      if (old.campaignId != r.campaignId || old.amountCents != r.amountCents) {
        throw StateError('This key belongs to a different donation.');
      }
      return old;
    }
    if (scenario == 'offline') throw PaymentOffline();
    final receipt = Receipt(
      id: 'DEMO-${r.key}',
      key: r.key,
      campaignId: r.campaignId,
      status: scenario == 'declined' ? 'declined' : 'succeeded',
      amountCents: r.amountCents,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    _receipts[r.key] = receipt;
    if (prefs != null) {
      await prefs!.setString(
        'giveflow_receipts_v1',
        jsonEncode(_receipts.values.map((x) => x.toJson()).toList()),
      );
    }
    if (scenario == 'timeout') throw PaymentUncertain();
    return receipt;
  }

  @override
  Future<Receipt?> lookup(String key) async => _receipts[key];
  @override
  Future<List<Receipt>> history() async =>
      _receipts.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

class ApiGateway implements Gateway {
  final String baseUrl;
  final http.Client client;
  ApiGateway(this.baseUrl, {http.Client? client})
    : client = client ?? http.Client();
  @override
  Future<Receipt> submit(DonationRequest r, String scenario) async {
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/donations'),
            headers: {
              'Content-Type': 'application/json',
              'Idempotency-Key': r.key,
            },
            body: jsonEncode({
              'campaign_id': r.campaignId,
              'amount_cents': r.amountCents,
              'currency': 'EUR',
              'scenario': scenario,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 503) throw PaymentOffline();
      if (response.statusCode == 504) throw PaymentUncertain();
      if (response.statusCode != 200) {
        throw StateError(
          'The API rejected this request (${response.statusCode}).',
        );
      }
      return Receipt.fromJson(jsonDecode(response.body));
    } on PaymentOffline {
      rethrow;
    } on StateError {
      rethrow;
    } catch (_) {
      throw PaymentUncertain();
    }
  }

  @override
  Future<Receipt?> lookup(String key) async {
    final response = await client
        .get(Uri.parse('$baseUrl/donations/by-key/$key'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('Could not check the donation.');
    }
    return Receipt.fromJson(jsonDecode(response.body));
  }

  @override
  Future<List<Receipt>> history() async {
    final response = await client
        .get(Uri.parse('$baseUrl/donations'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw StateError('History is unavailable.');
    return (jsonDecode(response.body) as List)
        .map((j) => Receipt.fromJson(j))
        .toList();
  }
}

enum Stage {
  amount,
  review,
  processing,
  succeeded,
  declined,
  uncertain,
  offline,
}

class DonationController extends ChangeNotifier {
  final Gateway gateway;
  final SharedPreferences? prefs;
  final Duration delay;
  Stage stage = Stage.amount;
  String campaignId = 'kitchen', scenario = 'success';
  String? error;
  int amountCents = 1000;
  DonationRequest? active;
  Receipt? receipt;
  List<Receipt> receipts = [];
  bool checking = false;
  DonationController(
    this.gateway, {
    this.prefs,
    this.delay = const Duration(milliseconds: 900),
  });
  Future<void> initialise() async {
    try {
      receipts = await gateway.history();
      final pending = prefs?.getString('giveflow_pending_v1');
      if (pending != null) {
        active = DonationRequest.fromJson(jsonDecode(pending));
        campaignId = active!.campaignId;
        amountCents = active!.amountCents;
        stage = Stage.uncertain;
      }
    } catch (_) {
      error = 'Could not load the saved demo. You can still choose a donation.';
    }
    notifyListeners();
  }

  void review(String amount) {
    try {
      amountCents = parseAmount(amount);
      error = null;
      stage = Stage.review;
    } on FormatException catch (e) {
      error = e.message;
    }
    notifyListeners();
  }

  void importCode(String code) {
    final parsed = parseDemoCode(code);
    campaignId = parsed.campaignId;
    amountCents = parsed.amountCents;
    error = null;
    notifyListeners();
  }

  void edit() {
    if (stage == Stage.processing || stage == Stage.uncertain) return;
    stage = Stage.amount;
    error = null;
    active = null;
    notifyListeners();
  }

  Future<void> submit() async {
    if (stage != Stage.review && stage != Stage.offline) return;
    active ??= DonationRequest(
      'request_${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
      campaignId,
      amountCents,
    );
    stage = Stage.processing;
    error = null;
    notifyListeners();
    try {
      if (prefs != null) {
        await prefs!.setString(
          'giveflow_pending_v1',
          jsonEncode(active!.toJson()),
        );
      }
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      receipt = await gateway.submit(active!, scenario);
      stage = receipt!.status == 'succeeded' ? Stage.succeeded : Stage.declined;
      await prefs?.remove('giveflow_pending_v1');
      receipts = await gateway.history();
    } on PaymentOffline {
      stage = Stage.offline;
      await prefs?.remove('giveflow_pending_v1');
    } on PaymentUncertain {
      stage = Stage.uncertain;
    } catch (_) {
      stage = Stage.uncertain;
      error = 'The outcome is unknown. Check its status before trying again.';
    }
    notifyListeners();
  }

  Future<void> reconcile() async {
    if (active == null || checking) return;
    checking = true;
    error = null;
    notifyListeners();
    try {
      receipt = await gateway.lookup(active!.key);
      if (receipt != null) {
        stage = receipt!.status == 'succeeded'
            ? Stage.succeeded
            : Stage.declined;
        await prefs?.remove('giveflow_pending_v1');
        receipts = await gateway.history();
      } else {
        error =
            'No record found yet. Keep this request and check again; do not create another donation.';
      }
    } catch (_) {
      error = 'Status is unavailable. Check again when connected.';
    }
    checking = false;
    notifyListeners();
  }

  Future<void> refreshHistory() async {
    try {
      receipts = await gateway.history();
    } catch (_) {
      error = 'History is unavailable.';
    }
    notifyListeners();
  }
}

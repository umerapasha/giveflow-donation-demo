import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'donation.dart';

const teal = Color(0xFF146A60),
    ink = Color(0xFF172C32),
    cream = Color(0xFFF7F6F0);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  const api = String.fromEnvironment('API_BASE_URL');
  final controller = DonationController(
    api.isEmpty ? DemoGateway(prefs: prefs) : ApiGateway(api),
    prefs: prefs,
  );
  await controller.initialise();
  runApp(GiveFlowApp(controller: controller));
}

class GiveFlowApp extends StatelessWidget {
  final DonationController controller;
  const GiveFlowApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'GiveFlow Donation Demo',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        primary: teal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: cream,
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: ink, fontSize: 15, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: Colors.white,
      ),
    ),
    home: DemoPage(controller: controller),
  );
}

class DemoPage extends StatefulWidget {
  final DonationController controller;
  const DemoPage({super.key, required this.controller});
  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  final amount = TextEditingController(text: '10');
  DonationController get c => widget.controller;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  Future<void> importCode() async {
    final input = TextEditingController(
      text: 'giveflow://donate?campaign=kitchen&amount=10.00',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import a demo code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste a sample donation payload. This validates a code; it does not use a camera or NFC reader.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: input,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Demo code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, input.text),
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        c.importCode(result);
        amount.text = (c.amountCents / 100).toStringAsFixed(2);
      } on FormatException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }
    Future<void>.delayed(const Duration(milliseconds: 300), input.dispose);
  }

  Future<void> history() async {
    await c.refreshHistory();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: SizedBox(
            height: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo activity',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Simulated transactions only. Saved locally in browser mode.',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: c.receipts.isEmpty
                      ? const Center(
                          child: Text(
                            'No activity yet. Try the donation flow.',
                          ),
                        )
                      : ListView.separated(
                          itemCount: c.receipts.length,
                          separatorBuilder: (_, i) => const Divider(),
                          itemBuilder: (_, i) {
                            final r = c.receipts[i];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                r.status == 'succeeded'
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                color: r.status == 'succeeded'
                                    ? teal
                                    : Colors.red,
                              ),
                              title: Text(
                                campaigns[r.campaignId] ?? r.campaignId,
                              ),
                              subtitle: Text('${r.status} · demo\n${r.key}'),
                              isThreeLine: true,
                              trailing: Text(
                                money(r.amountCents),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: teal,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite_outline,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'GiveFlow',
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: history,
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Activity'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth > 820;
                        final intro = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'INDEPENDENT PORTFOLIO DEMO',
                              style: TextStyle(
                                color: teal,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'A small gift.\nA clear journey.',
                              style: TextStyle(
                                fontSize: wide ? 54 : 34,
                                fontWeight: FontWeight.w800,
                                height: 1.07,
                                color: ink,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Choose a cause, confirm an amount, and follow the outcome. Every transaction here is simulated.',
                              style: TextStyle(
                                fontSize: 17,
                                color: ink,
                                height: 1.55,
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (wide) ...[
                              feature(
                                Icons.touch_app_outlined,
                                'A simple donation flow',
                                'Clear amounts, review before confirmation and readable outcomes.',
                              ),
                              feature(
                                Icons.sync_outlined,
                                'Handles uncertain outcomes',
                                'A lost response triggers a status check using the original request.',
                              ),
                              feature(
                                Icons.code_outlined,
                                'Flutter and Dart',
                                'A tested prototype with an optional local Python API.',
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Umera Wajeed Pasha\nSoftware development portfolio',
                                style: TextStyle(color: ink, height: 1.6),
                              ),
                            ],
                          ],
                        );
                        final app = Container(
                          key: const Key('app_panel'),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(color: const Color(0xFFE1E7DF)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x0C172C32),
                                blurRadius: 40,
                                offset: Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.science_outlined,
                                    size: 18,
                                    color: teal,
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'DEMO ONLY · No money collected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        color: teal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              content(),
                            ],
                          ),
                        );
                        return wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        top: 30,
                                        right: 60,
                                      ),
                                      child: intro,
                                    ),
                                  ),
                                  SizedBox(width: 430, child: app),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  intro,
                                  const SizedBox(height: 24),
                                  app,
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Fictional campaigns. No affiliation with Tap 2 Donate. AI-assisted project created for application preparation.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF60716F)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget feature(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: teal),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(color: Color(0xFF60716F))),
            ],
          ),
        ),
      ],
    ),
  );
  Widget content() {
    switch (c.stage) {
      case Stage.amount:
        return amountStep();
      case Stage.review:
        return reviewStep();
      case Stage.processing:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 70),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 24),
              Text('Processing the simulation…'),
              SizedBox(height: 10),
              Text(
                'Please wait. Your request is submitted once.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case Stage.uncertain:
        return outcome(
          Icons.sync,
          'Outcome not confirmed',
          'The simulated response was lost. The donation may already be recorded. Check the original request before another attempt.',
          c.checking ? 'Checking…' : 'Check donation status',
          c.checking ? null : c.reconcile,
        );
      case Stage.offline:
        return outcome(
          Icons.wifi_off_outlined,
          'You are offline',
          'No donation was recorded. Change the test scenario to Success, then retry the same request.',
          'Retry simulation',
          c.submit,
          controls: true,
        );
      case Stage.declined:
        return outcome(
          Icons.cancel_outlined,
          'Donation declined',
          'This attempt was declined. Nothing was collected. You can start a new attempt.',
          'Choose a new donation',
          c.edit,
        );
      case Stage.succeeded:
        return outcome(
          Icons.check_circle_outline,
          'Donation recorded',
          '${money(c.amountCents)} for ${campaigns[c.campaignId]}. This is a simulated receipt; no real payment was made.',
          'Make another demo donation',
          c.edit,
        );
    }
  }

  Widget amountStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Choose your cause',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      const Text('Three fictional campaigns to explore the flow.'),
      const SizedBox(height: 20),
      ...campaigns.entries.map(
        (entry) => Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: OutlinedButton(
            key: Key(entry.key),
            onPressed: () => setState(() => c.campaignId = entry.key),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              backgroundColor: c.campaignId == entry.key
                  ? const Color(0xFFEAF4EE)
                  : Colors.white,
              side: BorderSide(
                color: c.campaignId == entry.key
                    ? teal
                    : const Color(0xFFDEE5E0),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  entry.key == 'kitchen'
                      ? Icons.restaurant
                      : entry.key == 'learning'
                      ? Icons.menu_book
                      : Icons.waves,
                  color: teal,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (c.campaignId == entry.key)
                  const Icon(Icons.check_circle, color: teal, size: 20),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      const Text(
        'Donation amount',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [5, 10, 20, 50]
            .map(
              (n) => ChoiceChip(
                label: Text('€$n'),
                selected: amount.text == n.toString(),
                onSelected: (_) => setState(() => amount.text = n.toString()),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('amount_input'),
        controller: amount,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          labelText: 'Custom amount',
          prefixText: '€ ',
          helperText: '€1–€500 · up to two decimal places',
        ),
      ),
      if (c.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            c.error!,
            key: const Key('error'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      const SizedBox(height: 18),
      FilledButton(
        key: const Key('review_button'),
        onPressed: () => c.review(amount.text),
        child: const Text('Review donation'),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: importCode,
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Import demo donation code'),
      ),
    ],
  );
  Widget reviewStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Review your donation',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 26),
      Text(
        money(c.amountCents),
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w800,
          color: teal,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        campaigns[c.campaignId]!,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 24),
      const Text(
        'Currency: EUR\nPayment: simulation only\nYou will not be asked for card details.',
        style: TextStyle(height: 1.7),
      ),
      const SizedBox(height: 24),
      scenarioControl(),
      const SizedBox(height: 20),
      FilledButton(
        key: const Key('confirm_button'),
        onPressed: c.submit,
        child: const Text('Confirm simulated donation'),
      ),
      TextButton(onPressed: c.edit, child: const Text('Edit amount or cause')),
    ],
  );
  Widget scenarioControl() => DropdownButtonFormField<String>(
    initialValue: c.scenario,
    decoration: const InputDecoration(labelText: 'Test a payment outcome'),
    items: const [
      DropdownMenuItem(value: 'success', child: Text('Success')),
      DropdownMenuItem(value: 'declined', child: Text('Declined')),
      DropdownMenuItem(value: 'timeout', child: Text('Response timeout')),
      DropdownMenuItem(value: 'offline', child: Text('Offline')),
    ],
    onChanged: (v) => setState(() => c.scenario = v!),
  );
  Widget outcome(
    IconData icon,
    String title,
    String text,
    String action,
    VoidCallback? onTap, {
    bool controls = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 14),
      Icon(icon, color: teal, size: 58),
      const SizedBox(height: 20),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Text(text, textAlign: TextAlign.center),
      const SizedBox(height: 24),
      if (c.active != null) ...[
        SelectableText(
          'Request: ${c.active!.key}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF60716F)),
        ),
        const SizedBox(height: 20),
      ],
      if (c.error != null) ...[
        Text(c.error!, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 16),
      ],
      if (controls) ...[scenarioControl(), const SizedBox(height: 20)],
      FilledButton(onPressed: onTap, child: Text(action)),
      const SizedBox(height: 8),
      TextButton(onPressed: history, child: const Text('View demo activity')),
    ],
  );
}

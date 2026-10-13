# Three minute walkthrough

Practise this script after reviewing the code. Be transparent about AI assistance.

**0:00–0:25** — “I prepared GiveFlow with AI assistance to explore a donation-app workflow. My existing work involves React, Next.js and Python APIs. This project introduces Flutter/Dart using fictional campaigns and simulated transactions.”

**0:25–0:55** — Choose Learning Kits and enter 12.50. Review the EUR amount. Explain that validation is outside widget code and amounts use 1250 integer cents. Show that 0.50 and 1.234 are rejected.

**0:55–1:20** — Confirm Success, then show the receipt in Activity. Browser mode persists records locally; optional API mode uses SQLite.

**1:20–2:00** — Start another donation with Response timeout. Select “Check donation status” and show one receipt for that request. Explain that a payment may succeed even when its response is lost, so a new request must not be created blindly.

**2:00–2:25** — Show test output. Open `parseAmount`, `DonationController.submit` and the API's `BEGIN IMMEDIATE` block. Explain the difference between disabling a busy button and enforcing idempotency on the server.

**2:25–3:00** — “I would confirm the scanning method and payment provider before extending this. The demo validates pasted sample payloads. Camera/NFC integration, real payments and mobile-store releases are not implemented.”

## Code to understand

1. Trace `review → submit → uncertain → reconcile → succeeded` in `lib/donation.dart`.
2. Locate the unique key, conflicting-payload check and transaction boundary in `backend/app.py`.
3. Change an amount-validation boundary and explain the resulting test failure.
4. Distinguish behaviour assertions from appearance comparisons in `test/ui_test.dart`.
5. Explain why the live HTTP tests use a real API and skip in the ordinary suite.

Present this as a first AI-assisted prototype, with clear statements about what you verified and what you still need to learn.

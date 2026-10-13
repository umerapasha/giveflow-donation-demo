# Validation record

Prepared 13 October 2026 UTC. Flutter 3.35.7; Python 3.12.

| Check | Observed result |
| --- | --- |
| Flutter analyzer | No issues found after code cleanup. |
| Flutter unit and widget suite | 34 passed. The two live HTTP tests skip by design in this suite. |
| Real Flutter HTTP adapter to FastAPI | 2 passed using a temporary loopback server and disposable SQLite database. |
| Python API suite | 20 passed, including 8 concurrent identical requests creating one receipt. |
| Release Flutter web build | Succeeded with local web renderer assets. |
| UI renders | Six actual Flutter golden renders generated for desktop/mobile home, review, success and uncertain outcome. |

Tests cover cents parsing, range/precision rejection, payload validation, duplicate submit protection, replay, conflicting keys, offline handling, decline, restart recovery, HTTP serialization, real API timeout reconciliation, mobile scrolling, larger text and activity history.

The UI images are widget renders, not browser screenshots. No deployed-browser session, Android APK, iOS build, camera/NFC reader, real payment SDK or production security assessment was verified. Golden baseline comparisons are preparation checks and are not evidence of historical regression coverage. The GitHub Actions workflow is prepared, not executed on GitHub.

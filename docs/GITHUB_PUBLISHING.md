# Publish the prepared source

No GitHub account connection was used. Review the source before publishing.

Create an empty repository in `umerapasha` named `giveflow-donation-demo`. Choose Public for recruiter access. The ZIP omits hosted Site identity and Git metadata. In a clean extracted directory:

```bash
git init
git add .
git commit -m "Add AI-assisted GiveFlow donation workflow prototype"
git branch -M main
git remote add origin https://github.com/umerapasha/giveflow-donation-demo.git
git push -u origin main
```

These require your authenticated GitHub setup. That URL is an intended repository name, not a verified existing repository. Keep databases, virtual environments and credentials excluded.

Repository description: “AI-assisted Flutter/Dart donation workflow demo with a local FastAPI/SQLite API, idempotent requests and timeout reconciliation. Simulated payments only.”

Topics: `flutter`, `dart`, `fastapi`, `sqlite`, `portfolio`, `donation-demo`, `idempotency`.

Pin the repository. Retain screenshots and AI-assistance disclosure. Add a live URL only after checking its audience; the prepared hosted demo initially has owner-only access. The supplied GitHub Actions workflow is prepared and has not run on GitHub.

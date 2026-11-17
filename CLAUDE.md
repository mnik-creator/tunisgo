# TunisGO — notes for Claude

Read before working on this repo:

1. **Project brain (Obsidian vault): `brain/`**
   - Start at `brain/00 TunisGO.md` (map of content). `brain/Brain map.canvas` is the visual overview.
   - `brain/Decisions.md` and `brain/Gotchas.md` hold what was decided and the traps already hit — check them before release, data or notification work.
   - Keep the vault current: after a meaningful change (release, architecture, data, infra, a new trap), add a dated line to `Decisions.md` / `Gotchas.md` and update the relevant note. Never write secret values into it (see `brain/Secrets and keys.md`).

2. **Code knowledge graph (graphify): `graphify-out/`** (gitignored, regenerate when stale)
   - Structural questions ("what calls X", "how does live data reach the card"): `graphify query "<question>"` before broad grepping.
   - Refresh after larger code changes: `/graphify . --update`. Scope is set by `.graphifyignore`.
   - Human view: `graphify-out/graph.html`; summary: `graphify-out/GRAPH_REPORT.md`.

3. **Conventions**
   - Commit or push only when asked. Releases go through `android/fastlane` (see `brain/Release/Google Play and fastlane.md`).
   - l10n template is `lib/l10n/app_fr.arb`.
   - `AGENTS.md` is generic InsForge SDK documentation from the original template; live delays and timetable updates now run on Cloudflare (`cloudflare/live-worker`).

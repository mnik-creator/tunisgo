# tunisgo-live — Cloudflare Worker

Polls the public SNCFT live tracker and publishes one `live.json` that the
app reads, and serves timetable database updates. SNCFT sees a single client;
user IPs never reach it. Free plan is enough (no R2 needed).

```
cron (1/min; 15 min on quiet nights) ──► sncft_get_trains (1 req) + sncft_get_details (≤44 req)
                                     └─► Durable Object ◄── GET /live.json (edge cache 30 s) ◄── app
static assets: GET /db/manifest.json, /db/sncft-v<N>.db, /db/transtu-v<N>.db ◄── app (DatabaseUpdater)
```

## Deploy

```bash
cd cloudflare/live-worker
npm install
npx wrangler login
npm run deploy        # builds public/db/ from db.json, then wrangler deploy
```

The deploy prints `https://tunisgo-live.tunisgo.workers.dev`. Build the app with:

```bash
flutter build appbundle --dart-define=WORKER_URL=https://tunisgo-live.tunisgo.workers.dev
```

Without `WORKER_URL` all live UI stays hidden and no timetable updates are fetched.

## Shipping a new timetable without an app release

Two databases, each with its own version: `sncft` (SNCFT trains) and
`transtu` (métro léger + TGM, attached to sncft.db by the app).

1. Rebuild the database (`tools/build_timetable_db.py` for SNCFT,
   `tools/build_transtu_db.py` for TRANSTU) and copy it to
   `assets/initial/<name>.db` (or point `source` in `db.json` at it).
2. Raise `version` in `db.json`.
3. `npm run deploy`.

Apps check `/db/manifest.json` 10 s after start, download the file in the
background, verify its SHA-256 and switch to it on the next start (or at once
via Settings → check for updates). Raise `schema` in `db.json` only when the
tables change in a way older builds cannot read: they then keep their copy.
When you also bundle the new file in a release, set `kBundledDbVersions` in
`lib/services/database_updater.dart` to the same version.

## Night mode

From 00:30 to 04:15 Tunis time, when the last snapshot showed no train
running, the Worker polls every 15 minutes instead of every minute
(`pollIntervalMinutes` in `src/feed.js`). Overnight trains keep the 1-minute
cadence. `live.json` carries `nextAt` so the app does not treat a quiet-night
file as stale.

## Test

```bash
npm test                 # pure logic, no network
npx wrangler dev --test-scheduled
curl "http://localhost:8787/__scheduled?cron=*+*+*+*+*"   # run one refresh
curl http://localhost:8787/live.json
```

## Format (`v: 1`)

```json
{ "v": 1, "generatedAt": "2026-11-10T15:20:00.000Z", "nextAt": "2026-11-10T15:21:00.000Z", "source": "sncft.com.tn",
  "trains": [ { "id": "18873645", "num": "0005076", "unite": "GL",
                "name": "GABES - TUNIS", "status": "EN_ROUTE", "delay": 0,
                "curFr": "M'SAKEN", "nextFr": "SOUSSE", "arrivalPlan": "18:17",
                "arrivalForecast": "18:30", "prog": 31,
                "stops": [ { "n": "Gabes", "a": "قابس", "pd": "13:05", "ad": "13:07" } ],
                "stopsAt": 1762787940 } ] }
```

Train fields keep SNCFT's names. Stop keys: `n` name, `a` Arabic name,
`pa`/`pd` planned arrival/departure, `aa`/`ad` actual, `fa` forecast arrival.
`stops` is `null` until fetched. ~110 KB raw, ~14 KB gzipped at peak.

## Limits to know

- Free Workers plan: 50 subrequests per run, so stop lists refresh in a
  rolling way — running trains every 2 min, others every 10 min, finished never.
- 100 000 Worker requests/day on the free plan. Static assets (`/db/*`) do
  not count. `live.json` is edge-cached 30 s per location; past the limit,
  move to Workers Paid ($5/month) or a custom domain with a cache rule.
- The SNCFT endpoints are undocumented and unlicensed. If the snapshot fails
  the previous file stays and the app hides live data once `generatedAt` is
  older than 5 minutes.

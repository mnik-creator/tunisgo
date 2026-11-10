# tunisgo-live — Cloudflare Worker

Polls the public SNCFT live tracker once a minute and publishes one
`live.json` that the app reads. SNCFT sees a single client; user IPs never
reach it. Free plan is enough.

```
cron (1/min) ──► sncft_get_trains (1 req) + sncft_get_details (≤44 req)
             └─► R2: live.json  ◄── GET /live.json (edge cache 30 s) ◄── app
```

## Deploy

```bash
cd cloudflare/live-worker
npm install
npx wrangler login
npx wrangler r2 bucket create tunisgo-live
npx wrangler deploy
```

The deploy prints `https://tunisgo-live.<account>.workers.dev`. Build the app with:

```bash
flutter build appbundle --dart-define=LIVE_FEED_URL=https://tunisgo-live.<account>.workers.dev/live.json
```

Without `LIVE_FEED_URL` all live UI stays hidden.

## Test

```bash
npm test                 # pure logic, no network
npx wrangler dev --test-scheduled
curl "http://localhost:8787/__scheduled?cron=*+*+*+*+*"   # run one refresh
curl http://localhost:8787/live.json
```

## Format (`v: 1`)

```json
{ "v": 1, "generatedAt": "2026-11-10T15:20:00.000Z", "source": "sncft.com.tn",
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
- 100 000 requests/day on `workers.dev`. With 60 s polling only while the
  station screen is open that is plenty; past that, put R2 behind a custom
  domain (`live.json` already carries `Cache-Control: public, max-age=30`).
- The SNCFT endpoints are undocumented and unlicensed. If the snapshot fails
  the previous file stays and the app hides live data once `generatedAt` is
  older than 5 minutes.

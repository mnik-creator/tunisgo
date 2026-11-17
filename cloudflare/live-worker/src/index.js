// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// TunisGO live proxy.
//
// Every minute (cron) it reads the public SNCFT live tracker once, refreshes
// the stop lists of the trains that need it, and stores one `live.json` in a
// Durable Object. Quiet nights poll every 15 min instead (see feed.js).
// The app reads that file instead of calling sncft.com.tn, so SNCFT sees one
// client no matter how many users there are, and user IPs never reach it.
//
//   GET /live.json         -> latest snapshot (edge-cached 30 s)
//   GET /db/manifest.json  -> timetable DB versions (static asset)
//   GET /db/<name>-v<N>.db -> timetable DB file (static asset)
import { DurableObject } from 'cloudflare:workers';

import {
  SUBREQUEST_BUDGET,
  buildFeed,
  compactStop,
  countRunning,
  mapLimit,
  mergeSnapshot,
  selectForRefresh,
  shouldPoll,
} from './feed.js';

const ORIGIN = 'https://www.sncft.com.tn';
const AJAX = `${ORIGIN}/wp-admin/admin-ajax.php`;
const PLUGIN = `${ORIGIN}/wp-content/plugins/sncft-live-tracker`;
const USER_AGENT = 'TunisGO-live/1.0 (+https://github.com/mnik-creator/tunisgo)';

/// Single instance holding the latest feed. Metadata is kept apart from the
/// body so the cron can decide whether to poll without reading 100 KB.
export class LiveStore extends DurableObject {
  async read() {
    return (await this.ctx.storage.get('body')) ?? null;
  }

  async running() {
    return (await this.ctx.storage.get('running')) ?? 1;
  }

  async write(body, running) {
    await this.ctx.storage.put({ body, running });
  }
}

const store = (env) => env.LIVE_STORE.get(env.LIVE_STORE.idFromName('live'));

export default {
  async scheduled(_event, env, ctx) {
    ctx.waitUntil(refresh(env));
  },

  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname !== '/live.json') {
      return new Response('Not found', { status: 404 });
    }
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method not allowed', { status: 405 });
    }

    // One cache entry regardless of query string.
    const cacheKey = new Request(`${url.origin}/live.json`);
    const cache = caches.default;
    const hit = await cache.match(cacheKey);
    if (hit) return hit;

    const body = await store(env).read();
    if (!body) {
      return json('{"error":"not ready"}', 503, 'no-store');
    }
    const response = json(body, 200, 'public, max-age=30');
    ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};

function json(body, status, cacheControl) {
  return new Response(body, {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': cacheControl,
      'access-control-allow-origin': '*',
    },
  });
}

async function refresh(env) {
  // Quiet nights: decide from the stored running count (no SNCFT request)
  // whether this minute's run is due.
  const live = store(env);
  if (!shouldPoll(new Date(), await live.running())) return;

  let used = 0;
  const getJson = async (url) => {
    used++;
    const res = await fetch(url, {
      headers: { accept: 'application/json', 'user-agent': USER_AGENT },
      cf: { cacheTtl: 0 },
    });
    if (!res.ok) throw new Error(`${res.status} ${url}`);
    const data = await res.json();
    if (!Array.isArray(data)) throw new Error(`not a list: ${url}`);
    return data;
  };

  let snapshot;
  try {
    snapshot = await getJson(`${AJAX}?action=sncft_get_trains`);
  } catch (e) {
    console.warn('snapshot via admin-ajax failed', String(e));
    try {
      snapshot = await getJson(`${PLUGIN}/proxy.php`);
    } catch (e2) {
      // Keep the previous file; the app shows it as stale via generatedAt.
      console.error('snapshot failed', String(e2));
      return;
    }
  }

  let previous = null;
  try {
    const body = await live.read();
    previous = body ? JSON.parse(body) : null;
  } catch {
    // Corrupt or missing: start fresh.
  }

  const trains = mergeSnapshot(snapshot, previous);
  const nowS = Math.floor(Date.now() / 1000);
  const queue = selectForRefresh(trains, nowS).slice(0, SUBREQUEST_BUDGET - used);

  await mapLimit(queue, 6, async (train) => {
    const id = encodeURIComponent(train.id);
    let rows = null;
    try {
      rows = await getJson(`${AJAX}?action=sncft_get_details&id=${id}`);
    } catch {
      if (used < SUBREQUEST_BUDGET) {
        rows = await getJson(`${PLUGIN}/details.php?id=${id}`).catch(() => null);
      }
    }
    if (rows && rows.length > 0) {
      train.stops = rows.map(compactStop);
      train.stopsAt = nowS;
    }
  });

  await live.write(JSON.stringify(buildFeed(trains)), countRunning(trains));
  console.log(`live.json: ${trains.length} trains, ${queue.length} stop lists refreshed, ${used} subrequests`);
}

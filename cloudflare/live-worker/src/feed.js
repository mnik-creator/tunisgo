// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Pure helpers for the live-feed Worker: no network, no bindings, so they can
// be unit-tested with `node --test`.

export const FEED_VERSION = 1;

/// Free Workers plan: 50 subrequests per invocation. Keep a margin for the
/// snapshot request and its fallback.
export const SUBREQUEST_BUDGET = 45;

/// How old a train's stop list may get before it is refetched.
export const RUNNING_REFRESH_S = 120;
export const IDLE_REFRESH_S = 600;

const TRAIN_FIELDS = [
  'id', 'num', 'unite', 'name', 'nameAr', 'status', 'delay',
  'curFr', 'curAr', 'nextFr', 'nextAr',
  'arrivalPlan', 'arrivalActual', 'arrivalForecast', 'prog',
];

/// Keeps the snapshot fields the app reads; drops `order` and anything new
/// upstream adds until the app knows what to do with it.
export function pickTrain(raw) {
  const out = {};
  for (const key of TRAIN_FIELDS) {
    if (raw[key] !== undefined && raw[key] !== null) out[key] = raw[key];
  }
  out.id = String(raw.id ?? '');
  out.num = String(raw.num ?? '').trim();
  return out;
}

/// `HH:MM` or null; rejects `--:--` and empty strings.
export function cleanTime(value) {
  if (typeof value !== 'string') return null;
  const s = value.trim();
  return /^\d{1,2}:\d{2}$/.test(s) ? s : null;
}

/// One details row -> compact stop with short keys, nulls dropped.
/// Cuts the payload roughly in half versus the upstream field names.
export function compactStop(row) {
  const stop = { n: String(row.LOC_NAME ?? '').trim() };
  const ar = String(row.ANAME ?? '').trim();
  if (ar) stop.a = ar;
  const times = {
    pa: row.PLAN_ARRIVAL,
    pd: row.PLAN_DEPARTURE,
    aa: row.ACTUAL_ARRIVAL,
    ad: row.ACTUAL_DEPARTURE,
    fa: row.FORECAST_ARRIVAL,
  };
  for (const [key, value] of Object.entries(times)) {
    const t = cleanTime(value);
    if (t) stop[key] = t;
  }
  return stop;
}

/// Carries stop lists over from the previous generation for trains that are
/// still in the snapshot.
export function mergeSnapshot(rawTrains, previous) {
  const prevById = new Map((previous?.trains ?? []).map((t) => [t.id, t]));
  return rawTrains
    .filter((t) => t && typeof t === 'object')
    .map((raw) => {
      const train = pickTrain(raw);
      const prev = prevById.get(train.id);
      train.stops = prev?.stops ?? null;
      train.stopsAt = prev?.stopsAt ?? 0;
      return train;
    });
}

/// Trains whose stop list should be (re)fetched this run, most urgent first.
///
/// Running trains change the most; trains without any stop list come next so
/// a new day fills in within a few runs; finished trains are never refetched.
export function selectForRefresh(trains, nowS) {
  const ranked = [];
  for (const t of trains) {
    const age = nowS - (t.stopsAt || 0);
    const hasStops = Array.isArray(t.stops) && t.stops.length > 0;
    let priority = null;
    if (t.status === 'EN_ROUTE') {
      if (!hasStops) priority = 0;
      else if (age >= RUNNING_REFRESH_S) priority = 2;
    } else if (t.status === 'NOT_STARTED') {
      if (!hasStops) priority = 1;
      else if (age >= IDLE_REFRESH_S) priority = 3;
    } else if (t.status === 'CANCELLED') {
      // Planned times are still useful to show the cancellation at a station.
      if (!hasStops) priority = 4;
    } else if (t.status !== 'TERMINATED' && !hasStops) {
      priority = 4; // unknown status: fetch once
    }
    if (priority !== null) ranked.push({ t, priority, age });
  }
  ranked.sort((a, b) => a.priority - b.priority || b.age - a.age);
  return ranked.map((r) => r.t);
}

/// Tunisia is UTC+1 all year (no DST since 2009).
const TUNIS_OFFSET_MIN = 60;

/// Night window (Tunis time, minutes since midnight) when, unless a train is
/// still running, the Worker polls only every [NIGHT_INTERVAL_MIN] minutes.
/// The last suburban trains end around 00:15 and the first leave at 04:30.
export const NIGHT_START_MIN = 30;
export const NIGHT_END_MIN = 4 * 60 + 15;
export const NIGHT_INTERVAL_MIN = 15;

export function tunisMinuteOfDay(now) {
  const m = now.getUTCHours() * 60 + now.getUTCMinutes() + TUNIS_OFFSET_MIN;
  return m % (24 * 60);
}

/// Minutes between SNCFT polls at [now] given how many trains the last
/// snapshot showed running. Overnight trains keep the 1-minute cadence.
export function pollIntervalMinutes(now, runningCount) {
  if (runningCount > 0) return 1;
  const m = tunisMinuteOfDay(now);
  return m >= NIGHT_START_MIN && m < NIGHT_END_MIN ? NIGHT_INTERVAL_MIN : 1;
}

/// Whether the cron run at [now] should poll SNCFT. Night runs are aligned to
/// the interval (00:30, 00:45, …) so the cadence survives missed runs.
export function shouldPoll(now, runningCount) {
  const interval = pollIntervalMinutes(now, runningCount);
  return interval === 1 || tunisMinuteOfDay(now) % interval === 0;
}

export function countRunning(trains) {
  return trains.filter((t) => t.status === 'EN_ROUTE').length;
}

/// [nextAt] tells the app when the next poll is due, so a quiet-night file is
/// not mistaken for a broken feed.
export function buildFeed(trains, now = new Date()) {
  const interval = pollIntervalMinutes(now, countRunning(trains));
  return {
    v: FEED_VERSION,
    generatedAt: now.toISOString(),
    nextAt: new Date(now.getTime() + interval * 60_000).toISOString(),
    source: 'sncft.com.tn',
    trains,
  };
}

/// Runs [fn] over [items] with at most [limit] in flight.
export async function mapLimit(items, limit, fn) {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next++];
      await fn(item);
    }
  });
  await Promise.all(workers);
}

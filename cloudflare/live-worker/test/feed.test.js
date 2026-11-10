// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  IDLE_REFRESH_S,
  RUNNING_REFRESH_S,
  buildFeed,
  cleanTime,
  compactStop,
  mapLimit,
  mergeSnapshot,
  pickTrain,
  selectForRefresh,
} from '../src/feed.js';

test('pickTrain keeps known fields, stringifies id and num', () => {
  const t = pickTrain({ id: 42, num: ' 0005076 ', status: 'EN_ROUTE', delay: 3, order: 1, arrivalActual: null });
  assert.deepEqual(t, { id: '42', num: '0005076', status: 'EN_ROUTE', delay: 3 });
});

test('cleanTime rejects placeholders', () => {
  assert.equal(cleanTime('06:21'), '06:21');
  assert.equal(cleanTime('--:--'), null);
  assert.equal(cleanTime(''), null);
  assert.equal(cleanTime(null), null);
});

test('compactStop uses short keys and drops empty times', () => {
  const stop = compactStop({
    LOC_NAME: 'Bir Kassa', ANAME: 'بئر القصعة',
    PLAN_DEPARTURE: '06:21', ACTUAL_DEPARTURE: '06:21',
    PLAN_ARRIVAL: '06:19', ACTUAL_ARRIVAL: '--:--', FORECAST_ARRIVAL: null,
  });
  assert.deepEqual(stop, { n: 'Bir Kassa', a: 'بئر القصعة', pa: '06:19', pd: '06:21', ad: '06:21' });
});

test('mergeSnapshot carries stops over by id and drops vanished trains', () => {
  const previous = { trains: [
    { id: '1', stops: [{ n: 'A' }], stopsAt: 100 },
    { id: 'gone', stops: [{ n: 'B' }], stopsAt: 100 },
  ] };
  const merged = mergeSnapshot([{ id: 1, num: '205' }, { id: 2, num: '206' }, null], previous);
  assert.equal(merged.length, 2);
  assert.deepEqual(merged[0].stops, [{ n: 'A' }]);
  assert.equal(merged[0].stopsAt, 100);
  assert.equal(merged[1].stops, null);
  assert.equal(merged[1].stopsAt, 0);
});

test('selectForRefresh orders by urgency and skips finished trains', () => {
  const now = 10_000;
  const fresh = now - 10;
  const trains = [
    { id: 'term', status: 'TERMINATED', stops: null, stopsAt: 0 },
    { id: 'idle-fresh', status: 'NOT_STARTED', stops: [{}], stopsAt: fresh },
    { id: 'idle-old', status: 'NOT_STARTED', stops: [{}], stopsAt: now - IDLE_REFRESH_S },
    { id: 'run-old', status: 'EN_ROUTE', stops: [{}], stopsAt: now - RUNNING_REFRESH_S },
    { id: 'run-fresh', status: 'EN_ROUTE', stops: [{}], stopsAt: fresh },
    { id: 'idle-new', status: 'NOT_STARTED', stops: null, stopsAt: 0 },
    { id: 'run-new', status: 'EN_ROUTE', stops: null, stopsAt: 0 },
    { id: 'cancel-new', status: 'CANCELLED', stops: null, stopsAt: 0 },
    { id: 'cancel-known', status: 'CANCELLED', stops: [{}], stopsAt: 0 },
  ];
  assert.deepEqual(
    selectForRefresh(trains, now).map((t) => t.id),
    ['run-new', 'idle-new', 'run-old', 'idle-old', 'cancel-new'],
  );
});

test('buildFeed stamps version and time', () => {
  const feed = buildFeed([], new Date('2026-11-10T15:00:00Z'));
  assert.deepEqual(feed, { v: 1, generatedAt: '2026-11-10T15:00:00.000Z', source: 'sncft.com.tn', trains: [] });
});

test('mapLimit never exceeds the concurrency limit', async () => {
  let inFlight = 0;
  let peak = 0;
  const seen = [];
  await mapLimit([1, 2, 3, 4, 5, 6, 7], 3, async (n) => {
    inFlight++;
    peak = Math.max(peak, inFlight);
    await new Promise((r) => setTimeout(r, 5));
    seen.push(n);
    inFlight--;
  });
  assert.equal(peak, 3);
  assert.deepEqual(seen.sort(), [1, 2, 3, 4, 5, 6, 7]);
});

// Copyright (c) 2025 mnik-creator
// Licensed under MIT — see LICENSE file
//
// Builds public/db/ from db.json before every deploy: one versioned copy of
// each timetable database plus manifest.json for the app's DatabaseUpdater.
//
// To ship a new timetable without an app release: rebuild the .db (see
// tools/build_timetable_db.py), raise its "version" in db.json, then
// `npm run deploy`. Raise "schema" only when the tables change in a way older
// app builds cannot read; those builds then keep their bundled copy.
import { createHash } from 'node:crypto';
import { copyFileSync, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const config = JSON.parse(readFileSync(join(root, 'db.json'), 'utf8'));
const out = join(root, 'public', 'db');

rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });

const databases = {};
for (const [name, { version, schema, source }] of Object.entries(config)) {
  if (!Number.isInteger(version) || version < 1) throw new Error(`${name}: bad version`);
  const path = resolve(root, source);
  const wal = `${path}-wal`;
  if (existsSync(wal) && statSync(wal).size > 0) {
    throw new Error(`${name}: ${wal} is not empty — checkpoint the database first`);
  }
  const bytes = readFileSync(path);
  if (bytes.subarray(0, 16).toString('latin1') !== 'SQLite format 3\0') {
    throw new Error(`${name}: ${path} is not a SQLite database`);
  }
  const file = `${name}-v${version}.db`;
  copyFileSync(path, join(out, file));
  databases[name] = {
    version,
    schema,
    file,
    size: bytes.length,
    sha256: createHash('sha256').update(bytes).digest('hex'),
  };
  console.log(`db: ${file} (${bytes.length} bytes)`);
}

writeFileSync(join(out, 'manifest.json'), `${JSON.stringify({ v: 1, databases }, null, 2)}\n`);

#!/usr/bin/env python3
"""
TunisGO — InsForge Storage upload pipeline.

Computes SHA-256 of a .db file, uploads it to the operator's bucket under a
versioned key ({operator}_v{N}.db), then updates manifest.json in the 'files'
bucket.  Old versions are intentionally left in place for rollback.

Usage:
    python scripts/upload_db.py \
        --operator sncft \
        --bucket   sncft \
        --version  8 \
        --db       ./build/sncft.db

Required environment variables:
    INSFORGE_URL      — e.g. https://crknube9.eu-central.insforge.app
    INSFORGE_API_KEY  — admin/service key (never commit this!)
"""

import argparse
import hashlib
import json
import os
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

INSFORGE_URL: str = os.environ.get("INSFORGE_URL", "").rstrip("/")
API_KEY: str = os.environ.get("INSFORGE_API_KEY", "")
MANIFEST_BUCKET = "files"
MANIFEST_KEY = "sncft_manifest.json"
MIN_APP_VERSION = "1.0.0"


def _check_env() -> None:
    missing = [k for k in ("INSFORGE_URL", "INSFORGE_API_KEY") if not os.environ.get(k)]
    if missing:
        print(f"ERROR: Missing environment variable(s): {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()


def _auth_headers() -> dict:
    return {"Authorization": f"Bearer {API_KEY}"}


def upload_file(bucket: str, local_path: Path, remote_key: str) -> None:
    """Upload a file to InsForge Storage using the SDK via Node.js.

    The REST POST endpoint auto-renames files when the key already exists, so
    we use the SDK's upload() method which preserves the requested key exactly.
    Requires `node` and `@insforge/sdk` installed in /tmp/insforge_upload/.
    """
    import subprocess, textwrap
    script = textwrap.dedent(f"""
        import {{ createClient }} from '@insforge/sdk';
        import {{ readFileSync }} from 'fs';
        const client = createClient({{ baseUrl: '{INSFORGE_URL}', anonKey: '{API_KEY}' }});
        const buf = readFileSync('{local_path}');
        const blob = new Blob([buf], {{ type: 'application/octet-stream' }});
        const {{ data, error }} = await client.storage.from('{bucket}').upload('{remote_key}', blob);
        if (error) {{ console.error(JSON.stringify(error)); process.exit(1); }}
        console.log(JSON.stringify(data));
    """).strip()
    tmp_js = Path(tempfile.mktemp(suffix=".mjs"))
    tmp_js.write_text(script)
    try:
        result = subprocess.run(
            ["node", str(tmp_js)],
            capture_output=True, text=True,
            cwd="/tmp/insforge_upload",
        )
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        print(f"  ✓ Uploaded  {bucket}/{remote_key}  ({local_path.stat().st_size:,} bytes)")
    finally:
        tmp_js.unlink(missing_ok=True)


def fetch_manifest() -> dict:
    """Download current manifest.json, or return an empty shell if absent."""
    url = f"{INSFORGE_URL}/api/storage/buckets/{MANIFEST_BUCKET}/objects/{MANIFEST_KEY}"
    r = requests.get(url, timeout=15)
    if r.status_code == 200:
        return r.json()
    if r.status_code == 404:
        print("  ℹ  manifest.json not found — will create a new one.")
        return {"databases": {}}
    r.raise_for_status()
    return {}  # unreachable


def delete_file(bucket: str, remote_key: str) -> None:
    """Delete a file from an InsForge Storage bucket (silently ignores 404)."""
    url = f"{INSFORGE_URL}/api/storage/buckets/{bucket}/objects/{remote_key}"
    r = requests.delete(url, headers=_auth_headers(), timeout=30)
    if r.status_code not in (200, 404):
        r.raise_for_status()


def push_manifest(manifest: dict) -> None:
    """Delete existing manifest, then upload the new one with the exact key.

    InsForge auto-renames uploads when the key already exists, so we must
    delete first to ensure manifest.json lands at the correct path.
    """
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".json", delete=False, encoding="utf-8"
    ) as tmp:
        json.dump(manifest, tmp, indent=2, ensure_ascii=False)
        tmp_path = Path(tmp.name)
    try:
        delete_file(MANIFEST_BUCKET, MANIFEST_KEY)
        upload_file(MANIFEST_BUCKET, tmp_path, MANIFEST_KEY)
    finally:
        tmp_path.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Core workflow
# ---------------------------------------------------------------------------

def publish_database(operator: str, bucket: str, version: int, db_path: Path) -> None:
    if not db_path.is_file():
        print(f"ERROR: File not found: {db_path}", file=sys.stderr)
        sys.exit(1)

    remote_key = f"{operator}_v{version}.db"
    digest = sha256_of(db_path)

    print(f"\nPublishing  {operator}  v{version}")
    print(f"  File      {db_path}  ({db_path.stat().st_size:,} bytes)")
    print(f"  SHA-256   {digest}")
    print(f"  Bucket    {bucket}/{remote_key}\n")

    # 1. Upload versioned .db
    upload_file(bucket, db_path, remote_key)

    # 2. Update manifest
    manifest = fetch_manifest()
    manifest.setdefault("databases", {})
    manifest["databases"][operator] = {
        "bucket": bucket,
        "version": version,
        "file": remote_key,
        "sha256": digest,
        "size_bytes": db_path.stat().st_size,
        "min_app_version": MIN_APP_VERSION,
        "released_at": datetime.now(timezone.utc).isoformat(),
    }
    manifest["updated_at"] = datetime.now(timezone.utc).isoformat()
    manifest["schema_version"] = 1

    push_manifest(manifest)
    print(f"\n✓ Published {operator} v{version} — manifest updated.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    _check_env()

    ap = argparse.ArgumentParser(
        description="Upload a versioned .db to InsForge Storage and update manifest.json."
    )
    ap.add_argument("--operator", required=True, help="Operator identifier, e.g. sncft")
    ap.add_argument("--bucket", required=True, help="InsForge Storage bucket name")
    ap.add_argument("--version", type=int, required=True, help="Integer version number")
    ap.add_argument("--db", type=Path, required=True, help="Path to the local .db file")
    args = ap.parse_args()

    publish_database(args.operator, args.bucket, args.version, args.db)

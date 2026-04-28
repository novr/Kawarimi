#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${PRESET:-small}"
FORMAT="${FORMAT:-yaml}"
FIXTURE_DIR="${FIXTURE_DIR:-$(mktemp -d -t kawarimi-perf-fixture)}"
OUT_DIR="${OUT_DIR:-$(mktemp -d -t kawarimi-perf-out)}"

cleanup() {
  if [[ "${KEEP_FIXTURE:-}" != "1" ]]; then
    rm -rf "$FIXTURE_DIR" "$OUT_DIR"
  fi
}
trap cleanup EXIT

if [[ "${KEEP_FIXTURE:-}" == "1" ]]; then
  python3 "$ROOT/Scripts/performance/generate_openapi_fixture.py" \
    --preset "$PRESET" \
    --format "$FORMAT" \
    "$FIXTURE_DIR"
else
  python3 "$ROOT/Scripts/performance/generate_openapi_fixture.py" \
    --preset "$PRESET" \
    --format "$FORMAT" \
    "$FIXTURE_DIR" >/dev/null
fi

if [[ "$FORMAT" == "yaml" || "$FORMAT" == "both" ]]; then
  SPEC="$FIXTURE_DIR/openapi.yaml"
elif [[ "$FORMAT" == "json" ]]; then
  SPEC="$FIXTURE_DIR/openapi.json"
else
  echo "unsupported FORMAT=$FORMAT" >&2
  exit 2
fi

mkdir -p "$OUT_DIR"
(cd "$ROOT" && swift run --quiet Kawarimi "$SPEC" "$OUT_DIR")

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEMO="$ROOT/Example/DemoPackage"
API_SWIFT="$DEMO/Sources/DemoAPI/DemoAPI.swift"
WORKDIR="$(mktemp -d -t kawarimi-incr-logs)"
SUMMARY="$WORKDIR/summary.txt"

if [[ ! -f "$API_SWIFT" ]]; then
  echo "expected DemoAPI.swift at $API_SWIFT" >&2
  exit 1
fi

if [[ "${1:-}" == "--clean" ]]; then
  rm -rf "$DEMO/.build"
fi

stat_mtime() {
  local f="$1"
  if stat -f '%m' "$f" >/dev/null 2>&1; then
    stat -f '%m %N' "$f"
  else
    stat -c '%Y %n' "$f"
  fi
}

list_kawarimi_mt() {
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    stat_mtime "$f"
  done < <(find "$DEMO/.build" \( -name 'Kawarimi.swift' -o -name 'KawarimiHandler.swift' -o -name 'KawarimiSpec.swift' \) 2>/dev/null | sort)
}

emit_section() {
  { echo ""; echo "=== $1 ==="; } | tee -a "$SUMMARY"
}

BACKUP="$WORKDIR/DemoAPI.swift.bak"
cp "$API_SWIFT" "$BACKUP"
restore() {
  cp "$BACKUP" "$API_SWIFT"
}
trap restore EXIT

strip_manifest_warnings() {
  grep -Ev '^warning:.*-primary-file .*(/Package\.swift|/Package@swift[^ ]*\.swift)'
}

demoapi_build_focus() {
  strip_manifest_warnings | grep -E '\[kawarimi-perf\]|DemoAPI' || true
}

emit_section "Build 1 (DemoAPI, --quiet)"
(cd "$DEMO" && swift build --target DemoAPI --quiet 2>&1) | tee "$WORKDIR/build1.log"

emit_section "Build 1 filtered (DemoAPI + [kawarimi-perf], manifest driver lines dropped)"
demoapi_build_focus <"$WORKDIR/build1.log" | tee "$WORKDIR/build1.summary.log" | tee -a "$SUMMARY"
read -r b1_lines _ < <(wc -l <"$WORKDIR/build1.summary.log")
echo "(filtered line count: $b1_lines)" | tee -a "$SUMMARY"

emit_section "Kawarimi*.swift mtimes after Build 1"
if list_kawarimi_mt | tee "$WORKDIR/kawarimi.after_b1.log" | tee -a "$SUMMARY" | grep -q .; then
  :
else
  echo "(no Kawarimi*.swift under .build yet — run a full build once without --clean)" | tee -a "$SUMMARY"
fi

case "$(uname -s)" in
Darwin) sed -i '' '1s/$/./' "$API_SWIFT" ;;
*) sed -i '1s/$/./' "$API_SWIFT" ;;
esac

emit_section "1 文字編集の差分 (DemoAPI.swift: 先頭行の末尾に . を 1 文字追加)"
diff -u "$BACKUP" "$API_SWIFT" | tee -a "$SUMMARY" || true

emit_section "Build 2 (DemoAPI, -v) after edit; full log: build2.log"
(cd "$DEMO" && swift build --target DemoAPI -v 2>&1) >"$WORKDIR/build2.log"

emit_section "Build 2 filtered"
demoapi_build_focus <"$WORKDIR/build2.log" | tee "$WORKDIR/build2.summary.log" | tee -a "$SUMMARY"
if [[ ! -s "$WORKDIR/build2.summary.log" ]]; then
  echo "(no matching lines; see full $WORKDIR/build2.log)" | tee -a "$SUMMARY"
fi
read -r b2_lines _ < <(wc -l <"$WORKDIR/build2.summary.log")
echo "(filtered line count: $b2_lines)" | tee -a "$SUMMARY"

emit_section "比較: フィルタ済み行数 (Build 1 vs Build 2)"
echo "build1.summary.log lines: $b1_lines" | tee -a "$SUMMARY"
echo "build2.summary.log lines: $b2_lines" | tee -a "$SUMMARY"

emit_section "比較: unified diff (build1.summary.log vs build2.summary.log)"
diff -u "$WORKDIR/build1.summary.log" "$WORKDIR/build2.summary.log" | tee -a "$SUMMARY" || true

emit_section "Kawarimi*.swift mtimes after Build 2"
if list_kawarimi_mt | tee "$WORKDIR/kawarimi.after_b2.log" | tee -a "$SUMMARY" | grep -q .; then
  :
else
  echo "(no Kawarimi*.swift under .build)" | tee -a "$SUMMARY"
fi

emit_section "比較: unified diff (Kawarimi mtimes after B2 vs after B1)"
if [[ -s "$WORKDIR/kawarimi.after_b1.log" ]] && [[ -s "$WORKDIR/kawarimi.after_b2.log" ]]; then
  diff -u "$WORKDIR/kawarimi.after_b1.log" "$WORKDIR/kawarimi.after_b2.log" | tee -a "$SUMMARY" || true
else
  echo "(skip: missing kawarimi mtime snapshot)" | tee -a "$SUMMARY"
fi

echo "" | tee -a "$SUMMARY"
echo "Logs: $WORKDIR" | tee -a "$SUMMARY"
echo "  build1.log / build2.log (raw), build1.summary.log / build2.summary.log (filtered)," | tee -a "$SUMMARY"
echo "  kawarimi.after_b1.log / kawarimi.after_b2.log, summary.txt (this run)" | tee -a "$SUMMARY"

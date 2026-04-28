# パフォーマンス計測

## 1. CLI（stderr）

成功時:

```text
[kawarimi-perf] phase=setup seconds=...
[kawarimi-perf] phase=load seconds=...
[kawarimi-perf] phase=generate_kawarimi seconds=...
[kawarimi-perf] phase=generate_handler seconds=...
[kawarimi-perf] phase=generate_spec seconds=...
[kawarimi-perf] phase=total seconds=...
```

- **setup**: ジェネレータ設定・stub 解決
- **load**: OpenAPI 読込
- **generate_***: 生成と書き込み（handler の警告のあとに `generate_handler`）

**SwiftPM**

- `time swift build`
- `swift build -v` / `swift build --very-verbose`
- `swift build -Xswiftc -driver-time-compilation`（増分では出力が少ないことがある）
- Xcode: Report navigator → Build → Timeline

**フィクスチャ**

```bash
./Scripts/performance/run_kawarimi_fixture.sh
```

| 変数 | 既定 |
|------|------|
| `PRESET` | `small`（~100 行 YAML）/ `large`（~5000 行） |
| `FORMAT` | `yaml` / `json` / `both` |
| `KEEP_FIXTURE` | `run_kawarimi_fixture.sh` のみ: `1` でフィクスチャ・出力を残し Python の `Wrote` も表示。未設定では `generate` の stdout を捨てる |

```bash
mkdir -p /tmp/kw-out /tmp/kw-spec
python3 Scripts/performance/generate_openapi_fixture.py --preset large --format both /tmp/kw-spec >/dev/null
swift run --quiet Kawarimi /tmp/kw-spec/openapi.yaml /tmp/kw-out 2>&1 | grep -F '[kawarimi-perf]'
swift run --quiet Kawarimi /tmp/kw-spec/openapi.json /tmp/kw-out 2>&1 | grep -F '[kawarimi-perf]'
```

`Wrote` を見たいときは `>/dev/null` を外す。`grep '[kawarimi-perf]'` は `[]` が文字クラスになるため **`grep -F '[kawarimi-perf]'`** か **`grep '\[kawarimi-perf\]'`** を使う。

`--operations N` も可。

---

## 2. インクリメンタル（DemoAPI）

`DemoAPI.swift` の先頭行（コメント）の末尾に `.` を 1 文字足し、終了時に元に戻す。Build 1 は `--quiet`、Build 2 は `-v`（全文は `build2.log`）。各ビルド後に同じフィルタで `build1.summary.log` / `build2.summary.log`（`DemoAPI` と `[kawarimi-perf]`、マニフェスト用 `warning: ... Package.swift` 行は除外）。標準出力と `summary.txt` に **ソースの unified diff**、**フィルタ済みログの unified diff**、**Kawarimi*.swift の mtime の unified diff**（`kawarimi.after_b1.log` vs `after_b2`）と行数比較を出す。

```bash
./Scripts/performance/incremental-build.sh
./Scripts/performance/incremental-build.sh --clean
```

ログディレクトリは末尾の `Logs:` 行。

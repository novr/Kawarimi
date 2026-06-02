# エージェント向けルール（Kawarimi）

OpenAPI からモック・Handler・Spec をビルド時生成する SwiftPM プラグイン。Types / Client / Server は swift-openapi-generator と併用。詳細は README、`docs`、および **`Roadmap.md`**（プロジェクトのゴール＝未来の方向。バックログ・議論は GitHub Issues、届けた変更は CHANGELOG）。

## Kawarimi 固有の境界

- **生成の分担**: 利用者ターゲットの **OpenAPI 文書**と **openapi-generator-config** は swift-openapi-generator と共有する。本パッケージは **Kawarimi（`ClientTransport` モック）・`KawarimiHandler`・`KawarimiSpec`** の生成に責務を限定し、Types / Client / Server の生成ロジックを抱えない。
- **ターゲットの役割**:
**`KawarimiCore`** — 共有モデル・ファイル I/O 等の土台。
**`KawarimiJutsu`** — OpenAPI の解釈と上記生成物の Swift ソース生成。
**`Kawarimi`** — CLI（プラグインがビルド時に起動する実行体を含む）。
**`KawarimiPlugin`** — SwiftPM Build Tool Plugin（CLI 実行と入出力パスを境界とする）。
**`KawarimiHenge`** — ランタイム側（動的モック UI 等）；コード生成パスと混同しない。
**`KawarimiServer`** — OpenAPI サーバ向け動的モック。

- **スコープ外**:
**実 API サーバの実装**や、本パッケージの成果物では満たせない **サーバ実装に閉じる要件**は本パッケージに含めない。Issue に残っていても、本リポジトリでの実装・保守対象外としてよい。

## Keep it Simple & Quick

Before implementing a large-scale change, always ask yourself: "Can we try something quicker/simpler?"
Prioritize utilizing existing code and minimizing moving parts over creating new abstractions or adding heavy dependencies.

## 作業の進め方

- **スコープ**: 依頼に必要な変更だけに限定する。無関係なリファクタや、明示されていないドキュメント追加を広げない。
- **ブランチとコミット**: 作業用ブランチを切り、**論理単位でコミットを分割**する。
- **プラン・To-do**: 既に To-do がある場合は作り直さず、**先頭から in_progress にして完了まで**進める。プラン用の添付ファイルは編集しない。
- **検証**: 変更内容に応じて `swift test`、必要なら `Scripts/performance/` や CI と揃えた環境変数で確認する。**パフォーマンスに触れたら性能チェックも行う**。
- **Linux（ローカル）**: macOS 上で ubuntu CI と同じテスト列を試すときは Docker 上の [`Scripts/linux-test.sh`](Scripts/linux-test.sh)（`KAWARIMI_LINUX_CI=1`、CI では未使用）。ビルド成果物は **`.build/linux-docker`** に隔離（macOS の `.build` と混ぜない）。全件 `./Scripts/linux-test.sh`、E2E のみ `./Scripts/linux-test.sh --filter DemoServerE2ETests`。以前の docker 実行で PCH パス不一致（`/workspace` vs 実パス）が出たら、壊れた Linux キャッシュを削除: `rm -rf .build/aarch64-unknown-linux-gnu .build/linux-docker Example/DemoPackage/.build/linux-docker`。SwiftUI の **`KawarimiHenge` Views** は macOS の `swift test` 全件で確認する。
- **ビルド情報**: コミット済みスタブ **`dev`**（ローカル・PR CI）。タグ付きリリース時のみ [`.github/workflows/release.yaml`](.github/workflows/release.yaml) が `git describe --tags` で `Generated.swift` を上書きし、Release 用ソースアーカイブに含める（ワークツリーは汚さない）。
- **`[kawarimi-perf]`**: 利用者・計測手向けの説明は [Scripts/performance/README.md](Scripts/performance/README.md) に従う（実装やワークフローへの参照はこのファイルでは書かない）。
- **Issue**: バグ・機能は Issue で追う。**サーバ実装依存は本パッケージのスコープ外**（上記「境界」と同じ前提）。

## ドキュメント更新

- **必ず更新する**: 利用者に見える **CLI やプラグインの挙動**、**統合手順**（配置・設定・ターゲット要件）、**モック／設定 YAML の意味**、**生成物の形式や互換**を変えたときは、該当する **README（`README_JA.md` / `README.md`）** および **`docs/ja/` / `docs/`** を同じ変更で直す。
- **広げない**: 依頼に無い **新規ドキュメントファイルの追加**や、章立ての大規模な組み替えはしない（必要なら Issue や別依頼にする）。
- **言語**: 触ったトピックに英日両方の入口がある場合は、**両方に反映**するか、一方のみが意図的なら既存パターンに合わせる。

### ドキュメントのみの PR と CI

- **`main` 向け PR**: [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) の `changes`（`dorny/paths-filter`）が、次のいずれかに触れる変更があるかだけを見る: `Sources/**`, `Tests/**`, `Package.swift`, `Package.resolved`, `Example/**`, `Scripts/**`, `.github/**`。
- **上記に該当しない差分だけ**（例: ルートの `README*.md`、`AGENTS.md`、`docs/**` のみ）の PR では、ubuntu 上のテストジョブはスキップされる。ブランチ保護で必須にしている **チェック名「Swift Test」** は、常に走る集約ジョブ `swift-test` が成功することで満たされる（ルール側で必須チェックを外す必要はない）。**`[kawarimi-perf]`** の計測は PR CI ではなく [Scripts/performance/README.md](Scripts/performance/README.md) の手動ワークフロー／ローカルスクリプト。
- **ubuntu CI（コード変更 PR）**: `swift:6.2-noble` コンテナ上で、ルートと `Example/DemoPackage` はそれぞれ `swift test`（**`BuildInfo.version` は生成しない** — スタブ **`dev`**）。**`KAWARIMI_LINUX_CI=1`** のとき **`KawarimiHengeCore`** と **`Tests/KawarimiCoreTests/Henge/`** を CI で実行する（SwiftUI の **`KawarimiHenge`** ライブラリ product と Demo の `HengeCli` は除外）。マージ前に macOS ローカルで `swift test` 全件（`KawarimiHenge` Views 含む）を実行すること。
- **ビルドや CI に効く新しいパス**（上記以外に置いたツールや設定など）を追加したら、同じワークフローの `code` フィルタに追記し、該当変更でテストが走るようにする。

## CHANGELOG

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) の形に従い、[Semantic Versioning](https://semver.org/spec/v2.0.0.html) を前提にする。
- **ユーザーまたは統合者が気づく変更**（新機能・修正・非互換・非推奨）は **`CHANGELOG.md` の `[Unreleased]`** に追記し、リリース時にバージョン見出しへ移す。
- **破壊的変更**は **`### Breaking`**（または既存スタイルの **Breaking** セクション）で明示する。内部リファクタのみで外向きの契約が変わらない場合は CHANGELOG を必須としない判断でよいが、迷ったら追記する。

### 構造（リリース workflow との契約）

- **バージョン見出し（必須）**: `## [X.Y.Z] - YYYY-MM-DD`（`X.Y.Z` は SemVer、日付は ISO `YYYY-MM-DD`）。タグ `vX.Y.Z` と対応し、[`.github/workflows/release.yaml`](.github/workflows/release.yaml) がこの形式の節だけを Release 本文に抽出する（見出し行 `## [X.Y.Z]` は除く）。
- **`[Unreleased]`**: ファイル内で **最初の `##` 見出し**として維持。リリース PR 後は空でもよいが、見出し行は削除しない（日付なしのため抽出対象外）。
- **並び**: リリース済みバージョンは **新しい順**（現状どおり）。
- **フッタリンク**: リリース PR で `[X.Y.Z]: https://github.com/novr/Kawarimi/releases/tag/vX.Y.Z` を `CHANGELOG.md` 末尾に追加。GitHub Release 本文には含めない（抽出範囲外）。
- **サブセクション**: `### Added` / `### Changed` / `### Fixed` / `### Docs` / `### Breaking` / `### Migration from …` 等は既存スタイルに合わせる。

## コミット

- **形式**: Conventional Commits 風の `type(scope): 説明`（英語、命令形／現在形）。例: `feat(cli): …`, `fix(release): …`, `chore(release): prepare 2.2.0`。
- **type の例**: `feat`, `fix`, `docs`, `chore`, `ci`, `perf`。**scope** は `cli`, `henge`, `server`, `jutsu`, `release`, `deps` 等。
- **機能 PR**: ユーザー向け変更は同一 PR で **`CHANGELOG.md` の `[Unreleased]`** に追記する。
- **リリース準備**: **`chore(release): prepare X.Y.Z`** を 1 コミットとし、CHANGELOG 確定・フッタリンクをまとめる（分割しない）。**パッチ**（`X.Y.Z` の `Z` のみ増加）では **`docs/integration.md` / `docs/ja/integration.md` は触らない**。**マイナー／メジャー**で統合者向けの移行が必要なときだけ integration の pin と移行メモを更新する。
- **タグ push 後**: Release 本文用の追加コミットは不要（workflow が CHANGELOG から設定する）。

## PR とリリース準備

リリースは **2 段階**: (1) リリース PR で CHANGELOG を確定（必要なら integration も） → (2) マージ後にタグ push で workflow が GitHub Release を公開。

- **PR（マージ前）**: 変更範囲に応じて本リポジトリの CI と整合する検証が通る状態にする（**コード変更**では ubuntu CI と同様の `swift test` に加え、macOS で **`KawarimiHenge` を含む全テスト**を実行すること。**ドキュメントのみ**の CI 挙動は「ドキュメントのみの PR と CI」を参照）。本文に**変更の要約**と**関連 Issue** を書く。**破壊的変更**は本文または CHANGELOG でレビュアーが見落とせないように示す。差分は**レビュー可能な粒度**を優先し、無理なら分割を検討する。
- **リリース PR（Phase 1）**:
  1. `CHANGELOG.md`: `[Unreleased]` を `## [X.Y.Z] - YYYY-MM-DD` へ移し、空の `[Unreleased]` を残す。フッタに `[X.Y.Z]: …/releases/tag/vX.Y.Z` を追加。
  2. **マイナー／メジャー**のみ: `docs/integration.md` と `docs/ja/integration.md` の SwiftPM pin と **直前版 → X.Y.Z** の移行メモ（破壊的変更時は必須）。**パッチ**は CHANGELOG のみ（integration は更新しない）。
  3. コミット: `chore(release): prepare X.Y.Z`（**1 コミット推奨**）。
  4. **SemVer** で `X.Y.Z` を決める（外向きの破壊的変更はメジャーを上げる等）。
- **タグ（Phase 2）**: マージコミットに `git tag vX.Y.Z` → `git push origin vX.Y.Z`。 [`.github/workflows/release.yaml`](.github/workflows/release.yaml) が `Generated.swift` を生成 → `swift test` → **`CHANGELOG.md` の該当節から Release 説明文**（見出し行 `## [X.Y.Z]` は除く）→ **`kawarimi-vX.Y.Z-source.tar.gz`** を添付。このアーカイブをビルドすると **`--version`** がタグと一致。GitHub 自動の **Source code (zip/tar.gz)** はスタブ **`dev`** のまま。**Release 本文の手動コピーは不要**。

## コードとテスト（原則）

- **コメント**: 経緯・チケットの転載・コードを読めば分かる言い換えは書かない。**非自明な理由（why）**があるときだけ短く書く（例: 外部仕様に合わせる不変条件、安全上の制約）。自明ならコメントを足さない。
- **責務と境界**: 再利用・単体テストが効く単位にロジックを置き、公開 API は必要最小限にする（高凝集・疎結合）。
- **観測可能な振る舞い**: テストは「何を約束するか」を直接検証する。主張の裏付けを**代理指標だけ**にしない。
- **契約と失敗**: 新しい分岐・エラー型・例外経路は、**成功と対になる形でテスト**し、利用者が遭遇しうる失敗を黙殺しない。
- **生成物・テキスト出力**: 実装の都合に引きずられた**文字列の部分一致**に依存しない。パースやデータとしての**意味的同等性**で検証する。
- **横断的変更**: プラグイン・ツール・UI・サンプルを同時に触るときは、**セキュリティ境界・環境制約・ユーザー状態の損失**を設計に含め、テスト範囲を明示する。
- **I/O と差分**: 同じ入力なら不要な書き込みや下流ビルドの無駄を増やさない（冪等性と副作用の意識）。変更検知は**安い判定から順に**行い、高コストな読み取り・比較は必要最小限にする。

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
- **ビルド情報**: 未生成時はコミット済みスタブ **`dev`**。**PR の CI** もスタブのままテストする。タグ付きリリースは [`.github/workflows/release.yaml`](.github/workflows/release.yaml) が `Scripts/generate-build-info.sh` を実行する。ローカルで `git describe` と揃えるときだけ手動で同スクリプトを実行する。
- **`[kawarimi-perf]`**: 利用者・計測手向けの説明は [Scripts/performance/README.md](Scripts/performance/README.md) に従う（実装やワークフローへの参照はこのファイルでは書かない）。
- **Issue**: バグ・機能は Issue で追う。**サーバ実装依存は本パッケージのスコープ外**（上記「境界」と同じ前提）。

## ドキュメント更新

- **必ず更新する**: 利用者に見える **CLI やプラグインの挙動**、**統合手順**（配置・設定・ターゲット要件）、**モック／設定 YAML の意味**、**生成物の形式や互換**を変えたときは、該当する **README（`README_JA.md` / `README.md`）** および **`docs/ja/` / `docs/`** を同じ変更で直す。
- **広げない**: 依頼に無い **新規ドキュメントファイルの追加**や、章立ての大規模な組み替えはしない（必要なら Issue や別依頼にする）。
- **言語**: 触ったトピックに英日両方の入口がある場合は、**両方に反映**するか、一方のみが意図的なら既存パターンに合わせる。

### ドキュメントのみの PR と CI

- **`main` 向け PR**: [`.github/workflows/ci.yaml`](.github/workflows/ci.yaml) の `changes`（`dorny/paths-filter`）が、次のいずれかに触れる変更があるかだけを見る: `Sources/**`, `Tests/**`, `Package.swift`, `Package.resolved`, `Example/**`, `Scripts/**`, `.github/**`。
- **上記に該当しない差分だけ**（例: ルートの `README*.md`、`AGENT.md`、`docs/**` のみ）の PR では、ubuntu 上のテスト／perf ジョブはスキップされる。ブランチ保護で必須にしている **チェック名「Swift Test」** は、常に走る集約ジョブ `swift-test` が成功することで満たされる（ルール側で必須チェックを外す必要はない）。
- **ubuntu CI（コード変更 PR）**: `swift:6.2-noble` コンテナ上で、ルートと `Example/DemoPackage` はそれぞれ `swift test`（**`BuildInfo.version` は生成しない** — スタブ **`dev`**）。**`KAWARIMI_LINUX_CI=1`** のとき `Package.swift` は Henge（および Demo の `HengeCli`）ターゲットを除外するため、Linux では Henge 系はビルドされない。**`KawarimiHengeTests` は CI に含めない**（SwiftUI）。マージ前に macOS ローカルで `swift test` 全件（Henge 含む）を実行すること。
- **ビルドや CI に効く新しいパス**（上記以外に置いたツールや設定など）を追加したら、同じワークフローの `code` フィルタに追記し、該当変更でテストが走るようにする。

## CHANGELOG

- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) の形に従い、[Semantic Versioning](https://semver.org/spec/v2.0.0.html) を前提にする。
- **ユーザーまたは統合者が気づく変更**（新機能・修正・非互換・非推奨）は **`CHANGELOG.md` の `[Unreleased]`** に追記し、リリース時にバージョン見出しへ移す。
- **破壊的変更**は **`### Breaking`**（または既存スタイルの **Breaking** セクション）で明示する。内部リファクタのみで外向きの契約が変わらない場合は CHANGELOG を必須としない判断でよいが、迷ったら追記する。

## PR とリリース準備

- **PR（マージ前）**: 変更範囲に応じて本リポジトリの CI と整合する検証が通る状態にする（**コード変更**では ubuntu CI と同様の `swift test` に加え、macOS で **`KawarimiHengeTests` を含む全テスト**を実行すること。**ドキュメントのみ**の CI 挙動は「ドキュメントのみの PR と CI」を参照）。本文に**変更の要約**と**関連 Issue** を書く。**破壊的変更**は本文または CHANGELOG でレビュアーが見落とせないように示す。差分は**レビュー可能な粒度**を優先し、無理なら分割を検討する。
- **リリース直前**: **`CHANGELOG.md`** の **`[Unreleased]`** を **`## [X.Y.Z] - YYYY-MM-DD`** 見出しへ移し、既存パターンに合わせて**フッタのバージョン比較リンク**（`CHANGELOG.md` 末尾）を更新する。**SemVer** で `X.Y.Z` を決める（外向きの破壊的変更はメジャーを上げる等）。
- **タグ**: 公開リリースは **`vX.Y.Z`**。`git push origin vX.Y.Z` で [`.github/workflows/release.yaml`](.github/workflows/release.yaml) が走り、`Scripts/generate-build-info.sh` → `swift test` のあと **`kawarimi-vX.Y.Z-source.tar.gz`** を GitHub Release に添付する（このアーカイブをビルドすると **`--version`** がタグと一致）。GitHub が自動生成する **Source code (zip/tar.gz)** はコミット済みスタブのままなので **`dev`** になる。

## コードとテスト（原則）

- **コメント**: 経緯・チケットの転載・コードを読めば分かる言い換えは書かない。**非自明な理由（why）**があるときだけ短く書く（例: 外部仕様に合わせる不変条件、安全上の制約）。自明ならコメントを足さない。
- **責務と境界**: 再利用・単体テストが効く単位にロジックを置き、公開 API は必要最小限にする（高凝集・疎結合）。
- **観測可能な振る舞い**: テストは「何を約束するか」を直接検証する。主張の裏付けを**代理指標だけ**にしない。
- **契約と失敗**: 新しい分岐・エラー型・例外経路は、**成功と対になる形でテスト**し、利用者が遭遇しうる失敗を黙殺しない。
- **生成物・テキスト出力**: 実装の都合に引きずられた**文字列の部分一致**に依存しない。パースやデータとしての**意味的同等性**で検証する。
- **横断的変更**: プラグイン・ツール・UI・サンプルを同時に触るときは、**セキュリティ境界・環境制約・ユーザー状態の損失**を設計に含め、テスト範囲を明示する。
- **I/O と差分**: 同じ入力なら不要な書き込みや下流ビルドの無駄を増やさない（冪等性と副作用の意識）。変更検知は**安い判定から順に**行い、高コストな読み取り・比較は必要最小限にする。

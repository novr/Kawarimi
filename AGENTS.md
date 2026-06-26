# エージェント向けルール（Kawarimi）

## 概要

- 依頼範囲だけ変更する。無関係なリファクタ・新規ドキュメント追加はしない。
- 大きな変更（目安: 3ファイル以上または50行以上）に入る前に、最小変更案（Impact Analysis: 変更対象・非対象・リスク）を提示し、承認後に実施する。
- 「依頼範囲だけ変更する」の判断が曖昧な場合は実装前に確認する（推測で広げない）。
- 利用者に見える挙動（CLI / Plugin / 統合手順 / YAML意味 / 生成物互換）を変えたら `README.md` / `README_JA.md` / `docs/` / `docs/ja/` を同一変更で更新する。
- ドキュメント更新は日英を同一PRで揃える（片側だけ更新しない）。

## コード規約

- コメントは非自明な `why`（不変条件・安全制約・外部仕様依存）のみ。コードの言い換えは書かない。
- ロジックはテスト可能な単位に置き、公開 API は最小限に保つ。
- 生成物やテキスト出力の検証は文字列部分一致に寄せず、意味的同等性で扱う。
- 同入力で不要な再書き込みを発生させない（冪等性を維持）。

## テスト

- コード変更時は `swift test` を実行する。
- エージェントは実行可能な環境で可能な限りテストを実行し、未実行項目と理由を明示して報告する。
- `KawarimiHenge` Views を含む macOS 前提テストは、人間またはCIで担保する（エージェント環境で実行不能なら必ず申し送り）。
- ubuntu 相当確認が必要な場合は `Scripts/linux-test.sh` を使い、成果物は `.build/linux-docker` に隔離する。
- パフォーマンスに触れた変更は `Scripts/performance/README.md` の手順で計測する。
- CI 対象外になり得る新規パスを追加したら `.github/workflows/ci.yaml` の `code` フィルタを更新する。

## 境界

- 生成責務は `Kawarimi`（`ClientTransport` モック）/ `KawarimiHandler` / `KawarimiSpec` に限定し、Types / Client / Server 生成ロジックは持たない。
- `KawarimiCore`: 共有モデル・ファイル I/O 基盤。
- `KawarimiJutsu`: OpenAPI 解釈と生成コード組み立て。
- `Kawarimi`: CLI 実行体。
- `KawarimiPlugin`: Build Tool Plugin（CLI 実行と入出力パス境界）。
- `KawarimiHenge`: ランタイム機能（生成パスと分離）。
- `KawarimiServer`: OpenAPI サーバ向け動的モック。
- `KawarimiClient`: OpenAPI クライアント向けシナリオオーケストレーション middleware。
- 実 API サーバ実装やサーバ内部要件はスコープ外。

## GIT

- 機能・修正は Issue 起点で追う。
- コミットは Conventional Commits 準拠（`type(scope)!: description`、英語）で、論理単位に分割する。
- `type` は `feat|fix|docs|test|refactor|perf|chore|ci` のみを使う。
- `scope` は `core|jutsu|cli|plugin|henge|server|release|deps` を優先する。
- ユーザー影響のある変更は同一 PR で `CHANGELOG.md` の `[Unreleased]` を更新する。
- 破壊的変更はコミットで `!` または `BREAKING CHANGE:` を使い、`CHANGELOG.md` でも明示する。
- リリース準備は `chore(release): prepare X.Y.Z` を原則 1 コミットにまとめる。
- パッチ時に `docs/integration.md` / `docs/ja/integration.md` を更新しないルールは、リリース準備コミット（`chore(release): prepare X.Y.Z`）にのみ適用する。

# ロードマップ

English: project **goals** (future direction only). Backlog, priorities, and discussion: [GitHub Issues](https://github.com/novr/Kawarimi/issues). Shipped changes: [CHANGELOG.md](CHANGELOG.md).

## プロジェクトのゴール

- **契約駆動のテスト基盤**: OpenAPI を単一のソースとして、ビルド時に **Kawarimi**（`ClientTransport` モック）・**KawarimiHandler**（`APIProtocol` のデフォルト実装）・**KawarimiSpec**（モック／契約メタデータ）を生成し、[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) が出す Types / Client / Server と **同一ターゲットで併用**できるようにする。**KawarimiSpec** には OpenAPI 由来の契約メタデータ（API 全体の `meta`、操作ごとのタグ・パラメータ等）を集約し、モック・UI・テストから参照しやすくする。
- **開発ループの速さと制御**: 不要な生成物を選べるようにし、CLI を自己説明的にし、定義が大きくても **解析と生成 Swift のビルド負荷が実務で困らない**ようにする。
- **本番に近い検証**: モックツールとして、**実行時の応答差し替え**、**遅延・タイムアウトの再現**、**操作・パラメータを識別・扱うためのメタデータ**など、本番挙動の検証に必要な機能を備える。

**ゴールに含めない:** **記録・再生**（本番トラフィックのキャプチャと replay）、**ステートフル**（呼び出し順序やセッションに依存するモック）は、本プロジェクトのゴールとしない。

## 本ドキュメントの位置づけ

進行方向（未来）の共有用である。優先度・着手順・リリース時期の約束は行わない。

- **バックログ・議論**: [GitHub Issues](https://github.com/novr/Kawarimi/issues)
- **届けた変更**: [CHANGELOG.md](CHANGELOG.md)
- **使い方・現状の機能**: [README.md](README.md) / [README_JA.md](README_JA.md)、[docs/README.md](docs/README.md) / [docs/ja/README.md](docs/ja/README.md)

## メンテナンス

- **プロジェクトのゴール**の文言は、製品の核が変わったときに見直す（Issue の増減のたびに書き換えない）。

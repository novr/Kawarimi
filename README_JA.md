日本語 | [English](README.md)

# Kawarimi（代わり身）

OpenAPI から **Kawarimi**（`ClientTransport` モック）・**KawarimiHandler**（`APIProtocol` のデフォルト実装）・**KawarimiSpec** をビルド時に生成する SwiftPM Build Tool Plugin。

Types / Client / Server は [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) の公式プラグインで生成する。

同じターゲットで **OpenAPIGenerator** と **KawarimiPlugin** を併用する。対応: `swift-openapi-generator 1.0.0+`。

Kawarimi（モック）は `Client` に transport として渡す。生成コードは `Client.swift` に依存しない。

## ドキュメント

| | |
| --- | --- |
| **[docs/ja/README.md](docs/ja/README.md)** | ガイド一覧 |
| [CHANGELOG.md](CHANGELOG.md) | リリース・破壊的変更（SemVer） |
| [導入・統合](docs/ja/integration.md) | SwiftPM、OpenAPI の配置、設定、テスト |
| [ダイナミックモック（Henge）](docs/ja/henge.md) | ランタイムモック、`__kawarimi` API、Vapor、`kawarimi.json` |
| [モック JSON の決め方](docs/ja/mock-json.md) | 埋め込みモック JSON の優先順位 |

**English:** [docs/README.md](docs/README.md)

## KawarimiHandler — witness 形（`on…` クロージャ）

`KawarimiHandler.swift` は operation ごとに `on...` クロージャを 1 つ生成し、同名の `APIProtocol` メソッドはそのクロージャへ委譲する（例: `getGreeting` → `onGetGreeting`）。

```swift
var handler = KawarimiHandler()
handler.onGetGreeting = { input in
    .ok(.init(body: .json(/* 任意のペイロード */)))
}
```

型は `@Sendable (Operations.….Input) async throws -> Operations.….Output` です。

`on…` と委譲メソッドの可視性は `openapi-generator-config.yaml` の `accessModifier`（`public` / `package` / `internal`、省略時 `public`）に合わせる。別ターゲットから API ターゲットを import する場合は `accessModifier: package` か `public` を使う。

デフォルトのスタブ本文は、スキーマから **`.json(...)` のリテラル式**が書けるときはそれを優先し、難しい場合は **`Kawarimi` トランスポートモックと同じ合成 JSON を `JSONDecoder` でデコード**する（[モック JSON の決め方](docs/ja/mock-json.md) の「KawarimiHandler のデフォルトスタブ」）。
**`handlerStubPolicy`** は `kawarimi-generator-config.yaml` で指定（[導入・統合](docs/ja/integration.md)）。

## サンプルプロジェクト

**DemoPackage**（SwiftPM + Vapor **DemoServer**）と **DemoApp**（SwiftUI）: [**Example/README_JA.md**](Example/README_JA.md) · [**Example/README.md**](Example/README.md)（構成、コマンド、スクリーンショット、セキュリティ注意）。

## 要件（要約）

Swift **6.2+**。詳細は [docs/ja/integration.md#要件ツールチェーン](docs/ja/integration.md#要件ツールチェーン)。**`Example/`** は macOS 14+。ライブラリは iOS 17+ も宣言。

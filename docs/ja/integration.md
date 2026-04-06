# 導入・統合

[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) と併用して Kawarimi を Swift パッケージに追加する手順です。

## 導入パターン

### 簡易

- **`openapi.yaml` を置いたライブラリターゲット（例: `MyAPI`）1 つ**に **OpenAPIGenerator** と **KawarimiPlugin** を付ける。ビルドで Types / Client / Server / Kawarimi 系が**同一モジュール**に生成される。
- **クライアントアプリ**は `MyAPI` のみ依存。**サーバ**（例: Vapor）は `MyAPI` に加え **Vapor**、Henge 用なら **KawarimiCore** とルート配線（[Example README_JA.md](../../Example/README_JA.md)）。
- **利点:** `Package.swift` が最小で、設定も一箇所。**注意:** アプリが Server を呼ばなくても、**生成された Server ソースは同じモジュールに含まれる**。バイナリ肥大やレイヤ境界は、分割するまで緩い。

### 推奨

- **`openapi.yaml` は 1 本に固定**し、**クライアント用とサーバ用でジェネレータの切り方を分ける**（ターゲットを分け、`openapi-generator-config.yaml` を用途別にするなど）。**アプリ向け**は Types + Client（必要なら Kawarimi／モック）、**サーバ向け**は Types + Server。**同じ Types を 2 モジュールに二重生成しない**よう、[swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration)に沿って構成する。
- **KawarimiPlugin** は、正とする **`openapi.yaml` を持つターゲット**に付ける。
- **利点:** 依存関係と成果物の境界が明確。**注意:** ターゲットや設定が増える。**CI でクライアント側・サーバ側の両方をビルド**する。

## 1. 依存とプラグイン

本パッケージの SwiftPM プロダクト:

- **KawarimiCore** — ランタイム（`MockOverride`、`KawarimiConfigStore`、`KawarimiAPIClient` など）。OpenAPIKit / Yams は含まない。
- **KawarimiJutsu** — ジェネレータ API（`KawarimiJutsu.loadOpenAPISpec`、YAML 設定ローダーなど）。OpenAPIKit 依存。CLI・テスト・独自ツール向けで、通常のアプリ本体には不要。
- **KawarimiHenge** — SwiftUI（`KawarimiConfigView`）。

**KawarimiSpec.swift** を置くターゲットでは、**`KawarimiCore`** に加え **`HTTPTypes`** プロダクトを**直接**依存に書く（[swift-http-types](https://github.com/apple/swift-http-types)）。**KawarimiCore** 経由の推移的依存だけでは SwiftPM が解決しません。

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.11.0"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
            .product(name: "HTTPTypes", package: "swift-http-types"),
            .product(name: "KawarimiCore", package: "Kawarimi"),
        ],
        plugins: [
            .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            .plugin(name: "KawarimiPlugin", package: "Kawarimi"),
        ]
    ),
]
```

ダイナミックモック用 SwiftUIには **KawarimiHenge**、`KawarimiAPIClient` には **KawarimiCore** を追加（[henge.md](henge.md)）。

## 2. OpenAPI の置き場所

ターゲットのソースディレクトリに `openapi.yaml` を 1 つ置く。ビルドで OpenAPIGenerator が Types.swift / Client.swift / Server.swift を、KawarimiPlugin が Kawarimi.swift / KawarimiHandler.swift / KawarimiSpec.swift を生成する。

## 3. オプション: ジェネレータ設定

`openapi.yaml` と**同じディレクトリ**に `openapi-generator-config.yaml`（または `.yml`）を置き、[swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration)で指定する。

Kawarimi が読むキーは **`namingStrategy`** と **`accessModifier`** です。

**`handlerStubPolicy`**（`throw` / `fatalError`、省略時 `throw`）は `openapi.yaml` と同じディレクトリの **`kawarimi-generator-config.yaml`**（または `.yml`）で指定します。

`Kawarimi` CLI / `KawarimiPlugin` は `openapi-generator-config.yaml` を優先し、無ければ `openapi-generator-config.yml` を探します。

## 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="要件ツールチェーン"></a>

## 要件・ツールチェーン

- Swift **6.2+**（`Package.swift` の `swift-tools-version` に合わせる）。**KawarimiPlugin** は `Kawarimi` 実行ファイルを `-parse-as-library`（`unsafeFlags`）でビルドする。**6.1** の SwiftPM は、プラグイン依存時にその依存グラフを**拒否**することがある。CI は [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) で **6.2** を選択。
- **`Example/`** 配下の SwiftPM サンプルは **macOS 14+**。Kawarimi のライブラリは **iOS 17+** も宣言（`Package.swift` の `platforms`）。
- `handlerStubPolicy: throw` はスタブ生成不能な operation で生成を失敗させます。
- `handlerStubPolicy: fatalError` は生成を継続し、該当 operation は実行時 `fatalError` になります。

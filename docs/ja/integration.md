# 導入・統合

[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) と併用して Kawarimi を Swift パッケージに追加する手順です。

## 導入パターン

### 簡易

- **`openapi.yaml` / `openapi.yml` / `openapi.json` のいずれか 1 本**を置いたライブラリターゲット（例: `MyAPI`）に **OpenAPIGenerator** と **KawarimiPlugin** を付ける。ビルドで Types / Client / Server / Kawarimi 系が**同一モジュール**に生成される。
- **クライアントアプリ**は `MyAPI` のみ依存。**サーバ**（例: Vapor）は `MyAPI` に加え **Vapor**、Henge 用なら **KawarimiCore** とルート配線（[Example README_JA.md](../../Example/README_JA.md)）。
- **利点:** `Package.swift` が最小で、設定も一箇所。**注意:** アプリが Server を呼ばなくても、**生成された Server ソースは同じモジュールに含まれる**。バイナリ肥大やレイヤ境界は、分割するまで緩い。

### 推奨

- **ターゲットあたり OpenAPI 仕様は 1 本**（`openapi.yaml` / `openapi.yml` / `openapi.json` のいずれか）にし、**クライアント用とサーバ用でジェネレータの切り方を分ける**（ターゲットを分け、`openapi-generator-config.yaml` を用途別にするなど）。**アプリ向け**は Types + Client（必要なら Kawarimi／モック）、**サーバ向け**は Types + Server。**同じ Types を 2 モジュールに二重生成しない**よう、[swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration)に沿って構成する。
- **KawarimiPlugin** は、その仕様を持つターゲットに付ける。
- **利点:** 依存関係と成果物の境界が明確。**注意:** ターゲットや設定が増える。**CI でクライアント側・サーバ側の両方をビルド**する。

## 1. 依存とプラグイン

更新時は **[CHANGELOG.md](../../CHANGELOG.md)** を参照。

**2.0.5 → 2.1.0**（追加のみ）:

1. pin を **`from: "2.1.0"`** に上げる。
2. サーバ: **KawarimiServer** と **`registerHandlers(middlewares:)`** の **`KawarimiServerMiddleware`** — [henge.md](henge.md)、[Example/README_JA.md](../../Example/README_JA.md)。
3. 旧 Example の Vapor グローバルインターセプタで operation モックしている場合は削除。
4. OpenAPI 再生成後に再ビルドし、**`responseMap`** と **`KawarimiSpec`** を揃える。

**2.1.0 → 2.2.0**（追加のみ）:

1. pin を **`from: "2.2.0"`** に上げる。
2. 任意の **`delayMs`**、任意の **`POST …/__kawarimi/reload`** / **`KawarimiConfigStore.reloadFromDisk()`**。
3. 独自 Henge UI: **`primaryEnabledOverrideForOperation`** / **`matchingEnabledOverridesForOperation`** ([#78](https://github.com/novr/Kawarimi/issues/78))。

**2.2.2 → 2.3.0**（追加のみ）:

1. pin を **`from: "2.3.0"`** に上げる。
2. **`SpecEndpointProviding`** や **`SpecResponse`** を使う場合は **`KawarimiSpec.swift` を再生成** — エンドポイントに任意の **`security`** が付き、OpenAPI に定義があるとき **`GET …/__kawarimi/spec`** の **`securitySchemes`** に載る ([#102](https://github.com/novr/Kawarimi/pull/102))。
3. **Henge** / admin の spec 利用者: wire JSON から **`KawarimiSpec.securitySchemes`** とエンドポイントごとの **`security`** を読める。oauth2 の flow URL は未展開。
4. クライアントのみ、またはプロセス内 **`Kawarimi()`** だけの利用者は、spec エンドポイントや生成 **`KawarimiSpec`** の形に依存しない限り変更不要。CHANGELOG の **2.3.0** を参照。

SwiftPM プロダクト:

- **KawarimiCore** — ランタイム（`MockOverride`、`KawarimiConfigStore`、`KawarimiAPIClient` など）。
- **KawarimiJutsu** — ジェネレータ API（CLI・テスト向け、OpenAPIKit 依存）。
- **KawarimiHenge** — SwiftUI 管理 UI — [henge.md](henge.md)。
- **KawarimiServer** — サーバ動的モック — [henge.md](henge.md)。

**KawarimiSpec.swift** を置くターゲットは **`KawarimiCore`** と **`HTTPTypes`** を**直接**依存に書く。

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "2.3.0"),
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

ダイナミックモック用 SwiftUI には **KawarimiHenge**、`KawarimiAPIClient` には **KawarimiCore**、サーバ実行時オーバーライドには **KawarimiServer** を追加（[henge.md](henge.md)）。

## 2. OpenAPI の置き場所

**Swift ターゲットルート**（[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) と同じ）に **`openapi.yaml`** / **`openapi.yml`** / **`openapi.json` のいずれか 1 本**。**KawarimiPlugin** は **`sourceFiles`** から選び、ディレクトリは走査しない。生成物: Types/Client/Server（OpenAPIGenerator）、Kawarimi/KawarimiHandler/KawarimiSpec（KawarimiPlugin）。

## 3. ジェネレータ設定（必須）

OpenAPI と同じディレクトリに **`openapi-generator-config.yaml`** または **`.yml` を 1 つ**（[設定](https://github.com/apple/swift-openapi-generator#configuration)）。Kawarimi は **`namingStrategy`** と **`accessModifier`** を読む。

任意の **`kawarimi-generator-config.yaml`**（高々 1 本）: **`handlerStubPolicy`**、`generateKawarimi` / `generateHandler` / `generateSpec`（省略時 `true`、いずれか 1 つは必須）。プラグインは **`sourceFiles`**、CLI は仕様パスのディレクトリ。

**`SpecEndpointProviding`** 利用時はアップグレード後に **`KawarimiSpec.swift` を再生成**。エンドポイントの **`tags`** は OpenAPI どおり（無いとき `nil`）。parameters は [#74](https://github.com/novr/Kawarimi/issues/74)。

## 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="要件ツールチェーン"></a>

## 要件・ツールチェーン

- Swift **6.2+**（`Package.swift`）。**KawarimiPlugin** は `-parse-as-library`（`unsafeFlags`）。**6.1** の SwiftPM は依存グラフを拒否することがある。
- **`Example/`**: macOS 14+。ライブラリは **iOS 17+** も宣言。
- **`handlerStubPolicy`**: `throw` はスタブ不能 operation があると生成失敗、`fatalError` は生成継続・実行時失敗（[mock-json.md](mock-json.md)）。

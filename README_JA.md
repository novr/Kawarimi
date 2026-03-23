日本語 | [English](README.md)

# Kawarimi（代わり身）

OpenAPI から Kawarimi（ClientTransport モック）・KawarimiHandler（APIProtocol のデフォルト実装）・KawarimiSpec をビルド時に生成する SwiftPM Build Tool Plugin。Types / Client / Server は [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) の公式プラグインで生成する。

**OpenAPIGenerator への暗黙的な依存**: 同じターゲットで両方のプラグインを使うこと。対応バージョン: **swift-openapi-generator 1.0.0 以上**。実質の型依存は **Types.swift**（`Operations.*` の Input/Output）と **Server.swift**（`APIProtocol`）のみ。KawarimiHandler がこれらを参照する。Kawarimi（モック）は Client に渡して使う側であり、Client.swift は依存先ではない。

## 使い方

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.3.0"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [
            .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator"),
            .plugin(name: "KawarimiPlugin", package: "Kawarimi"),
        ]
    ),
]
```

### 2. OpenAPI を置く

ターゲットのソースディレクトリに openapi.yaml を 1 つ置く。ビルドで OpenAPIGenerator が Types.swift / Client.swift / Server.swift を、KawarimiPlugin が Kawarimi.swift / KawarimiHandler.swift / KawarimiSpec.swift を生成する。

### 3. オプション: 公式 generator の設定

Types/Client/Server の生成オプションは、同じディレクトリに openapi-generator-config.yaml を置いて [swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration) で指定する。

### 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## ダイナミックモック

Kawarimi はビルド時に `KawarimiSpec.swift` を他のファイルと一緒に生成します。このファイルには API の全エンドポイントとレスポンスボディが Swift の定数として含まれます。サーバー側の `KawarimiInterceptorMiddleware` と Henge API を組み合わせることで、再コンパイルなしに実行時モックレスポンスを切り替えられます。

### 生成ファイル: KawarimiSpec.swift

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: (body, contentType)]
```

### Henge API（DemoServer / `{pathPrefix}/__kawarimi/*`）

**Henge API** は動的モック管理用 API の通称です（「Henge」は機能名）。**Example の `DemoServer`** では、OpenAPI API と同じパスプレフィックス（`KawarimiSpec.meta.apiPathPrefix`、例 **`/api/__kawarimi/spec`**）の下にマウントされます。独自構成ではルート直下に置くこともできます。`KawarimiAPIClient` の `baseURL` と揃えてください。

`DemoServer` をモックサーバーとして使う場合、admin ルートとミドルウェアを登録します:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "config.json")
registerKawarimiRoutes(app: app, store: store)
app.middleware.use(KawarimiInterceptorMiddleware(store: store))
```

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | path/method/statusCode のモックレスポンスを有効化 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

例 — GET /api/greet の 200 モックを有効化（Example `DemoServer`、既定 `pathPrefix` `/api`）:

```bash
curl -X POST http://localhost:8080/api/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}'
```

### クライアント: 実サーバーと Kawarimi モック

プロセス内の example モックと実サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。`Kawarimi()`（ネットワークなし）と、[swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` で `DemoServer` に繋ぐクライアントです（ターゲットにその製品を追加）。Example では **`DemoAPITests`** が `Kawarimi` 側を検証し、**`DemoApp`**（SwiftUI）の OpenAPI タブが起動中サーバーへの HTTP を試せます。

**1つの**クライアントで実／モックを実行時に切り替えたい、常に `x-kawarimi-mockId` を付けたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

### config.json / KAWARIMI_CONFIG

`KawarimiConfigStore` はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `config.json`）。ファイル形式は `KawarimiConfig`（overrides 配列）を使用します。**DemoServer は Example ディレクトリをカレントにして起動してください**（`config.json` の読み書き先を揃えるため。例: `cd Example && swift run DemoServer`）。環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。オーバーライドの `body` または `contentType` が空文字の場合は保存時に「未設定」に正規化され、レスポンス時も空 body は Spec のレスポンスにフォールバックします（カスタム body なし）。**DemoServer** は生成された `KawarimiSpec.meta.apiPathPrefix`（OpenAPI の `servers[0].url` のパス由来）を `pathPrefix` に渡すため、別環境変数は不要で Spec とマウントが一致します。独自サーバーでは `registerHandlers` や OpenAPI の `servers` と同じプレフィックスを `KawarimiConfigStore` に渡してください。

```bash
cd Example && swift run DemoServer   # config.json は Example/ に作成
KAWARIMI_CONFIG=/tmp/mock-config.json swift run DemoServer
```

### DemoApp（SwiftUI・macOS）

`swift run DemoApp` でウィンドウが開き、実行中サーバーの全エンドポイントを表示してピッカーでモックレスポンスを切り替えられます — ターミナル不要。**Server URL** と **API prefix** は `KawarimiSpec.meta` を初期値とし、**UserDefaults** に保存されます。手元で DemoServer を動かすときはホストを `http://localhost:8080` などに書き換えてください。

## Example

**`Example/` Swift パッケージ**は **macOS 専用のサンプル**です。本番向けの安全対策は含みません。**`__kawarimi`** 管理 API に**認証はなく**、**`DemoApp`** は入力した**任意の URL** へ HTTP を送れます。信頼できる環境での利用に留め、実運用では認証・ネットワーク制御などを自前で追加してください。

```bash
cd Example && swift build
swift run DemoServer   # 別ターミナルで
swift run DemoApp      # SwiftUI: OpenAPI + Henge（任意）
```

## 要件・詳細

- Swift 6.2+ / macOS 14+
- 生成対象: 200 + application/json の operation、$ref で components/schemas を参照する schema
- 詳しくはリポジトリを参照

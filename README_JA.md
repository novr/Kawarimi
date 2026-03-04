日本語 | [English](README.md)

# Kawarimi（代わり身）

swift-openapi-generator を使って Types / Client / Server と Kawarimi（ClientTransport モック）・KawarimiHandler（APIProtocol のデフォルト実装）をビルド時に生成する SwiftPM Build Tool Plugin。

## 使い方

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.3.0"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [.plugin(name: "KawarimiPlugin", package: "Kawarimi")]
    ),
]
```

### 2. OpenAPI を置く

ターゲットのソースディレクトリに openapi.yaml を 1 つ置く。ビルドで Types.swift / Client.swift / Server.swift / Kawarimi.swift / KawarimiHandler.swift が生成される。

### 3. オプション: 設定ファイル

同じディレクトリに kawarimi.yaml（または openapi-generator-config.yaml）を置くと、generate / filter / featureFlags など swift-openapi-generator 向けの設定を指定できる。

### 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## ダイナミックモック

Kawarimi はビルド時に `KawarimiSpec.swift` を他のファイルと一緒に生成します。このファイルには API の全エンドポイントとレスポンスボディが Swift の定数として含まれます。サーバー側の `MockInterceptorMiddleware` と Admin API を組み合わせることで、再コンパイルなしに実行時モックレスポンスを切り替えられます。

### 生成ファイル: KawarimiSpec.swift

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: (body, contentType)]
```

### Admin API（DemoServer / /__kawarimi/*）

`DemoServer` をモックサーバーとして使う場合、admin ルートとミドルウェアを登録します:

```swift
let store = MockConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "config.json")
registerAdminRoutes(app: app, store: store)
app.middleware.use(MockInterceptorMiddleware(store: store))
```

| エンドポイント | 説明 |
|---|---|
| `POST /__kawarimi/configure` | path/method/statusCode のモックレスポンスを有効化 |
| `GET /__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST /__kawarimi/reset` | 全オーバーライドを解除 |
| `GET /__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

例 — GET /api/greet の 200 モックを有効化:

```bash
curl -X POST http://localhost:8080/__kawarimi/configure \
  -H "Content-Type: application/json" \
  -d '{"path":"/api/greet","method":"GET","statusCode":200,"isEnabled":true}'
```

### DynamicMockTransport（クライアント側）

`DynamicMockTransport` は `DemoAPI` に手書きで追加する `ClientTransport` です。実サーバーとモックサーバーを実行時に切り替えられます:

```swift
let transport = DynamicMockTransport(
    underlying: URLSessionTransport(),
    realBaseURL: URL(string: "https://example.com/api")!,
    mockBaseURL: URL(string: "http://localhost:8080/api")!,
    useMockServer: true
)
let client = Client(serverURL: transport.mockBaseURL, transport: transport)
```

`x-kawarimi-mockId` ヘッダーで特定の名前付きオーバーライドを指定できます:

```swift
transport.mockId = "error-case"
```

### config.json / KAWARIMI_CONFIG

`MockConfigStore` はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `config.json`）。**DemoServer は Example ディレクトリをカレントにして起動してください**（`config.json` の読み書き先を揃えるため。例: `cd Example && swift run DemoServer`）。環境変数 `KAWARIMI_CONFIG` でパスを上書きできます:

```bash
cd Example && swift run DemoServer   # config.json は Example/ に作成
KAWARIMI_CONFIG=/tmp/mock-config.json swift run DemoServer
```

### SwiftUI 管理 UI（DemoAppUI）

`swift run DemoAppUI` で macOS ウィンドウが開き、実行中サーバーの全エンドポイントを表示してピッカーでモックレスポンスを切り替えられます — ターミナル不要。

## Example

```bash
cd Example && swift build
swift run DemoServer   # 別ターミナルで
swift run DemoApp      # クライアント
swift run DemoAppUI    # SwiftUI 管理 UI（任意）
```

## 要件・詳細

- Swift 6.2+ / macOS 14+
- 生成対象: 200 + application/json の operation、$ref で components/schemas を参照する schema
- 詳しくはリポジトリを参照

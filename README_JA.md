日本語 | [English](README.md)

# Kawarimi（代わり身）

OpenAPI から Kawarimi（ClientTransport モック）・KawarimiHandler（APIProtocol のデフォルト実装）・KawarimiSpec をビルド時に生成する SwiftPM Build Tool Plugin。

Types / Client / Server は [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) の公式プラグインで生成する。

同じターゲットで `OpenAPIGenerator` と `KawarimiPlugin` を併用してください。
対応バージョン: `swift-openapi-generator 1.0.0+`。

Kawarimi（モック）は Client に渡して使う側であり、Client.swift は依存先ではない。

### KawarimiHandler — witness 形（`on…` クロージャ）

`KawarimiHandler.swift` は operation ごとに `on...` クロージャを 1 つ生成し、同名の `APIProtocol` メソッドはそのクロージャへ委譲します（例: `getGreeting` → `onGetGreeting`）。

差し替え例:

```swift
var handler = KawarimiHandler()
handler.onGetGreeting = { input in
    .ok(.init(body: .json(/* 任意のペイロード */)))
}
```

型は `@Sendable (Operations.….Input) async throws -> Operations.….Output` です。

`on…` と委譲メソッドの可視性は `openapi-generator-config.yaml` の `accessModifier`（`public` / `package` / `internal`、省略時 `public`）に合わせます。
別ターゲットから API ターゲットを import する場合は `accessModifier: package` か `public` を使ってください。

## 使い方

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.9.0"),
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

ダイナミックモック用の SwiftUI や `KawarimiAPIClient` を使う **アプリ（またはツール）ターゲット**には、**KawarimiHenge** プロダクトも依存に追加してください（後述「ダイナミックモック（KawarimiHenge）」）。

### 2. OpenAPI を置く

ターゲットのソースディレクトリに openapi.yaml を 1 つ置く。ビルドで OpenAPIGenerator が Types.swift / Client.swift / Server.swift を、KawarimiPlugin が Kawarimi.swift / KawarimiHandler.swift / KawarimiSpec.swift を生成する。

### 3. オプション: 公式 generator の設定

Types/Client/Server の生成オプションは、`openapi.yaml` と**同じディレクトリ**に `openapi-generator-config.yaml`（または `.yml`）を置き、[swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration) で指定する。

Kawarimi が読むキーは `namingStrategy` と `accessModifier` です。

`handlerStubPolicy`（`throw` / `fatalError`、省略時 `throw`）は `openapi.yaml` と同じディレクトリの `kawarimi-generator-config.yaml`（または `.yml`）で指定します。

`Kawarimi` CLI / `KawarimiPlugin` は `openapi.yaml` と同じ場所の `openapi-generator-config.yaml` を優先し、無ければ `openapi-generator-config.yml` を探します。

### 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## ダイナミックモック（KawarimiHenge）

**ビルド時:** **Kawarimi** プラグインが `KawarimiSpec.swift` を生成し、エンドポイントとレスポンスボディを Swift の定数として埋め込みます。

**実行時**にオーバーライドを切り替えて再コンパイルなしでモックを変える流れは、**KawarimiHenge** の機能です。

アプリターゲットに **KawarimiHenge** を追加すると、SwiftUI（`KawarimiConfigView`）と `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使えます。

サーバー側は **KawarimiCore**（`KawarimiConfigStore`、`KawarimiInterceptorMiddleware`）と、**Henge API** として公開するルート（Example `DemoServer` 参照）を組み合わせます。

### 生成ファイル: KawarimiSpec.swift

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: (body, contentType)]
```

### Henge API（DemoServer / `{pathPrefix}/__kawarimi/*`）

**Henge API** は、**KawarimiHenge** の `KawarimiAPIClient` が呼び出す HTTP 面です（「Henge」は機能名）。

**Example** の `DemoServer` では、OpenAPI API と同じパスプレフィックス（`KawarimiSpec.meta.apiPathPrefix`、例 **`/api/__kawarimi/spec`**）の下にマウントします。

独自構成ではルート直下に置いても構いません。`KawarimiAPIClient` の `baseURL` と揃えてください。

`DemoServer` をモックサーバーとして使う場合、admin ルートとミドルウェアを登録します:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
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

プロセス内の example モックと実サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし、OpenAPI の `example` 由来の応答。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` で `DemoServer` に繋ぐクライアント（ターゲットにその製品を追加）。

Example では **`DemoAPITests`** が `Kawarimi` 側を検証します。

**`DemoApp`**（SwiftUI）の Henge タブは **KawarimiHenge**、OpenAPI タブは起動中サーバーへの HTTP 用です。

**1つの**クライアントで実／モックを実行時に切り替えたい、常に `x-kawarimi-mockId` を付けたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

### kawarimi.json / KAWARIMI_CONFIG

`KawarimiConfigStore`（**KawarimiCore**）はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `kawarimi.json`）。

ファイル形式は `KawarimiConfig`（overrides 配列）です。

**DemoServer は `Example/DemoPackage` をカレントにして起動してください**（`kawarimi.json` の読み書き先を揃える。例: `cd Example/DemoPackage && swift run DemoServer`）。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

`kawarimi.json` はランタイムの `overrides` のみを持ちます（生成の `handlerStubPolicy` は `kawarimi-generator-config.yaml`）。

`kawarimi-generator-config.yaml` の例:

```yaml
handlerStubPolicy: throw
```

`kawarimi.json` の例:

```json
{
  "overrides": []
}
```

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッド・`x-kawarimi-mockId` の条件が一致）、インターセプタは **`MockOverride.sortedForInterceptorTieBreak`** で並べ替えた **先頭**を採用します。比較順は `path` → **`mockId` が非 nil を nil より先** → `mockId` 文字列 → `statusCode` → `name` → `exampleId` です。キーが同順位のときは Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

**DemoServer** は `KawarimiSpec.meta.apiPathPrefix`（OpenAPI `servers[0].url` のパス由来）を `pathPrefix` に渡すため、Spec とマウントが一致し、別の環境変数は不要です。

独自サーバーでは `registerHandlers` や OpenAPI `servers` と同じプレフィックスを `KawarimiConfigStore` に渡してください。

```bash
cd Example/DemoPackage && swift run DemoServer   # kawarimi.json は Example/DemoPackage/ に作成
KAWARIMI_CONFIG=/tmp/kawarimi.json swift run DemoServer
```

### DemoApp（SwiftUI・macOS / iOS）

SwiftUI のサンプルは **`Example/DemoApp/`** にあり、**`Example/DemoApp.xcodeproj`** でビルドします（例: `xed Example/DemoApp.xcodeproj`）。**`DemoPackage` の `DemoAPI`** とリポジトリルートの **KawarimiCore / KawarimiHenge** にリンクしており、**`DemoPackage` 側に SwiftUI 依存はありません**。

**Server URL** と **API prefix** は `KawarimiSpec.meta` に**固定**（アプリ内は `KawarimiExampleConfig`）。

Example の `openapi.yaml` は **HTTP** かつ **`127.0.0.1`**（例: `http://127.0.0.1:8080/api`）。`localhost` が **`::1`** になり、Vapor が **IPv4 の 127.0.0.1** だけで待ち受けているときの接続拒否を避けるため。**`DemoApp-Info.plist`**（同期対象の `DemoApp/` ではなく `DemoApp.xcodeproj` と同階層）で **NSAppTransportSecurity → NSAllowsLocalNetworking** を有効にし、ATS がローカル向け平文 HTTP を許可します。**`DemoApp.entitlements`** で **App Sandbox** と **`com.apple.security.network.client`** を有効にし、URLSession がローカルサーバーへ接続できるようにしています（無いと `connectx` が *Operation not permitted* になります）。

手元で DemoServer を動かすときは、`openapi.yaml` の `servers` と実際のホストが一致するようにしてください。

## Example

**`Example/DemoPackage/`** は **OpenAPI 生成の `DemoAPI`** と **macOS 向け `DemoServer`（Vapor）** を含みます。SwiftUI アプリは **Xcode の `Example/DemoApp/`** のみです。本番向けの安全対策は含みません。

**`__kawarimi`** 管理 API に**認証はありません**。

**`DemoApp`** の OpenAPI 実行は **Spec で定義されたベース URL** に向けます。信頼できる環境でのみ使い、実運用では認証・ネットワーク制御を自前で追加してください。

```bash
cd Example/DemoPackage && swift build
swift run DemoServer   # 別ターミナルで。SwiftUI は Example/DemoApp.xcodeproj を開く
```

## 補足

- Swift 6.1+（`Package.swift` の `swift-tools-version` に合わせる。GitHub Actions の `macos-latest` は Swift 6.1 系）。**Example/DemoPackage** は **macOS 14+**。Kawarimi のライブラリは **iOS 17+** も宣言（`Package.swift` の `platforms`）。
- `handlerStubPolicy: throw` はスタブ生成不能な operation で生成を失敗させます。
- `handlerStubPolicy: fatalError` は生成を継続し、該当 operation は実行時 `fatalError` になります。

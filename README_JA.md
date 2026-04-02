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

### 導入パターン

#### 簡易

- **`openapi.yaml` を置いたライブラリターゲット（例: `MyAPI`）1 つ**に **OpenAPIGenerator** と **KawarimiPlugin** を付ける。ビルドで Types / Client / Server / Kawarimi 系が**同一モジュール**に生成される。
- **クライアントアプリ**は `MyAPI` のみ依存。**サーバ**（例: Vapor）は `MyAPI` に加え **Vapor**、Henge 用なら **KawarimiCore** とルート配線（参照サンプルは [`Example/README_JA.md`](Example/README_JA.md)）を足す。
- **利点:** `Package.swift` が最小で、設定も一箇所。**注意:** アプリが Server を呼ばなくても、**生成された Server ソースは同じモジュールに含まれる**。バイナリ肥大やレイヤ境界は、分割するまで緩い。

#### 推奨

- **`openapi.yaml` は 1 本に固定**し、**クライアント用とサーバ用でジェネレータの切り方を分ける**（ターゲットを分け、`openapi-generator-config.yaml` を用途別にするなど）。**アプリ向け**は Types + Client（必要なら Kawarimi／モック）、**サーバ向け**は Types + Server。**同じ Types を 2 モジュールに二重生成しない**よう、[swift-openapi-generator の設定](https://github.com/apple/swift-openapi-generator#configuration)に沿って構成する。
- **KawarimiPlugin** は、正とする **`openapi.yaml` を持つターゲット**に付ける（yaml をコピーして二系統にすると同期コストが増える）。
- **利点:** 依存関係と成果物の境界が明確で、クライアントに Server 実装を載せない方針にしやすい。**注意:** ターゲットや設定が増える。**CI でクライアント側・サーバ側の両方をビルド**し、仕様変更が片方だけ壊れないようにする。

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.9.4"),
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

ダイナミックモック用の SwiftUI には **KawarimiHenge**、`KawarimiAPIClient` には **KawarimiCore** を **アプリ（またはツール）ターゲット**の依存に追加してください（後述「ダイナミックモック（KawarimiHenge）」）。

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

アプリターゲットに **KawarimiCore** を追加すると `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使え、**KawarimiHenge** を追加すると SwiftUI（`KawarimiConfigView`）が使えます。

サーバー側は **KawarimiCore**（`KawarimiConfigStore`、`PathTemplate`、`MockOverride` など）と、**Henge API** ルートを組み合わせます。**オーバーライドを適用する Vapor の `AsyncMiddleware` は KawarimiCore の製品ではありません**—参照実装として [`KawarimiInterceptorMiddleware.swift`](Example/DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift) をコピー／改変するか、[`Example/README_JA.md`](Example/README_JA.md) の構成に沿って自分で書いてください。

### Vapor 向けに使う外部パッケージ（サーバ）

Kawarimi 単体に Vapor 用プロダクトはありません。生成した API ターゲットに、定番の OpenAPI + Vapor の組み合わせを載せます。

| 役割 | リンク / メモ |
| --- | --- |
| Web フレームワーク | [github.com/vapor/vapor](https://github.com/vapor/vapor) |
| 生成 Server と Vapor の橋渡し | [github.com/vapor/swift-openapi-vapor](https://github.com/vapor/swift-openapi-vapor)（`OpenAPIVapor`） |
| 生成コードのランタイム | [github.com/apple/swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) |
| OpenAPI からのコード生成 | [github.com/apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) |
| Henge の設定ストア・マッチング | **KawarimiCore**（本パッケージ） |

本リポジトリの **`DemoPackage` の構成** と **`DemoServer` のエントリポイント**: [**Example/README_JA.md**](Example/README_JA.md)。

### 生成ファイル: KawarimiSpec.swift

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: (body, contentType)]
```

### KawarimiSpec / `Kawarimi` トランスポートのモック JSON

各 `application/json` レスポンスについて、Kawarimi は `KawarimiSpec` に埋め込む JSON 文字列（および生成される `Kawarimi` 型の `ClientTransport` モックでは **200** の本文）を決めます。優先順は次のとおりです。

1. **Media Type Object** — `example`、または `examples` だけがある場合は OpenAPIKit が解決した先頭の値（`example` と `examples` の同時指定は仕様上不可）。
2. **そのメディア型の JSON Schema** — `example`、次に `default`。
3. **形からの合成** — `object` / `array` を再帰し、プリミティブは必要ならプレースホルダで埋める。
4. **`oneOf` / `anyOf`** — 空に近いプレースホルダ（`{}` / `""` / `0` / `false` / `[]` など）でない最初の枝を採用。どの枝もプレースホルダに近い場合は先頭の枝。
5. **`allOf`** — 先頭のサブスキーマ（明示的な example がないときの簡易ヒューリスティック）。
6. **`enum`（`allowedValues`）** — 先頭値を JSON としてエンコード。
7. **プリミティブ** — 文字列 `""`、数値 `0` など。型が取れない場合は `{}`。

`KawarimiHandler` のスタブ生成は別問題です。swift-openapi-generator 上の都合で、上記のモック JSON が取れている場合でも **一部の enum などはスタブ生成が失敗**し、`on…` の手実装や `handlerStubPolicy` が必要になることがあります。

### Henge API（`{pathPrefix}/__kawarimi/*`）

**Henge API** は、**KawarimiCore** の `KawarimiAPIClient` が呼び出す HTTP 面です（「Henge」は機能名）。

OpenAPI API と**同じパスプレフィックス体系**の下にマウントするのが一般的です（例: API が `/api` なら **`/api/__kawarimi/spec`**）。独自構成ではルート直下に置いても構いません。`KawarimiAPIClient` の `baseURL` と揃えてください。

Vapor で admin ルートとミドルウェアを登録する例:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
registerKawarimiRoutes(app: app, store: store)
app.middleware.use(KawarimiInterceptorMiddleware(store: store))
```

`KawarimiInterceptorMiddleware` はライブラリではなく **Example** のターゲット内のコードです。Vapor の `AsyncMiddleware` として、`__kawarimi` 管理パスは素通しし、有効なオーバーライド（パステンプレート・メソッド）にマッチしたら本体／`KawarimiSpec.responseMap` からボディを組み立てて即 `Response` を返し、無ければ `next` に委譲します。**自前のミドルウェアを書くときの手本**にしてください。

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | path/method/statusCode のモックレスポンスを有効化 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

本リポジトリの **DemoServer** 向けの **`curl` 例**: [Example/README_JA.md](Example/README_JA.md#henge-api-demoserver)。

### クライアント: 実サーバーと Kawarimi モック

プロセス内のモックと実 HTTP サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし。応答本文は上記のモック JSON ルール（operation ごとの 200 + `application/json`）に従います。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` でサーバーに繋ぐクライアント（ターゲットにその製品を追加）。

参照の **DemoServer** と **DemoApp** は **`Example/`** にあります: [Example/README_JA.md](Example/README_JA.md)。

**1つの**クライアントで実／モックを実行時に切り替えたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

### kawarimi.json / KAWARIMI_CONFIG

`KawarimiConfigStore`（**KawarimiCore**）はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `kawarimi.json`）。

ファイル形式は `KawarimiConfig`（overrides 配列）です。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

`kawarimi.json` はランタイムの `overrides` のみを持ちます（生成の `handlerStubPolicy` は `kawarimi-generator-config.yaml`）。

**初期 `kawarimi.json`・サンプル `kawarimi-generator-config.yaml`・`swift run DemoServer` のカレントディレクトリ**については [Example/README_JA.md](Example/README_JA.md) を参照してください。

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッドが一致）、インターセプタは **`MockOverride.sortedForInterceptorTieBreak`** で並べ替えた **先頭**を採用します。比較順は `path` → `statusCode` → `name` → `exampleId` です。キーが同順位のときは Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

## 参照サンプル（`Example/`）

本リポジトリには **DemoPackage**（SwiftPM + Vapor **DemoServer**）と **DemoApp**（SwiftUI）が含まれます。構成・セキュリティ注意・コマンド・スクリーンショットは [**Example/README_JA.md**](Example/README_JA.md) · [**Example/README.md**](Example/README.md)。

## 補足

- Swift **6.2+**（`Package.swift` の `swift-tools-version` に合わせる）。**KawarimiPlugin** は `Kawarimi` 実行ファイルを `-parse-as-library`（`unsafeFlags`）でビルドする。**6.1** の SwiftPM は、プラグイン依存時にその依存グラフを**拒否**することがある。CI は [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) で **6.2** を選択。**`Example/`** 配下の SwiftPM サンプルは **macOS 14+**。Kawarimi のライブラリは **iOS 17+** も宣言（`Package.swift` の `platforms`）。
- `handlerStubPolicy: throw` はスタブ生成不能な operation で生成を失敗させます。
- `handlerStubPolicy: fatalError` は生成を継続し、該当 operation は実行時 `fatalError` になります。

日本語 | [English](README.md)

# Kawarimi（代わり身）

OpenAPI から Kawarimi（ClientTransport モック）・KawarimiHandler（APIProtocol のデフォルト実装）・KawarimiSpec をビルド時に生成する SwiftPM Build Tool Plugin。

Types / Client / Server は [swift-openapi-generator](https://github.com/apple/swift-openapi-generator) の公式プラグインで生成する。

**OpenAPIGenerator への暗黙的な依存**: 同じターゲットで両方のプラグインを使うこと。

対応バージョン: **swift-openapi-generator 1.0.0 以上**。

実質の型依存は **Types.swift**（`Operations.*` の Input/Output）と **Server.swift**（`APIProtocol`）のみ。KawarimiHandler がこれらを参照する。

Kawarimi（モック）は Client に渡して使う側であり、Client.swift は依存先ではない。

### KawarimiHandler — witness 形（`on…` クロージャ）

`KawarimiHandler.swift` では **operation ごとに `var` を 1 つ**（可視性は **`accessModifier` と同じ**）出し、名前は **`on` + メソッド名の先頭大文字**（例: `getGreeting` → **`onGetGreeting`**）。同じ可視性の **`func`** がそのプロパティへ委譲（`try await onGetGreeting(input)`）します。クロージャのデフォルト実装は従来どおりの JSON / 空ボディ / 204 スタブです。

**一部の operation だけ差し替える例:**

```swift
var handler = KawarimiHandler()
handler.onGetGreeting = { input in
    .ok(.init(body: .json(/* 任意のペイロード */)))
}
```

型は **`@Sendable (Operations.….Input) async throws -> Operations.….Output`** です。差し替え時は並行性の要件に注意してください。

**アクセス修飾子:** `on…` と委譲メソッドは `openapi-generator-config.yaml` の **`accessModifier`**（`public` / `package` / `internal`、省略時は **`public`**）に合わせます。swift-openapi-generator の `Operations.*` と揃えないとコンパイルできません（例: `Operations` が `package` ならハンドラも `package`）。

**要件:** 同一 SwiftPM パッケージ内の別ターゲット（テスト・アプリ・サーバ・別ライブラリなど）から API ターゲットを import する場合は、**`accessModifier` を `package` または `public`（Swift の可視性でいう `package` 以上）**にしてください。**`internal`** だと生成される `Operations.*`・`Client`・`Server`・`KawarimiHandler` が API モジュール内に閉じるため、import 側はコンパイルできません。

**セマバ 0.x:** 破壊的変更があり得るので、アップグレード後は再生成し、差し替えは **`on…`** に寄せてください。`unsupportedHandlerStub` の挙動は §3 にまとめています。

**生成エラー**には **`[METHOD /path]`** と、可能な範囲で **OpenAPI 上の schema 位置**（`responses.200` や `components.schemas.*` など）が含まれます。

**ロードマップ（本リリース未実装）:** **文字列 enum の自動スタブ**（計画 B）は swift-openapi-generator のケース名と完全一致が必要。**合成 schema**（`allOf` / `oneOf` / …）は既定の **`throw`** では引き続き **生成失敗（C1）**。**`unsupportedHandlerStub: fatalError`** で「コンパイル優先・スタブ不能箇所は実行時 `fatalError`」を選べ、該当 operation ごとに stderr 警告が出ます。

## 使い方

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.7.0"),
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

**Kawarimi がこのファイルから読むのは `namingStrategy`（`defensive` / `idiomatic`）、`accessModifier`（`public` / `package` / `internal`）、`unsupportedHandlerStub`（`fatalError` / `throw`）の 3 つです。** 前者 2 つは `KawarimiHandler` の `Operations.*` 参照と、`on…` / メソッドの可視性を swift-openapi-generator と揃えます。ファイルが無い、またはキー省略時は命名 **`defensive`**、アクセス **`public`**、**`unsupportedHandlerStub: throw`**（fail-fast）です。**`throw`:** スタブを出せない operation があると**生成失敗**。**`fatalError`:** **生成は成功**し、該当 operation のクロージャは **`fatalError(...)`** になり、CLI はその分 **stderr に警告**を出します（Xcode ではビルドログの Kawarimi ステップを確認）。その他のキーは主に公式ジェネレータ専用です。

**要件（別ターゲットから import する場合）:** **`accessModifier: package`** または **`public`** を使うこと。**`internal`** は、生成 API をそのターゲット内だけで完結させる場合に限り有効です。

`Kawarimi` CLI / `KawarimiPlugin` は `openapi.yaml` と同じ場所の `openapi-generator-config.yaml` を優先し、無ければ `openapi-generator-config.yml` を探します。

### 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## ダイナミックモック（KawarimiHenge）

**ビルド時:** **Kawarimi** プラグインが `KawarimiSpec.swift` を生成し、エンドポイントとレスポンスボディを Swift の定数として埋め込みます。

**実行時**にオーバーライドを切り替えて再コンパイルなしでモックを変える流れは、**KawarimiHenge** の機能です。

アプリターゲットに **KawarimiHenge** を追加すると、SwiftUI（`KawarimiConfigView`、`OverrideEditorView`）と `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使えます。

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

プロセス内の example モックと実サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし、OpenAPI の `example` 由来の応答。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` で `DemoServer` に繋ぐクライアント（ターゲットにその製品を追加）。

Example では **`DemoAPITests`** が `Kawarimi` 側を検証します。

**`DemoApp`**（SwiftUI）の Henge タブは **KawarimiHenge**、OpenAPI タブは起動中サーバーへの HTTP 用です。

**1つの**クライアントで実／モックを実行時に切り替えたい、常に `x-kawarimi-mockId` を付けたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

### config.json / KAWARIMI_CONFIG

`KawarimiConfigStore`（**KawarimiCore**）はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `config.json`）。

ファイル形式は `KawarimiConfig`（overrides 配列）です。

**DemoServer は Example ディレクトリをカレントにして起動してください**（`config.json` の読み書き先を揃える。例: `cd Example && swift run DemoServer`）。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッド・`x-kawarimi-mockId` の条件が一致）、インターセプタは **`MockOverride.sortedForInterceptorTieBreak`** で並べ替えた **先頭**を採用します。比較順は `path` → **`mockId` が非 nil を nil より先** → `mockId` 文字列 → `statusCode` → `name` → `exampleId` です。キーが同順位のときは Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

**DemoServer** は `KawarimiSpec.meta.apiPathPrefix`（OpenAPI `servers[0].url` のパス由来）を `pathPrefix` に渡すため、Spec とマウントが一致し、別の環境変数は不要です。

独自サーバーでは `registerHandlers` や OpenAPI `servers` と同じプレフィックスを `KawarimiConfigStore` に渡してください。

```bash
cd Example && swift run DemoServer   # config.json は Example/ に作成
KAWARIMI_CONFIG=/tmp/mock-config.json swift run DemoServer
```

### DemoApp（SwiftUI・macOS）

`swift run DemoApp` でウィンドウが開きます。**KawarimiHenge** で実行中サーバーのエンドポイント一覧とピッカーによるモック切り替えができます（ターミナル不要）。

**Server URL** と **API prefix** は `KawarimiSpec.meta` を初期値とし、**UserDefaults** に保存されます。

手元で DemoServer を動かすときはホストを `http://localhost:8080` などに合わせてください。

## Example

**`Example/` Swift パッケージ**は **macOS 専用のサンプル**です。本番向けの安全対策は含みません。

**`__kawarimi`** 管理 API に**認証はありません**。

**`DemoApp`** は入力した**任意の URL** へ HTTP を送れます。信頼できる環境でのみ使い、実運用では認証・ネットワーク制御を自前で追加してください。

```bash
cd Example && swift build
swift run DemoServer   # 別ターミナルで
swift run DemoApp      # SwiftUI: OpenAPI + Henge（任意）
```

## プラグインと実行順

Types/Client/Server と Kawarimi（モック・ハンドラ）の生成順を保証する方法:

### 案1: 1 プラグイン内で buildCommand を2つ

- **コマンド1**: openapi.yaml から Types / Client / Server を生成（現行 swift-openapi-generator と同様）。
- **コマンド2**: 同じ openapi.yaml から Kawarimi.swift / KawarimiHandler / KawarimiSpec を生成。
- コマンド2 の `inputFiles` にコマンド1の `outputFiles`（少なくとも KawarimiHandler が依存する Types.swift と Server.swift）を含める。

  SwiftPM のビルドグラフでコマンド2が後に実行される。

- **利点**: 1 プラグイン内の入出力で順序が固定される。公式ジェネレータに依存しなくなったらコマンド1だけ差し替えればよい。

### 案2: プラグイン適用順を文書化

- 公式 **swift-openapi-generator** と **KawarimiPlugin** を同一ターゲットに追加する（前者が Types/Client/Server、後者がモック系）。
- SwiftPM はプラグイン間の実行順を保証しないため、README や例で「公式 → Kawarimi」の順を推奨と書く。
- **注意**: ビルドシステムが順序を保証しない。両方とも基本は openapi.yaml を入力にする（Kawarimi が生成済み Swift を入力に変える場合は別）。

---

## 要件・詳細

- Swift 6.2+ / macOS 14+。
- **KawarimiHandler スタブ（既定 `unsupportedHandlerStub: throw`）:** 各 operation は **HTTP 200 または 201** で **`application/json`** かつ Kawarimi が単純な `.init(...)` に落とせる JSON schema を持つか、**200/201 で `content` を書かない**（ボディなし成功 — swift-openapi-generator と同様に `.ok(.init())` / `.created(.init())` を出す）、**または 204 のみ**（`.noContent`）である必要があります。`application/json` と書いてあるのに schema を解決できない、**JSON 以外の content のみ**、**レスポンスヘッダーだけ**でボディが無い、schema が **列挙（`allowedValues`）** や **allOf/oneOf/anyOf/not** などの場合は、コンパイル不能なコードを出さず**生成をエラーで中止**します。エラー文には **`[METHOD /path]`** と schema 位置のヒントが含まれることがあります。**`unsupportedHandlerStub: fatalError`** のときはビルドは通りますが、該当 operation を呼ぶと**実行時に trap** します。スキーマ分割・**`on…` での手実装**・自前 `APIProtocol` などで対処してください。
- **Kawarimi** モック（`Kawarimi.swift`）は従来どおり 200 + JSON + `components/schemas` の `$ref` を想定した動きです。
- 詳しくはリポジトリを参照。

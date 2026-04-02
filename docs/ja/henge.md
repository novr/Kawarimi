# ダイナミックモック（KawarimiHenge）

**ビルド時:** **Kawarimi** プラグインが `KawarimiSpec.swift` を生成し、エンドポイントとレスポンスボディを Swift の定数として埋め込みます。

**実行時**にオーバーライドを切り替えて再コンパイルなしでモックを変える流れは、**KawarimiHenge** の機能です。

アプリターゲットに **KawarimiCore** を追加すると `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使え、**KawarimiHenge** を追加すると SwiftUI（`KawarimiConfigView`）が使えます。

サーバー側は **KawarimiCore**（`KawarimiConfigStore`、`PathTemplate`、`MockOverride` など）と、**Henge API** ルートを組み合わせます。**オーバーライドを適用する Vapor の `AsyncMiddleware` は KawarimiCore の製品ではありません**—参照実装として [`KawarimiInterceptorMiddleware.swift`](../../Example/DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift) をコピー／改変するか、[Example README_JA.md](../../Example/README_JA.md) の構成に沿ってください。

## Vapor 向けに使う外部パッケージ（サーバ）

Kawarimi 単体に Vapor 用プロダクトはありません。生成した API ターゲットに、定番の OpenAPI + Vapor の組み合わせを載せます。

| 役割 | リンク / メモ |
| --- | --- |
| Web フレームワーク | [github.com/vapor/vapor](https://github.com/vapor/vapor) |
| 生成 Server と Vapor の橋渡し | [github.com/vapor/swift-openapi-vapor](https://github.com/vapor/swift-openapi-vapor)（`OpenAPIVapor`） |
| 生成コードのランタイム | [github.com/apple/swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) |
| OpenAPI からのコード生成 | [github.com/apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) |
| Henge の設定ストア・マッチング | **KawarimiCore**（本パッケージ） |

本リポジトリの **`DemoPackage` の構成** と **`DemoServer` のエントリポイント**: [Example/README_JA.md](../../Example/README_JA.md)。

## 生成ファイル: `KawarimiSpec.swift`

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

OpenAPI の **`content.examples` のキー**は、`endpoints` の `exampleId` と内側の `responseMap` のキーになります。

無名の単一例（またはスキーマからのフォールバック）は、予約キー **`__default`** に載ります。

実行時、`MockOverride.exampleId` が `nil`・JSON の `null`・空文字のとき、ルックアップは **`__default`** です。

「デフォルト例」を表すために JSON に文字列 `__default` を書く必要はありません。キー省略または `null` でよい。

`KawarimiConfigStore.configure` は、**`path`・HTTP メソッド・`statusCode`・正規化後の `exampleId`** が一致するエントリだけを同一キーとして上書きします。

同じパスに複数の名前付き例を同時に有効にする場合は、`exampleId` で区別します。

モック JSON 文字列の決め方は [mock-json.md](mock-json.md) を参照してください。

## Henge API（`{pathPrefix}/__kawarimi/*`）

**Henge API** は、**KawarimiCore** の `KawarimiAPIClient` が呼び出す HTTP 面です（「Henge」は機能名）。

OpenAPI API と**同じパスプレフィックス体系**の下にマウントするのが一般的です（例: API が `/api` なら **`/api/__kawarimi/spec`**）。独自構成ではルート直下に置いても構いません。`KawarimiAPIClient` の `baseURL` と揃えてください。

Vapor で admin ルートとミドルウェアを登録する例:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
registerKawarimiRoutes(app: app, store: store)
app.middleware.use(KawarimiInterceptorMiddleware(store: store))
```

`KawarimiInterceptorMiddleware` はライブラリではなく **Example** のターゲット内のコードです。

Vapor の `AsyncMiddleware` として次のように動きます。

- `__kawarimi` 管理パスは素通しする。
- 有効なオーバーライド（パステンプレート・メソッド）にマッチしたら、オーバーライド本文、または **`statusCode` と実効の例キー**（未設定の `exampleId` は `__default`）で `KawarimiSpec.responseMap` を参照してボディを組み立てる。
- 即 `Response` を返し、無ければ `next` に委譲する。

**自前のミドルウェアを書くときの手本**にしてください。

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | path/method/statusCode（および名前付き例なら `exampleId`）でモックレスポンスを有効化 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

本リポジトリの **DemoServer** 向けの **`curl` 例**: [Example/README_JA.md#henge-api-demoserver](../../Example/README_JA.md#henge-api-demoserver)。

## クライアント: 実サーバーと Kawarimi モック

プロセス内のモックと実 HTTP サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし。応答本文は [mock-json.md](mock-json.md) のルール（operation ごとの 200 + `application/json`）に従います。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` でサーバーに繋ぐクライアント（ターゲットにその製品を追加）。

参照の **DemoServer** と **DemoApp** は **`Example/`** にあります: [Example/README_JA.md](../../Example/README_JA.md)。

**1つの**クライアントで実／モックを実行時に切り替えたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

<a id="kawarimijson--kawarimi_config"></a>

## `kawarimi.json` / `KAWARIMI_CONFIG`

`KawarimiConfigStore`（**KawarimiCore**）はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `kawarimi.json`）。

ファイル形式は `KawarimiConfig`（overrides 配列）です。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

`kawarimi.json` はランタイムの `overrides` のみを持ちます（生成の `handlerStubPolicy` は `kawarimi-generator-config.yaml`）。

**初期 `kawarimi.json`・サンプル `kawarimi-generator-config.yaml`・`swift run DemoServer` のカレントディレクトリ**については [Example/README_JA.md](../../Example/README_JA.md) を参照してください。

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッドが一致）、インターセプタは **`MockOverride.sortedForInterceptorTieBreak`** で並べ替えた **先頭**を採用します。

比較順は `path` → `statusCode` → `name` → `exampleId` です。

キーが同順位のときは、Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

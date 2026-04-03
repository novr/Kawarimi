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

### 予約語: `__default`

文字列 **`__default` は Kawarimi が予約**しています。

- **合成のデフォルト行**用の `responseMap` 内側キー（名前付き OpenAPI `examples` が無い場合や、フォールバックで 1 行だけ出す場合など）。
- **`MockOverride.exampleId` が省略・JSON `null`・空**のときのルックアップ先（空白のみは正規化で空扱い）。

**OpenAPI の `content.examples` のキーとして `__default` は使わないでください。** 別名（例: `default` や `success`）にし、この予約スロットと衝突しないようにします。オーバーライドで `exampleId` にリテラル `"__default"` を入れてそのマップ行を明示的に指すことは可能ですが、デフォルト例では通常は **`exampleId` を省略**します。

`KawarimiConfigStore.configure` は、**`path`・HTTP メソッド・`statusCode`・正規化後の `exampleId`** が一致するエントリだけを同一キーとして上書きします。

`configure` は **1 行の upsert** です。`isEnabled: false` にするとモックをオフにしつつ、その行は **`kawarimi.json` に残ります**。**`KawarimiConfigStore.removeOverride`** は **`configure` と同じ正規化後の同一視**で最初の 1 行を配列から削除します。一致する行が無いときの `removeOverride` は **何もしない**（べき等）です。

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

### 任意のリクエストヘッダー: `X-Kawarimi-Example-Id`

**リクエストごと**にどの有効オーバーライドを優先するか切り替える場合（`configure` の JSON 本体とは別）、参照ミドルウェアは **`X-Kawarimi-Example-Id`** を読みます。定数名は **KawarimiCore** の **`KawarimiMockRequestHeaders.exampleId`** です。

**同じパス・メソッドに複数の有効オーバーライド**があるとき、空でないヘッダー値で候補を絞り込みます（比較は ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` と同じ。例: `success` は `exampleId` が `"success"` のオーバーライドに一致。デフォルト例行は値 **`__default`**）。絞り込み結果が **0 件**のときはヘッダーを無視し、従来どおり全候補からタイブレークします。

ヘッダーを付けない、または空白のみのときは絞り込みしません。

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | path/method/statusCode（および名前付き例なら `exampleId`）で 1 行を upsert。`isEnabled`・`body`・`contentType` などを指定 |
| `POST {pathPrefix}/__kawarimi/remove` | `configure` と同じ同一視（正規化後の path・メソッド・`statusCode`・`exampleId`）で 1 行を削除。べき等 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

**KawarimiHenge（`KawarimiConfigView`）:** マイナス（**Del**）は、モックがオンのとき **`isEnabled: false` を保存**します。すでにオフで、かつそのチップ用の**保存済み行**があるときは **`remove`** を呼び、サーバー設定から行を消してエディタを Spec のドラフトに戻します。組み込み時は **`removeOverride`** を `KawarimiConfigView` に渡してください（**KawarimiCore** の **`KawarimiAPIClient.removeOverride(override:)`** を参照）。

本リポジトリの **DemoServer** 向けの **`curl` 例**: [Example/README_JA.md#henge-api-demoserver](../../Example/README_JA.md#henge-api-demoserver)。

## オーバーライドエディタ（`OverrideEditorView`）

モック用 SwiftUI は **KawarimiHenge** の **`OverrideEditorView`**（エンドポイント一覧＋詳細ペイン）です。**編集ルール**（レスポンスチップ、Save 時の `configure` ペイロード、Del の分岐、エンドポイント検索）は **`Sources/KawarimiHenge/EditorSupport/`** にあります（例: `OverrideResponseChipLogic`、`OverrideSavePayloadBuilder`、`OverrideDisableMockRowPlanner`、`OverrideEndpointFilter`）。**どの行を選んでいるか**や `validationMessage` / `isDirty` など UI メタは **`OverrideEditorStore`** / **`OverrideDetailDraft`** が持ちます。

| UI / ドキュメント上の言い方 | コード側 | メモ |
| --- | --- | --- |
| リストの 1 行 | `EndpointRowKey` + `SpecEndpointItem` | 選択は `EndpointRowKey`。 |
| 詳細の編集対象 | `OverrideDetailDraft` 内の `MockOverride` 1 件 | 選択中の論理行のスナップショット。`kawarimi.json` 全体ではない。 |
| サーバー / 設定の 1 行 | `kawarimi.json` の `MockOverride` | `configure` / `remove` と同じ同一視: **`path` + `method` + `statusCode` + 正規化後 `exampleId`**。「`operationId` だけで削除」と書かない。 |
| デフォルト / 無名の例 | `exampleId` が nil（空白正規化後も） | ルックアップでは予約 **`__default`** と対応。UI チップは「例 ID なし」として扱う。 |

**Spec** チップが選ばれるのは、ドラフトのモックが **オフ**で、かつ現在の `statusCode` / `exampleId` に一致する**保存済み行がない**ときです（オフだが保存行がある場合はそのチップ側に留まります）。

**Save** は **`OverrideSavePayloadBuilder`** が組み立てた内容で `configure` を呼びます。モックトグルがオン、またはその status/example に保存行がある、または OpenAPI のレスポンス一覧に無い組み合わせ（カスタム行）のいずれかなら送信ペイロードは有効扱いになります。Spec 上の行だけを「オフ」のまま送る場合は、**`statusCode`** は操作の先頭の Spec 行、**`exampleId`** はクリア、本文系もワイヤ上はクリアされます。

**Del** は **`OverrideDisableMockRowPlanner`** が分岐します。アクティブなモック → 同一キーで `isEnabled: false` の `configure`。すでにオフで保存行が一致 → **`remove`** の後、ドラフトを Spec 側へ寄せるリセット。それ以外 → 何もしません。

**自動テスト:** **`KawarimiHengeTests`**（`Tests/KawarimiHengeTests/`）でフィルタ、チップ遷移、Save ペイロード、Del 計画を検証しています。

## クライアント: 実サーバーと Kawarimi モック

プロセス内のモックと実 HTTP サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし。応答本文は [mock-json.md](mock-json.md) のルール（operation ごとの 200 + `application/json`）に従います。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` でサーバーに繋ぐクライアント（ターゲットにその製品を追加）。

`KawarimiSpec`（および Henge / `responseMap`）は、インプロセスの `Kawarimi` トランスポートと **同じ生成パスでは埋まりません**。詳しくは [mock-json.md](mock-json.md) の **「`KawarimiSpec` とインプロセス `Kawarimi` トランスポート」**を参照してください。

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

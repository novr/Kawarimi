# ダイナミックモック（KawarimiHenge）

**ビルド時:** **Kawarimi** プラグインが `KawarimiSpec.swift` を生成し、エンドポイントとレスポンスボディを Swift の定数として埋め込みます。

**実行時**にオーバーライドを切り替えて再コンパイルなしでモックを変える流れは、**KawarimiHenge** の機能です。

アプリターゲットに **KawarimiCore** を追加すると `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使え、**KawarimiHenge** を追加すると SwiftUI（`KawarimiConfigView`）が使えます。

サーバー側は **KawarimiCore**（`KawarimiConfigStore`、`MockOverride` など）、**KawarimiServer**（`KawarimiServerMiddleware`）、**Henge API** ルートを組み合わせます。

OpenAPI に登録した operation へは **`KawarimiServerMiddleware`**（`registerHandlers(middlewares:)`）で動的モックを適用します。handler に載せないパスへ override したい場合だけ、Vapor グローバル `AsyncMiddleware` を任意で足してください（下記）。

## Vapor 向けに使う外部パッケージ（サーバ）

Kawarimi 単体に Vapor 用プロダクトはありません。生成した API ターゲットに、定番の OpenAPI + Vapor の組み合わせを載せます。

| 役割 | リンク / メモ |
| --- | --- |
| Web フレームワーク | [github.com/vapor/vapor](https://github.com/vapor/vapor) |
| 生成 Server と Vapor の橋渡し | [github.com/vapor/swift-openapi-vapor](https://github.com/vapor/swift-openapi-vapor)（`OpenAPIVapor`） |
| 生成コードのランタイム | [github.com/apple/swift-openapi-runtime](https://github.com/apple/swift-openapi-runtime) |
| OpenAPI からのコード生成 | [github.com/apple/swift-openapi-generator](https://github.com/apple/swift-openapi-generator) |
| Henge の設定ストア・マッチング | **KawarimiCore**（本パッケージ） |
| サーバ operation への動的モック | **KawarimiServer**（`KawarimiServerMiddleware`） |
| Henge 管理 HTTP（`__kawarimi/*`） | **KawarimiServer**（`KawarimiAdminHTTPHandler`。admin は OpenAPI 登録外） |
| OpenAPI クライアントのシナリオオーケストレーション | **KawarimiClient**（`KawarimiClientOrchestrationMiddleware`） |

本リポジトリの **`DemoPackage` の構成** と **`DemoServer` のエントリポイント**: [Example/README_JA.md](../../Example/README_JA.md)。

<a id="hengecli-macos"></a>

## HengeCli（macOS 用サンプル実行ファイル）

**`Example/DemoPackage`** に実行ファイルプロダクト **`HengeCli`** があります。

**macOS 専用**の SwiftUI アプリで、**`KawarimiConfigView(client: KawarimiAPIClient(baseURL: …))`** を起動します。管理用 **`baseURL`** の既定値は `http://127.0.0.1:8080/api`（Demo **`openapi.yaml`** の `servers`）で、**`KAWARIMI_BASE_URL`** で上書きできます — **`DemoSupport`** / `KawarimiDemoClientURL.swift`（**DemoApp** と共有）。

- **起動:** `Example/DemoPackage` で `swift run HengeCli`（または `swift build --product HengeCli`）。  
  先に **`DemoServer`** を立てるか、その base URL 配下で **`…/__kawarimi/*`** が応答するサーバーを用意してください。

- **ウィンドウ:** **最後のウィンドウを閉じるとプロセス終了**（`applicationShouldTerminateAfterLastWindowClosed`）。

  起動時は **`NSApp.activate(ignoringOtherApps: true)`** と **`makeKeyAndOrderFront`** で前面・キーウィンドウにし、ターミナル起動などでもテキスト入力が通りやすくしています。

- **URL が不正:** **`KAWARIMI_BASE_URL`**（または既定値）が有効な URL でない場合は **`ContentUnavailableView`** で env var または既定 URL の設定を促します。

iOS など他プラットフォーム向けビルドでは **スタブの `main`** がメッセージを出して終了します。

SwiftUI ホストは **`DemoApp`** や自前ターゲットを使ってください。

詳細列レイアウト回帰（DemoApp Preview + 手動確認）: [henge-detail-column-regression.md](../henge-detail-column-regression.md)。

## 生成ファイル: `KawarimiSpec.swift`

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta             // title, version, serverURL
KawarimiSpec.securitySchemes  // components.securitySchemes のカタログ（空なら nil）
KawarimiSpec.endpoints        // 各 operation（effective security を含む場合あり）
KawarimiSpec.responseMap      // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

各 **`Endpoint.security`** はその operation の **effective** OpenAPI security です（operation で省略時はグローバル `security` を継承、`security: []` は認証なし）。`security` 配列の要素間は **OR**、各 `SecurityRequirement.schemes` 内は **AND** です。apiKey は `apiKeyName` / `apiKeyIn`、`http` は `httpScheme` / `bearerFormat`、openIdConnect は `openIdConnectURL`。OAuth2 の flow URL や scopes は載せません。`ScopedSecurityScheme.name` は components のキーです。

生成される型 **`SpecResponse`** は **`KawarimiFetchedSpec`** に準拠し、Henge の wire JSON（`GET …/__kawarimi/spec`）用に **`securitySchemes`** も載せます。生成 API モジュールをリンクするホストコードは **`KawarimiAPIClient.fetchSpec(as: SpecResponse.self)`** で同じ wire JSON をデコードできます。

**Henge UI** は **`KawarimiConfigView(client:)`** のみ: spec / endpoints は Core の **`HengeSpecSnapshot`** / **`fetchHengeSpec()`** 経由で **`GET …/__kawarimi/spec`** から取得し、Henge 専用ターゲットに生成 **`SpecResponse`** は不要です。

OpenAPI の **`content.examples` のキー**は、`endpoints` の `exampleId` と内側の `responseMap` のキーになります。

無名の単一例（またはスキーマからのフォールバック）は、予約キー **`__default`** に載ります。

実行時、`MockOverride.exampleId` が `nil`・JSON の `null`・空文字のとき、ルックアップは **`__default`** です。

「デフォルト例」を表すために JSON に文字列 `__default` を書く必要はありません。キー省略または `null` でよい。

### 予約語: `__default`

文字列 **`__default` は Kawarimi が予約**しています。

- **合成のデフォルト行**用の `responseMap` 内側キー（名前付き OpenAPI `examples` が無い場合や、フォールバックで 1 行だけ出す場合など）。
- **`MockOverride.exampleId` が省略・JSON `null`・空**のときのルックアップ先（空白のみは正規化で空扱い）。

**OpenAPI の `content.examples` のキーとして `__default` は使わないでください。** 別名（例: `default` や `success`）にし、この予約スロットと衝突しないようにします。

オーバーライドで `exampleId` にリテラル `"__default"` を入れてそのマップ行を明示的に指すことは可能ですが、デフォルト例では通常は **`exampleId` を省略**します。

`KawarimiConfigStore.configure` は次の順で同一行を判定します。

1. **`rowId` 一致を最優先**（UUID 文字列。正規化後は大文字小文字を吸収）。
2. **legacy fallback** は **入力行の `rowId` が nil** の場合のみ: `path` + HTTP メソッド + `statusCode` + 正規化後 `exampleId`。
3. legacy で複数行が残る場合は、**配列先頭 1 行**を採用（安定・決定的）。

`configure` は **1 行の upsert** です。`isEnabled: false` にするとモックをオフにしつつ、その行は **`kawarimi.json` に残ります**。

**`KawarimiConfigStore.removeOverride`** も `configure` と同じ順序（`rowId` 優先、入力行 `rowId=nil` 時のみ legacy）で最初の 1 行を削除します。一致する行が無いときは **何もしない**（べき等）です。

同じパスに複数の名前付き例を同時に有効にする場合は、`exampleId` で区別します。

モック JSON 文字列の決め方は [mock-json.md](mock-json.md) を参照してください。

## Henge API（`{pathPrefix}/__kawarimi/*`）

**Henge API** は、**KawarimiCore** の `KawarimiAPIClient` が呼び出す HTTP 面です（「Henge」は機能名）。

OpenAPI API と**同じパスプレフィックス体系**の下にマウントするのが一般的です（例: API が `/api` なら **`/api/__kawarimi/spec`**）。

独自構成ではルート直下に置いても構いません。`KawarimiAPIClient` の `baseURL` と揃えてください。

### Core 管理ルート契約

**KawarimiCore** が共通 HTTP 契約を公開し、クライアントとサーバーでパス文字列の重複を避けます。

- **`KawarimiAdminRoute`** — `spec` / `status` / `configure` / `remove` / `reset` / `reload`。各 case に **`httpMethod`**・**`relativePath`**・**`successStatusCode`**（いずれも `200`）。
- **`KawarimiAdminRoute.adminURL(baseURL:route:)`** — `{baseURL}/__kawarimi/{segment}` を組み立て（**`KawarimiAPIClient`** と同じ規則）。
- **`KawarimiAdminRoute.matching(requestPath:method:pathPrefix:)`** — サーバ側も **`adminURL`** / **`KawarimiAPIClient`** と同じパス規則。
- **`KawarimiAdminSpecWire.validate(_:)`** — encode した spec wire JSON が **`HengeSpecSnapshot`** として decode できるか起動時に fail-fast 検証（`GET …/spec` 契約）。ホストの **`SpecResponse`**（相当型）を **`JSONEncoder`** した直後に呼ぶ。**`KawarimiAdminHeaders.jsonContentType`** は JSON **`Content-Type`** 文字列。

**`KawarimiAdminHTTPHandler`**（製品 **KawarimiServer**）を HTTP スタックに載せ、生成 handler 登録時に **`KawarimiServerMiddleware`** を渡す。Vapor の例は **DemoServer**（[`KawarimiAdminVaporMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiAdminVaporMiddleware.swift)）:

```swift
let store = try KawarimiConfigStore(configPath: ProcessInfo.processInfo.environment["KAWARIMI_CONFIG"] ?? "kawarimi.json")
let adminHandler = KawarimiAdminHTTPHandler(
    store: store,
    specWireData: { try SpecResponse.encodedWireData() } // ホスト相当
)
app.middleware.use(KawarimiAdminVaporMiddleware(handler: adminHandler))
let transport = VaporTransport(routesBuilder: app)
try handler.registerHandlers(
    on: transport,
    serverURL: serverURL,
    middlewares: [KawarimiServerMiddleware(store: store, responseMap: KawarimiSpec.responseMap)]
)
```

**`KawarimiAdminHTTPHandler`** は admin 以外を `nil` にして通常 API のルーティングを妨げない。**`ServerMiddleware` ではない** — `__kawarimi` は OpenAPI operation として登録されない。

**`KawarimiServerMiddleware`**（製品 **KawarimiServer**）は swift-openapi-runtime の **`ServerMiddleware`** です。

- 有効なオーバーライド（パステンプレート、または `MockOverride.name` と `operationId`、HTTP メソッド）にマッチしたら、オーバーライド本文、または **`statusCode` と実効の例キー**（未設定の `exampleId` は `__default`）で `KawarimiSpec.responseMap` を参照してボディを組み立てる。
- モックが当たったら **`next` を呼ばず** 合成レスポンスを返す。
- **`KAWARIMI_UPSTREAM_URL`** 設定時にオーバーライド未マッチなら、生 HTTP で upstream に転送する（**`next` を呼ばない**）。詳細は [Proxy（dev sidecar）](#proxy-upstream-forward) を参照。
- 上記以外は生成 handler に委譲（**`next`** → OpenAPI スタブ）。

**プロセス内の `Kawarimi`（`ClientTransport`）は `kawarimi.json` を読まず、実行時オーバーライドも適用しません** — 上記サーバ経路（または自前統合）のみです。

<a id="proxy-upstream-forward"></a>

## Proxy（dev sidecar）

**Proxy** は **ローカル開発向け sidecar** です。本番 API ゲートウェイや透過リバースプロキシではありません。典型構成は **DemoServer** + Henge admin + `KawarimiServerMiddleware` + `kawarimi.json`。アプリは sidecar に向け、未 override の operation だけ dev/staging API へ forward し、変更中の operation だけ差し替えます。

挙動は有効オーバーライドと upstream 設定による**スペクトラム**であり、「直結 / Proxy / フルモック」という別モードではありません。

| 状況 | 運用 | 結果 |
| --- | --- | --- |
| **直結** | Proxy を起動せず、アプリを実 API へ | Kawarimi ランタイムは経路に入らない |
| **Proxy + upstream、override 0** | Proxy 起動 + `KAWARIMI_UPSTREAM_URL` | 登録 operation は upstream へ forward |
| **一部 override** | 一部 operation のみ有効化 | マッチ → モック、他 → upstream |
| **フルモック相当** | 対象 operation をすべて override | それらは upstream に届かない |

**向いている用途:** 実バックエンドを叩きつつ一部だけ mock；Bearer 想定の JSON API；OpenAPI 登録 operation。

**向いていない用途:** Cookie セッション中継；上限超の大きな payload；生成 operation 外の path；本番 ingress。

**`KAWARIMI_UPSTREAM_URL` 未設定**時は従来どおり：オーバーライド未マッチ → **`next`** → 生成 OpenAPI スタブ。新規レスポンスヘッダーは付かず、既存 E2E 挙動は変わりません。

### 転送の実装

upstream への forward は **`KawarimiServerMiddleware`** が **`KawarimiUpstreamHTTPForwarder`** で行う（生 HTTP。生成 `KawarimiHandler` / Client 委譲ではない）。**`__kawarimi/*`** は **`KawarimiAdminHTTPHandler`** のみで、upstream へ転送しません。

転送時は hop-by-hop ヘッダー（`Host`、`Connection` 等）と Kawarimi 制御ヘッダー（`X-Kawarimi-*`、`X-Next-Kawarimi-*`）を除外し、それ以外のリクエストヘッダーは透過。body 付き転送時は `Content-Length` を省略し、送信側クライアントが再設定する。Cookie セッション認証の Proxy 経由は **v1 対象外**（Bearer 想定）。

`URLSession` はデフォルトでリダイレクトを**追従**する。リクエスト body は temp file → `httpBodyStream` で upstream へストリーム転送（上限 **10 MiB**）。Apple ではレスポンスを `URLSession.bytes(for:)` の `AsyncBytes` を 16 KiB チャンクで `HTTPBody` に流す。Linux では同一上限で `data(for:)` バッファ転送（CI / ヘッドレス検証）。`Content-Length` / `expectedContentLength` が上限超のときは body 読取前に `502`；chunked は読取中に同上限（Apple のみ）。

カスタム `URLSession` 注入は不可（delegate は session 生成時に固定され、差し替えるとストリーム転送が黙って壊れる）。

転送 path は **`KawarimiPath.aligned`** と `apiPathPrefix`（不足時のみ再付与。**strip 禁止**）。

| URL | 形式 |
| --- | --- |
| `KAWARIMI_BASE_URL` | `{proxy-origin}{apiPathPrefix}` — Henge / アプリ → Proxy |
| `KAWARIMI_UPSTREAM_URL` | **origin のみ** — 例 `https://staging.example.com`（`/api` は載せない。forward 時に aligned で付与） |

### 環境変数（Proxy）

| 変数 | 必須 | 用途 |
| --- | --- | --- |
| `KAWARIMI_UPSTREAM_URL` | 任意 | 設定時のみ override 未マッチを upstream へ forward。origin のみ。 |
| `KAWARIMI_BASE_URL` | 任意 | Henge / クライアントの Proxy 接続先（`apiPathPrefix` 込み）。 |
| `KAWARIMI_UPSTREAM_STRICT` | 任意 | `1` で upstream URL に path 成分があると起動失敗。 |
| `KAWARIMI_PROXY_DEBUG` | 任意 | upstream 設定時の `KawarimiProxy` OSLog を詳細化。 |

upstream 設定時のみ、レスポンスに **`X-Kawarimi-Proxy-Action: mock`** または **`forward`** が付くことがあります。未設定時は付きません。

**v1 スコープ外:** 本番透過プロキシ / API ゲートウェイとしての利用；Client middleware による切り替え；未登録 path の catch-all；path リマップ；Cookie リライト；admin 認証。

### オーバーライドマッチングの Product ルール

マッチングとプライマリ選択の**実装の単一ソース**は **KawarimiCore**（`MockOverrideRequestMatching`、`MockOverride.sortedForOverrideTieBreak`）です。Henge エクスプローラと `KawarimiServerMiddleware` は同じ API を使います。以下は利用者向けの契約です。

1. **Operation identity** — `MockOverride.name` と OpenAPI の `operationId` が両方非空で一致すれば、**path は比較せず**同一 operation とみなします（手編集の `path` の typo でも id でマッチ）。意図したルールであり、バグではありません。
2. **Path binding** — identity で決まらないとき:
   - **着信 HTTP（サーバ）:** リクエスト URL（path のみ）と persisted `path` を `PathTemplate` + `pathPrefix` で比較（`overrideMatchesIncomingRequest`）。
   - **エクスプローラ行（Henge）:** spec / 行のテンプレート path と persisted `path` を `KawarimiPath.aligned` で比較（`overrideMatchesOperation`）。
3. **Primary selection** — 同一 operation にマッチする **enabled** 行のうち、`sortedForOverrideTieBreak` の**先頭**がプライマリ（`path` → `statusCode` → `name` → `exampleId`、同順位は安定ソートで `hits` 順を維持）。**`X-Kawarimi-Example-Id`** は**着信**時のみ候補を絞ります（`matchingEnabledOverrides`）。エクスプローラはこのヘッダーを送りません。
4. **非目標** — プロセス内 `Kawarimi`（`ClientTransport`）は実行時オーバーライド非対応（#75）。

API 対応:

| 文脈 | マッチ | プライマリ / 一覧 |
| --- | --- | --- |
| サーバ（`KawarimiServerMiddleware`） | `matchingEnabledOverrides` / `primaryEnabledOverride` | 着信 path + 任意の example ヘッダー |
| Henge エクスプローラ | `matchingEnabledOverridesForOperation` / `primaryEnabledOverrideForOperation` | spec 行 path + `operationId` |

`sortedForInterceptorTieBreak` は `sortedForOverrideTieBreak` の別名です。

### 実行時更新

| 対象 | 挙動 |
| --- | --- |
| **オーバーライド（`kawarimi.json`）** | Henge / `KawarimiAPIClient` の `POST …/configure`、**`POST …/reload`**、または **`KawarimiConfigStore/startFileWatchIfEnabled()`** 有効時（**DemoServer** は既定で有効）のディスク保存で更新。**`KAWARIMI_CONFIG_WATCH=0`** で監視 OFF。reload / 監視は起動時と同じ読み込み規則（無効 JSON → 空）。ディスク読み込み時は `configure` の全正規化は行わないが、`rowId` は読み込み時に正規化（trim + UUID 検証 + lowercase）する。単一プロセス内では最後に完了した `configure` / `reload` / `reset` / ディスク reload が勝つ。 |
| **シナリオ（`kawarimi-scenarios.json`）** | ランタイムは読み取り専用（Henge 管理 API なし）。起動時・**`POST …/reload`**・ファイル監視有効時に overrides と同時に読み込み。パス: init `scenariosPath:` → **`KAWARIMI_SCENARIOS_CONFIG`** → `{kawarimi.json のディレクトリ}/kawarimi-scenarios.json`。無効 JSON → 空の scenarios。構造上の問題は **`KawarimiScenarioValidation`** が **warning** ログ。macOS では**既存ファイル**への atomic 上書きが vnode 監視で拾えないことがある — 反映されないときは **`POST …/reload`** を使う。 |
| **`KawarimiSpec` / `responseMap`** | OpenAPI からの**ビルド時生成**（`kawarimi.json` とは別）。**`KawarimiServerMiddleware` 初期化時に固定**。OpenAPI 再生成後は **ビルド + 再起動**（または middleware 再登録）。**`POST …/reload` は spec 本文を更新しない**。 |

### 任意: Vapor グローバル middleware

**`registerHandlers` に載せないパス**へも動的モックが必要なときは、**KawarimiCore** の **`MockOverrideRequestMatching`** / **`KawarimiDynamicMockResponseResolver`** を使った Vapor `AsyncMiddleware` を自前で足せます。

### 任意のリクエストヘッダー: `X-Kawarimi-Example-Id`

**リクエストごと**にどの有効オーバーライドを優先するか切り替える場合（`configure` の JSON 本体とは別）、**`KawarimiServerMiddleware`** は **`X-Kawarimi-Example-Id`** を読みます。

定数名は **KawarimiCore** の **`KawarimiMockRequestHeaders.exampleId`** です。

**同じパス・メソッドに複数の有効オーバーライド**があるとき、空でないヘッダー値で候補を絞り込みます（比較は ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` と同じ。例: `success` は `exampleId` が `"success"` のオーバーライドに一致。デフォルト例行は値 **`__default`**）。

絞り込み結果が **0 件**のときはヘッダーを無視し、従来どおり全候補からタイブレークします。

ヘッダーを付けない、または空白のみのときは絞り込みしません。

### シナリオオーケストレーション（`kawarimi-scenarios.json`）

**複数ステップのフロー**では、レスポンス本文は既存の **`MockOverride`** 行を再利用します。シナリオ定義は **`kawarimi-scenarios.json`**（`kawarimi.json` とは別ファイル）。パスは init **`scenariosPath:`** または **`KAWARIMI_SCENARIOS_CONFIG`** で上書き。

`POST …/__kawarimi/reload` とファイル監視の reload は **`kawarimi.json` と `kawarimi-scenarios.json` の両方**を再読み込みします。**DemoServer** のファイル監視は（パスが異なるとき）**両ファイル**を監視します。

**オーバーライドとシナリオ JSON の作成**（書式・`rowId` の結合 — ランタイムではない）: [skills/kawarimi-user-mock-and-scenario-format/SKILL.md](../../skills/kawarimi-user-mock-and-scenario-format/SKILL.md)。コミット前の **`KawarimiValidate`** も同 Skill を参照。

#### HTTP ヘッダー（`KawarimiScenarioHeaders`）

| ヘッダー | 方向 | 役割 |
| --- | --- | --- |
| `X-Kawarimi-Scenario-Id` | リクエスト | シナリオ選択 |
| `X-Kawarimi-Id` | リクエスト | 現在ステップ。初回は省略 |
| `X-Next-Kawarimi-Id` | レスポンス | クライアントが次に送るステップ。`next` 未設定時は省略 |

#### サーバ（`KawarimiServerMiddleware`）

**`X-Kawarimi-Scenario-Id`** があるとき、**`KawarimiScenarioResolver`** が `X-Kawarimi-Example-Id` / 通常の override マッチより**先**に実行されます。

- **マッチ** — `rowId` の override を返し、case に `next` があれば **`X-Next-Kawarimi-Id`** を付与。
- **非マッチ**（未知シナリオ、同一 `scenarioId`+`endpoint`+`kawarimiId` の重複、override 欠落、endpoint 不整合、不正ヘッダー）— **既存の override 解決へフォールバック**（`503` は返さない）。

#### クライアント（`KawarimiClientOrchestrationMiddleware`）

**KawarimiClient** の OpenAPI **`ClientMiddleware`**（swift-openapi-runtime 依存）:

- **`scenarioIdProvider`** — アプリがリクエストごとにアクティブな scenario id を返す（任意）。
- リクエストの **`X-Kawarimi-Scenario-Id`** は provider より優先。
- scenario id があるときのみ、シナリオ別 state から **`X-Kawarimi-Id`** を注入（レスポンスの **`X-Next-Kawarimi-Id`** で更新）。
- 終端レスポンス（**`X-Next-Kawarimi-Id` なし**）で当該シナリオの state を破棄 — next ヘッダーのないエラー応答も同様（次リクエストはサーバー上で `initial` から）。
- **並行リクエスト**で同一 `scenarioId` を共有する場合、state は1つ。最後に返った **`X-Next-Kawarimi-Id`** が勝つ（並列 UI／テスト向けの文書化された挙動）。
- テストや手動リセット用に **`reset(scenarioId:)`** / **`resetAll()`**。

ディスク上の不正な scenario JSON は load/reload 時に **警告ログ**のみ。リクエストはフォールバックする。**`KawarimiValidate`** はこのソフトな挙動に頼らず CI で落とす — [validation.md](../../skills/kawarimi-user-mock-and-scenario-format/validation.md)。

コミット済みフィクスチャと curl 例: [Example/README_JA.md](../../Example/README_JA.md)。

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | 1 行 upsert。**`200`** + **`GET …/status` 同型**の JSON オーバーライド配列。 |
| `POST {pathPrefix}/__kawarimi/remove` | 1 行削除（`configure` と同じ同一視）。**`200`** + JSON オーバーライド配列。べき等 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除。**`200`** + JSON オーバーライド配列（通常 `[]`） |
| `POST {pathPrefix}/__kawarimi/reload` | **`kawarimi.json` を再読み込み**（ファイル監視の reload と同じ）。`**200**` と **`X-Kawarimi-Reload: applied`**（更新あり）または **`unchanged`**（既に一致）、および **`GET …/status` と同型**の JSON オーバーライド配列。spec / `responseMap` の更新用ではない。 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

### Admin エラー応答

HTTP 契約: [`KawarimiAdminHTTPHandler`](../Sources/KawarimiServer/KawarimiAdminHTTPHandler.swift)。Vapor 配線: [`KawarimiAdminVaporMiddleware.swift`](../Example/DemoPackage/Sources/DemoServer/KawarimiAdminVaporMiddleware.swift)。ホスト実装は異なってよい。クライアントは 2xx 以外を **`KawarimiAPIError`**。

| ルート | ステータス | レスポンス body |
|---|---|---|
| `POST …/configure` | `400` | プレーンテキスト（**`MockOverride`** JSON として不正な body） |
| `POST …/configure` | `413` | プレーンテキスト（override **`body`** が **`MockOverride.maxBodyLength`**（65536 バイト）超過） |
| `POST …/configure` | `500` | プレーンテキスト（**`KawarimiConfigStoreError`** や永続化失敗） |
| `POST …/remove` | `400` | プレーンテキスト（**`MockOverride`** JSON として不正な body） |
| `POST …/remove` | `500` | プレーンテキスト（ストア失敗） |

成功時の JSON 応答（**`GET …/status`**、**`GET …/spec`**、**`POST …/configure`**、**`POST …/remove`**、**`POST …/reset`**、**`POST …/reload`**）は **`Content-Type: application/json`**（**`KawarimiAdminHeaders.jsonContentType`**）。**`POST …/reload`** は **`X-Kawarimi-Reload`** も付与。

**`KawarimiAPIClient`**: **`configure`** / **`removeOverride`** / **`reset`** はレスポンス body から overrides をデコード。**`configureAndFetchOverrides`** 等はエイリアス（追加 **`GET …/status`** なし）。

**KawarimiHenge（`KawarimiConfigView`）:** 管理 API の **`baseURL`** に揃えた **`KawarimiAPIClient`** のみ渡します（例: `http://127.0.0.1:8080/api`）。Spec とエンドポイントは **`GET …/__kawarimi/spec`**（`HengeSpecSnapshot`）で取得します。

画面上のサーバー表記は、初回 fetch 後は **`meta.serverURL`**（取得前は **`client.baseURL`**）。

マイナス（**Del**）は、現在のチップに対応する**保存済み行**があるとき **`POST …/__kawarimi/remove`** で行を削除します（**`kawarimi.json` に保存された `path` / `exampleId`** を使う）。**保存行がなく未 Save のドラフトだけ**のときはサーバー呼び出しなしで Spec 寄せに**ローカルクリア**します。モックを止めつつ**行と JSON を残す**ときは **無効チップ + Save**（**Del ではない**）。

OpenAPI の**番号チップ**（例: **200 formal**、**200 success**）は spec から**常に表示**されます。**Del** が消すのは **`kawarimi.json` の保存行**だけで、OpenAPI チップ列自体は残ります。`exampleId` なしで保存されたが、名前付き例のテンプレ本文と一致する legacy 行も **Del** でマッチします。

本リポジトリの **DemoServer** 向けの **`curl` 例**: [Example/README_JA.md#henge-api-demoserver](../../Example/README_JA.md#henge-api-demoserver)。

## オーバーライドエディタ（`OverrideEditorView`）

モック用 SwiftUI は **KawarimiHenge** の **`OverrideEditorView`**（エンドポイント一覧＋詳細ペイン）です。

<a id="henge-explorer-state"></a>

### エクスプローラの状態モデル（3 つの役割）

1. **サーバー側スナップショット（ほぼ読み取り）** — **`KawarimiConfigView`** が **`meta`**・**`endpoints`**・**`overridesSnapshot`**（**`GET …/__kawarimi/status`** のデコード結果）を **`@State`** で持ち、**`OverrideEditorView`** に `let` で渡す。エクスプローラの行・例キャプション・**`primaryOverride(for:)`**・保存済み行に基づくチップは、このスナップショットを読む。

2. **エディタのドラフト（選択中）** — **`OverrideEditorStore`**（`@Observable`）が **`OverrideDetailDraft`**（**`mock`**・**`isDirty`**・**`pinnedNumberedResponseChip`** など）を保持。配列全体のコピーではなく、**開いている行の編集バッファ**。**退避** — 別エンドポイントへ移るとき **`isDirty`** なら **`pendingDraftsByRowKey`** に退避し、同じ行を再度選ぶと復元（**Spec 再取得**で退避は消える）。

3. **ミューテーションの橋渡し** — 子へ渡す **`configureOverride`** / **`removeOverride`** は **`(MockOverride) async throws -> [MockOverride]`**。親ラッパー（**`KawarimiConfigView`**）が **`disableConflictingStatusMocks`** のあと **`KawarimiAPIClient`** の **`configure`** / **`remove`** を呼び、**レスポンス body** から **`overridesSnapshot`** を更新する（追加 **`GET …/status`** なし）。**`OverrideEditorStore`** は成功経路で **`markSavedClean()`** の直後にその配列で **`resyncDetailAfterOverridesRefresh`** を呼び、ドラフトをサーバー一覧と揃える。

<a id="henge-dirty-vs-unsaved"></a>

#### `isDirty` と「未保存」／一覧のドット

| 信号 | 意味 | コード側 |
| --- | --- | --- |
| **`isDirty`** | 編集操作があったため、**自動の** **`resyncDetailAfterOverridesRefresh`** を止め、行を離れるときに**退避**するべき状態。 | 本文・モック編集、**Format**、**`applyMockEdit`** などで立つ。Save 成功経路・Spec 再同期・Reset などで下げる。 |
| **「未保存」／ドット** | 現在の **`overridesSnapshot`** に対して、**`resyncMockFromServer` が作る正規形**とドラフトの **永続化フィールド**が違う（JSON の空白差は同一視）。**`isDirty` とは独立**（整形だけしてサーバーと同じでも `isDirty` は true のまま、など）。 | **`OverrideDetailDraft.persistableMockDiffersFromServer`**、等価は **`OverrideListQueries.persistableMockConfigurationEqual`**。 |

<a id="henge-draft-bootstrap"></a>

#### ドラフトの起動（一覧から行を開くとき）

退避が無いとき、**`OverrideExplorerDraftBootstrap.makeFreshDetail`** が **`MockDraftDefaults.specPlaceholder`** を作り、**`OverrideListQueries.primaryEnabledOverride`** があれば **`statusCode`** / **`exampleId`** / **`isEnabled`** / **`name`** を上書きしてから **`resyncMockFromServer`** を実行します。無効の既定行が有効なプライマリより **JSON 上で前に出てくる**場合でも、プレースホルダ **(200, nil)** だけで **`storedOverride`** が誤った行に結びつくのを防ぎ、**一覧の P** と **Spec チップ**の表示を揃えます。

<a id="henge-ui-data-flow"></a>

#### ライフサイクル／一覧の更新

4. **Spec ＋ overrides の再読み込み** — **`loadSpecAndOverrides()`** が **`specLoadID`** を進めると、**`OverrideEditorView`** の **`.task(id: specLoadID)`** が **`resyncDetailAfterSpecReload`** を実行（退避ドラフト破棄・詳細をサーバー状態で置換）。

5. **一覧の同一性** — overrides のみ再取得のたびに **`overridesRevision`** を進め、**`List`** に **`.id`** として付与して split ビューでの表示ずれを防ぐ。

<a id="henge-editor-ux"></a>

### 利用の流れ（UX）

エンドポイントを選び、**レスポンスのチップ**で行を選び、必要なら JSON を編集して **Save**（通常は `configure`。**Spec 追従**のときは **`remove`** — 下記参照）。

| やりたいこと | 操作 |
| --- | --- |
| この操作は OpenAPI のみ（実効は **Spec**） | **Spec** をタップ（先頭の spec ステータス・名前付き例なし・本文欄クリア）。ドラフトが **Spec 形**で **Spec チップ**上なら、一致する保存済み既定行があれば **Save** で **`remove`**（`kawarimi.json` に ghost 行を残さない）。保存行がなければ HTTP なし。サーバーに **enabled 行が無い** とき実効は **Spec** で、**Spec** チップを強調表示します。 |
| まだ行を消さずに「テンプレだけ見る」状態に戻す | **Spec** タップで本文クリア、または **enabled なし**＋無効の既定行ならテンプレ JSON が入っていても **Spec** が光る。**200 OK** をタップすると番号チップのまま同じ本文を編集できる。 |
| ドキュメント上のあるレスポンスをモックする（サーバー上の **プライマリ**にする） | **ステータス／例**のチップを選び（ドラフト **`isEnabled: true`**）、本文を編集して **Save**。**`KawarimiConfigView`** は同じ OpenAPI 操作の**他の** enabled 行を先に **`isEnabled: false`** で `configure` してから現在の行を **有効**で保存します（通常は操作あたりアクティブは1行）。 |
| OpenAPI に無いステータス（や例）を足す | **+**（Add response）でステータスを選び、メイン画面で編集して **Save**（チップ／保存行のオンオフに従う）。 |
| 本文は残すが **アクティブにしない** | **オフ**の行のチップを選び（保存済み無効行を読み込むなど）、本文を編集して **Save** — **`isEnabled: false`** のまま **body** / **contentType** も送ります。 |
| モックを止めるが `kawarimi.json` の行は残す | **無効チップ + Save**（**`isEnabled: false`** で body 保持）。 |
| **今選んでいるチップ**に対応する保存行を消す | 保存行があるとき **Del**（**`remove`**。オン／オフ問わず 1 回）。 |
| この operation の **無効行**をまとめて消す | 詳細ヘッダーの **trash** アクションを押す（選択中 operation の無効行を一括 `remove`。enabled 行は残る）。 |
| **未 Save のドラフト**だけ捨てる | 保存行がなくエディタがサーバーとずれているとき **Del**（HTTP なし）。 |
| **既定行**（先頭の spec ステータス・無名例）をオフ＋本文クリアにし、エディタをそれに合わせる | 下部 **Reset** — **Spec** 上の **Save** と同じ Spec-only 経路: 一致する保存行があれば **`remove`**、なければ **`configure`**。同じ操作の**別チップ**の行は残るので、消すときはチップごとに **Del**。 |
| 全オーバーライドを消す | エクスプローラの **Reset all overrides**（確認あり）。 |
| ディスク編集後にサーバーが `kawarimi.json` を再読み込み | エクスプローラの **Reload kawarimi.json** — **`POST …/__kawarimi/reload`**（レスポンス body に overrides）。ボタン下に **applied** / **unchanged** を表示。spec は再取得しない。 |

**Save** は **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`** を組み立て、**`OverrideEditorStore`** が **`SavePayload.isSpecOnlyRemovePayload`** なら一致する保存済み既定行を **`remove`**（無効 placeholder の upsert はしない）。保存行がなければ HTTP なし。**Spec 形**でも **番号チップ**（**`pinnedNumberedResponseChip`** true）なら **`configure` で有効**を送りプライマリにします。それ以外は **`mock.isEnabled`** で **有効**／**無効**を **`configure`** し、**無効**でもトリム済みの **body** / **contentType** を送ります。

詳細の番号チップの **`P`** だけが**サーバー上のプライマリ**行を示します（未保存の選択とは一致しないことがあります）。**一覧**は **P なし**でプライマリの HTTP ステータス（と例キャプション）を出し、編集中のチップとは切り離されます。同一操作に **enabled 行が2件以上**あるときは一覧に**警告**が出ます。サーバーとエクスプローラはどちらも `sortedForOverrideTieBreak`（Core 共通）の先頭を使います。

**Del**（−）: 保存行が一致 → **`remove`**（設定から行削除、エディタは Spec 寄せ）。**`OverrideListQueries.storedOverrideForDel`** は exact 一致のあと、`exampleId` なし legacy 行の本文テンプレ一致も見ます。**未 Save ドラフトのみ** → ローカルクリア（サーバー未呼び出し）。**オフのまま JSON を残す** → 無効チップ + **Save**（**Del ではない**）。OpenAPI 番号チップは **Del 後も表示**されます。

**更新／同期:** エディタは**ローカルで一人が触る**前提で、refresh で詳細が置き換わるときも**確認ダイアログは出しません**。**Spec を再取得**（ツールバー **Refresh**）するとエンドポイント一覧が更新され、**開いている詳細はサーバー状態で上書き**されます（**未保存の編集は失われます**）。**Reload kawarimi.json** はサーバー上のディスク再読み込みのみ行い、オーバーライド一覧を更新します。**`isDirty`** が false のとき開いている詳細も再同期し、サーバーがファイルを取り込んだか（**applied**）既に一致していたか（**unchanged**）をボタン下に表示します。**Save** / **configure** / **remove** 成功後は、親が **fetch した `[MockOverride]` を戻り値で渡し**、ストアが **`markSavedClean()`** のあと **`resyncDetailAfterOverridesRefresh`** で詳細を合わせます（成功経路では **`isDirty`** は false のため再同期が走る）。**別エンドポイントへ移ったとき、未保存（dirty）のドラフトは行キーごとに退避**され、同じ行を再度選ぶと復元されます（**Spec の再取得**で退避は消えます）。

---

### 実装者向け（コード対応）

**編集ルール**は **`KawarimiHengeCore`**（`Sources/KawarimiHengeCore/`）— `ResponseChips`、`SavePayload`、`DisableMockPlanner`、`EndpointFilter`、**`OverrideListQueries`**、**`OverrideExplorerDraftBootstrap`**。**選択とドラフトメタ**（`validationMessage`、`isDirty`）は **`OverrideEditorStore`** / **`OverrideDetailDraft`**。SwiftUI は **`KawarimiHenge`**（`Sources/KawarimiHenge/`）。

| UI / ドキュメント上の言い方 | コード側 | メモ |
| --- | --- | --- |
| リストの 1 行 | `EndpointRowKey` + `SpecEndpointItem` | 選択は `EndpointRowKey`。 |
| 行を初めて開く（退避なし） | `OverrideExplorerDraftBootstrap.makeFreshDetail` | プレースホルダ → プライマリ上書き → `resyncMockFromServer`。 |
| 詳細の編集対象 | `OverrideDetailDraft` 内の `MockOverride` 1 件 | 選択中の論理行のスナップショット。 |
| サーバー / 設定の 1 行 | `kawarimi.json` の `MockOverride` | 同一視は **`rowId` 優先**（UUID）。legacy fallback は **入力 `rowId` が nil のときのみ** `path + method + statusCode + 正規化後 exampleId`。 |
| 保存済み row ID（詳細ヘッダ） | `RowIdPresentation.displayRowId` | 選択チップが **`rowId` 付きの保存行**と一致するとき表示。**Copy** で UUID をクリップボードへ（`kawarimi-scenarios.json` 編集用）。Spec のみ・未保存ドラフトでは非表示。 |
| デフォルト / 無名の例 | `exampleId` が nil（空白正規化後も） | ルックアップは **`__default`**。 |

**レスポンスチップ:** OpenAPI の**番号行**（ステータス＋名前付き例）は spec から常に表示。**追加チップ**は spec に無い**保存行**向け（カスタムステータス等）。本文なし無効の spec-follow ghost 行は追加チップから非表示（**`OverrideListQueries.isSpecFollowGhostRow`**）。**モックオフ**時の **`ResponseChips.chipIsSelected`** は **Save** と同じ **`draftRepresentsSpecOnlyRowForSave`**（本文空またはテンプレ一致）で **Spec** を光らせる。**`OverrideDetailDraft.pinnedNumberedResponseChip`** が立っていれば番号チップ優先（**再同期・Save 成功・Reset**、ストアが本文やモックを変えたとき — **`applyMockEdit`**、**整形（Format）** でクリア）。

**SavePayload** の先頭 return は **`draftRepresentsSpecOnlyRowForSave`** のみが使う。

**アクティブは1行:** **`KawarimiConfigView`** の `configure` ラッパーが **`peerShouldBeDisabledWhenSavingEnabledRow`** で、**保存対象と同じ override 行でない**（別ステータスや別 `exampleId` も含む）同じ操作の enabled 行を、**先に** `configure` で **`isEnabled: false` のみ**送る（**`body` / `contentType` はそのまま**）。

**Save** — UI は **`SavePayload.build`** のあと **`OverrideEditorStore`**: **`SavePayload.isSpecOnlyRemovePayload`** かつ一致する保存既定行あり → **`remove`**。Spec-only 形で保存行なし → HTTP なし。それ以外 → **`configure`**。**`buildApplyPrimary`** / **`buildSaveInactive`** は Spec-only **形状**のテスト用。

**Del** — **`DisableMockPlanner`**（**`storedOverrideForDel`**）: チップに保存行あり → **`removeIdentity`** で **`remove`** ＋ Spec 寄せリセット。未 Save ドラフトのみ → **ローカルクリア**。それ以外は no-op。

**自動テスト:** Henge エクスプローラのロジックは **`KawarimiHengeCoreTests`**（`Tests/KawarimiHengeCoreTests/`、モジュール **`KawarimiHengeCore`**）。ubuntu CI は **`KawarimiHengeCore`** のみ。SwiftUI の **`KawarimiHenge`** は macOS ローカルで確認。

## クライアント: 実サーバーと Kawarimi モック

プロセス内のモックと実 HTTP サーバーの両方を使うなら、生成された **`Client` を2つ**用意します。

- `Kawarimi()` — ネットワークなし。応答本文は [mock-json.md](mock-json.md) のルール（operation ごとの 200 + `application/json`）に従います。
- [swift-openapi-urlsession](https://github.com/apple/swift-openapi-urlsession) の `URLSessionTransport()` でサーバーに繋ぐクライアント（ターゲットにその製品を追加）。

`KawarimiSpec`（および Henge / `responseMap`）は、インプロセスの `Kawarimi` トランスポートと **同じ生成パスでは埋まりません**。

詳しくは [mock-json.md](mock-json.md) の **「`KawarimiSpec` とインプロセス `Kawarimi` トランスポート」**を参照してください。

参照の **DemoServer** と **DemoApp** は **`Example/`** にあります: [Example/README_JA.md](../../Example/README_JA.md)。

**1つの**クライアントで実／モックを実行時に切り替えたい場合は、アプリ側で `ClientTransport` に準拠する薄いラッパーを自作し、`URLSessionTransport` に委譲しつつ `baseURL` やヘッダーを選ぶ形にしてください。

<a id="kawarimijson--kawarimi_config"></a>

## `kawarimi.json` / `KAWARIMI_CONFIG`

`KawarimiConfigStore`（**KawarimiCore**）はオーバーライドを JSON ファイルに読み書きします（デフォルト: カレントディレクトリの `kawarimi.json`）。

ファイル形式は `KawarimiConfig`（overrides 配列）です。**作成時のルール**（フィールドの意図・ランタイムではない）: [skills/kawarimi-user-mock-and-scenario-format/SKILL.md](../../skills/kawarimi-user-mock-and-scenario-format/SKILL.md)。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

`KAWARIMI_CONFIG_WATCH` はディスク上の設定ファイル変更時の自動 reload: **未設定** または **`1`** で監視 ON、**`0`** で OFF（**`false`** などは ON のまま）。**DemoServer** は起動時に `startFileWatchIfEnabled()` を呼びます。他ホストでも同様にする場合は同 API を呼んでください。

### `kawarimi-scenarios.json` / `KAWARIMI_SCENARIOS_CONFIG`

シナリオ定義は同一ストアが読み込みます（読み取り専用。`configure` では書き込まない）。パス解決の優先順:

1. **`KawarimiConfigStore`** init の `scenariosPath:`（非空のとき）
2. 環境変数 **`KAWARIMI_SCENARIOS_CONFIG`**
3. 解決済み `kawarimi.json` と同じディレクトリの **`kawarimi-scenarios.json`**

`kawarimi.json` はランタイムの `overrides` のみを持ちます（生成の `handlerStubPolicy` と `generateKawarimi` / `generateHandler` / `generateSpec` は `kawarimi-generator-config.yaml`）。

各オーバーライドに任意の **`delayMs`**（ミリ秒、1–60000）を指定できます。省略・`null`・`0`・負数は遅延なしです。参照ミドルウェアはモック応答の直前にスリープします。

**初期 `kawarimi.json`・サンプル `kawarimi-generator-config.yaml`・`swift run DemoServer` のカレントディレクトリ**については [Example/README_JA.md](../../Example/README_JA.md) を参照してください。

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッドが一致）、**`KawarimiServerMiddleware`** は **`MockOverride.sortedForOverrideTieBreak`** で並べ替えた **先頭**を採用します。

比較順:

`path` → `statusCode` → `name` → `exampleId`

キーが同順位のときは、Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

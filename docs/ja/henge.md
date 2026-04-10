# ダイナミックモック（KawarimiHenge）

**ビルド時:** **Kawarimi** プラグインが `KawarimiSpec.swift` を生成し、エンドポイントとレスポンスボディを Swift の定数として埋め込みます。

**実行時**にオーバーライドを切り替えて再コンパイルなしでモックを変える流れは、**KawarimiHenge** の機能です。

アプリターゲットに **KawarimiCore** を追加すると `KawarimiAPIClient`（`{pathPrefix}/__kawarimi/*` への HTTP）が使え、**KawarimiHenge** を追加すると SwiftUI（`KawarimiConfigView`）が使えます。

サーバー側は **KawarimiCore**（`KawarimiConfigStore`、`PathTemplate`、`MockOverride` など）と、**Henge API** ルートを組み合わせます。

**オーバーライドを適用する Vapor の `AsyncMiddleware` は KawarimiCore の製品ではありません**—参照実装として [`KawarimiInterceptorMiddleware.swift`](../../Example/DemoPackage/Sources/DemoServer/KawarimiInterceptorMiddleware.swift) をコピー／改変するか、[Example README_JA.md](../../Example/README_JA.md) の構成に沿ってください。

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

<a id="hengecli-macos"></a>

## HengeCli（macOS 用サンプル実行ファイル）

**`Example/DemoPackage`** に実行ファイルプロダクト **`HengeCli`** があります。

**macOS 専用**の SwiftUI アプリで、**`KawarimiConfigView`** を **`KawarimiAPIClient`** とともに起動します。クライアントの **`baseURL`** は生成された **`KawarimiSpec.meta`**（`serverURL` と `apiPathPrefix`）から決まります（Demo アプリと同系の解決ルール。実装は `Sources/HengeCli/HengeCliConfig.swift`）。

- **起動:** `Example/DemoPackage` で `swift run HengeCli`（または `swift build --product HengeCli`）。  
  先に **`DemoServer`** を立てるか、OpenAPI の `servers` と整合する URL で Henge API が出ているサーバーを用意してください。

- **ウィンドウ:** **最後のウィンドウを閉じるとプロセス終了**（`applicationShouldTerminateAfterLastWindowClosed`）。

  起動時は **`NSApp.activate(ignoringOtherApps: true)`** と **`makeKeyAndOrderFront`** で前面・キーウィンドウにし、ターミナル起動などでもテキスト入力が通りやすくしています。

- **URL が不正:** `servers` やプレフィックスから URL を組めない場合は **`ContentUnavailableView`** で `openapi.yaml` の確認と再生成を促します。

iOS など他プラットフォーム向けビルドでは **スタブの `main`** がメッセージを出して終了します。

SwiftUI ホストは **`DemoApp`** や自前ターゲットを使ってください。

## 生成ファイル: `KawarimiSpec.swift`

`KawarimiSpec` は API ターゲットに生成され、以下を公開します:

```swift
KawarimiSpec.meta        // title, version, serverURL
KawarimiSpec.endpoints   // 全エンドポイントと利用可能なレスポンス一覧
KawarimiSpec.responseMap // "METHOD:/path" → [statusCode: [exampleId: (body, contentType)]]
```

生成される型 **`SpecResponse`** は **`KawarimiFetchedSpec`** に準拠しています。

そのため **`KawarimiConfigView(client:specType:)`** が `/__kawarimi/spec` を手動クロージャなしでデコードできます。

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

`KawarimiConfigStore.configure` は、**`path`・HTTP メソッド・`statusCode`・正規化後の `exampleId`** が一致するエントリだけを同一キーとして上書きします。

`configure` は **1 行の upsert** です。`isEnabled: false` にするとモックをオフにしつつ、その行は **`kawarimi.json` に残ります**。

**`KawarimiConfigStore.removeOverride`** は **`configure` と同じ正規化後の同一視**で最初の 1 行を配列から削除します。一致する行が無いときの `removeOverride` は **何もしない**（べき等）です。

同じパスに複数の名前付き例を同時に有効にする場合は、`exampleId` で区別します。

モック JSON 文字列の決め方は [mock-json.md](mock-json.md) を参照してください。

## Henge API（`{pathPrefix}/__kawarimi/*`）

**Henge API** は、**KawarimiCore** の `KawarimiAPIClient` が呼び出す HTTP 面です（「Henge」は機能名）。

OpenAPI API と**同じパスプレフィックス体系**の下にマウントするのが一般的です（例: API が `/api` なら **`/api/__kawarimi/spec`**）。

独自構成ではルート直下に置いても構いません。`KawarimiAPIClient` の `baseURL` と揃えてください。

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

**リクエストごと**にどの有効オーバーライドを優先するか切り替える場合（`configure` の JSON 本体とは別）、参照ミドルウェアは **`X-Kawarimi-Example-Id`** を読みます。

定数名は **KawarimiCore** の **`KawarimiMockRequestHeaders.exampleId`** です。

**同じパス・メソッドに複数の有効オーバーライド**があるとき、空でないヘッダー値で候補を絞り込みます（比較は ``KawarimiExampleIds/responseMapLookupKey(forOverrideExampleId:)`` と同じ。例: `success` は `exampleId` が `"success"` のオーバーライドに一致。デフォルト例行は値 **`__default`**）。

絞り込み結果が **0 件**のときはヘッダーを無視し、従来どおり全候補からタイブレークします。

ヘッダーを付けない、または空白のみのときは絞り込みしません。

| エンドポイント | 説明 |
|---|---|
| `POST {pathPrefix}/__kawarimi/configure` | path/method/statusCode（および名前付き例なら `exampleId`）で 1 行を upsert。`isEnabled`・`body`・`contentType` などを指定 |
| `POST {pathPrefix}/__kawarimi/remove` | `configure` と同じ同一視（正規化後の path・メソッド・`statusCode`・`exampleId`）で 1 行を削除。べき等 |
| `GET {pathPrefix}/__kawarimi/status` | 有効なオーバーライド一覧を取得 |
| `POST {pathPrefix}/__kawarimi/reset` | 全オーバーライドを解除 |
| `GET {pathPrefix}/__kawarimi/spec` | KawarimiSpec の全内容（meta + endpoints）を返す |

**KawarimiHenge（`KawarimiConfigView`）:** API の `baseURL` に揃えた **`KawarimiAPIClient`** と、生成された **`SpecResponse.self`**（**`KawarimiFetchedSpec`** 準拠）を渡します。

画面上のサーバー表記は **`client.baseURL.absoluteString`** です。

マイナス（**Del**）は、モックがオンのとき **`isEnabled: false` を保存**します。

すでにオフで、かつそのチップ用の**保存済み行**があるときは **`remove`** を呼び、サーバー設定から行を消してエディタを Spec のドラフトに戻します（HTTP は **KawarimiCore** の **`KawarimiAPIClient.removeOverride(override:)`** と同じ経路です）。

本リポジトリの **DemoServer** 向けの **`curl` 例**: [Example/README_JA.md#henge-api-demoserver](../../Example/README_JA.md#henge-api-demoserver)。

## オーバーライドエディタ（`OverrideEditorView`）

モック用 SwiftUI は **KawarimiHenge** の **`OverrideEditorView`**（エンドポイント一覧＋詳細ペイン）です。

<a id="henge-explorer-state"></a>

### エクスプローラの状態モデル（3 つの役割）

1. **サーバー側スナップショット（ほぼ読み取り）** — **`KawarimiConfigView`** が **`meta`**・**`endpoints`**・**`overridesSnapshot`**（**`GET …/__kawarimi/status`** のデコード結果）を **`@State`** で持ち、**`OverrideEditorView`** に `let` で渡す。エクスプローラの行・例キャプション・**`primaryOverride(for:)`**・保存済み行に基づくチップは、このスナップショットを読む。

2. **エディタのドラフト（選択中）** — **`OverrideEditorStore`**（`@Observable`）が **`OverrideDetailDraft`**（**`mock`**・**`isDirty`**・**`pinnedNumberedResponseChip`** など）を保持。配列全体のコピーではなく、**開いている行の編集バッファ**。**退避** — 別エンドポイントへ移るとき **`isDirty`** なら **`pendingDraftsByRowKey`** に退避し、同じ行を再度選ぶと復元（**Spec 再取得**で退避は消える）。

3. **ミューテーションの橋渡し** — 子へ渡す **`configureOverride`** / **`removeOverride`** は **`(MockOverride) async throws -> [MockOverride]`**。親ラッパー（**`KawarimiConfigView`**）が **`disableConflictingStatusMocks`** のあと **`KawarimiAPIClient`** の **`configure`** / **`remove`** を呼び、**`refreshOverridesOnly()`** で **`overridesSnapshot`** を更新し、**fetch で得た同じ `[MockOverride]` を `return`**（この戻り値用に **`@State` を二度読みしない**）。**`OverrideEditorStore`** は成功経路で **`markSavedClean()`** の直後にその配列で **`resyncDetailAfterOverridesRefresh`** を呼び、ドラフトをサーバー一覧と揃える。

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

エンドポイントを選び、**レスポンスのチップ**で行を選び、必要なら JSON を編集して **Save**（サーバーへ `configure`）。

| やりたいこと | 操作 |
| --- | --- |
| この操作は OpenAPI のみ（実効は **Spec**） | **Spec** をタップ（先頭の spec ステータス・名前付き例なし・本文欄クリア）。ドラフトが **Spec 形**なら **Save** で Spec 専用の**無効化**ペイロードを送ります。サーバーに **enabled 行が無い** とき実効は **Spec** で、**Spec** チップを強調表示します。 |
| まだ行を消さずに「テンプレだけ見る」状態に戻す | **Spec** タップで本文クリア、または **enabled なし**＋無効の既定行ならテンプレ JSON が入っていても **Spec** が光る。**200 OK** をタップすると番号チップのまま同じ本文を編集できる。 |
| ドキュメント上のあるレスポンスをモックする（サーバー上の **プライマリ**にする） | **ステータス／例**のチップを選び（ドラフト **`isEnabled: true`**）、本文を編集して **Save**。**`KawarimiConfigView`** は同じ OpenAPI 操作の**他の** enabled 行を先に **`isEnabled: false`** で `configure` してから現在の行を **有効**で保存します（通常は操作あたりアクティブは1行）。 |
| OpenAPI に無いステータス（や例）を足す | **+**（Add response）でステータスを選び、メイン画面で編集して **Save**（チップ／保存行のオンオフに従う）。 |
| 本文は残すが **アクティブにしない** | **オフ**の行のチップを選び（保存済み無効行を読み込む、**Del** 後など）、本文を編集して **Save** — **`isEnabled: false`** のまま **body** / **contentType** も送ります。 |
| モックを止めるが `kawarimi.json` の行は残す | オン中に **Del**、または無効のチップで **Save**。 |
| **今選んでいるチップ**に対応する保存行だけ消す | モックがオフで保存行があるとき **Del**（**`remove`**）。 |
| **既定行**（先頭の spec ステータス・無名例）をオフ＋本文クリアにし、エディタをそれに合わせる | 下部 **Reset** — そのキーへの **`configure` のみ**。同じ操作の**別チップ**の行は残るので、消すときはチップごとに **Del**。 |
| 全オーバーライドを消す | エクスプローラの **Reset all overrides**（確認あり）。 |

**Save** は **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`** を組み立てて `configure` します。**Spec 形**のドラフトでも、ユーザーが **Spec チップ**を選んでいるときだけ（**`pinnedNumberedResponseChip`** が false）**無効＋本文クリア**の先頭分岐に入ります。**200 OK** など番号チップ（pin true）で、保存行はまだオフでも本文がテンプレ一致のときは **有効**を送り、プライマリにします。それ以外は **`mock.isEnabled`** で **有効**／**無効**を切り替え、**無効**でもトリム済みの **body** / **contentType** を送ります。

詳細の番号チップの **`P`** だけが**サーバー上のプライマリ**行を示します（未保存の選択とは一致しないことがあります）。**一覧**は **P なし**でプライマリの HTTP ステータス（と例キャプション）を出し、編集中のチップとは切り離されます。同一操作に **enabled 行が2件以上**あるときは一覧に**警告**が出ます。インターセプターはサーバー側の並び（`sortedForInterceptorTieBreak`）の先頭を使います。

**Del**（−）: モック **オン** → 同一キーで **`configure` でオフ**。**オフ**で保存行が一致 → **`remove`**（設定から行削除）。

**更新／同期:** エディタは**ローカルで一人が触る**前提で、refresh で詳細が置き換わるときも**確認ダイアログは出しません**。**Spec を再取得**するとエンドポイント一覧が更新され、**開いている詳細はサーバー状態で上書き**されます（**未保存の編集は失われます**）。**Save** / **configure** / **remove** 成功後は、親が **fetch した `[MockOverride]` を戻り値で渡し**、ストアが **`markSavedClean()`** のあと **`resyncDetailAfterOverridesRefresh`** で詳細を合わせます（成功経路では **`isDirty`** は false のため再同期が走る）。**別エンドポイントへ移ったとき、未保存（dirty）のドラフトは行キーごとに退避**され、同じ行を再度選ぶと復元されます（**Spec の再取得**で退避は消えます）。

---

### 実装者向け（コード対応）

**編集ルール**は **`Sources/KawarimiHenge/EditorSupport/`**（`ResponseChips`、`SavePayload`、`DisableMockPlanner`、`EndpointFilter`、**`OverrideListQueries`**、**`OverrideExplorerDraftBootstrap`**）。**選択とドラフトメタ**（`validationMessage`、`isDirty`）は **`OverrideEditorStore`** / **`OverrideDetailDraft`**。

| UI / ドキュメント上の言い方 | コード側 | メモ |
| --- | --- | --- |
| リストの 1 行 | `EndpointRowKey` + `SpecEndpointItem` | 選択は `EndpointRowKey`。 |
| 行を初めて開く（退避なし） | `OverrideExplorerDraftBootstrap.makeFreshDetail` | プレースホルダ → プライマリ上書き → `resyncMockFromServer`。 |
| 詳細の編集対象 | `OverrideDetailDraft` 内の `MockOverride` 1 件 | 選択中の論理行のスナップショット。 |
| サーバー / 設定の 1 行 | `kawarimi.json` の `MockOverride` | **`path` + `method` + `statusCode` + 正規化後 `exampleId`**。 |
| デフォルト / 無名の例 | `exampleId` が nil（空白正規化後も） | ルックアップは **`__default`**。 |

**レスポンスチップ（モックオフ）:** **`ResponseChips.chipIsSelected`** は **Save** と同じ **`draftRepresentsSpecOnlyRowForSave`**（本文空またはテンプレ一致）で **Spec** を光らせる。**`OverrideDetailDraft.pinnedNumberedResponseChip`** が立っていれば番号チップ優先（**再同期・Save 成功・Reset**、ストアが本文やモックを変えたとき — **`applyMockEdit`**、**整形（Format）** でクリア）。

**SavePayload** の先頭 return は **`draftRepresentsSpecOnlyRowForSave`** のみが使う。

**アクティブは1行:** **`KawarimiConfigView`** の `configure` ラッパーが **`peerShouldBeDisabledWhenSavingEnabledRow`** で、**保存対象と同じ override 行でない**（別ステータスや別 `exampleId` も含む）同じ操作の enabled 行を、**先に** `configure` で **`isEnabled: false` のみ**送る（**`body` / `contentType` はそのまま**）。

**Save** — UI は **`SavePayload.build(mock:endpoint:pinnedNumberedResponseChip:)`**。**`draftRepresentsSpecOnlyRowForSave`** かつ **番号チップでない**ときだけ先に **無効＋クリア**で return。番号チップ（**`pinnedNumberedResponseChip`**）ならテンプレ一致のオフ行でも **有効**へ。それ以外は **`mock.isEnabled`** で **有効**／**無効**。**`buildApplyPrimary`** / **`buildSaveInactive`** はテストや強制経路用です。

**Del** — **`DisableMockPlanner`**: アクティブ → `configure` でオフ。オフ＋保存行一致 → **`remove`** ＋ Spec 寄せのリセット。それ以外は no-op。

**自動テスト:** **`KawarimiHengeTests`**（`Tests/KawarimiHengeTests/`）。

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

ファイル形式は `KawarimiConfig`（overrides 配列）です。

環境変数 `KAWARIMI_CONFIG` でパスを上書きできます。

`kawarimi.json` はランタイムの `overrides` のみを持ちます（生成の `handlerStubPolicy` は `kawarimi-generator-config.yaml`）。

**初期 `kawarimi.json`・サンプル `kawarimi-generator-config.yaml`・`swift run DemoServer` のカレントディレクトリ**については [Example/README_JA.md](../../Example/README_JA.md) を参照してください。

オーバーライドの `body` / `contentType` が空文字のときは保存時に「未設定」に正規化され、レスポンス時は空 body は Spec にフォールバックします。

同一リクエストに複数のオーバーライドがマッチする場合（パステンプレート・メソッドが一致）、インターセプタは **`MockOverride.sortedForInterceptorTieBreak`** で並べ替えた **先頭**を採用します。

比較順:

`path` → `statusCode` → `name` → `exampleId`

キーが同順位のときは、Swift の **安定ソート**で `hits` 内の元の順序が保たれます。ログにはその並びで警告が出ます。

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

**0.11.x からの更新**は **[CHANGELOG.md](../../CHANGELOG.md)** の破壊的変更と移行手順を参照。

**1.0.x → 1.1.0:** **`OpenAPIPathPrefix`** を削除しました。**`KawarimiPath`**（`splitPathSegments`、`joinPathPrefix`、`aligned(path:pathPrefix:)`）に置き換えてください。詳しくは CHANGELOG の **1.1.0** を参照。

本パッケージの SwiftPM プロダクト:

- **KawarimiCore** — ランタイム（`MockOverride`、`KawarimiConfigStore`、`KawarimiAPIClient` など）。OpenAPIKit / Yams は含まない。
- **KawarimiJutsu** — ジェネレータ API（`KawarimiJutsu.loadOpenAPISpec` は **OpenAPIKit** の **`OpenAPI.Document`**、OpenAPI **3.0.x / 3.1.x / 3.2.0** を **swift-openapi-generator** の **YamsParser** と同様に読み込み、`OpenAPISpecDocumentURL`、YAML 設定ローダーなど）。**OpenAPIKit** / **OpenAPIKit30** / **OpenAPIKitCompat** 依存。CLI・テスト・独自ツール向けで、通常のアプリ本体には不要。
- **KawarimiHenge** — SwiftUI（`KawarimiConfigView`）。**エクスプローラの状態**（スナップショット・ドラフト・起動・`isDirty` と未保存）: [henge.md](henge.md#henge-explorer-state)。ライフサイクル／一覧 `.id`: [henge.md](henge.md#henge-ui-data-flow)。

**KawarimiSpec.swift** を置くターゲットでは、**`KawarimiCore`** に加え **`HTTPTypes`** プロダクトを**直接**依存に書く（[swift-http-types](https://github.com/apple/swift-http-types)）。**KawarimiCore** 経由の推移的依存だけでは SwiftPM が解決しません。

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "1.1.2"),
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

ダイナミックモック用 SwiftUIには **KawarimiHenge**、`KawarimiAPIClient` には **KawarimiCore** を追加（[henge.md](henge.md)）。

## 2. OpenAPI の置き場所

**Swift ターゲットのルートディレクトリ**（SwiftPM がそのターゲットに割り当てるディレクトリ。[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) と同じ置き場所）に、**次のいずれか 1 本だけ**置く: **`openapi.yaml`**、**`openapi.yml`**、**`openapi.json`**。同じターゲットに複数置かない（SwiftPM が渡すファイル一覧上で 0 件または複数件ならエラー。OpenAPIGenerator の **`PluginUtils`** と同じルール）。
**KawarimiPlugin** は **`SwiftSourceModuleTarget.sourceFiles`** に載るファイルから上記ファイル名だけを拾い、ディレクトリを独自に走査しません。
ビルドで OpenAPIGenerator が Types.swift / Client.swift / Server.swift を、KawarimiPlugin が Kawarimi.swift / KawarimiHandler.swift / KawarimiSpec.swift を生成する。

## 3. ジェネレータ設定（必須）

**OpenAPI 仕様と同じディレクトリ**（ターゲットルート）に **`openapi-generator-config.yaml`** または **`openapi-generator-config.yml` をちょうど 1 つ**置く（[swift-openapi-generator](https://github.com/apple/swift-openapi-generator) と同じ。0 個または複数はエラー）。[設定の内容](https://github.com/apple/swift-openapi-generator#configuration)は公式どおり。

Kawarimi が読むキーは **`namingStrategy`** と **`accessModifier`** です。

**`handlerStubPolicy`**（`throw` / `fatalError`、省略時 `throw`）は **`kawarimi-generator-config.yaml`**（または `.yml`）に書きます（`openapi-generator-config` とは別。Kawarimi 専用キー）。**`kawarimi-generator-config` は高々 1 本**（CLI では仕様と同じディレクトリ、プラグインでは **`sourceFiles`** 上。2 本以上はエラー）。

**KawarimiPlugin** は OpenAPI 仕様、**`openapi-generator-config`**、任意の **`kawarimi-generator-config`** を **`sourceFiles`** から解決します。**`Kawarimi`** CLI は仕様パスと同じディレクトリから **`openapi-generator-config`** と任意の **`kawarimi-generator-config`** を読みます（`openapi-generator-config` 系のエラー文面は swift-openapi-generator の **`FileError`** と同一。文言は **`Plugins/KawarimiPlugin/`** の **シンボリックリンク**で **KawarimiJutsu** と共有）。

## 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

<a id="要件ツールチェーン"></a>

## 要件・ツールチェーン

- Swift **6.2+**（`Package.swift` の `swift-tools-version` に合わせる）。**KawarimiPlugin** は `Kawarimi` 実行ファイルを `-parse-as-library`（`unsafeFlags`）でビルドする。**6.1** の SwiftPM は、プラグイン依存時にその依存グラフを**拒否**することがある。CI は [swift-actions/setup-swift](https://github.com/swift-actions/setup-swift) で **6.2** を選択。
- **`Example/`** 配下の SwiftPM サンプルは **macOS 14+**。Kawarimi のライブラリは **iOS 17+** も宣言（`Package.swift` の `platforms`）。
- `handlerStubPolicy: throw` は、**いずれかの** operation で `KawarimiHandler` のデフォルトスタブが組めないときに生成を失敗させます。
  例: ドキュメント上の成功が **HTTP 200 / 201** の `application/json` または本文なし、**HTTP 204** のパターンに合わない、ヘッダのみで本文のスタブを自動生成できない、など。
- `handlerStubPolicy: fatalError` は生成を継続し、**なお**スタブを組めない operation だけ実行時 `fatalError()` のクロージャになります（該当 `operationId` を stderr に警告）。
  `application/json` の成功レスポンスは、式スタブが書けるときはそのまま、無理なときは [mock-json.md](mock-json.md)（「KawarimiHandler のデフォルトスタブ」）の **JSON デコードフォールバック**を使います。

# モック JSON の決め方

各 `application/json` レスポンスについて、Kawarimi は `KawarimiSpec` に埋め込む JSON 文字列を決めます。

生成される `Kawarimi` 型の `ClientTransport` モックでは、**200** の本文が使われます。

## `KawarimiSpec` とインプロセス `Kawarimi` トランスポート

ジェネレータ内で **別々の実装**になります。

| 出力 | 内容 |
| --- | --- |
| **`KawarimiSpec`**（`endpoints`、`responseMap`） | インラインの名前付き `examples` を **エントリごとに** `MockResponse` として出す。例のキーは **辞書順（Unicode コードポイント順）**にソートし、生成物の再現性を揃える。 |
| **`Kawarimi` `ClientTransport`** | 操作ごとに **HTTP 200** 用の JSON を **1 つ**だけ出す。`defaultResponseJSON` で **`content.example`** を見てから、スキーマ由来のモック（`mockJSONBodyFromJSONMediaType`）に進む。**`KawarimiSpec` と同じ `examples` 列挙はしない**。 |

ドキュメントに **`example` が無く `examples` マップだけ**ある場合、OpenAPIKit 側でトランスポート用に **1 つの `example` に畳まれる**ことがありますが、それが `KawarimiSpec` のどの名前付き行に対応するかは **保証されません**。特定の名前付き例の本文で試したいときは、**HTTP クライアント**で `responseMap` / Henge を使うサーバーに当てるか、トランスポートが実際に出す本文を前提にしてください。

以下の番号付きルールは、主に **トランスポート用の単一 200 本文**（および名前付き `examples` が無いときの **1 行の Spec**）の決め方です。

優先順は次のとおりです。

1. **Media Type Object** — `example`、または `examples` だけがある場合は OpenAPIKit が解決した先頭の値（`example` と `examples` の同時指定は仕様上不可）。
2. **そのメディア型の JSON Schema** — `example`、次に `default`。
3. **形からの合成** — `object` / `array` を再帰し、プリミティブは必要ならプレースホルダで埋める。
4. **`oneOf` / `anyOf`** — 空に近いプレースホルダ（`{}` / `""` / `0` / `false` / `[]` など）でない最初の枝を採用。どの枝もプレースホルダに近い場合は先頭の枝。
5. **`allOf`** — 先頭のサブスキーマ（明示的な example がないときの簡易ヒューリスティック）。
6. **`enum`（`allowedValues`）** — 先頭値を JSON としてエンコード。
7. **プリミティブ** — 文字列 `""`、数値 `0` など。型が取れない場合は `{}`。

`KawarimiHandler` のスタブ生成は別問題です。

swift-openapi-generator 上の都合で、上記のモック JSON が取れている場合でも **一部の enum などはスタブ生成が失敗**し、`on…` の手実装や `handlerStubPolicy` が必要になることがあります。

## 名前付き例と `responseMap`

レスポンスの `application/json` に OpenAPI の **`examples` マップ**があり、各エントリに **インライン**の JSON 値がある場合、Kawarimi は **マップのキーごとに 1 つの `MockResponse`** を出します。

**例のキーは辞書順にソート**され、生成結果の順序が安定します。

そのキーが `exampleId` になります。`KawarimiSpec.responseMap` は本文を **`[statusCode: [exampleId: (body, contentType)]]`** としてネストします。

**予約語:** OpenAPI の `examples` のキーとして **`__default` は使わないでください**。Kawarimi が合成デフォルト行と `exampleId` 省略時のルックアップ用に予約しています。詳しくは [henge.md](henge.md) の **「予約語: `__default`」**を参照してください。

**`externalValue` のみ**のエントリは生成時に **スキップ**されます。

その結果として、上記の単一例ルールに従い **`__default`** など 1 行にまとまることがあります。

**単一**のインライン `example`、または解決結果が 1 つだけのときは、生成 Spec では **`exampleId` が `__default`** の 1 行になります（複数の名前付き例がある場合を除く）。

次の内容は [henge.md](henge.md) を参照してください。

- `MockOverride.exampleId` を省略したときの **`__default` 扱い**。
- ランタイムのオーバーライドと `kawarimi.json`。

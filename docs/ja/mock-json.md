# モック JSON の決め方

各 `application/json` レスポンスについて、Kawarimi は `KawarimiSpec` に埋め込む JSON 文字列（および生成される `Kawarimi` 型の `ClientTransport` モックでは **200** の本文）を決めます。優先順は次のとおりです。

1. **Media Type Object** — `example`、または `examples` だけがある場合は OpenAPIKit が解決した先頭の値（`example` と `examples` の同時指定は仕様上不可）。
2. **そのメディア型の JSON Schema** — `example`、次に `default`。
3. **形からの合成** — `object` / `array` を再帰し、プリミティブは必要ならプレースホルダで埋める。
4. **`oneOf` / `anyOf`** — 空に近いプレースホルダ（`{}` / `""` / `0` / `false` / `[]` など）でない最初の枝を採用。どの枝もプレースホルダに近い場合は先頭の枝。
5. **`allOf`** — 先頭のサブスキーマ（明示的な example がないときの簡易ヒューリスティック）。
6. **`enum`（`allowedValues`）** — 先頭値を JSON としてエンコード。
7. **プリミティブ** — 文字列 `""`、数値 `0` など。型が取れない場合は `{}`。

`KawarimiHandler` のスタブ生成は別問題です。swift-openapi-generator 上の都合で、上記のモック JSON が取れている場合でも **一部の enum などはスタブ生成が失敗**し、`on…` の手実装や `handlerStubPolicy` が必要になることがあります。

ランタイムのオーバーライドと `kawarimi.json` は [henge.md](henge.md) を参照してください。

# 詳細カラム — レイアウト回帰

オーバーライド **詳細カラム**（ヘッダー、JSON エリア、下部ツールバー）の回帰を防ぐためのチェック。

**English:** [../henge-detail-column-regression.md](../henge-detail-column-regression.md)

| 失敗例 | 合格条件 |
|--------|----------|
| 下部ツールバーが見えない | Validate / Format / Save / Reset が JSON エリアと同時に見える |
| ヘッダーが潰れる／隠れる | operationId、tags、parameters（ある場合）、status チップが読める |
| 長い JSON で UI が隠れる | ツールバーは固定、JSON エリアだけがスクロールする |

数値レイアウトは `DetailColumnLayoutCoreTests`（#118）で担保。**Preview** は stateless レイアウトのみ。残りは以下の手動確認で補完する。

## Preview（DemoApp、stateless）

`Example/DemoApp/DemoAppUI/DetailColumnPreviews.swift` を開く（DemoApp scheme）。

| ケース | 合格条件 |
|--------|----------|
| メタデータ少なめ | ヘッダー + ツールバーが同時に見える。PARAMETERS（query）が表示される（`getGreeting` 相当） |
| Security 多め | PARAMETERS（path / query / header）と長い SECURITY があってもツールバーが見える |
| JSON 長文 | ツールバーが見え、JSON はエディタ内でスクロールする |

Preview で見ない項目: mock off、dirty/save error、チップ適用、sheet。Henge 実画面で手動確認する。

## 手動（DemoServer + Henge）

| ケース | 合格条件 |
|--------|----------|
| `getGreeting` | 上記「メタデータ少なめ」と同様 |
| `listItems` | ヘッダーがスクロールしてもツールバーは固定 |
| 任意 operation の長文 JSON | ツールバー固定、エディタ本文のみスクロール |
| 保存済み行で Del | 1 回で一致する保存行をサーバーから削除できる（disable→再Del の 2 段階にならない） |
| 行を残してオフ | 無効チップ + Save で JSON を保持したまま disabled 行として残る |

## 関連

- [#119](https://github.com/novr/Kawarimi/issues/119)
- [#118](https://github.com/novr/Kawarimi/pull/118)

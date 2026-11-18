---
name: kawarimi-release
description: >-
  Use when preparing a Kawarimi release PR (`chore(release): prepare X.Y.Z`).
  Promotes [Unreleased] and adds merged Dependabot bumps missing from CHANGELOG.md
  to the new version section. Not for feature PRs or for editing a published version.
---

# Kawarimi リリース準備

`chore(release): prepare X.Y.Z` を1コミットで作る。Dependabot の PR は `CHANGELOG.md` を更新しないので、このコミットで拾う。

## 手順

1. **版を決める** — 版番号はこのスキルでは決めない。依存と Actions の更新だけならパッチ。
2. **見出しを上げる** — `## [Unreleased]` の直下に `## [X.Y.Z] - YYYY-MM-DD` を入れ、`[Unreleased]` を空にする。末尾のリンク一覧の先頭に `[X.Y.Z]: https://github.com/novr/Kawarimi/releases/tag/vX.Y.Z` を足す。
3. **範囲を決める** — 最新の `v*` タグの一つ前のタグから `HEAD` まで。最新が `v4.2.0` なら `v4.1.0..HEAD`。前回タグに入ったのに前回の節へ書き忘れた更新も、この範囲で拾う。

   ```bash
   git tag --sort=-v:refname -l 'v*' | sed -n 2p
   git log <prev-prev-tag>..HEAD --format='%h %an | %s'
   ```

4. **Dependabot のコミットを選ぶ** — 作者が `dependabot[bot]`、またはメッセージが `chore(deps):` で始まるもの。PR 番号はメッセージ末尾の `(#NNN)`。
5. **記載済みを飛ばす** — `CHANGELOG.md` のどこかに `(#NNN)`（`pull/NNN` のリンク）があれば飛ばす。公開済みの版の節には足さない。
6. **差分を読む** — 各コミットとその親（`<sha>^`）で、ファイル全体を比べる。unified diff の行は照合しない。
   - `Package.resolved` と `Example/DemoPackage/Package.resolved`: JSON の `pins[].identity` ごとに `state.version` を比べる。
   - `.github/workflows/*.yaml`: `uses: owner/repo@<sha> # vX.Y.Z` のコメントの版を action 名ごとに集める。同じ action が複数ファイルにあっても1回だけ書く。
7. **新しい版の節に書く** — 行き先は手順2で作った `## [X.Y.Z]` の `### Changed`。`[Unreleased]` には置かない。その版に `### Changed` が無ければ、`### Added` の後、`### Deprecated` / `### Removed` / `### Fixed` / `### Security` / `### Docs` / `### Breaking` / `### Migration` の前に作る。
8. **コミット** — 見出し、Dependabot の行、リンクを `chore(release): prepare X.Y.Z` の1コミットにまとめる。

## 行の形

1 PR につき1行。upstream の Release notes や GHSA の要約は書かない。

Actions（action 名の昇順）:

```markdown
- **CI:** bump GitHub Actions — `actions/download-artifact` v8.0.1 → v8.0.2, `actions/upload-artifact` v7.0.1 → v7.0.2, `dorny/paths-filter` v4.0.2 → v4.0.3, `softprops/action-gh-release` v3.0.2 → v3.0.3 ([#245](https://github.com/novr/Kawarimi/pull/245)).
```

ルートの Swift 依存（`Package.swift` の `.package(url:from:)` が変わっていないもの）:

```markdown
- **Dependencies:** [swift-http-types](https://github.com/apple/swift-http-types) 1.6.0 → 1.8.0 ([#247](https://github.com/novr/Kawarimi/pull/247)). Package.resolved pin only; Package.swift lower bound unchanged.
```

- リンク先は pin の `location` から末尾の `.git` を除いたもの。
- 同じ PR で複数の pin が変わったら、`; ` で区切って1行に並べる。
- `Package.swift` に無い pin（推移依存）には、`Package.resolved pin only; …` の文を付けない。
- `Package.swift` の `from:` も変わったときは、その文を付けず `Package.swift` lower bound X → Y と書く。
- `Example/DemoPackage/Package.resolved` の更新は `**Example/DemoPackage:**` で始める。

## 書かずに残すもの

次のときは行を作らず、リリース PR の本文に PR 番号と理由を書いて人に確認してもらう。

- `uses:` の SHA だけが変わり、`# vX.Y.Z` のコメントが無い。
- 同じ action 名に複数の版コメントがある。
- 版の変化が読み取れない。

## 範囲外

- 機能・修正 PR の記載。それらは各 PR が `[Unreleased]` に書く。
- 公開済みの版の節と GitHub Release の本文。
- タグの作成と push。リリース PR のマージ後に行う。

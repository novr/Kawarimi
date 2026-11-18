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
   PREV=$(git tag --sort=-v:refname -l 'v*' | sed -n 2p)
   git log --author='dependabot\[bot\]' "$PREV..HEAD" --format='%h %s'
   ```

4. **Dependabot のコミットを選ぶ** — 作者が `dependabot[bot]` のものだけ。人が書いた `chore(deps):` は、その PR が自分で `[Unreleased]` に書いている。PR 番号はメッセージ末尾の `(#NNN)`。同じ PR 番号のコミットが複数あれば、まとめて1件として扱う。
5. **記載済みを飛ばす** — `CHANGELOG.md` のどこかに `[#NNN]` があれば飛ばす。issue と PR は同じ番号空間なので、`issues/NNN` と `pull/NNN` のどちらのリンクでも同じ件を指す。
6. **差分を読む** — 各コミットとその親（`<sha>^`）で、ファイル全体を比べる。unified diff の行は照合しない。タイトルの版は使わない（#31 はタイトルが「openapikit 5.3.0」だが、中身は `.github/dependabot.yml` だけ）。
   - `Package.resolved`: JSON の `pins[].identity` ごとに `state.version` を比べる。
   - `Package.swift`: `.package(url:from:)` の `from:` を URL ごとに比べる。URL は末尾の `.git` を除いて pin の `location` と突き合わせる。
   - `Example/DemoPackage/Package.swift`: 同じく `from:` を比べる。`Example/DemoPackage/Package.resolved` は `.gitignore` 対象でリポジトリに無い。
   - `.github/workflows/*.yaml`: `uses: owner/repo@<ref>` の版を action 名ごとに集める。版は `# vX.Y.Z` コメント、コメントが無ければ `<ref>` 自体が `vN` / `vN.N.N` のときその値。同じ action が複数ファイルにあっても1回だけ書く。
   - 上のファイル以外が変わっていたら、行を作らない（「書かずに残すもの」）。
7. **前の版に入っていたか見る** — `git tag --contains <sha> --sort=v:refname -l 'v*' | head -1` で最も古いタグを探す。あれば、その更新は前の版ですでに出ている。行末に `Included in vA.B.C but not listed there.` を付ける。
8. **新しい版の節に書く** — 行き先は手順2で作った `## [X.Y.Z]` の `### Changed`。`[Unreleased]` には置かない。公開済みの版の節は書き換えない。その版に `### Changed` が無ければ、`### Added` の後、`### Deprecated` / `### Removed` / `### Fixed` / `### Security` / `### Docs` / `### Breaking` / `### Migration` の前に作る。
9. **コミット** — 見出し、Dependabot の行、リンクを `chore(release): prepare X.Y.Z` の1コミットにまとめる。

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
- `Package.swift` の `from:` も変わったときは、その文の代わりに pin の後へ `; Package.swift lower bound X → Y` を書く（例: `[Yams](https://github.com/jpsim/Yams) 5.4.0 → 6.2.1; Package.swift lower bound 5.0.0 → 6.2.1`）。
- `Example/DemoPackage/Package.swift` の更新は `**Example/DemoPackage:**` で始め、`from:` の変化を書く。
- 前の版に入っていた更新は、行末に `Included in v4.2.0 but not listed there.` のように付ける。

## 書かずに残すもの

次のときは行を作らず、リリース PR の本文に PR 番号と理由を書いて人に確認してもらう。

- 依存ファイルと workflow 以外が変わっている（#31 は `.github/dependabot.yml` だけ）。
- `uses:` の ref が SHA で、`# vX.Y.Z` のコメントが無い。
- 同じ action 名に複数の版がある。
- 版の変化が読み取れない。

## 範囲外

- 機能・修正 PR の記載。それらは各 PR が `[Unreleased]` に書く。
- 公開済みの版の節と GitHub Release の本文。
- タグの作成と push。リリース PR のマージ後に行う。

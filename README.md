# claude-usage-monitor

Claude Code のプロンプト入力欄の上に **USAGE MONITOR** を表示する mod（プラグイン名: `usage-monitor`）です。

```
╭──────────────────────────────────────────────────────────────╮
│ USAGE MONITOR           ■ account ■ this session ░ free   [x] │
│ 5h [██████░░░░░░░░░░░░░░░░░░] 12.0% +3.1% ⟳ 4h51m             │
│ 7d [█░░░░░░░░░░░░░░░░░░░░░░░]  4.0% +0.4% ⟳ 4d19h             │
│ ses 445.1k tok │ in 16.3k out 3.7k cache 425.0k │ cost $1.85  │
╰──────────────────────────────────────────────────────────────╯
```

- **5h / 7d**: アカウントのレート制限の使用率。バーのうち、マゼンタがこのセッションで使った分、シアンがそれ以外、`░` が空き。右端はリセットまでの時間。
- **+x.x%**: このセッションで最初に読み取れた使用率からの増分（再起動すると 0 に戻ります）。
- **ses**: このセッションの合計トークン（入力・出力・キャッシュ）と、in / out / cache の内訳、費用。
- サブスクリプションでない環境など、レート制限の値が取れない場合は「waiting for the first rate-limit reading…」と出ます。

## インストール

ターミナルの Claude Code セッションで次を入力します。`<owner>` は、このリポジトリ（`claude-usage-monitor`）を置いている GitHub のユーザー名または組織名に置き換えてください。

```
/plugin install usage-monitor --marketplace <owner>/claude-usage-monitor
```

`Add marketplace?` には `y`、続くスコープ選択は Enter（user スコープ）で進めます。ローカルのフォルダから入れる場合は、`<owner>/claude-usage-monitor` の代わりにクローンしたフォルダのパスを指定できます。

`/usage-monitor` でバンドの表示/非表示を切り替えられます（`[x]` でも隠せます）。

### クローン／tarball からインストール（`scripts/install.sh`）

リポジトリをクローン（または tarball を展開）したフォルダから、コピー先を選んでインストールできます。コピーしたあと `claude plugin marketplace add` と `claude plugin install` まで実行します。

```sh
bash scripts/install.sh                  # ユーザー: ~/.claude/plugins/claude-usage-monitor へコピー（user スコープ）
bash scripts/install.sh --project [DIR]  # リポジトリ: DIR(省略時はカレント)/.claude/plugins/claude-usage-monitor へコピー（project スコープ）
bash scripts/install.sh --target DIR     # 任意: DIR/claude-usage-monitor へコピー（user スコープ）
```

| オプション | 意味 |
|---|---|
| `-y`, `--yes` | 確認なしで実行 |
| `--no-register` | コピーだけ行い、`claude` への登録はしない |
| `--dry-run` | 何も変更せず、実行内容だけ表示 |

- プラグインはコピー先から読み込まれます。インストール後にコピー先を移動・削除しないでください。
- マーケットプレイス名 `claude-usage-monitor` の登録は 1 つだけです（user / project 共通）。既に別の登録元（GitHub など）で入れている場合は、実行前の表示で警告し、登録先が付け替わります。
- `--project` の設定は `<DIR>/.claude/settings.json` に絶対パスで書かれます。チームで共有する場合は、各自が `install.sh` を実行してください。
- 更新するときは、新しい内容を取得したうえで同じコマンドをもう一度実行し、`/reload-plugins` を入力します。

## 配り方・入れ方の詳しい手順（非エンジニア向け）

[docs/share-and-install-guide.md](docs/share-and-install-guide.md) に、配る人・使う人それぞれの手順、画面の見方、オフ・削除の方法、困ったときの対処をまとめています。

## 開発
開発中の確認用コマンドです。
- 設定とコードの形を検証し、テストでロジックを確かめ、実際に起動して画面の動きを見ます
- 形（validate）→ ロジック（test）→ 実際の動き（--plugin-dir）の順に確認します

```sh
claude plugin validate .
claude plugin test .
claude --plugin-dir .
```

## ライセンス

[MIT](LICENSE)

---

🤖 Built with [Claude Code](https://claude.com/claude-code)

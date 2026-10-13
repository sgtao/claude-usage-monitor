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

## 開発

```
claude plugin validate .
claude plugin test .
claude --plugin-dir .
```

## ライセンス

[MIT](LICENSE)

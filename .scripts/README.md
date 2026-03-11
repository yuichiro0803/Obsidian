# 📜 スクリプト | push_to_github_issues.py

## 概要

`🏫 Enablement` フォルダ内の Markdown ファイルを、`yuichiro0803/Obsidian` の GitHub Issues に同期するスクリプト。

---

## 必要なもの

- **GitHub CLI（gh）**: インストール済みの前提
- **Python 3**: macOS には標準搭載

---

## 初回セットアップ

ターミナルで以下を実行（初回のみ）

```bash
gh auth login
```

---

## 実行方法

```bash
cd ~/Desktop/Obsidian
python3 .scripts/push_to_github_issues.py
```

---

## 動作の仕組み

| 状態 | 処理 |
|------|------|
| 初めてのファイル | GitHub Issue を新規作成 |
| 内容が変わっていないファイル | スキップ（変更なし） |
| 内容が変わったファイル | 既存の Issue を更新 |
| `README.md` | 常にスキップ |

---

## 管理ファイル

`.scripts/.issue_tracker.json` に、Issue番号・URL・ファイルハッシュを自動記録。手動で編集しないこと。

---

## Issue のラベル

自動で `enablement` ラベル（青）が付与される。なければ自動作成。

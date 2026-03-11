#!/usr/bin/env python3
"""
push_to_github_issues.py

Obsidian の 🏫 Enablement フォルダ内の Markdown ファイルを
GitHub Issues に同期するスクリプト（半自動・手動実行）

使い方:
    python3 .scripts/push_to_github_issues.py

実行前に:
    gh auth login  # GitHub CLIのログイン（初回のみ）
"""

import os
import subprocess
import json
import glob
import hashlib

# ===== 設定 =====
REPO = "yuichiro0803/Obsidian"
ENABLEMENT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "📁 Projects", "📖 Docs", "業務ヒアリング力の強化", "🏫 Enablement"
)
LABEL_NAME = "enablement"
LABEL_COLOR = "0075ca"
LABEL_DESCRIPTION = "業務ヒアリング力強化 チーム育成・勉強会"
TRACKER_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".issue_tracker.json")
SKIP_FILES = {"README.md"}  # Issue化しないファイル


# ===== ユーティリティ =====

def load_tracker() -> dict:
    """発行済みIssueのトラッカーを読み込む"""
    if os.path.exists(TRACKER_FILE):
        with open(TRACKER_FILE, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_tracker(tracker: dict):
    """トラッカーを保存する"""
    with open(TRACKER_FILE, "w", encoding="utf-8") as f:
        json.dump(tracker, f, indent=2, ensure_ascii=False)


def file_hash(filepath: str) -> str:
    """ファイルのMD5ハッシュを返す（変更検知に使用）"""
    with open(filepath, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()


def extract_title(content: str, fallback: str) -> str:
    """Markdownの最初のH1見出しをタイトルとして取得する"""
    for line in content.split("\n"):
        if line.startswith("# "):
            return line[2:].strip()
    return fallback


def run_gh(*args) -> tuple[int, str, str]:
    """gh コマンドを実行して (returncode, stdout, stderr) を返す"""
    result = subprocess.run(
        ["gh", *args],
        capture_output=True,
        text=True,
        encoding="utf-8"
    )
    return result.returncode, result.stdout.strip(), result.stderr.strip()


# ===== メイン処理 =====

def ensure_label():
    """ラベルが存在しなければ作成する"""
    code, out, _ = run_gh("label", "list", "--repo", REPO, "--json", "name")
    if code == 0:
        labels = [l["name"] for l in json.loads(out or "[]")]
        if LABEL_NAME not in labels:
            run_gh(
                "label", "create", LABEL_NAME,
                "--repo", REPO,
                "--color", LABEL_COLOR,
                "--description", LABEL_DESCRIPTION
            )
            print(f"🏷️  ラベル作成: {LABEL_NAME}")


def create_issue(title: str, body_file: str) -> tuple[int | None, str | None]:
    """GitHub Issue を新規作成し、(issue_number, url) を返す"""
    code, out, err = run_gh(
        "issue", "create",
        "--repo", REPO,
        "--title", title,
        "--body-file", body_file,
        "--label", LABEL_NAME
    )
    if code == 0 and out:
        url = out.split("\n")[-1]  # 最後の行にURLが出力される
        number = int(url.rstrip("/").split("/")[-1])
        return number, url
    else:
        print(f"  ❌ エラー: {err}")
        return None, None


def update_issue(issue_number: int, title: str, body_file: str) -> bool:
    """既存の GitHub Issue を更新する"""
    code, _, err = run_gh(
        "issue", "edit", str(issue_number),
        "--repo", REPO,
        "--title", title,
        "--body-file", body_file
    )
    if code != 0:
        print(f"  ❌ エラー: {err}")
    return code == 0


def main():
    print(f"\n📂 Enablement フォルダ: {ENABLEMENT_DIR}")
    print(f"🔗 対象リポジトリ: {REPO}\n")

    # --- 前提チェック ---
    code, _, err = run_gh("auth", "status")
    if code != 0:
        print("❌ GitHub CLI がログインされていません。以下を実行してください:")
        print("   gh auth login")
        return

    ensure_label()

    tracker = load_tracker()
    md_files = sorted(glob.glob(os.path.join(ENABLEMENT_DIR, "*.md")))

    if not md_files:
        print("⚠️  Markdownファイルが見つかりませんでした。")
        return

    for filepath in md_files:
        filename = os.path.basename(filepath)

        # スキップ対象
        if filename in SKIP_FILES:
            print(f"⏭️  スキップ: {filename}")
            continue

        with open(filepath, encoding="utf-8") as f:
            content = f.read()

        title = extract_title(content, filename.replace(".md", ""))
        current_hash = file_hash(filepath)

        print(f"📄 {filename}")
        print(f"   タイトル: {title}")

        if filename in tracker:
            # すでにIssue化済み
            if tracker[filename]["hash"] == current_hash:
                print(f"   ✅ 変更なし（Issue #{tracker[filename]['issue_number']} はスキップ）\n")
                continue
            else:
                # ファイルが更新されている → Issue を更新
                issue_number = tracker[filename]["issue_number"]
                print(f"   🔄 更新中... → Issue #{issue_number}")
                if update_issue(issue_number, title, filepath):
                    tracker[filename]["hash"] = current_hash
                    tracker[filename]["title"] = title
                    print(f"   ✅ 更新完了\n")
                else:
                    print(f"   ❌ 更新失敗\n")
        else:
            # 新規作成
            print(f"   🆕 Issue を新規作成中...")
            issue_number, url = create_issue(title, filepath)
            if issue_number:
                tracker[filename] = {
                    "issue_number": issue_number,
                    "title": title,
                    "url": url,
                    "hash": current_hash
                }
                print(f"   ✅ 作成完了: {url}\n")
            else:
                print(f"   ❌ 作成失敗\n")

        save_tracker(tracker)

    print("🎉 同期完了！")
    print(f"\n📋 発行済みIssue一覧:")
    for fname, info in tracker.items():
        print(f"  #{info['issue_number']:>4} | {info['title']}")
        print(f"         {info['url']}")


if __name__ == "__main__":
    main()

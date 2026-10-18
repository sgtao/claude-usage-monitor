#!/usr/bin/env bash
# =============================================================================
# setup-hooks.sh — この clone で .githooks/ の Git フック（pre-push）を有効にする
#
# Usage:
#   bash scripts/setup-hooks.sh            # core.hooksPath を .githooks に設定
#   bash scripts/setup-hooks.sh --remove   # 設定を解除（フックを無効化）
#
# 設定はこの clone の .git/config にだけ書かれる（他のリポジトリには影響しない）。
# =============================================================================
set -euo pipefail

HOOKS_DIR=".githooks"

error() { printf "[ERROR] %s\n" "$*" >&2; }
info()  { printf "[INFO] %s\n" "$*"; }

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd -P)"

if ! git -C "${root}" rev-parse --is-inside-work-tree &>/dev/null; then
  error "Git リポジトリではありません（tarball の展開先など）: ${root}"
  exit 1
fi

current="$(git -C "${root}" config --local --get core.hooksPath || true)"

if [[ "${1:-}" == "--remove" ]]; then
  if [[ "${current}" == "${HOOKS_DIR}" ]]; then
    git -C "${root}" config --local --unset core.hooksPath
    info "フックを無効化しました"
  else
    info "${HOOKS_DIR} は設定されていません（現在: ${current:-未設定}）"
  fi
  exit 0
fi

if [[ -n "${current}" && "${current}" != "${HOOKS_DIR}" ]]; then
  error "core.hooksPath が既に別の値です: ${current}（上書きしません）"
  exit 1
fi

chmod +x "${root}/${HOOKS_DIR}"/*
git -C "${root}" config --local core.hooksPath "${HOOKS_DIR}"
info "有効化しました: core.hooksPath = ${HOOKS_DIR}"
info "git push の前に claude plugin validate / test が実行されます（回避: git push --no-verify）"

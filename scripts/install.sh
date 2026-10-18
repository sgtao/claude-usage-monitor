#!/usr/bin/env bash
# =============================================================================
# install.sh — claude-usage-monitor（プラグイン usage-monitor）のインストール支援
#
# クローン／tarball を展開したこのリポジトリの内容を、指定の場所へコピーし、
# Claude Code に登録（claude plugin marketplace add + install）する。
#
# Usage:
#   bash scripts/install.sh                     # ユーザー: ~/.claude/plugins へコピー → user スコープで登録
#   bash scripts/install.sh --project [DIR]     # リポジトリ: DIR(省略時はカレント)/.claude/plugins へコピー → project スコープで登録
#   bash scripts/install.sh --target DIR        # 任意: DIR へコピー → user スコープで登録
#   bash scripts/install.sh --help              # ヘルプ表示
#
# Options:
#   -y, --yes        確認なしで実行（CI / 自動化向け）
#   --no-register    コピーだけ行い、claude への登録はしない
#   --dry-run        何も変更せず、実行内容だけ表示
#
# Environment variables:
#   CLAUDE_PLUGINS_DIR  - ユーザーモードのコピー先を上書き（デフォルト: ~/.claude/plugins）
# =============================================================================
set -euo pipefail

# ─── 設定 ─────────────────────────────────────────────────────────────────────
PLUGINS_DIR_DEFAULT="${HOME}/.claude/plugins"
PAYLOAD_ITEMS=".claude-plugin hooks types docs README.md README.ja.md LICENSE"   # コピー対象（.git などは含めない）
MODE=""            # user | project | target
PROJECT_DIR=""     # --project のリポジトリ
TARGET_DIR=""      # --target のコピー先
ASSUME_YES=0       # -y / --yes で 1
DRY_RUN=0          # --dry-run で 1
REGISTER=1         # --no-register で 0

# ─── 色定義（TTY 時のみ有効） ─────────────────────────────────────────────────
if [ -t 1 ]; then
  C_INFO='\033[0;34m' C_WARN='\033[0;33m' C_ERR='\033[0;31m'
  C_OK='\033[0;32m'   C_BOLD='\033[1m'    C_RESET='\033[0m'
else
  C_INFO='' C_WARN='' C_ERR='' C_OK='' C_BOLD='' C_RESET=''
fi

# ─── ログヘルパー ─────────────────────────────────────────────────────────────
info()    { printf "${C_INFO}${C_BOLD}[INFO]${C_RESET} %s\n"    "$*"; }
warn()    { printf "${C_WARN}${C_BOLD}[WARN]${C_RESET} %s\n"    "$*"; }
error()   { printf "${C_ERR}${C_BOLD}[ERROR]${C_RESET} %s\n"    "$*" >&2; }
success() { printf "${C_OK}${C_BOLD}[OK]${C_RESET} %s\n"        "$*"; }

# ─── ヘルプ ───────────────────────────────────────────────────────────────────
usage() {
  cat <<'EOF'
install.sh — usage-monitor プラグインのインストール支援

Usage:
  bash scripts/install.sh                  ~/.claude/plugins へコピーし、user スコープで登録
  bash scripts/install.sh --project [DIR]  DIR(省略時はカレント)/.claude/plugins へコピーし、project スコープで登録
  bash scripts/install.sh --target DIR     DIR へコピーし、user スコープで登録
  bash scripts/install.sh --help           このヘルプを表示

Options:
  -y, --yes        確認なしで実行
  --no-register    コピーだけ行い、claude への登録はしない
  --dry-run        何も変更せず、実行内容だけ表示

Environment:
  CLAUDE_PLUGINS_DIR   ユーザーモードのコピー先を上書き（デフォルト: ~/.claude/plugins）

コピー先は <場所>/claude-usage-monitor になる。プラグインはこの場所から読み込まれる
ため、インストール後にこのフォルダを移動・削除しないこと。
EOF
}

# ─── リポジトリルート（scripts/ の1つ上）を解決 ───────────────────────────────
resolve_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. && pwd -P
}

# ─── JSON から最初の "key": "value" の value を取り出す（jq 不要） ────────────
json_first_string() {
  local file="$1" key="$2"
  sed -n "s/.*\"${key}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "${file}" | head -n 1
}

# ─── 相対パス・~ を含まない絶対パスへ解決（存在するディレクトリ用） ────────────
abs_dir() {
  ( cd "$1" 2>/dev/null && pwd -P )
}

# ─── 登録済みマーケットプレイスの登録元を返す（例: "Folder (/path)" "GitHub (owner/repo)"。未登録・取得失敗なら空） ─
registered_marketplace_source() {
  local name="$1"
  claude plugin marketplace list 2>/dev/null | awk -v n="${name}" '
    $1 == "❯" { f = ($2 == n); next }
    f && /Source: / { sub(/^[[:space:]]*Source: /, ""); sub(/[[:space:]]+$/, ""); print; exit }'
}

# ─── 確認ゲート（y/Y のときのみ 0 を返す） ────────────────────────────────────
confirm() {
  local answer
  printf "%b[CONFIRM]%b %s [y/N] " "${C_BOLD}" "${C_RESET}" "$1"
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]]
}

# ─── 登録コマンドを claude 実行ディレクトリ付きで流す ─────────────────────────
run_claude() {
  ( cd "${RUN_DIR}" && claude plugin "$@" )
}

# ─── コピー（既存の同名インストールは中身を入れ替える） ────────────────────────
copy_payload() {
  local root="$1" dest="$2" item
  mkdir -p "${dest}"
  for item in ${PAYLOAD_ITEMS}; do
    [[ -e "${root}/${item}" ]] || continue
    rm -rf "${dest:?}/${item}"
    cp -R "${root}/${item}" "${dest}/"
  done
}

# ─── エントリポイント ─────────────────────────────────────────────────────────
main() {
  # 引数解析
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --user)
        [[ -z "${MODE}" ]] || { error "--user / --project / --target は同時に指定できません"; exit 1; }
        MODE="user" ;;
      --project)
        [[ -z "${MODE}" ]] || { error "--user / --project / --target は同時に指定できません"; exit 1; }
        MODE="project"
        if [[ $# -gt 1 && "$2" != -* ]]; then PROJECT_DIR="$2"; shift; fi ;;
      --target)
        [[ -z "${MODE}" ]] || { error "--user / --project / --target は同時に指定できません"; exit 1; }
        MODE="target"
        if [[ $# -lt 2 || "$2" == -* ]]; then error "--target にはディレクトリを指定してください"; exit 1; fi
        TARGET_DIR="$2"; shift ;;
      -y|--yes)      ASSUME_YES=1 ;;
      --no-register) REGISTER=0 ;;
      --dry-run)     DRY_RUN=1 ;;
      -h|--help)     usage; exit 0 ;;
      *)             error "不明な引数: $1"; usage; exit 1 ;;
    esac
    shift
  done
  [[ -n "${MODE}" ]] || MODE="user"

  # ソース（このリポジトリ）の検証と名前の取得
  local root plugin_name market_name
  root="$(resolve_root)"
  if [[ ! -f "${root}/.claude-plugin/plugin.json" || ! -f "${root}/.claude-plugin/marketplace.json" ]]; then
    error ".claude-plugin/plugin.json または marketplace.json が見つかりません: ${root}"
    exit 1
  fi
  plugin_name="$(json_first_string "${root}/.claude-plugin/plugin.json" name)"
  market_name="$(json_first_string "${root}/.claude-plugin/marketplace.json" name)"
  if [[ -z "${plugin_name}" || -z "${market_name}" ]]; then
    error "プラグイン名・マーケットプレイス名を JSON から読み取れませんでした"
    exit 1
  fi

  # モードごとの コピー先の親ディレクトリ / スコープ / claude 実行ディレクトリ
  local base scope
  RUN_DIR="${HOME}"
  case "${MODE}" in
    user)
      base="${CLAUDE_PLUGINS_DIR:-$PLUGINS_DIR_DEFAULT}"
      scope="user" ;;
    project)
      [[ -n "${PROJECT_DIR}" ]] || PROJECT_DIR="$(pwd -P)"
      if [[ ! -d "${PROJECT_DIR}" ]]; then error "リポジトリのディレクトリが存在しません: ${PROJECT_DIR}"; exit 1; fi
      PROJECT_DIR="$(abs_dir "${PROJECT_DIR}")"
      base="${PROJECT_DIR}/.claude/plugins"
      scope="project"
      RUN_DIR="${PROJECT_DIR}" ;;
    target)
      base="${TARGET_DIR}"
      scope="user" ;;
  esac

  # コピー先の絶対パス（親が未作成でも解決できるよう、存在する祖先から組み立てる）
  local dest in_place=0
  dest="${base}/${market_name}"
  case "${dest}" in
    /*) ;;
    *)  dest="$(pwd -P)/${dest#./}" ;;
  esac
  dest="${dest%/}"
  if [[ -d "${dest}" ]]; then
    dest="$(abs_dir "${dest}")"
    [[ "${dest}" == "${root}" ]] && in_place=1
  fi

  # 既存のコピー先が「このプラグインのインストール」でなければ触らない
  if [[ -e "${dest}" && "${in_place}" -eq 0 && ! -f "${dest}/.claude-plugin/marketplace.json" ]]; then
    if [[ -n "$(ls -A "${dest}" 2>/dev/null)" ]]; then
      error "コピー先が既に存在し、このプラグインのインストールではないため中止します: ${dest}"
      exit 1
    fi
  fi

  # claude の有無と、既存登録の確認
  local have_claude=0 current_source=""
  if command -v claude &>/dev/null; then
    have_claude=1
    current_source="$(registered_marketplace_source "${market_name}" || true)"
  fi
  if [[ "${REGISTER}" -eq 1 && "${have_claude}" -eq 0 ]]; then
    warn "claude コマンドが見つかりません。コピーのみ行い、登録コマンドを案内します"
    REGISTER=0
  fi

  # 実行内容の表示
  echo ""
  info "モード      : ${MODE}（スコープ: ${scope}）"
  info "コピー元    : ${root}"
  if [[ "${in_place}" -eq 1 ]]; then
    info "コピー先    : ${dest}（コピー元と同じ場所のため、コピーせず登録のみ）"
  else
    info "コピー先    : ${dest}"
    [[ -d "${dest}" ]] && warn "既存のインストールを入れ替えます: ${dest}"
  fi
  if [[ "${REGISTER}" -eq 1 ]]; then
    info "登録        : claude plugin marketplace add ${dest} --scope ${scope}"
    info "              claude plugin install ${plugin_name}@${market_name} --scope ${scope}"
    if [[ -n "${current_source}" && "${current_source}" != "Folder (${dest})" ]]; then
      warn "マーケットプレイス '${market_name}' は既に別の登録元で登録されています: ${current_source}"
      warn "  登録は名前ごとに1つだけ（user / project 共通）。実行すると ${dest} に付け替わり、"
      warn "  インストール済みの ${plugin_name} も以後ここから更新されます"
    fi
  else
    info "登録        : しない"
  fi
  echo ""

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    info "--dry-run のため、何も変更していません"
    exit 0
  fi

  # 確認ゲート
  if [[ "${ASSUME_YES}" -ne 1 ]]; then
    if [ ! -t 0 ]; then
      warn "非対話環境のため確認をスキップしました。実行するには -y を付けてください"
      exit 0
    fi
    if ! confirm "上記の内容で実行しますか？"; then
      info "中止しました"
      exit 0
    fi
  fi

  # コピー
  if [[ "${in_place}" -eq 0 ]]; then
    copy_payload "${root}" "${dest}"
    dest="$(abs_dir "${dest}")"
    success "コピー完了: ${dest}"
  fi

  # 登録
  if [[ "${REGISTER}" -eq 1 ]]; then
    if ! run_claude marketplace add "${dest}" --scope "${scope}"; then
      error "マーケットプレイスの登録に失敗しました。手動で実行してください:"
      error "  claude plugin marketplace add \"${dest}\" --scope ${scope}"
      error "  claude plugin install ${plugin_name}@${market_name} --scope ${scope}"
      exit 1
    fi
    if ! run_claude install "${plugin_name}@${market_name}" --scope "${scope}"; then
      error "プラグインのインストールに失敗しました。手動で実行してください:"
      error "  claude plugin install ${plugin_name}@${market_name} --scope ${scope}"
      exit 1
    fi
    success "登録完了: ${plugin_name}@${market_name}（スコープ: ${scope}）"
    info "起動中の Claude Code では /reload-plugins を入力するか、起動し直してください"
    if [[ "${MODE}" == "project" ]]; then
      info "project スコープの設定は ${PROJECT_DIR}/.claude/settings.json に書かれます（コピー先は絶対パスで記録されます）"
    fi
  else
    info "あとで登録するときは、次の2行を実行してください:"
    info "  claude plugin marketplace add \"${dest}\" --scope ${scope}"
    info "  claude plugin install ${plugin_name}@${market_name} --scope ${scope}"
  fi
}

main "$@"

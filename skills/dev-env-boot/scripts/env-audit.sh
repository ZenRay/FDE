#!/usr/bin/env bash
# env-audit.sh — 只读开发环境审计（dev-env-boot skill）
# 用法: bash env-audit.sh [project-dir]   默认当前目录
# 退出码: 0=全PASS  1=有WARN  2=有FAIL
# 严格只读：除 stdout 外不写任何东西
set -u
DIR="${1:-$PWD}"
WARN=0; FAIL=0
pass(){ printf 'PASS  %s\n' "$*"; }
info(){ printf 'INFO  %s\n' "$*"; }
warn(){ printf 'WARN  %s\n' "$*"; WARN=1; }
fail(){ printf 'FAIL  %s\n' "$*"; FAIL=1; }

echo "== 1. 工具存在性 =="
for t in pyenv uv direnv; do
  if command -v "$t" >/dev/null 2>&1; then pass "$t: $(command -v "$t")"
  else warn "$t 未安装（项目需要时才装）"; fi
done
[ -s "$HOME/.nvm/nvm.sh" ] && pass "nvm: $HOME/.nvm/nvm.sh" || warn "nvm 未安装"
command -v java >/dev/null 2>&1 && info "java: $(java -version 2>&1 | head -1)" || info "java 未安装（按需）"

echo "== 2. shell hook (~/.bashrc) =="
BRC="$HOME/.bashrc"
if [ -f "$BRC" ]; then
  grep -q 'pyenv init' "$BRC" && pass "pyenv hook" || { command -v pyenv >/dev/null && fail "pyenv 已装但无 hook" || info "无 pyenv hook（未装 pyenv）"; }
  grep -q 'nvm.sh' "$BRC" && pass "nvm hook" || { [ -s "$HOME/.nvm/nvm.sh" ] && fail "nvm 已装但无 hook" || info "无 nvm hook"; }
  grep -q 'direnv hook bash' "$BRC" && pass "direnv hook" || { command -v direnv >/dev/null && fail "direnv 已装但无 hook" || info "无 direnv hook"; }
  [ -d "$HOME/.sdkman" ] && { grep -q 'sdkman-init.sh' "$BRC" && pass "sdkman hook" || fail "sdkman 已装但无 hook"; }
else
  warn "~/.bashrc 不存在"
fi

echo "== 3. 遗留问题 =="
if [ -f "$BRC" ]; then
  if grep -qE '^export PATH="[^"]*\.nvm/versions/node' "$BRC"; then
    warn "bashrc 硬编码 nvm node PATH（绕过 nvm 版本管理，陷阱#5）"
  else pass "无硬编码 node PATH"; fi
fi
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  DEF=$(bash -c 'source "$HOME/.nvm/nvm.sh"; nvm alias default 2>/dev/null' | head -1)
  case "$DEF" in *"N/A"*|"") warn "nvm default 别名解析异常: ${DEF:-空}（陷阱#4）";; *) pass "nvm default: $DEF";; esac
fi

echo "== 4. 项目: $DIR =="
if [ -f "$DIR/.python-version" ]; then
  PV=$(head -1 "$DIR/.python-version")
  if [ -d "$HOME/.pyenv/versions/$PV" ]; then pass ".python-version $PV 已安装"
  else fail ".python-version $PV 未在 pyenv 安装"; fi
else info "无 .python-version"; fi
if [ -f "$DIR/.nvmrc" ]; then
  NV=$(head -1 "$DIR/.nvmrc"); NV="${NV#v}"
  if ls -d "$HOME/.nvm/versions/node/v$NV"* >/dev/null 2>&1; then pass ".nvmrc v$NV 已安装"
  else fail ".nvmrc v$NV 未在 nvm 安装"; fi
else info "无 .nvmrc"; fi
if [ -f "$DIR/.envrc" ]; then
  pass ".envrc 存在"
  # 剥离注释后再匹配，防止注释文字（如"无 use nvm"）造成误报
  ENVRC_CODE=$(grep -vE '^[[:space:]]*#' "$DIR/.envrc")
  grep -q 'use nvm' <<<"$ENVRC_CODE" && warn ".envrc 含 'use nvm'：direnv stdlib 无此命令，静默无效（陷阱#1）"
  grep -qE '\|\|[[:space:]]*true' <<<"$ENVRC_CODE" && warn ".envrc 含 '|| true'：静默吞错（陷阱#8）"
  if command -v direnv >/dev/null 2>&1; then
    ST=$(cd "$DIR" && direnv status 2>/dev/null | grep -oE 'Found RC allowed [0-9]+' | grep -oE '[0-9]+$')
    case "${ST:-x}" in
      0) pass "direnv 授权: allowed";;
      1) warn ".envrc 未授权(blocked)：direnv 跳过加载，需 direnv allow .（陷阱#9）";;
      2) fail ".envrc 被 deny 封禁：完全静默跳过（无输出无报错），需 direnv allow . 解除（陷阱#9）";;
      *) info "direnv 授权状态无法解析（direnv status 输出异常）";;
    esac
  fi
else
  [ -d "$DIR/.venv" ] && warn "有 .venv 但无 .envrc（进目录不会自动激活）" || info "无 .envrc"
fi
if [ -f "$DIR/.venv/pyvenv.cfg" ]; then
  H=$(grep '^home' "$DIR/.venv/pyvenv.cfg" | cut -d= -f2 | tr -d ' ')
  case "$H" in *"/.pyenv/versions/"*) pass ".venv 解释器来自 pyenv: $H";;
    *) fail ".venv 解释器非 pyenv（uv 越权下载，陷阱#6）: $H";; esac
fi

echo "== 5. gitignore 锚定抽查 =="
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GI=$(git -C "$DIR" rev-parse --show-toplevel)/.gitignore
  if [ -f "$GI" ]; then
    HIT=0
    while IFS= read -r p; do
      d="${p%/}"
      T=$(git -C "$DIR" ls-files -- "*/$d/*" | head -1)
      N=$(find "$DIR" -mindepth 2 -maxdepth 6 -type d -name "$d" -not -path '*/.git/*' 2>/dev/null | head -1)
      if [ -n "$T" ] && [ -n "$N" ]; then
        warn "gitignore 非锚定 '$p' 命中含已跟踪文件的嵌套目录 $N（陷阱#7：新文件会被静默忽略；仅根意图请写 /$d/）"; HIT=1
      fi
    done < <(grep -E '^[A-Za-z0-9_.-]+/$' "$GI")
    [ "$HIT" = 0 ] && pass "无非锚定误伤"
  else info "无 .gitignore"; fi
else info "非 git 仓库，跳过"; fi

echo "== 结果: WARN=$WARN FAIL=$FAIL =="
[ "$FAIL" = 1 ] && exit 2; [ "$WARN" = 1 ] && exit 1; exit 0

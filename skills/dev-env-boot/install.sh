#!/usr/bin/env bash
# install.sh — 复制安装 dev-env-boot 技能快照到 ~/.claude/skills/
# 语义：无目标→安装；有 .installed-from 标记→更新快照；无标记的已有目录→拒绝覆盖
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/skills/dev-env-boot"
MARKER=".installed-from"

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$DEST/$MARKER" ]; then rm -rf "$DEST"; echo "uninstalled: $DEST"
  elif [ -e "$DEST" ]; then echo "错误: $DEST 无 $MARKER 标记（非本技能快照），拒绝删除" >&2; exit 1
  else echo "本就未安装: $DEST"; fi
  exit 0
fi

mkdir -p "$HOME/.claude/skills"
if [ -e "$DEST" ] && [ ! -f "$DEST/$MARKER" ]; then
  echo "错误: $DEST 已存在且非本技能快照（无 $MARKER）——拒绝覆盖，请手动移走后重试" >&2; exit 1
fi
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
echo "$SRC" > "$DEST/$MARKER"
[ -f "$DEST/SKILL.md" ] || { echo "错误: 安装后 SKILL.md 不可读" >&2; exit 1; }
echo "installed: $DEST (快照来源: $SRC)"
echo "提示: 新会话生效；仓库源码迭代后重跑本脚本发布新快照"

#!/bin/bash
# 云端容器里搭测试环境：zsh、与环境登记同版本的 Godot Linux 版、转换产物、导入缓存。可重复运行。
# 用法：bash 03_再刷重制_Godot/07_开发环境/云端准备.sh [转换产物打包.tgz]
# 跑完照提示 export GODOT=… 后再跑 检查.sh。说明见 云端测试.md。
set -euo pipefail
ENV_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT="$ENV_DIR/../01_Godot工程"
GENERATED="$PROJECT/modes/xiyou/generated"
TGZ="${1:-${XIYOU_GENERATED_TGZ:-/mnt/project-files/云端测试/generated.tgz}}"
log() { echo "[云端准备] $*" >&2; }

if ! command -v zsh >/dev/null 2>&1; then
  log "安装 zsh"
  (apt-get update -qq && apt-get install -y -qq zsh) >/dev/null 2>&1 || true
  command -v zsh >/dev/null 2>&1 || log "zsh 安装失败"
fi

VERSION=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$ENV_DIR/环境登记.json")
GDIR="$HOME/.cache/xiyou-godot/$VERSION"
GODOT="$GDIR/Godot_v${VERSION}-stable_linux.x86_64"
if [ ! -x "$GODOT" ]; then
  log "下载 Godot $VERSION Linux 版并校验 SHA512"
  mkdir -p "$GDIR"
  base="https://github.com/godotengine/godot-builds/releases/download/${VERSION}-stable"
  zip="Godot_v${VERSION}-stable_linux.x86_64.zip"
  (cd "$GDIR" && curl -fsSLO "$base/$zip" && curl -fsSLO "$base/SHA512-SUMS.txt" \
    && grep " $zip\$" SHA512-SUMS.txt | sha512sum -c - >/dev/null && unzip -oq "$zip" && rm -f "$zip")
fi
"$GODOT" --headless --version >/dev/null

if [ ! -f "$GENERATED/manifest.json" ]; then
  if [ -f "$TGZ" ]; then
    log "解开转换产物 $TGZ"
    tar -xzf "$TGZ" -C "$PROJECT"
  else
    log "没有转换产物打包（$TGZ）：内容相关的测试会失败，取法见 云端测试.md"
  fi
fi

if [ -f "$GENERATED/manifest.json" ] && [ ! -d "$PROJECT/.godot/imported" ]; then
  log "godot --import"
  timeout 900 "$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1 || log "导入返回非 0"
fi
echo "export GODOT=\"$GODOT\" CHECK_JOBS=$(nproc)"

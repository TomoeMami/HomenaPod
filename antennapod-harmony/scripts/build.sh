#!/usr/bin/env bash
# 构建入口：工具链可用时执行 DevEco 构建，否则提示阻塞。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v hvigorw >/dev/null 2>&1; then
  echo "ERROR: hvigorw not found. 请安装 DevEco Command Line Tools 并设置 DEVECO_SDK_HOME。"
  echo "参考: docs/toolchain-blocker.md"
  exit 1
fi

if [ -z "${DEVECO_SDK_HOME:-}" ]; then
  echo "WARN: DEVECO_SDK_HOME 未设置，将使用 hvigorw 默认 SDK 查找。"
fi

hvigorw clean --no-daemon
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
echo "BUILD OK"

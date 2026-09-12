#!/usr/bin/env bash
# 输出当前环境与工具链状态，用于判断是否能进行 DevEco 构建。
echo "== PWD =="; pwd
echo "== Node =="; node -v 2>&1 || echo "missing"
echo "== npm =="; npm -v 2>&1 || echo "missing"
echo "== Java =="; java -version 2>&1 | head -1 || echo "missing"
echo "== ohpm =="; command -v ohpm || echo "missing"
echo "== hvigorw =="; command -v hvigorw || echo "missing"
echo "== DEVECO_SDK_HOME =="; echo "${DEVECO_SDK_HOME:-<unset>}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HARMONY="$ROOT/antennapod-harmony"
echo "== 工作区根 =="; echo "$ROOT"
echo "== 工程文件数（不含 build/ 与依赖）=="; find "$HARMONY" -type f -not -path '*/build/*' -not -path '*/oh_modules/*' 2>/dev/null | wc -l
echo "== check-project =="; bash "$HARMONY/scripts/check-project.sh" >/tmp/ap-cc.log 2>&1 && tail -1 /tmp/ap-cc.log || echo "FAILED"

#!/usr/bin/env bash
# 输出当前环境与工具链状态，用于判断是否能进行 DevEco 构建。
echo "== PWD =="; pwd
echo "== Node =="; node -v 2>&1 || echo "missing"
echo "== npm =="; npm -v 2>&1 || echo "missing"
echo "== Java =="; java -version 2>&1 | head -1 || echo "missing"
echo "== ohpm =="; command -v ohpm || echo "missing"
echo "== hvigorw =="; command -v hvigorw || echo "missing"
echo "== DEVECO_SDK_HOME =="; echo "${DEVECO_SDK_HOME:-<unset>}"
echo "== 正确工作区 =="; ls -d /home/riko/homennapodcast 2>/dev/null || echo "missing"
echo "== 误路径残留 =="; ls -d /home/riko/homenpodcast 2>/dev/null || echo "none"
echo "== 工程文件数 =="; find /home/riko/homennapodcast/antennapod-harmony -type f 2>/dev/null | wc -l
echo "== check-project =="; bash /home/riko/homennapodcast/antennapod-harmony/scripts/check-project.sh >/tmp/ap-cc.log 2>&1 && tail -1 /tmp/ap-cc.log || echo "FAILED"

#!/usr/bin/env bash
# 静态类型检查（无 DevEco 工具链时的替代验证）
# 只检查非 ArkUI 声明式文件（pages/components 除外），平台 API 用桩声明模拟。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/antennapod-harmony/entry/src/main/ets"
TOOLS="$ROOT/antennapod-harmony/tools"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

python3 - "$SRC" "$WORK" <<'PY'
import os, shutil, glob, re, sys
src, dst = sys.argv[1], sys.argv[2]
for root, dirs, files in os.walk(src):
    rel = os.path.relpath(root, src)
    if rel.startswith('pages') or rel.startswith('components'):
        continue
    for f in files:
        if f.endswith('.ets'):
            outdir = os.path.join(dst, rel)
            os.makedirs(outdir, exist_ok=True)
            text = open(os.path.join(root, f)).read()
            lines = [line for line in text.splitlines()
                     if not re.match(r"\s*import\s+.*from\s+['\"]@(ohos|kit)\.", line)]
            open(os.path.join(outdir, f[:-4] + '.ts'), 'w').write('\n'.join(lines))
PY

cp "$TOOLS/platform-stubs.d.ts" "$WORK/platform.d.ts"
cat > "$WORK/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "ESNext",
    "moduleResolution": "node",
    "strict": false,
    "noEmit": true,
    "skipLibCheck": true
  },
  "include": ["**/*.ts", "platform.d.ts"]
}
JSON

cd "$WORK"
tsc -p tsconfig.json
echo "Static check passed ($(find "$WORK" -name '*.ts' | wc -l) TS files)."

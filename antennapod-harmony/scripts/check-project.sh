#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HARMONY="$ROOT/antennapod-harmony"
ETS="$HARMONY/entry/src/main/ets"
RES="$HARMONY/entry/src/main/resources"

# 1. 路径一致性：确认不存在路径笔误产生的副本目录
if [ -d /home/riko/homenpodcast ]; then
  echo "FAIL: 发现路径笔误副本 /home/riko/homenpodcast，请清理" >&2
  exit 1
fi
echo "OK 路径一致性"

# 2. 导入路径检查
python3 - "$ETS" <<'PY'
import os, re, glob, sys
base = sys.argv[1]
missing = []
for f in glob.glob(base + '/**/*.ets', recursive=True):
    txt = open(f).read()
    for m in re.finditer(r"from '(\.[^']+)'", txt):
        rel = m.group(1)
        b = os.path.dirname(f)
        cands = [os.path.join(b, rel), os.path.join(b, rel + '.ets'),
                 os.path.join(b, rel + '.ts'), os.path.join(b, rel, 'index.ets')]
        if not any(os.path.exists(c) for c in cands):
            missing.append((f, rel))
if missing:
    print('FAIL missing imports:')
    for f, r in missing:
        print(' ', f, '->', r)
    sys.exit(1)
print('OK 导入路径')
PY

# 3. 资源三语对齐
python3 - "$RES" <<'PY'
import json, os, sys
base = sys.argv[1]
def names(p):
    return set(i['name'] for i in json.load(open(os.path.join(base, p, 'element/string.json')))['string'])
b, z, e = names('base'), names('zh_CN'), names('en_US')
if b - z or b - e:
    print('FAIL resource mismatch:', b-z, b-e)
    sys.exit(1)
print('OK 资源三语 对齐', len(b))
PY

# 4. 页面注册
python3 - "$ETS" "$HARMONY" <<'PY'
import os, glob, json, sys
ets, harmony = sys.argv[1], sys.argv[2]
pages = set('pages/' + os.path.basename(f)[:-4] for f in glob.glob(ets + '/pages/*.ets')
            if '@Entry' in open(f).read())
registered = set(json.load(open(harmony + '/entry/src/main/resources/base/profile/main_pages.json'))['src'])
if pages - registered or registered - pages:
    print('FAIL page registration:', pages ^ registered)
    sys.exit(1)
print('OK 页面注册', len(pages))
PY

# 5. 全量非 UI 静态类型检查
bash "$HARMONY/scripts/static-check.sh"

# 6. 纯逻辑运行时断言
bash "$HARMONY/scripts/runtime-pure-test.sh"

echo "ALL PROJECT CHECKS PASSED"

#!/bin/zsh
# 共用提交前检查：Claude 与 Codex 每次提交前都跑这一条。
# 用法：03_再刷重制_Godot/07_开发环境/检查.sh [--oracle]
#   --oracle  另外启动 MV 参照引擎做一次启动检查（约 5 秒）
set -u
ENV_DIR=${0:A:h}
ROOT=${ENV_DIR:h:h}
PROJECT=$ROOT/03_再刷重制_Godot/01_Godot工程
GODOT=$ENV_DIR/godot
FAIL=0
ok()   { print -r -- "  ✓ $1"; }
bad()  { print -r -- "  ✗ $1"; FAIL=1; }

print "== 文档与登记"
python3 - "$ROOT" <<'PY' || FAIL=1
import json, re, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]); bad = []
files = subprocess.run(['git', '-c', 'core.quotePath=false', 'ls-files', '--cached', '--others', '--exclude-standard'],
                       cwd=root, capture_output=True, text=True).stdout.splitlines()
for rel in files:
    p = root / rel
    if not p.is_file():
        continue
    if p.suffix == '.json':
        try: json.loads(p.read_text())
        except Exception as e: bad.append(f'JSON 无效 {rel}: {e}')
    if p.suffix == '.md':
        for m in re.finditer(r'\]\((<[^>]+>|[^)\s]+)\)', p.read_text()):
            ref = m.group(1).strip('<>').split('#', 1)[0]
            if not ref or '://' in ref or ref.startswith('~'):
                continue
            target = Path(ref) if ref.startswith('/') else p.parent / ref
            if not target.exists(): bad.append(f'失效链接 {rel} -> {ref}')
dev = json.loads((root / '03_再刷重制_Godot/开发编号.json').read_text())['current']
proj = re.search(r'config/version="([^"]+)"', (root / '03_再刷重制_Godot/01_Godot工程/project.godot').read_text()).group(1)
build = json.loads((root / '03_再刷重制_Godot/01_Godot工程/content/build_info.json').read_text())['developmentVersion']
if not dev == proj == build:
    bad.append(f'开发编号不一致：开发编号.json={dev} project.godot={proj} build_info={build}')
for b in bad: print('  ✗ ' + b)
print(f'  ✓ JSON、链接、开发编号（{dev}）' if not bad else f'  共 {len(bad)} 项问题')
sys.exit(1 if bad else 0)
PY

print "== Godot 测试"
"$GODOT" --headless --path "$PROJECT" --import >/dev/null 2>&1
tests=("$PROJECT"/tests/*.tscn(N))
if (( ${#tests} == 0 )); then bad "tests/ 下没有测试场景"; fi
for t in $tests; do
  name=${t:t}
  # 每个测试最多 5 分钟；脚本语法错误时场景不会自行退出，超时即判失败
  out=$(perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$PROJECT" "res://tests/$name" 2>&1); rc=$?
  line=$(print -r -- "$out" | grep -m1 '^TEST_RESULT=')
  if (( rc == 0 )) && [[ -n $line ]] && ! print -r -- "$out" | grep -qE 'SCRIPT ERROR|^ERROR:'; then
    ok "$name ${line#TEST_RESULT=}" | cut -c1-120
  else
    bad "$name (rc=$rc)"; print -r -- "$out" | grep -E 'ERROR|FAIL |passed|TEST_RESULT' | head -8 | sed 's/^/      /'
  fi
done

if [[ ${1:-} == --oracle ]]; then
  print "== MV 参照引擎"
  oracle=$ROOT/03_再刷重制_Godot/03_转换工具/mv_oracle
  if [[ -d $oracle/node_modules ]]; then
    res=$(cd "$oracle" && node boot_check.cjs 2>/dev/null | tail -1)
    if print -r -- "$res" | grep -q '"db":true' && print -r -- "$res" | grep -q '"modulesFailed":\[\]'; then ok "$res" | cut -c1-120; else bad "参照引擎启动异常：$res"; fi
    if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/验证西游来源.py"; then ok "当前西游来源、转换产物、六难度参照同源"; else bad "西游来源/转换/参照不一致"; fi
  else
    bad "mv_oracle 未安装依赖（在该目录运行 npm install）"
  fi
fi

print "== Git"
git -C "$ROOT" -c core.quotePath=false status --short | sed 's/^/  /'
(( FAIL == 0 )) && print "全部通过" || print "有失败项，请先处理再提交"
exit $FAIL

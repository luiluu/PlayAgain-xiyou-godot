#!/bin/zsh
# 共用提交前检查：Claude 与 Codex 每次提交前都跑这一条。
# 用法：03_再刷重制_Godot/07_开发环境/检查.sh [--oracle]
#   在 worktree（多会话车道）里也可运行：测试自动只并行 2 个；交付单／开发编号占位检查只在主工作区做
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
gd = subprocess.run(['git', 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'], cwd=root, capture_output=True, text=True).stdout.split('\n')
in_worktree = len(gd) > 1 and gd[0] != gd[1]
main_root = Path(gd[1]).parent if in_worktree else root  # worktree 里不入 Git 的本地证据（验证与备份、本地结果）只在主工作区
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
            if not target.exists() and in_worktree and not ref.startswith('/'):
                try: target = main_root / (p.parent / ref).resolve().relative_to(root.resolve())
                except ValueError: pass
            if not target.exists(): bad.append(f'失效链接 {rel} -> {ref}')
dev = json.loads((root / '03_再刷重制_Godot/开发编号.json').read_text())['current']
proj = re.search(r'config/version="([^"]+)"', (root / '03_再刷重制_Godot/01_Godot工程/project.godot').read_text()).group(1)
build = json.loads((root / '03_再刷重制_Godot/01_Godot工程/content/build_info.json').read_text())['developmentVersion']
if not dev == proj == build:
    bad.append(f'开发编号不一致：开发编号.json={dev} project.godot={proj} build_info={build}')
state = json.loads((root / '00_项目管理/当前状态.json').read_text())
source = json.loads((root / '00_项目管理/来源登记.json').read_text())
remake = next(s for s in source['sources'] if s['id'] == 'new_godot_remake')
if state['godot']['developmentVersion'] != dev or remake['developmentVersion'] != dev:
    bad.append('当前状态／来源登记的开发编号与工程不一致')
# 多会话并行（AGENTS.md）：主工作区不应留有未并入的交付单或开发编号占位
if not in_worktree:
    left = [f for f in files if f.startswith('00_项目管理/交付/') and f != '00_项目管理/交付/README.md']
    if left: bad.append('交付单未并入：' + '、'.join(left))
    marker = 'dev.' + '待定'
    exempt = {'AGENTS.md', '00_项目管理/交付/README.md'}
    hits = [f for f in files if f not in exempt and f.endswith(('.md', '.json', '.gd', '.py', '.sh')) and (root / f).is_file()
            and marker in (root / f).read_text(errors='ignore')]
    if hits: bad.append(marker + ' 未替换：' + '、'.join(hits))
# 执行—核查双轨流程（AGENTS.md）：待交叉核查超过 10 行时提示（用户 2026-10-15 由 4 改 10）（不判失败，超限期间仍要能收工修复）
board = (root / '00_项目管理/交接板.md').read_text()
pending = board.split('## 待交叉核查', 1)[1].split('\n## ', 1)[0] if '## 待交叉核查' in board else ''
rows = [l for l in pending.splitlines() if l.startswith('| ') and not l.startswith('| 提交 ') and not l.startswith('| ---')]
if len(rows) > 10:
    print(f'  ⚠ 待交叉核查 {len(rows)} 行，超过 10 行上限：停派新车道、停新功能，先启动 Codex（沙僧）核查')
for b in bad: print('  ✗ ' + b)
print(f'  ✓ JSON、链接、开发编号（{dev}）' if not bad else f'  共 {len(bad)} 项问题')
sys.exit(1 if bad else 0)
PY

print "== Godot 测试"
import_out=$(perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$PROJECT" --import 2>&1); import_rc=$?
if (( import_rc != 0 )) || print -r -- "$import_out" | grep -qE 'SCRIPT ERROR|^ERROR:'; then
  bad "Godot 导入失败 (rc=$import_rc)"; print -r -- "$import_out" | grep -E 'ERROR|FAIL' | head -8
fi
# 测试并行运行（每个测试独立临时 HOME，互不干扰、不碰真实用户数据）；CHECK_JOBS=1 时逐个运行
if ! python3 "$ENV_DIR/并行测试.py" "$GODOT" "$PROJECT"; then FAIL=1; fi

print "== 参照工具访问守卫"
if node "$ROOT/03_再刷重制_Godot/03_转换工具/mv_oracle/guard_check.cjs"; then ok "MV 文件守卫"; else bad "MV 文件守卫"; fi
if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/ui_reference/guard_check.py"; then ok "界面参照服务守卫"; else bad "界面参照服务守卫"; fi
if python3 "$ENV_DIR/测试工作树清理.py" >/dev/null; then ok "工作树清理保护"; else bad "工作树清理保护"; fi

if [[ ${1:-} == --oracle ]]; then
  print "== MV 参照引擎"
  oracle=$ROOT/03_再刷重制_Godot/03_转换工具/mv_oracle
  if [[ -d $oracle/node_modules ]]; then
    res=$(cd "$oracle" && node boot_check.cjs); oracle_rc=$?
    if (( oracle_rc == 0 )) && python3 -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d.get("db") is True and d.get("modulesFailed")==[] and d.get("errors")==[] else 1)' "$res"; then ok "$res" | cut -c1-120; else bad "参照引擎启动异常：$res"; fi
    if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/验证西游来源.py"; then ok "当前西游来源、转换产物、六难度参照同源"; else bad "西游来源/转换/参照不一致"; fi
  else
    bad "mv_oracle 未安装依赖（在该目录运行 npm install）"
  fi
fi

print "== Git"
git -C "$ROOT" -c core.quotePath=false status --short | sed 's/^/  /'
(( FAIL == 0 )) && print "全部通过" || print "有失败项，请先处理再提交"
exit $FAIL

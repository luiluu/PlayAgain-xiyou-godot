#!/bin/zsh
# 共用提交前检查：Claude 与 Codex 每次提交前都跑这一条。
# 用法：03_再刷重制_Godot/07_开发环境/检查.sh [--oracle] [--full] [--affected <基准提交> [--cloud]]
#   在 worktree（多会话车道）里也可运行：测试自动只并行 2 个；交付单／开发编号占位检查只在主工作区做
#   --oracle  另外启动 MV 参照引擎做一次启动检查（约 5 秒）
#   --full    Godot 测试整轮重跑，不沿用上轮通过结果（也可 CHECK_FULL=1；沿用条件见 并行测试.py 文件头）
#   --affected <基准>  选测（三级检查②）：按 选测对照.json 只跑与「基准到工作区」改动相关的 Godot 场景和非 Godot 检查，
#             先打印选了什么、为什么；文档与登记检查照常；有拿不准的改动就整轮。不加时行为不变（全量）
#             选中的场景按工程指纹沿用上次通过结果（并行测试.py --reuse；--full 不沿用）
#   --cloud   只和 --affected 用：选中的 Godot 场景改在 GitHub Actions 云端跑（云端选测.py run＋wait，只测已提交的 HEAD、
#             基准是 GitHub 上的 main；文档、守卫、工具回归等非 Godot 检查照旧在本机跑）。云端不可用（推送失败、超时）直接判失败并提示
#             去掉 --cloud 改本机跑，不静默降级。环境变量：CHECK_CLOUD_NO_UPLOAD=1 不重传转换产物，CHECK_CLOUD_TIMEOUT=秒（默认 2700）
#   --keep-going  文档与登记检查（JSON／链接／开发编号）失败后仍跑 Godot 测试与其余检查（默认此时立即失败退出，免得白跑几十分钟）
set -u
ENV_DIR=${0:A:h}
ROOT=${ENV_DIR:h:h}
if [[ ${XIYOU_LONG_TASK_MANAGED:-0} != 1 ]]; then
  task_log=${XIYOU_TASK_LOG:-$ROOT/03_再刷重制_Godot/04_验证/本地结果/任务/check-$(date +%Y%m%d_%H%M%S)-$$.log}
  exec python3 "$ENV_DIR/长任务.py" run "$task_log" -- "${0:A}" "$@"
fi
PROJECT=$ROOT/03_再刷重制_Godot/01_Godot工程
GODOT=${GODOT:-$ENV_DIR/godot}   # 云端等没有本机 Godot.app 时用环境变量指定（见 云端测试.md）
FAIL=0
ORACLE=0; TEST_ARGS=(); AFFECTED=; KEEP_GOING=0; CLOUD=0
CLOUD_SCRIPT=${XIYOU_CLOUD_SCRIPT:-$ENV_DIR/云端选测.py}
while (( $# )); do
  case $1 in
    --oracle) ORACLE=1 ;;
    --full) TEST_ARGS+=(--full) ;;
    --keep-going) KEEP_GOING=1 ;;
    --cloud) CLOUD=1 ;;
    --affected) (( $# >= 2 )) || { print -r -- "--affected 要跟基准提交"; exit 2; }; AFFECTED=$2; shift ;;
    *) print -r -- "未知参数：$1（只认 --oracle、--full、--keep-going、--affected <基准>、--cloud）"; exit 2 ;;
  esac
  shift
done
(( ! CLOUD )) || [[ -n $AFFECTED ]] || { print -r -- "--cloud 只和 --affected 一起用（云端只做选测；整轮请在本机跑）"; exit 2; }
ok()   { print -r -- "  ✓ $1"; }
bad()  { print -r -- "  ✗ $1"; FAIL=1; FAIL_ITEMS+=("$1"); }
FAIL_ITEMS=()  # 收尾汇总用（哪吒_7 t4：失败项夹在长日志中间难找，Godot 场景带日志路径）
# xiyou_rules 按编号过滤只给车道专项用：检查（尤其整轮会被记作通过、下轮沿用）里不许带着它跑
if [[ -n ${RULES_ONLY_TROOPS:-}${RULES_ONLY_ACTORS:-} ]]; then
  print -r -- "环境里设了 RULES_ONLY_TROOPS／RULES_ONLY_ACTORS（只给车道专项用），先 unset 再跑检查"; exit 2
fi
# 选测：SEL_FULL=1 时与不加 --affected 完全相同；否则只跑 SEL_SCENES 与 SEL_CHECKS 选中的部分
SEL_FULL=1; SEL_SCENES=(); SEL_CHECKS=()
if [[ -n $AFFECTED ]]; then
  sel_out=$(python3 "$ENV_DIR/选测.py" "$AFFECTED" --root "$ROOT" --shell) || { print -r -- "选测失败，未运行检查"; exit 2; }
  eval "$sel_out"
fi
want() { (( SEL_FULL )) || (( ${SEL_CHECKS[(Ie)$1]} )); }

print "== 文档与登记"
python3 - "$ROOT" <<'PY' || FAIL=1
import json, re, subprocess, sys
from pathlib import Path
root = Path(sys.argv[1]); bad = []
# 历史只追加：防止合并交付单时把变更记录整页替换成当批条目；分卷＋当前卷连起来与 HEAD 比（规则：文件职责与记录「变更记录分卷」）
tools = root / '03_再刷重制_Godot/07_开发环境'
history = subprocess.run([sys.executable, str(tools / '变更记录分卷.py'), '--check', '--root', str(root)], capture_output=True, text=True)
if history.returncode: bad.append(history.stdout.strip().removeprefix('✗ ') or '变更记录分卷检查失败：' + history.stderr.strip()[-200:])
volumes = '00_项目管理/变更记录卷/'  # 只读分卷：链接与占位检查只扫当前卷
gd = subprocess.run(['git', 'rev-parse', '--path-format=absolute', '--git-dir', '--git-common-dir'], cwd=root, capture_output=True, text=True).stdout.split('\n')
in_worktree = len(gd) > 1 and gd[0] != gd[1]
main_root = Path(gd[1]).parent if in_worktree else root  # worktree 里不入 Git 的本地证据（验证与备份、本地结果）只在主工作区
files = subprocess.run(['git', '-c', 'core.quotePath=false', 'ls-files', '--cached', '--others', '--exclude-standard'],
                       cwd=root, capture_output=True, text=True).stdout.splitlines()
for rel in files:
    p = root / rel
    if not p.is_file() or rel.startswith(volumes):
        continue
    if p.suffix == '.json':
        try: json.loads(p.read_text())
        except Exception as e: bad.append(f'JSON 无效 {rel}: {e}')
    if p.suffix == '.md':
        for m in re.finditer(r'\]\((<[^>]+>|[^)\s]+)\)', p.read_text()):
            ref = m.group(1).strip('<>').split('#', 1)[0]
            if not ref or '://' in ref or ref.startswith('~'):
                continue
            if len(ref) <= 2 and not re.search(r'[/.]', ref):
                continue  # 正文方括号后跟 (a) 之类不是路径（如表格里「变身[萧萧](a)」，唐僧_13 2026-10-26）
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
# 执行—核查双轨流程：待交叉核查由提交尾注生成，超过 10 批时提示（用户 2026-10-15 由 4 改 10）（不判失败，超限期间仍要能收工修复）
review = subprocess.run([sys.executable, str(tools / '待核查.py'), '--root', str(root), '--limit', '10'], capture_output=True, text=True)
print(review.stdout.rstrip() if review.returncode == 0 else '  ⚠ 待核查清单生成失败：' + review.stderr.strip()[-200:])
for b in bad: print('  ✗ ' + b)
print(f'  ✓ JSON、链接、开发编号（{dev}）' if not bad else f'  共 {len(bad)} 项问题')
sys.exit(1 if bad else 0)
PY
(( FAIL )) && FAIL_ITEMS+=("文档与登记（见上方 == 文档与登记 段）")

if (( FAIL && ! KEEP_GOING )); then
  print "文档与登记检查失败：先修好再跑（未运行 Godot 测试与其余检查；要照旧全跑加 --keep-going）"
  exit 1
fi

print "== Godot 测试"
(( SEL_FULL )) || TEST_ARGS+=(--reuse)
if (( ! SEL_FULL && ${#SEL_SCENES} == 0 )); then
  print "  （选测：没有要跑的 Godot 场景，跳过导入与测试）"
elif (( CLOUD )); then
  # 云端选测：推 HEAD 到 ci/<分支> 触发 GitHub Actions，等结果（汇总里有失败场景）；只测已提交的 HEAD
  print "  （--cloud：选中的 ${#SEL_SCENES} 个场景交给云端，本机不跑 Godot；云端只测已提交的 HEAD）"
  cloud_head=$(git -C "$ROOT" rev-parse HEAD)
  cloud_run=(python3 "$CLOUD_SCRIPT" run); (( ${CHECK_CLOUD_NO_UPLOAD:-0} )) && cloud_run+=(--no-upload)
  if ! "${cloud_run[@]}"; then
    bad "云端选测触发失败（网络、权限或额度）；去掉 --cloud 改用本机跑"
  elif python3 "$CLOUD_SCRIPT" wait "$cloud_head" --mode affected --timeout ${CHECK_CLOUD_TIMEOUT:-2700}; then
    ok "云端选测通过（$cloud_head[1,9]）"
  else
    cloud_rc=$?
    if (( cloud_rc == 124 )); then bad "云端选测超时没有结果（$cloud_head[1,9]）；看 GitHub Actions「云端选测」，或去掉 --cloud 改用本机跑"
    elif (( cloud_rc == 4 )); then bad "云端没有启动（多半是本月 GitHub Actions 额度用完）（$cloud_head[1,9]）；去掉 --cloud 改用本机跑选测"
    elif (( cloud_rc == 3 )); then bad "云端运行已结束但没有结果（$cloud_head[1,9]）；看 GitHub Actions「云端选测」，或去掉 --cloud 改用本机跑"
    else bad "云端选测未通过（$cloud_head[1,9]），失败场景见上方汇总"; fi
  fi
else
# 车道 worktree：补齐带进来的主工作区参照与本分支切片不同批时提示（不判失败，见 参照批次.py）
python3 "$ENV_DIR/参照批次.py" check "$PROJECT/modes/xiyou/generated" || true
# 导入是重进程：先占共用槽（占槽.py），排队心跳经 fd 3 送回本日志
import_out=$(python3 "$ENV_DIR/占槽.py" --label "godot --import" --notice-fd 3 -- perl -e 'alarm 300; exec @ARGV' "$GODOT" --headless --path "$PROJECT" --import 3>&2 2>&1); import_rc=$?
if (( import_rc != 0 )) || print -r -- "$import_out" | grep -qE 'SCRIPT ERROR|^ERROR:'; then
  bad "Godot 导入失败 (rc=$import_rc)"; print -r -- "$import_out" | grep -E 'ERROR|FAIL' | head -8
fi
# 测试并行运行（每个测试独立临时 HOME，互不干扰、不碰真实用户数据）；CHECK_JOBS=1 时逐个运行
# 慢的先跑、各工作树共用并发上限、工程未变时沿用上轮通过结果（--full 强制整轮），见 并行测试.py 文件头
failed_file=$(mktemp -t xiyou_check_failed)
if ! CHECK_FAILED_FILE=$failed_file python3 "$ENV_DIR/并行测试.py" "$GODOT" "$PROJECT" "${TEST_ARGS[@]}" "${SEL_SCENES[@]}"; then
  FAIL=1
  scene_rows=("${(@f)$(<$failed_file)}")
  for row in ${scene_rows:#}; do FAIL_ITEMS+=("Godot 场景 ${row%%$'\t'*}  日志 ${row#*$'\t'}"); done
  (( ${#${scene_rows:#}} )) || FAIL_ITEMS+=("Godot 测试（未写出失败场景，见上方 == Godot 测试 段）")
fi
rm -f "$failed_file"
fi

print "== 参照工具访问守卫"
want guards && { if node "$ROOT/03_再刷重制_Godot/03_转换工具/mv_oracle/guard_check.cjs"; then ok "MV 文件守卫"; else bad "MV 文件守卫"; fi; }
want guards && { if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/ui_reference/guard_check.py"; then ok "界面参照服务守卫"; else bad "界面参照服务守卫"; fi; }
want tools && { if python3 "$ENV_DIR/测试工作树清理.py" >/dev/null; then ok "工作树清理保护"; else bad "工作树清理保护"; fi; }
want tools && { if python3 "$ENV_DIR/测试参照批次.py" >/dev/null 2>&1; then ok "车道参照与切片同批提示"; else bad "参照批次工具回归失败，单跑 07_开发环境/测试参照批次.py 看详情"; fi; }
want guards && { if python3 "$ENV_DIR/测试导出过滤.py"; then ok "导出包排除测试与参照数据"; else bad "导出过滤没挡住测试或参照数据"; fi; }
want tools && { if python3 "$ENV_DIR/测试共性验收.py"; then ok "共性参照对照工具保护"; else bad "共性验收工具回归失败"; fi; }
want content && { if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/共性参照验收.py"; then ok "共性参照完整性（尚非Godot实现验收）"; else bad "共性参照缺失或异常"; fi; }
want tools && { if python3 "$ENV_DIR/测试合并工具.py"; then ok "新增用例、进度账与合并保护"; else bad "合并工具回归失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试公式程序.py"; then ok "结构化公式编译边界"; else bad "公式编译边界失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试状态js翻译.py" >/dev/null 2>&1; then ok "状态效果 js 再翻译整块边界"; else bad "状态 js 翻译边界失败，单跑 07_开发环境/测试状态js翻译.py 看详情"; fi; }
want tools && { if python3 "$ENV_DIR/测试转换器写入.py"; then ok "转换器增量写入与中断恢复"; else bad "转换器写入回归失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试记录工具.py" >/dev/null 2>&1; then ok "变更记录分卷与待核查清单工具"; else bad "记录工具回归失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试云端准备.py"; then ok "云端导入失败保护"; else bad "云端导入保护回归失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试内容覆盖.py" >/dev/null 2>&1; then ok "内容覆盖检查工具"; else bad "内容覆盖检查工具回归失败"; fi; }
want tools && { if python3 "$ENV_DIR/测试提交守卫.py" >/dev/null 2>&1; then ok "主工作区 main 提交守卫"; else bad "提交守卫回归失败，单跑 07_开发环境/测试提交守卫.py 看详情"; fi; }
# 测试选测满载偶发 1 项失败、单跑复现不了：失败时打出用例名，整份输出留在 本地结果/选测回归/ 当证据（tools22）
if want tools; then
  sel_log=$(mktemp -t xiyou_sel_test)
  if python3 "$ENV_DIR/测试选测.py" >"$sel_log" 2>&1; then
    ok "选测对照与 检查.sh --affected"
  else
    sel_keep=$ROOT/03_再刷重制_Godot/04_验证/本地结果/选测回归/$(date +%Y%m%d_%H%M%S)-$$.log
    mkdir -p "${sel_keep:h}" && cp "$sel_log" "$sel_keep"
    sel_cases=(${(f)"$(sed -n 's/^FAILED_CASE=\([^	]*\).*/\1/p' "$sel_log")"})
    grep '^FAILED_CASE=' "$sel_log" | sed 's/^FAILED_CASE=/    /' | head -5
    bad "选测回归失败：${${(j:、:)sel_cases}:-未打出用例名}；日志 $sel_keep（满载偶发时先单跑 07_开发环境/测试选测.py 对照）"
  fi
  rm -f "$sel_log"
fi
want tools && { if python3 "$ENV_DIR/测试角色同步提速.py" >/dev/null 2>&1; then ok "扩角色同步提速（缓存携带、手动种子隔离、六难度共用并发池）"; else bad "扩角色同步提速回归失败，单跑 07_开发环境/测试角色同步提速.py 看详情"; fi; }
want tools && { if python3 "$ENV_DIR/测试事件探针分段.py" >/dev/null 2>&1; then ok "事件探针分段并行（均衡分组、拼回顺序逐字相同）"; else bad "事件探针分段回归失败，单跑 07_开发环境/测试事件探针分段.py 看详情"; fi; }
# 内容覆盖（沙僧协助计划第 8 项）：缺素材／无效引用／未翻译不得出现基线外的新问题；修好或接受后 --update-baseline
want content && { if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/内容覆盖检查.py" --check; then ok "内容覆盖（无基线外新问题）"; else bad "内容覆盖出现新问题，见 04_验证/本地结果/内容覆盖/报告.json"; fi; }

if (( ORACLE )); then
  print "== MV 参照引擎"
  oracle=$ROOT/03_再刷重制_Godot/03_转换工具/mv_oracle
  if [[ -d $oracle/node_modules ]]; then
    res=$(cd "$oracle" && node boot_check.cjs); oracle_rc=$?
    if (( oracle_rc == 0 )) && python3 -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d.get("db") is True and d.get("modulesFailed")==[] and d.get("errors")==[] else 1)' "$res"; then ok "$res" | cut -c1-120; else bad "参照引擎启动异常：$res"; fi
    if want same_source; then
      if python3 "$ROOT/03_再刷重制_Godot/03_转换工具/验证西游来源.py"; then ok "当前西游来源、转换产物、六难度参照同源"; else bad "西游来源/转换/参照不一致"; fi
    fi
  else
    bad "mv_oracle 未安装依赖（在该目录运行 npm install）"
  fi
fi

if (( ! ORACLE && ! SEL_FULL && ${SEL_CHECKS[(Ie)same_source]} )); then
  print -r -- "  ⚠ 选测选中了同源检查，但没加 --oracle，未跑（合并车道.sh --affected 会带 --oracle）"
fi

if (( ${#FAIL_ITEMS} )); then
  print -r -- "== 失败项汇总（${#FAIL_ITEMS} 项）"
  for item in "${FAIL_ITEMS[@]}"; do print -r -- "  ✗ $item"; done
fi
print "== Git"
git -C "$ROOT" -c core.quotePath=false status --short | sed 's/^/  /'
if [[ -n $AFFECTED ]] && (( ! SEL_FULL )); then
  (( FAIL == 0 )) && print "选测全部通过（基准 $AFFECTED；当天全量前算「选测已验」）" || print "有失败项，请先处理再提交"
else
  (( FAIL == 0 )) && print "全部通过" || print "有失败项，请先处理再提交"
fi
exit $FAIL

#!/usr/bin/env python3
"""补跑 event_state_probe（审查 41 P2-1，cc·哪吒 fix4）：generated/oracle/event_states.json 缺失或比预设旧时补量一次（约 10 秒）。

它是 gitignore 的产物，只有同步会生成；新工作树、没同步过的 main 里没有，于是 xiyou_event_compare 的变体段和
事件空绿扫描 --check 要么报红要么（旧版）静默跳过。检查.sh 在 Godot 测试前、新建工作树.sh --补齐 在收尾时调用它。
探针只许写 mv_oracle/.sandbox（守卫），量完再拷进 generated/oracle。参照引擎或冻结正式源不在（云端等）就跳过，不算失败，
缺文件由对照专项与空绿扫描照实报红。用法：补跑事件状态探针.py [--force]
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ENV = Path(__file__).resolve().parent
TOOLS = ENV.parent / '03_转换工具'
GEN = ENV.parent / '01_Godot工程/modes/xiyou/generated'
ORACLE = TOOLS / 'mv_oracle'
OUT = GEN / 'oracle/event_states.json'
SRC = ORACLE / '.sandbox/event_states.json'


def needs(force):
    if force or not OUT.exists():
        return True
    stamp = OUT.stat().st_mtime
    # 预设在 03_转换工具/ 下（event_state_probe.cjs 读 ../event_presets.json）；原先写成 mv_oracle/ 下，找不到就永远不补跑（八戒 events8 发现）
    deps = [TOOLS / 'event_presets.json', ORACLE / 'event_state_probe.cjs', GEN / 'oracle/events.json']
    missing = [str(p.relative_to(ENV.parent)) for p in deps if not p.exists()]
    if missing:
        print('⚠ 判断要不要补跑时找不到：' + '、'.join(missing))
    return any(p.exists() and p.stat().st_mtime > stamp for p in deps)


def main():
    force = '--force' in sys.argv[1:]
    if not needs(force):
        print('事件状态探针产物在，不用补跑')
        return 0
    if not (ORACLE / 'node_modules').exists() or not (GEN / 'maps').exists():
        print('⚠ 没有参照引擎依赖或转换产物，跳过补跑 event_states.json（事件对照与空绿扫描会照实报缺）')
        return 0
    app = os.environ.get('XIYOU_APP')
    env = dict(os.environ, XIYOU_GENERATED=str(GEN))
    if not app:   # 探针默认读主工作区的冻结源绝对路径；工作树里那条链接同一份，优先用本树的
        link = ENV.parent / '02_内容与素材/冻结正式源/app.nw'
        if link.exists():
            env['XIYOU_APP'] = str(link)
    env.pop('XIYOU_EVENT_OUT', None)
    r = subprocess.run(['node', 'event_state_probe.cjs'], cwd=ORACLE, env=env, capture_output=True, text=True)
    if r.returncode or not SRC.exists():
        print('✗ event_state_probe 失败：' + (r.stderr or r.stdout).strip()[-300:])
        return 1
    OUT.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SRC, OUT)
    print('✓ 已补跑 event_states.json：' + r.stdout.strip()[-120:])
    return 0


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""工具快速回归门禁（tools65）：几十秒跑完「最容易在总装合并时才挂」的那几个工具回归。

为什么有它：车道改了 检查.sh、选测对照.json、转换器清单、翻译、插件备注相关代码，却不跑全量 检查.sh，
替身名单（CheckerTests）、插件备注覆盖、状态 js 翻译这类绑定了「会被车道做掉的东西」的回归要到总装合并的本机收尾才挂
（tools63、events2、fix4 各一次），每次白耗一轮云端＋本机 10 分钟。

用法：
  python3 工具回归.py            并行跑完整个门禁，失败打印末尾日志，退出码 1
  python3 工具回归.py --list     只打印门禁里有哪些、各自命令
  python3 工具回归.py --jobs N   并行数（默认 3）
谁用：车道交付前必跑（车道须知）；选测.py --list 在改到工具时提示它；合并车道.py --finish 在开云端选测前先跑，失败早停。
这里的每一项都必须同时被 检查.sh 的 tools 组调用（测试工具回归.py 核对），不另造一套。"""
import argparse
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (名字, 脚本, 参数, 说明)。要慢的（测试合并工具.py，满载时近 8 分钟）不放这里，留给 检查.sh 的 tools 组。
GATE = [
    ('选测替身与 检查.sh 解析', '测试选测.py', ['CheckerTests', 'CheckerStubParseTests'], '检查.sh 新增检查、替身名单、--affected 选测'),
    ('插件备注覆盖', '测试插件备注覆盖.py', [], '已知例绑定了会被车道做掉的备注标签'),
    ('状态 js 翻译', '测试状态js翻译.py', [], '已知例绑定了会被翻掉的状态'),
    ('回退开关覆盖', '测试回退开关覆盖.py', [], '回退开关登记与豁免'),
    ('探针登记检查', '测试探针登记检查.py', [], '新探针忘了登记、五乘区存量'),
    ('提交守卫', '测试提交守卫.py', [], '主工作区 main 提交守卫'),
    ('记录工具', '测试记录工具.py', [], '变更记录分卷与待核查清单'),
    ('切场景后调用扫描', '测试切场景后调用扫描.py', [], '发行版空视口闪退同类写法的静态扫描'),
    ('临时探针车道标签', '测试临时探针.py', [], '产物名带车道标签、clone 里 --补齐 转用主工作区脚本'),
    ('补齐整轮重导入', '测试导入超时.py', [], '删过 ctex 时 --补齐 的导入不被 300 秒掐断'),
    ('发行入口冒烟安卓分支', '测试发行入口冒烟.py', [], '认模拟器、不碰真机、入口文件清单'),
    ('发行出包', '测试发行出包.py', [], '发行说明去内部信息、旧目录压 zip 不删、体积表'),
    ('Windows 实机冒烟', '测试Windows实机冒烟.py', [], '假 exe：入口、按键、存档目录不落 _开发、按键组与发行入口冒烟一致'),
    ('安卓实机冒烟', '测试安卓实机冒烟.py', [], '假 adb：返回键两次退出、回车开新游戏、切后台同一进程、崩溃行、不碰真机'),
]
TIMEOUT = 900


def command(entry):
    return [sys.executable, str(HERE / entry[1]), *entry[2]]


def run_one(entry):
    start = time.time()
    try:
        p = subprocess.run(command(entry), capture_output=True, text=True, timeout=TIMEOUT)
        rc, out = p.returncode, p.stdout + p.stderr
    except subprocess.TimeoutExpired:
        rc, out = 124, '超时（%d 秒）' % TIMEOUT
    return entry, rc, out, time.time() - start


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--jobs', type=int, default=3)
    a = ap.parse_args(argv)
    if a.list:
        for e in GATE:
            print('%s：python3 %s' % (e[0], ' '.join([e[1], *e[2]])))
        return 0
    print('== 工具快速回归（%d 项，并行 %d）' % (len(GATE), a.jobs), flush=True)
    failed = []
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=max(1, a.jobs)) as pool:
        for entry, rc, out, sec in pool.map(run_one, GATE):
            if rc == 0:
                print('  ✓ %s（%.0f 秒）' % (entry[0], sec), flush=True)
            else:
                failed.append(entry)
                tail = '\n'.join(out.strip().splitlines()[-25:])
                print('  ✗ %s（%.0f 秒，rc=%d）：单跑 python3 07_开发环境/%s\n%s' % (entry[0], sec, rc, ' '.join([entry[1], *entry[2]]), tail), flush=True)
    if failed:
        print('工具快速回归失败 %d 项：%s（共 %.0f 秒）' % (len(failed), '、'.join(e[0] for e in failed), time.time() - t0))
        return 1
    print('工具快速回归全部通过（共 %.0f 秒）' % (time.time() - t0))
    return 0


if __name__ == '__main__':
    sys.exit(main())

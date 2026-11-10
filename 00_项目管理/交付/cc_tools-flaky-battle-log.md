# 交付：cc/tools-flaky-battle-log

- 车道／工作者：tools／哪吒（cc）
- 状态：可合并

## 根因

`xiyou_battle_log` 的 `indicator_case`（宿傩领域法阵、黑闪觉醒描边）每步改状态后只 `await 物理帧`，但 `XBattlerSprite._update_indicators` 在 `_process`（渲染帧）里更新。机器负载高时物理帧可以连跑几次而 `_process` 一次没跑，测试读到旧状态：失败项是 `indicator.domain-view／domain-live／outline／outline-expired／dead`，每次随机挂 1～3 项。这与 flaky.jsonl 里 11-03 那次（rc=1、重跑通过）和两次跨车道偶发一致。

## 复现

- 单跑加 3 路并发（占槽）共 65 次：全过。占槽让并发实际不高，复现不了。
- 无占槽 12 路并发（8 核）：第一轮 13 次里 4 次失败，且每次都落在上面的 indicator 检查上。

## 修法

只改测试 `tests/xiyou_battle_log.gd`：新增 `procs(n)`（等 n+1 个 `process_frame`，保证至少一整帧 `_process` 已跑完），`indicator_case` 里状态改动后的等待由 `frames` 换成 `procs`；`domain-anim` 那段前面加一次 `frames(1)` 对齐到物理帧信号，保证「10 帧＝10 步」。游戏代码不动，断言数量不变。

## 验证

- 修前：无占槽 12 路并发 13 次里 4 次挂在 indicator 检查（根因同上）。
- 修后：同样 12 路并发（8 核）共 48 次全过（74/74）；中途一版只换了 `procs`、没对齐物理帧，`indicator.domain-anim` 12/12 稳定失败，已补 `frames(1)` 对齐。
- `语法检查.py` 通过；`并行测试.py … xiyou_battle_log` 单跑通过（14 秒）。
- 只改了一个测试文件，没跑 `工具回归.py`（没碰工具、选测对照、检查.sh）。`选测.py main --list` 只列出这个场景。
- 不用豁免清单：根因在测试等待方式，已修。

## 变更记录草稿

## 2026-11-10 【cc·哪吒·未经审查】xiyou_battle_log 偶发失败修复（dev.待定）

- 根因：专项里宿傩领域法阵、黑闪觉醒描边的检查每步只等物理帧，而指示物在 `_process` 里更新；机器负载高时物理帧连跑、`_process` 没跑，读到旧状态，随机挂 `indicator.*` 1～3 项（flaky.jsonl 11-03 那次、两次跨车道偶发都是它）。
- 修法：`tests/xiyou_battle_log.gd` 加 `procs(n)` 等渲染帧，indicator 段的状态后等待改用它，`domain-anim` 前对齐到物理帧；游戏代码不动，断言数不变。
- 验证：修前 12 路并发 13 次挂 4 次；修后同负载 48 次全过。

## 交接板

- 下一步：无
- 用户试玩说明：无（只改测试）
- 需要用户决定：无

## 可优化（流程／工具／效率）

- 建议：车道在 `占槽.py` 里排队跑会把并发压低，复现偶发要绕开占槽（直接起多个 godot 进程，数量超过核数）；可在 `并行测试.py` 加 `--repeat N --stress` 之类的复现模式（预计省一轮摸索，归 tools 车道）。
- 建议：其它测试若在 `await physics_frame` 后读 `_process` 才更新的状态（弹字、指示物、光标），同类偶发风险；可 `rg "_process" ` 对照 tests 里只等物理帧的用例扫一遍（归 tools 车道）。

## 本分支提交

- 见 git log

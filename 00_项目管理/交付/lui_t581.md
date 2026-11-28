# 交付：lui/t581

- 车道／工作者：T581 徐凤年 2539 状态表记忆键缺西游档改写（cc，Opus 5.5＋medium）
- 状态：可合并
- 基于：`luiluu/t586` 的 `5ac3ffcc4`（T586 派单时还没合进 main，照派单基于它开分支；合并时 T586 要先合或一起合）

## 变更记录草稿

## 2026-11-28 【cc·未经审查】T581 状态表记忆键带上西游档改写（dev.待定）

- 问题（T576 交付单另报）：O-390 状态表记忆（`XBattler.STATES_MEMO`）的键是状态编号、破甲倍率、天启篇卡、隐月修正、底表，没有「西游档改写开没开」。`XDB.rec` 只在西游档把徐凤年 2539 真·剑九换成 `XXufeng` 改写副本（终伤 +500% → +200%）；读档时 `XState.from_dict` 在新档变成当前档之前就给角色算过一次状态表（那时没有存档或还是旧档），记下原版 +500% 的记录，之后身上状态没变就一直用它。
- 复现（专项 `xiyou_t581_states_memo`，修前 13/17）：标题画面读西游档（读档前没有当前档）后，徐凤年 `states()` 里的 2539 是原版记录（k = 5.0，+500%）；开战打第一回合时 READ_VERIFY 报 `states 角色 152`／`actor_states 角色 152` 记忆不一致（同 T576 在玩家档上看到的）。同类还有离群削弱（`XXiyouNerf`）改写的 2739：读档后也是原版记录。
- 修法：`modes/xiyou/core/battler.gd` 记忆键加第 6 项 `_states_memo_xiyou_tag()`＝`XXufeng.xiyou_save_on()`、`XXiyouNerf.xiyou_save_on()` 两位；当前档从没有／旧档换成西游档时当场重算。天启篇两位恒为 0，键的取值和以前一样（天启篇零改动）。
- 回退：`XBattler.STATES_MEMO_XIYOU_KEY = false`（键里这一项恒为 0，同 T581 之前）。专项里核了关掉后回到旧行为。
- 玩家可见：西游档徐凤年读档后第一场开头几下「真·剑九」的伤害不再按原版 +500% 多算（改为与之后一致的 +200%）。

## 交接板

- 下一步：无新增
- 用户试玩说明：西游档徐凤年读档后进第一场，真·剑九的伤害与之后各场一致
- 需要用户决定：无

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 动了的共用函数和开关

| 函数／开关 | 调用方 N 处（附 grep 命令） | 逐处结论 |
| --- | --- | --- |
| `XBattler._states_memo_list` | 4 处（`git grep -nE '[^[:alnum:]_]_states_memo_list[[:space:]]*\(' -- '*.gd'`） | 调用方 4 处逐处结论：定义 1 处、`states()`、`states_stamp()`、`XActor._actor_states_memo` 各 1 处；签名和返回不变，只是键多一项，多一种情况会重算（换档时），命中时结果与现算相同（READ_VERIFY 专项零不一致） |
| `XBattler.STATES_MEMO_XIYOU_KEY`（新） | 0 处产品代码读写，只在 `_states_memo_xiyou_tag` 里读 | 默认 true；回退开关，专项 `xiyou_t581_states_memo` 设 false 核旧行为 |

## 验收（派单 3 条）

1. 复现 ✓：读档后首场 2539 是原版 +500%（专项修前 `xy.load.2539_rework` 得 k=5.0；`xy.turn1.verify_no_mismatch` 报 `states 角色 152`）。修前 4 项失败：`xy.load.2539_rework`、`xy.turn1.verify_no_mismatch`、`nerf.load.2739_rework`、`no_save.2539_original`。
2. 修记忆键带上西游档改写 ✓（见上）。
3. 回归测试 ✓：新专项 `xiyou_t581_states_memo` 17/17，含「存档→读档（读档前无当前档）→第一回合」：读档后、开战、打完第一回合，2539 都是改写后的 +200%，READ_VERIFY 零不一致；西游档读西游档、没有存档回原版、回西游档再换回改写；天启篇读档后 2539 与 `XDB.rec` 同一份，记忆开／关结果相同。

## 测试

- 本机（临时 HOME，`--audio-driver Dummy`）相关 10 个场景全过：`xiyou_t581_states_memo` 17/17、`xiyou_act_stat_memo` 30、`xiyou_xufeng_rework` 65/65、`xiyou_xufeng_t586` 53/53、`xiyou_xufeng_t585` 29/29、`xiyou_t463_t465` 20/20、`xiyou_tianqi_xufeng` 33/33、`xiyou_t574_lag` 44、`xiyou_t576_lag` 63、`xiyou_xufeng_release` 28/28。
- 云端选测：提交 `dd70e64bf`，基准 `5ac3ffcc4`，233 个场景、16 片，**通过**，`gh run watch` 前台等完：https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/46113260318 。偶发 1 个（并行时失败、单跑通过，算通过）：`xiyou_gojo`（天启篇五条悟专项，与本单无关）。之后的提交只改交付单。
- `发行空壳.py check`：通过（88 个脚本，879 个函数都有）。

## 本分支提交

- dd70e64bf 状态表记忆键带上西游档改写、回退开关、专项

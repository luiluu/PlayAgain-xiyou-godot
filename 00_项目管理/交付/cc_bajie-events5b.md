# 交付：cc/bajie-events5b（半成品，Kyo 11-05 让车道收工，WIP 停手）

- 车道：A 内容·事件解释器／八戒（cc）。分支 cc/bajie-events5b（原 events5 被旧会话占着，改名；起点 8519eac9）。
- 状态：**未完成，不可合并**

## 一、已做（已提交）

1. **跳过基线**：`xiyou_event_compare` 收集各用例解释器 skipped，写 `tests/event_skipped_baseline.json`（160 例 436 条，`--update-baseline` 重写）；新增跳过＝`no_new_skipped` 红。本机跑 6230 例 0 回归。
2. **跳过清单分诊**（81 种写法 + 脚本普查 101 条）：战斗里跑的（action.*、敌人参数、333、条件 5，战斗解释器原生认，调用方是技能／敌群）、手机云存档、原版语法错、静态/动态都没有调用方（CE988 批量卖出、宠物 GTWar、CE817）、角色变量为空时原版同样不提示的 toaster（95 例）——都不是缺口。**唯一玩家可达的真缺口：CE1386（守护者战斗背景，Map5／18／44／67／85／171）一直被 `skip_common_events` 跳过**，已改成不跳（`mv_event_core.gd`），283 宿主入口早就有。
3. **观察面扩充**（三处同改：`event_probe.cjs`、`event_state_probe.cjs`、`xiyou_event_compare.gd`）：角色 `hp`／`mp`／`paramPlus`（指令 317 的八项能力加成）、顶层 `battleback`；预设新增 `defeats`（击败数），加变体 `m17e4p0#d1`（66 号击败 999，走认证成功分支）。

## 二、停在哪一步

- 同步 `--accept-additions` 已跑，**退出码 2**（测量有变化，需接受单）。已用 `生成接受单.py` 出草稿 `04_验证/测量接受/cc_bajie-events5b_obs.json`（474 条，理由统一一句，**没逐条看**）。
- 另有前一步已通过的 `cc_bajie-events5b.json`（320 条，刷新 main 落后的参照，已同步通过）。
- 还没做：用 `--accept-changes` 两份接受单重跑同步 → 跑 `xiyou_event_compare`，看新观察面是否咬出真差异（hp／mp／paramPlus 可能有噪声：Godot 初值与 MV 不一致就要看是不是真缺口）→ 有真差异先量原版再修 → `--update-baseline`（跳过基线、对照基线）→ 专项＋必跑项（选测.py main --list；`工具回归.py`）→ 云端选测。没碰 `battle_logic.gd`、`damage.gd`。

## 三、下一步

1. 看 474 条接受单草稿的变化分布（按字段分：hp／mp／paramPlus／battleback），核对不是噪声后同步。
2. 对照里 hp／mp 若全是初值差异，只保留 `paramPlus`＋`battleback`，hp／mp 改成"仅指令改过的角色才记"。
3. 其余按上面。
4. 提示：`main` 的参照产物落后于已合并的 events4（总装在 main 上同步被拒过，接受单对不上）；本分支 `cc_bajie-events5b.json` 可作 main 刷新参照用。

## 变更记录草稿

## 2026-11-05 【cc·八戒·未经审查】事件对照加跳过基线、扩 hp/mp/能力加成/战斗背景观察面，守护者战斗背景不再跳过（dev.待定）

- 地图事件对照新增"解释器跳过"基线（160 例 436 条），新增跳过会红；分诊后唯一玩家可达缺口是 CE1386（守护者战斗背景），已修。
- 快照加角色 hp／mp／能力加成与战斗背景，预设加击败数。**半成品，未验收。**

## 待交叉核查

- `mv_event_core.gd`：`skip_common_events` 清空（CE1386 现会执行 283）。
- `xiyou_event_compare.gd` 与两个探针的快照同规则。

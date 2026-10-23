# 交付：claude/youthful-rubin-d03e77

- 车道／工作者：B 界面／八戒（Claude，重制_八戒_59）
- 状态：可合并
- 说明：唐僧安排的分支是 `claude/bajie-tribe`，但本会话由 app 建在自己的 worktree（`.claude/worktrees/youthful-rubin-d03e77`），写不了别的 worktree，所以照「app 自建 worktree」流程在 `claude/youthful-rubin-d03e77` 上做（起点即 `claude/bajie-tribe` 的 33fab43c），交付单也按这个分支名。

## 规模与分期

- 期一（本单）：种族祝福的菜单侧。运行时、选单页、主菜单入口、事件脚本入口、原版参照与专项。
- 期二（不在本单）：战斗与能力值效果，在沙僧独占文件里，接口见下文「规则接口」。
- 期三（不在本单）：方桌大厅种族向导选完后挪位（`relocateGuide`，Map4 EV22 挪到 EV47 右边一格；地图事件，悟空车道）。

## 变更记录草稿

## 2026-10-23 【Claude·八戒_59·未经Codex检验】种族祝福菜单侧（dev.待定）

- **运行时**（新 `modes/xiyou/core/race.gd` XRace，照冻结 v0.28 installNativeRaceRuntime 的菜单侧）：存档新字段 `XState.race`（`default` 开局默认、`guideChosen`、`actors` 每名角色 `{race, rank, free, blood, legacy}`）；第一次读到角色时按已学的种族技能推出种族（一族即它、多族待选、无则开局默认），种族技能 `CodexRaces.skills[族][阶-1]` 写进角色技能（sync）；开关 281～287 恰好开一个时当开局默认；`setDefault`（没选也没旧技能的角色改为该族，开关只开对应一个，提示「开局默认祝福：X族」）、`change`（每人第一次免费，之后忘情水×1，血契关、旧记录清空）、`upgrade`（七族通用进阶石，须先有上一阶）、领种族补给暂存箱；换族与进阶后按原比例恢复生命、法力。
- **选单页**（新 `ui/race_menu.gd` XRaceMenu，CodexBinding 选单＝XChoiceWindow）：未选开局默认时先进默认页（七族→确认页带一阶说明）；队员页「名字 · X族祝福·N阶」；角色页（调整种族、进阶至第 N 阶、魔族多一行血契开关；说明是种族技能说明按「；」拆行）；换族页（当前族标「（当前）」）与确认页（「保留当前阶位；本次调整免费／消耗忘情水×1」）；进阶确认页（「消耗祝福进阶石·N阶×1」）。行文、提示、各页取消去向照原版。
- **入口**：主菜单「种族祝福」开放（原版 Scene_Menu 直接 openMenu，不走公共事件）；事件脚本 `CodexRaces.openMenu()`（方桌大厅种族向导 Map4 EV22）、`CodexRaces.openMenu({rank:N})`（进阶石公共事件 610～616、862～899：从队员页进角色页那一次进阶行写第 N 阶）、`CodexRaces.setDefault(N)`（公共事件 841～847）。`mv_script.gd` 加这几条识别、`map_scene.gd` 加 `open_race_menu(rank)`（这两处不是本车道独占，各几行）。
- **参照与测试**：新探针 `mv_oracle/race_menu_probe.cjs`（新局队伍 1/8/9：初值、setDefault／change／upgrade 各种返回、旧技能与开关推断、暂存箱、9 条点选路线的各页行文与提示），产物 `generated/oracle/race_menu.json`；新专项 `xiyou_race_menu` 66 项逐项比对（不比生命、法力，原版换族会因能力值倍率改最大生命，倍率属期二）。`xiyou_panels` 灰显名单 3→2 项（异化工坊、反馈），`xiyou_notice_options` 灰显蜂鸣改用「异化工坊」，`界面风格.md` 同步。
- **规则接口（期二交沙僧）**：
  - 读：`XRace.data(s, actor)` → `{race, rank, blood}`（race 0～6 依次神妖人魔鬼灵蛮，-1 未选），`XRace.rate(s, actor)` ＝ `CodexRaces.rates[rank-1]`（未选为 0）。只在战斗外的菜单与事件脚本里变（换族、进阶、开局默认、血契开关），战斗中不变；战斗里原版还有指令「血契：开／关」（Window_ActorCommand，改的也是这个 `blood`）。
  - 能力值（原版 Game_Actor.param／paramPlus，`actor.gd` 或 `battler.gd`）：人族八项 ×1.03；鬼族最大法力 ×(1+q)；蛮族最大生命 ×(1+q)（三者都 Math.round）；灵族 paramPlus 加武器本体值（扣宝珠附加）×q/2；鬼族技能 MP／TP 消耗 ×(1−q/2) 向上取整、至少 1。改完要刷新被动缓存。
  - 战斗（`damage.gd`／`battler.gd`／`battle_logic.gd`）：神族魔法伤害与治疗 ×(1+q)、每回合首次魔法无视 q/2 魔防；妖族猎物（群攻选一名，Boss 优先，预演伤害最高）无视 q 双防与固定减伤、伤害 ×(1+q/2)，猎物生命≤30% 时 ×(1+q)；人族回合末毒鸡汤（有效伤害×q/2）与 q/2 概率额外行动；魔族物理 ×(1+q)、暴击倍率 +q/2，血契每回合首次物理技能付 3% 最大生命再 ×(1+q/2)（手动≥30%、挂机≥50% 才发动）；鬼族残响（连续两回合同组技能，第二次额外 q 结算）；灵族匹配兵器的技能终伤 ×(1+q)；蛮族单次受伤上限（0.75−2q，0.45 记 0.5）与反攻（受伤≥10% 最大生命后下回合对来源 ×(1+1.5q)）。战斗数据原版放在 `_codexRaceBattle`，每场重置，不进存档。
  - 原版学会种族技能时直接改种族数据（learnSkill 拦截）；这里在第一次读数据时按技能推断，之后事件再学种族技能不会改种族（目前切片里没有这样的事件，接 learnSkill 时可在 `actor.gd` 调 XRace）。
- **未做**：向导挪位（期三）；旧档迁移（不迁移 MV 存档）。

## 交接板

- 下一步：种族祝福期二（战斗与能力值效果，沙僧，接口见变更记录本条「规则接口」）；期三向导挪位（悟空）。
- 用户试玩说明：主菜单「种族祝福」可以用了：第一次打开先选开局默认祝福，之后可以逐人换族（第一次免费，之后要忘情水）、用进阶石进阶、魔族开关血契；方桌大厅的种族向导和进阶石也会打开同一个菜单。战斗里的种族效果还没有接，选了族暂时只改技能栏里的祝福技能。

## 进度账

- 界面：主菜单 18 项里只剩异化工坊、反馈两项灰显。

## 验证

- `并行测试.py` 专项：`xiyou_race_menu` 66/66、`xiyou_panels` 35/35、`xiyou_notice_options` 71/71、`xiyou_orb_shop_ui` 27/27。
- `同步正式西游.py --accept-additions` 在本 worktree 跑过（新探针 race_menu）。

## 本分支提交

- a0d8f457 交付单规模与分期
- 48df8c42 XRace、XRaceMenu、主菜单与事件入口、原版参照与专项
- ffd02223 主菜单灰显名单与说明去掉种族祝福
- cec6118b 合并 main

# 交付：claude/bajie-pets-source-97efd5-3

- 车道／工作者：B 界面·养成／八戒（Claude，重制_八戒_71）
- 状态：进行中
- 本分支从 claude/bajie-pets-source-97efd5-2（期一）切出，含期二、期一全部提交；合并顺序：期二 → 期一 → 本张。

## 期四 战斗中技能／物品的公共事件（效果 44）通用化

### 原版怎么跑（冻结 v0.28）
- YEP_BattleEngineCore 在战斗中关掉 `Game_Action.applyGlobal`，公共事件改由行动序列预约：默认收尾段最后一条 `ACTION COMMON EVENT`（`actionActionCommonEvent`）把道具每个 44 效果依次 `$gameTemp.reserveCommonEvent`——**单槽**，后一个盖前一个；ActSeqPack1 的 `COMMON EVENT: X` 没事件在跑时同样预约（有事件在跑时插成子事件立即执行）。切片里技能、物品全部都有 yepSeq，只有 622／825 两个技能（`occasion 0`，公共事件 1159 空事件）的收尾没写 ACTION COMMON EVENT。
- 行动结束后 `BattleManager.updateEventMain` → `Game_Troop.setupBattleEvent`：解释器空闲时**预约的公共事件先于敌群页**（本版 rpg_objects 的 `setupReservedCommonEvent`）。YEP 的 `checkBattleEnd` 在行动刚结束的 `actionList` 阶段与事件进行中都不判定，所以**打倒最后一只敌人后，预约的公共事件照样跑完才胜利**（参照 `thunder_battle_end`：84 仍对已倒下的目标强制 533）。

### 重制
- 新文件 `core/battle_common_event.gd`（XBattleCommonEvent）：`reserve`／`reserve_action`（单槽、记最后一次用道具的行动给 PetGet）／`take`（取成 XBattleEventRunner；一次检查里接连预约上限 64 次防死循环）。
- 挂点（都调新模块，不落在沙僧的状态效果接线里）：
  - `battle_logic.gd` `_drive_events` 选页之前一行：`if _runner == null: _runner = XBattleCommonEvent.take(self)`。
  - `battle_logic.gd` 删掉期二 `_apply_effect` 的 `44:` 特判（只认 173 的那行）。
  - `battle/action_sequence.gd` `_command`：`ACTION COMMON EVENT` → `reserve_action`，`COMMON EVENT` → `reserve`。
  - `battle/battle_event_runner.gd` 355 分支：`Star.PetSystem.PetGet()` → `XPetCapture.pet_get`；整段只有一条 `$.toaster(...)` 时照地图 MVScript 拼文字记成提示。
  - `battle/battle_scene.gd` `_main`：打赢／打输后若还有预约，先 `_play_troop_events` 一次再进结算（一行）。无界面的 `run_turn` 本来就先查事件。
- XPetCapture：`item_event` 拆成 `pet_get`（读最后一次用道具的行动）与 `capture`；捕获网现在和原版一样在**行动结束后**的事件检查里才判定。
- 战斗中物品／技能的公共事件现在**通用**：条件分支、变量、开关、状态、强制行动（339）、敌人状态等战斗内解释器已有的指令都照跑。

### 盘点（`xiyou_battle_common_events` 运行时打印）
- 切片里战斗中能用（occasion 0／1）的技能、物品带 44 效果的：**240 个公共事件**（1525 处引用里 occasion 0／1 的部分），绝大多数是「再次释放」类（条件分支＋339 强制行动，111／412／339 各 150～190 处）。
- 逐个在战斗里跑一遍（只走得到当前状态下的分支），带没翻译指令的 **49 个**：
  - 355 脚本 51 处：最多的是 `for(let i …){ … BattleManager.forceAction(actor) }` 一类自写强制行动循环（如 17 水流、72～78、107、116、121～130 等「再释放」）、`var actorN = $gameActors.actor(N)` 后改技能／状态，以及 942～946 的 `$gameParty._targetActorId` 等。这些是各角色专属机制，宜随角色车道逐个接。
  - 250 播放音效、311 改 HP、322 换角色图、331 改敌人 HP 各 1 处（331 在 1401「敌人恢复所有血量」）。
- 没翻译的指令照旧跳过并记进 `troop_event_skipped`（页号记 0），不影响其余指令。

### 与原版的差别
- `COMMON EVENT: X` 在事件进行中（强制行动里）原版插成子事件立即执行，重制排到当前事件之后再跑（用到的 12 个技能：踏地／回音重踏／黝石重踏 → 375、灼烂歼鬼·炮 → 1712）。
- 一次检查里接连预约超过 64 次就停（原版会一直跑；正常数据靠条件收住）。

### 提案（要总装定，本期没做）
- **开战公共事件 1320「战斗开始时调整变量」**：本版改过的 `BattleManager.startBattle` 每场开战都 `reserveCommonEvent(1320)`（再调 1315 特殊物品数量、1372 见钱眼开、1373 血脉数量统计、1375 半人马上阵统计，改变量与状态），重制没有。有了本期的通用机制，接法是在开战时 `XBattleCommonEvent.reserve(logic, 1320)` 一行，开战第一次事件检查就会先跑它；但它改的是战斗公式要用的变量，会影响规则对照，属于战斗规则改动，先问总装。其中 1373／1375 的 355 循环脚本还要翻译。

## 变更记录草稿

## 2026-10-25 【Claude·八戒·未经Codex检验】战斗中技能／物品的公共事件通用化（dev.待定）

- 战斗里技能、物品带的公共事件（使用效果 44）照原版 YEP 流程执行：收尾序列 ACTION COMMON EVENT（及 COMMON EVENT: X）单槽预约，行动结束后的事件检查先跑预约再看敌群页，打倒最后一只敌人后也照跑。新模块 `core/battle_common_event.gd`；捕获网（公共事件 173）改走通用路径。
- 切片里战斗可用的 240 个公共事件中，49 个走到的分支里还有没翻译的指令（多为角色专属 355 脚本），照旧跳过并记录；战斗事件里的 `$.toaster` 提示接上。
- 参照：`mv_oracle/battle_common_event_probe.cjs`（84 魔雷会／不会 5083、打倒最后一只敌人、173 捕获网）；专项 `xiyou_battle_common_events`。
- 待定：开战公共事件 1320 未接（提案见交付单）。
- 提交：见交付单「本分支提交」

## 交接板

- 下一步：开战公共事件 1320 是否接（提案）；角色专属的 355 脚本随各角色车道接；期三领袖旗标等通知。
- 用户试玩说明：魔雷老人、吕布等「再次释放」类技能在战斗里会照原版再放一次；捕获网在出手动作结束后才判定捕捉。

## 进度账

- 战斗·事件：技能／物品的公共事件从「不执行」到通用执行（240 个里 191 个走到的分支已全部可执行）。

## 可优化（流程／工具／效率）

- 已做：`xiyou_battle_common_events` 的盘点每次运行都打印「战斗公共事件里没翻译的指令」清单，接角色专属脚本的车道可直接拿来对账（可回退：删掉 `_inventory` 即可）。
- 建议：同类「行动序列＋敌群事件」的原版参照（battle_event_probe、本次的 battle_common_event_probe）每次都重写一遍 BattleManager 占位与逐帧推进。可抽一个 `mv_oracle/shared/battle_host.cjs`（setup 队伍敌群、占位精灵、逐帧推进到第 N 次行动、记行动与事件），新探针只写用例。预计每个新战斗探针省 80 行；归哪吒（工具）或沙僧（参照框架）。

## 验证

- 已过：`xiyou_battle_common_events` 22/22（单跑）、`xiyou_pet_capture` 43/43（单跑，改走通用路径后）。
- **停在这里（2026-10-25，5 小时额度 79% 按总装要求收尾）**：必跑项一批已用 `长任务.py` 起（日志 /private/tmp/claude-501/-Users-kyo-Documents----------claude-worktrees-bajie-pets-source-97efd5/950f25cb-744e-44dc-9a85-d0ba8dcd5041/scratchpad/t6.log，名单：xiyou_battle_common_events、xiyou_battle_events、xiyou_pet_capture、xiyou_random_streams、xiyou_rules 难度 1 四段、xiyou_battle*／xiyou_combat／xiyou_troop_events／xiyou_sequence_visual／xiyou_action_sequence／xiyou_determinism／xiyou_smart_ai／xiyou_event_compare／xiyou_otb／xiyou_item_use／xiyou_cat），排队等槽时两条同步占满，收尾时还没开始跑，让它继续排着。
- 接续要点：① 看 t6.log 结果（`等待任务.sh <日志> --timeout 540`），重点是 xiyou_rules 难度 1 四段与 xiyou_smart_ai／troop_events——技能公共事件现在会执行，若规则对照有变化，先查是哪个技能的 44 公共事件在对照战斗里被触发；xiyou_battle_events 的 seal1691 三条是 main 既有问题。② 结果写进本节，状态改「可合并」，报总装。③ 开战公共事件 1320 等总装答复提案。

## 本分支提交

- 6f0e683c WIP: XBattleCommonEvent、捕获网改走公共事件 173
- e3505637 打完最后一击仍跑预约、战斗事件里的 toaster、参照与专项

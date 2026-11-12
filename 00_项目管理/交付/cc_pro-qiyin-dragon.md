# 交付：cc/pro-qiyin-dragon

- 车道／工作者：C 规则·机制（纯逻辑＋数据表，只加新文件）／cc（Pro，云端线程）
- 状态：可合并

## 变更记录草稿

## 2026-11-12 【cc·Pro·未经审查】天启篇「七首之龙」出现判定、龙隙、奖励与龙血的纯逻辑（dev.待定）

- 照七印祭坛方案 v0.4（Kyo 11-12 定稿）给特殊副本「七首之龙」加纯逻辑与数据表，只加新文件，不做战斗本身、不接界面和存档：
  - 数据表 `modes/xiyou/tianqi_data/qiyin_dragon.json`（表头 `draft: true`）：五档出现率 3%／5%／6%／8%／10%、暗保底 30、最多存 1 次；战斗数据（艰险 250 万、其他难度乘 `balance_table.json` 的敌人血量倍率、攻防照 36 层普通首领一击约 8.5 万、每回合 3 次、七段按 bai→mo 揭印、灰印缓期 2 回合）；奖励（真印套装件印自选、部位在六件防具里随机，龙血 1 瓶，真印毕业武器 33%、流派随机，神器 3%、五件随机，首杀多招一人照 30 层招募表）；龙血每瓶 3%、每人最多 3 瓶。
  - 逻辑 `modes/xiyou/core/tianqi_qiyin_dragon.gd`（`class_name XTianqiQiyinDragon`）：状态 Dictionary 传进传出（不改传入的），随机数用注入的 `XRandomStream`。
- 接口：
  - `new_state()` → `{misses: 0, rift: "none", first_kill: false, blood_stock: 0, blood: {}}`
  - `roll_rift(state, difficulty, rng)` → `{state, rolled, appeared, pity}`：`rift` 不是 `none`（刚出现、存着、在打）时不判定、不抽随机数、保底不涨；否则固定抽 1 个 float（保底那次也抽）；连空 30 次后下一次必出；出了 `rift=offered`、`misses` 归零。错难度返回 `error`。
  - `store_rift(state)`：`offered → stored`；`enter_rift(state)`：`offered／stored → fighting`（不要印钥）；`lose_rift(state)`：`fighting → none`（存的那次也没了）。状态不对返回 `error`。
  - `reward(state, chosen_seal, rng)`（须在 `fighting`）→ `{state, true_set_piece:{seal, part, true_seal:true}, dragon_blood:1, weapon:null|{seal, true_seal:true}, artifact:null|神器键, extra_recruit:bool, recruit_floor:30}`；龙血同时记进 `state.blood_stock`，`first_kill` 置真、龙隙关上。抽随机数顺序：部位 → 武器判定 →（中了）武器的印 → 神器判定 →（中了）哪件。
  - 龙血：`can_drink(state, actor_id)`、`drink(state, actor_id)` → `{state, ok, reason?}`（`no_blood`／`full`，拒绝不消耗）、`bonus(state, actor_id)` → 0／0.03／0.06／0.09。
  - 战斗数据：`max_hp(difficulty)`、`fight_data(difficulty)`（含七段 `segment_hp`，最后一段补零头）。
  - `nice_number_violations()`：表里设计数值含 4 的列表（豁免键在表头 `nice_number_exempt`）。
- 和派单的出入：龙血加了 `blood_stock`（手上瓶数），`drink` 要扣瓶，所以「第 4 瓶拒绝、不消耗」有东西可不消耗；武器只给印（流派），具体武器类（每印两类、默印 12 类随机）留给掉落／装备车道。物品掉落加成没接：龙给的毕业武器都是真印，方案写真印几率不吃掉落加成，神器也不吃。
- 验证：新测试 `xiyou_tianqi_qiyin_dragon` 92/92（云端 Godot 4.7.2 headless）；`xiyou_tianqi_balance` 85/85（未改，顺带确认）。反向验证：把保底改 31、武器改 0.4，16 项失败，还原后全过。统计（固定种子）：艰险 20000 次判定出 1269 次，出现率 **6.35%**（算上 30 次保底的理论值 6.28%，其中保底兜出 239 次）；奖励 20000 次武器 33.28%、神器 3.11%，七个流派、五件神器都出过。
- 未完成／已知问题：`语法检查.py` 在云端写死 Mac 的 Godot 路径跑不了（Godot 直接加载新脚本没有报错）；`.gd.uid` 两个文件本车道按派单没加（只加点名文件），总装合并导入后会自己生成。

## 交接板

- 下一步：七首之龙接进流程（里副本 Boss 打赢后调 `roll_rift`、龙隙当场问／存、战斗按 `fight_data` 做、奖励和龙血接背包与存档）；战斗本身要另派车道。
- 用户试玩说明：无（纯逻辑，玩家还看不到）
- 需要用户决定：无

## 进度账

- 天启篇七印祭坛：七首之龙纯逻辑完成，战斗、界面、存档未接（扩展账）

## 可优化（流程／工具／效率）

- 建议：`语法检查.py` 读 `GODOT` 环境变量或 `/root/.cache/xiyou-godot/` 下的 Linux 版，云端车道就能跑（预计省一次手动确认；归工具车道）。

## 本分支提交

- （见分支 cc/pro-qiyin-dragon 上第一条提交）七首之龙数据表、逻辑、测试与交付单

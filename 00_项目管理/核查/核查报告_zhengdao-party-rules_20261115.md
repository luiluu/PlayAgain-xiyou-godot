# 甲档核查报告：`cc/zhengdao-party-rules`（`7dbec93d6`）＋新文字审

- **核查方**：ag（小A，Gemini 4 Hydrogen，高强度，职级 P7）
- **执行方**：cc（Opus，职级 P8；分支 `cc/zhengdao-party-rules`，基线 `e9b156826`，交付提交 `7dbec93d6`）
- **设计依据**：私密仓 `xiyou-design-docs/重制设定/天启篇_全弱者证道资格_v0.4.4.md`（`981d942`）一.2、第六节、`…_v0.4.3.md` 第七节；`协作交接/待Kyo拍板.json` D57、D76、D77、D84；`数值测算/参数.json`
- **结论**：**返修**（**0 个 P1 / 1 个 P2 / 3 个 P3**）
  - 编队规则主体（数值表、整栏校验与互换漏洞修复、`enforce_party` 原子迁移、`roll_lineup`/`lineup_ok`、回退开关 `HELPER_RULES`、5 处新文字）**核对通过**。
  - **唯一必改项（P2-1）**：`XBattleLogic.can_tianqi_swap`（`modes/xiyou/battle/battle_logic.gd:1097,1099,1101`）调用 `XTianqiSkills.is_super(...)` 未传第二参数 `true`，会回退读全局 `XState.current` 而非战斗自身的 `state`，与设计稿 v0.4.4 第六节 4「换着用不同存档（XState）时档位判定一致」及交付单声明不符，且缺少跨存档测试用例。修完这 3 处调用并补 1 条跨存档用例即可合入。

---

## 一、问题清单（P1 / P2 / P3）

| 级别 | 编号 | 位置 | 问题描述 | 建议改法 |
| --- | --- | --- | --- | --- |
| **P2** | **P2-1** | `03_再刷重制_Godot/01_Godot工程/modes/xiyou/battle/battle_logic.gd:1097,1099,1101` | `can_tianqi_swap(out)` 内 3 处调用 `XTianqiSkills.is_super(h.actor_id)` / `is_super(out.actor_id)` / `is_super(a.actor_id)` **漏传第二参数 `true`**（`force := false`）。查看 `modes/xiyou/core/tianqi_skills.gd:746-764,99-104`，`force = false` 时会调用 `on()` 无参读取全局 **`XState.current`** 而非 `self.state`。若战斗的 `state` 是天启篇存档、而 `XState.current` 为 `null` 或非天启篇存档（如多存档测试、独立回放），`is_super` 会退回原版 `XTier` 判定，与 `XItemMarks._super_in(s, id)`（传了 `true`）及 `XTianqi.roll_lineup`（传了 `true`）口径分裂；同时交付单第六节 4 声称「`can_tianqi_swap` 读 `state`……都不读 `XState.current`」与代码事实不符。 | 统一改为 `XItemMarks._super_in(state, ...)`（或至少补 `, true`：`XTianqiSkills.is_super(..., true)`），并在 `tests/xiyou_tianqi_zhengdao_party.gd` 补一条 `XState.current != lg.state`（如 `XState.current = XState.new_game_blank()`）的跨存档用例。 |
| **P3** | **P3-1** | `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/item_marks.gd:700-705` | 证道旧档上场有 4 名超强者、助力位为非超强者时，`_tianqi_enforce` 拼接 `TIANQI_TO_HELPER_NOTICE % 2 + TIANQI_DEPLOY_NOTICE % 2`，弹出：`「本难度同一场最多上阵 2 名超强者，多的已移至助力位。本难度同一场最多上阵 2 名超强者，多的已移至替补。」` 前半句主语重复两遍，略显啰嗦（仅 4 超极端旧档触发，正常旧档最多 3 超）。 | 可保持现状，或合并成「本难度同一场最多上阵 %d 名超强者，多的已移至助力位与替补。」（不改也不阻合）。 |
| **P3** | **P3-2** | `03_再刷重制_Godot/01_Godot工程/modes/xiyou/core/item_marks.gd:644-651` | `can_swap_slots(s, a, b)` 未对 `a`/`b` 做 `0 <= a, b < XState.MAX_BATTLE_MEMBERS` 越界校验。当前唯一调用方 `XPartyScene.page`（`ui/party_scene.gd:268-271`）能保证 `0..4`，UI 路径安全；但作为公开静态校验函数，对照 `_tianqi_can_deploy` 已加的越界检查（`item_marks.gd:633`），补上边界判断更稳。 | 在 `can_swap_slots` 开头对 `a < 0 or b < 0 or a >= XState.MAX_BATTLE_MEMBERS or b >= XState.MAX_BATTLE_MEMBERS` 返回 `false`。 |
| **P3** | **P3-3** | `03_再刷重制_Godot/01_Godot工程/modes/xiyou/tianqi_data/balance_table.json:3` | 表头 `source` 仍写设计仓提交 `7767262`，未更新到同步修改 `参数.json` 的提交 `8d07344`（交付单「没做的」已显式说明）。 | 总装合入后或下批数值同步时顺手更新提交号即可。 |

---

## 二、7 项核查逐条说明（分清「核了规则本身」与「只看了测试」）

### 1. 数值表 `super_cap` / `helper_super` 与 D57 对照（**已核规则本身**）
- **核了规则与数据源**：
  - 私密仓 `数值测算/参数.json` 五档配置为：寻常 `0`、艰险 `0`、九死 `1`、炼狱 `2`、证道 `2 + "助力位放超强者": true`。
  - `modes/xiyou/tianqi_data/balance_table.json:55-64` 完全一致：`0/0/1/2/2`，仅 `zhengdao` 写 `"helper_super": true`。
  - `modes/xiyou/core/tianqi_balance.gd:127-129` 与 `modes/xiyou/core/tianqi.gd:149-151,206-217` 均从表拍平 `super_cap` 与 `helper_super`（缺省 `false`），并提供 `helper_super_ok` / `helper_super_key` / `lineup_super_max`。
  - `03_转换工具/天启篇数据校验.py:37` `ROSTER_KEYS` 已加 `'helper_super': '助力位放超强者'`；实跑 `--params` 通过。
  - `nice_number_exempt` 未加 `helper_super` 合理（GDScript `tianqi_balance.gd:169` 与 Python `天启篇数据校验.py:72` 均跳过布尔值）。

### 2. 整队页放人、两格互换、翻页对调与原漏洞复现（**已核规则本身**）
- **原漏洞复现路径（已核实逻辑）**：
  - 原 `can_deploy` 为 `if not _super_in(s, actor_id) or slot < 0 or slot == XTianqi.HELPER_SLOT: return true`。
  - 场景：证道（`super_cap=2`）当前 `battle_slots = [sup0, sup1, w2, w3, sup2]`。玩家在整队页选中第 4 格（助力位，当前是 `sup2`），在名单里选已上场的非超强者 `w2` 放进助力位。原代码因 `w2` 不是超强者且目标是助力位直接返回 `true`，随后 `party_scene.gd:227-230` 将 `w2` 与 `sup2` 对调，变成 `[sup0, sup1, sup2, w3, w2]`，**场上超强者违规变为 3 名**。同理，九死也可通过直接往助力位放超强者绕过。
- **新实现核查**：
  - `XItemMarks._tianqi_can_deploy`（`modes/xiyou/core/item_marks.gd:625-640`）：`slot < 0` 时遍历 `0..4` 存在一格可放即 `true`；指定格先拦截越界格与不在 `s.party` 的角色，再在 `battle_slots.duplicate()` 上模拟对调/放入，最后由 `tianqi_slots_ok`（`:609-619`）统一校验「前 4 格超强者 ≤ `super_cap`」与「第 5 格若超强者则 `helper_super_ok(s)`」。上述原漏洞对调后会得到 3 超在场，被拦截返回 `false`。
  - 整队页列表半透明判定（`modes/xiyou/ui/party_scene.gd:156-158`）：天启篇开启 `HELPER_RULES` 时传当前光标格 `slot_index`（指令态为 `-1`，选格/选人态为 `0..4`），与确定按钮 `ok()`（`:219`）口径一致。
  - 翻页键对调（`party_scene.gd:265-280`）：`Q/E`/`PageUp/PageDown` 先过 `XItemMarks.can_swap_slots(s, slot_index, other)`（`item_marks.gd:644-651`），不合规时播蜂鸣音 `3`、不改 `battle_slots`、不移动光标。
  - 整队页其余写 `battle_slots` 路径：`revert`（`:201` 恢复到 `deploy_start` 清理后的 `_former`）、`remove`（`:213` 清 `0`）、`list` 选「离队」（`:225` 清 `0`）均立即调 `s.rearrange_actors()`（前后各走 `enforce_party`），且不会把人顶超上限。`XActorWarehouse.deposit`（`core/actor_warehouse.gd:57-65`）移出出战成员时也会触发 `s.init_battle_slots()` 进而跑 `enforce_party`。未发现绕过入口。

### 3. `enforce_party` 读档迁移（**已核规则本身**）
- **代码逐行核查**（`modes/xiyou/core/item_marks.gd:662-708`）：
  - **独立副本计算、原子效果**：在 `slots = s.battle_slots.duplicate()` 上依次完成：① 前 4 格按格序留前 `cap` 个超强者，多余记入 `extras` 和 `vacancies` 并清 `0`；② 助力位是超强者且 `not helper_ok`（九死/炼狱/艰险/寻常旧档）→ 清 `0` 并入 `vacancies`；③ `not extras.is_empty()` 且 `helper_ok`（证道）且助力位非超强者 → 弹出 `extras[0]` 放进助力位（D77）；④ `if slots == s.battle_slots: return false`（合规档不写、不改提示、幂等）；⑤ 从 `s.party` 顺序取「非超强者且不在 `slots` 中」的人补 `vacancies`，不够留 `0`。
  - **写回与全弱者资格**：只对变化的格调 `s.set_battle_slot(i, int(slots[i]))`（`xstate.gd:605-607`）。`XTianqiWeakClear` 仅在 36 层决战期间 `_tracking == true`（`tianqi_weak_clear.gd:71,95`），战外清理不会写入资格；且 `_seen` 只记非弱者污点，不会因为清走超强者授予资格，也不碰 `flags.tianqi.weak_clear` 已存记录。
  - **是否丢人/复制人/改结构**：全程不增删改 `s.party`（仅在替换时从 `party` 读取替补），不碰角色数据/装备/背包；`extras` 移出必先置 `0` 或从 `slots` 移除后才填入 `hs`，`reserves` 过滤 `not slots.has(id)`，不会复制人或丢人；**未改变任何存档字段结构**（`to_dict`/`from_dict` 零改动）。
  - **入口覆盖**：`XState.from_dict` 读档后，进入地图 `map_scene.gd:172,1553,2183` 与开整队页 `party_scene.gd:47` 均调 `deploy_start`（`enforce_party + flush_deploy_notice`），`battle_members` / `init_battle_slots` / `add_actor` / `rearrange_actors` 均会调用 `enforce_party`。若 `battle_members` 先于 `deploy_start` 清过一次，因已合规后第二次 `_tianqi_enforce` 在第 688 行提前 `return false`，不会清空此前写好的 `_deploy_notice`/`_deploy_notice_text`，进地图 `flush_deploy_notice` 仍能正常弹出一次提示。
  - **开关关掉时旧档行为**：`XTianqi.HELPER_RULES = false` 时 `enforce_party` 走原逻辑（`item_marks.gd:560-583`），只查前 4 格超强者 ≤ `super_cap`（证道因读表仍为 2，第 3 超去替补而不进助力位），九死/炼狱助力位超强者保留。

### 4. `roll_lineup` 与 `lineup_ok`（**已核规则本身**）
- **`roll_lineup` 与 `_seat_lineup`**（`modes/xiyou/core/tianqi.gd:242-290`）：
  - 先按 `min_weak` 抽够弱者，再从未抽池补齐 5 人，其中超强者计数上限为 `lineup_super_max(key)`（证道 `2 + 1 = 3`，其余等于 `super_cap`），完全打乱后再进 `_seat_lineup`：
    - 非证道（`helper_ok = false`）第 5 位为超强者 → 与前 4 位随机 1 个非超强者对调（因超强者 ≤ 2，前 4 位必有非超强者）。
    - 证道（`helper_ok = true`）前 4 位超强者超过 `cap`（只可能是 3 个全在前 4 位，第 5 位非超强者）→ 从前 4 位随机选 1 个超强者与第 5 位对调。
    - 无需调整时不消耗 `rng`（保持原种子流）。
  - `opening_commands`（`tianqi.gd:398-413`）在 `_seat_lineup` 之后按 `lineup` 顺序 `add_actor` 入队并给 `lineup[0]` 发开局技能 `2571/2786`，因此「1 号位」与前 4 格/第 5 格位置完全吻合。
- **`lineup_ok`**（`tianqi.gd:299-320`）：保留 5 人、全在候选池、无重复、`weak >= min_weak` 全部旧条件，并在 `HELPER_RULES` 下新增总数 ≤ `lineup_super_max`、前 4 位 ≤ `super_cap`、第 5 位超强者需 `helper_super_key(key)`。

### 5. 战斗换人 `can_tianqi_swap`（**核了规则本身，发现 1 个 P2**）
- **已通过部分**：
  - `battle_logic.gd:1094-1095`：新增 `if XTianqi.HELPER_RULES and not out.is_alive(): return false`，倒下的人不可换人，对齐 `v0.4.4` 一.2（且 `h` 活着已由 `:1092` 校验）。
  - `battle_logic.gd:1096-1098`：九死/炼狱下助力位超强者换上来、场上超强者换下去都拦截。
  - `battle_logic.gd:1099-1101`：保留 `is_super(h) and not is_super(out)` 时检查场上超强者数（含倒下的，因 `actors` 仍保留倒下队员）`< super_cap(state)`。
  - `battle_scene.gd:940-941,1183-1185`：`tianqiSwap` 放弃本次行动（`[null, null]`），消费行动后在演出末执行 `_tianqi_swap`，由 `h` 继承 `out` 在 `current_order`/`next_order` 里的剩余位置和 `_acted` 计数。
- **发现问题（P2-1）**：`battle_logic.gd:1097,1099,1101` 未传 `, true`，导致隐式读 `XState.current` 而非 `state`（见第一节）。

### 6. 回退开关 `XTianqi.HELPER_RULES = false`（**已核规则＋设计取舍**）
- 检索全仓 `HELPER_RULES` 全部 7 处生产代码引用（`tianqi.gd`、`tianqi_balance` 无引用但经 `tianqi.gd` 控制、`item_marks.gd`、`party_scene.gd`、`battle_logic.gd`、`entry.gd`、`tianqi_trim.gd`，另 `vp_growth.gd:541` 经 `helper_super_ok` 联动）：
  - `false` 时：助力位所有难度皆可放超强者、整队页恢复仅查放入者且 `slot` 传 `-1`、翻页不拦、`enforce_party` 只清前 4 格、`roll_lineup`/`lineup_ok` 回退为最多 `super_cap` 且不排第 5 位、`can_tianqi_swap` 退回原校验、`entry.gd` 与 `tianqi_trim.gd` 文案回退原句。
- **交付单对 `super_cap` 仍由表管之理由评价**：**合理**。`balance_table.json` 是五档 `super_cap` 单一真值来源（且受 `天启篇数据校验.py --params` 约束）；若在开关内另硬编码 `zhengdao -> 3` 会制造双真值来源。注释与开关定义已明确「上限 0/0/1/2/2 归表管」。

### 7. 新文字审（**逐字核对**）

| 位置 | 新文字内容 | 核查结论 |
| --- | --- | --- |
| `entry.gd:642-645` | 证道：`随机阵容 · 证道（同一场最多上阵 2 名超强者，助力位可再放 1 名）`；其余照旧（如九死：`随机阵容 · 九死（同一场最多上阵 1 名超强者）`） | **通过**：玩家易懂、无西游元素、与 D57/D76 一致。 |
| `tianqi_trim.gd:90` | 许可时：`助力位只有证道能放超强者，多出来的只能当替补。`（从 `helper_super_key` 动态拼接难度名；关开关时回退 `多出来的只能当替补。`） | **通过**：与前一句「每场上阵上限：寻常 0，艰险 0，九死 1，炼狱 2，证道 2。」衔接自然，无西游元素、口径一致。 |
| `item_marks.gd:522` | `本难度助力位不能放超强者，已移至替补。` | **通过**：简洁准确，与原 `TIANQI_DEPLOY_NOTICE` 风格一致，无西游元素。 |
| `item_marks.gd:523` | `本难度同一场最多上阵 %d 名超强者，多的已移至助力位。` | **通过**：准确传达 D77 行为（`%d=2`），无西游元素。（注：与 `520` 连用时有 P3-1 轻微重复，不阻合。） |
| `tianqi.gd:49`（未改，留用核对） | 炼狱描述：`敌人大幅强化，可上阵更多超强者` | **通过**：炼狱上限 2 仍高于九死 1，表述仍成立，无西游元素。 |

---

## 三、交付单「我不同意的地方」4 条与派单合理性评议

### 1. 交付单「我不同意的地方」4 条
1. **`nice_number_exempt` 不加 `helper_super`**：**同意 cc**。`tianqi_balance.gd:169` 与 `天启篇数据校验.py:72` 均天然跳过布尔值，`xiyou_tianqi_balance.gd:132` 要求豁免键只放个数类，不加更干净。
2. **战斗换人 `can_tianqi_swap` 改了（草稿曾说不用改）**：**同意 cc**。不改的话九死/炼狱会把场上超强者换进助力位、倒下的人也能换，且漏防旧档残留；加入口校验是必需的（仅 P2-1 需补传 `, true`）。
3. **D77「助力位原来的人去替补」实际等价于对调**：**同意 cc**。原助力位角色本就是主力 5 人之一、在 `party` 排在替补前，按现有补位顺序让他自然顶回空出的上场格（等于与第 3 超对调），比「强行扔进替补、拉一个未培养的第 6 人上场」合理得多，且对证道一命模式更安全。若 Kyo 坚持要严格去替补，总协调确认后改一行过滤即可。
4. **回退开关不回退 `super_cap` 2→3**：**同意 cc**。避免出现代码与 `balance_table.json` 两处真值；真要整体回退 D57 本就应同时关开关与改表。

### 2. 派单本身合理性评价
- **总体合理**：指定工作树只读核（不改代码、不跑 `并行测试.py`/长测试）、要求对照 `v0.4.4` 与 D57/D76/D77、要求区分「核规则本身」与「只看测试」，分工边界清晰。
- **两处轻微文档口径出入**（仅供总协调/总装参考）：
  1. 派单写设计依据为 `v0.4.4 第六、七节`，实际本次编队实现对照清单是 **`v0.4.4` 一.2 与第六节**（`v0.4.4` 第七节是待 Kyo 定项；原代码草稿在 `v0.4.3` 第七节）。
  2. [天启篇三方协作](00_项目管理/规则/天启篇三方协作.md) 第一节表格仍写 ag「不做的：甲档战斗核心的最终核查（交 co）」、第三节写「不再一核一报告」；派单实际按最新拍板 **D84**（允许低一级且换家核查）并要求写核查报告落盘本分支。操作上可行，建议总装后续抽空将 `天启篇三方协作.md` 第一节按 D84 同步更新。

---

## 四、本轮实际检查与未核边界（留给总装）

### 1. 本轮前台实际运行并全部通过（只跑几秒的单项）
- `python3 03_再刷重制_Godot/03_转换工具/天启篇数据校验.py --params "/Users/kyo/Documents/xiyou-design-docs/重制设定/数值测算/参数.json"`：全部通过
- `python3 03_再刷重制_Godot/07_开发环境/发行空壳.py check`：通过（62 个脚本，535 个函数都有）
- `python3 03_再刷重制_Godot/07_开发环境/语法检查.py`：通过（956 个 `.gd`，0 个问题）
- `python3 03_再刷重制_Godot/07_开发环境/回退开关覆盖.py`：通过（`XTianqi.HELPER_RULES` 无缺口）
- `./03_再刷重制_Godot/07_开发环境/godot --headless --path 03_再刷重制_Godot/01_Godot工程 res://tests/xiyou_tianqi_zhengdao_party.tscn`：**`89/89` 通过**

### 2. 本轮未运行的长测试／选测／工具（留给总装修复 P2-1 并合入前后执行）
- 专项与回归测试（本轮仅代码审阅，未独立重跑）：`xiyou_tianqi_e2e`、`xiyou_tianqi_party`、`xiyou_tianqi_opening`、`xiyou_tianqi_balance`、`xiyou_tianqi_numbers`、`xiyou_tianqi_trim`、`xiyou_tianqi_weak_clear`、`xiyou_tianqi_affix_battle`、`xiyou_virtual_player` 及云端全量/选测 `检查.sh`。
- 脚本工具：`03_再刷重制_Godot/07_开发环境/反向验证.py`、`工具回归.py`。
- 实机手测：按交付单「用户试玩说明」抽查整队页蜂鸣、随机阵容标题与 3 超占位、旧档进图单次提示。

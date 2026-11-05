# 交付：cc/nezha-raven2

- 车道／工作者：C 规则／机制·哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·哪吒·未经审查】渡鸦反射：黑暗侵蚀增伤晚一击查清并照做（dev.待定）

- **查清（raven1「没查清」那条）：原因不是神话形态，是 krz_state_re 的状态缓存时序。** Game_Actor 的特性来源 `states()` 读缓存，只有 `refresh()` 且 `need_refresh` 为真时才重建；`addState` 自己会 refresh，但如果 `need_refresh` 已被前面的 refresh 消耗掉，就不重建。同一次 apply 里「伤害充 TP」（`onDamage→chargeTpByDamage→gainSilentTp`，`floor(50×伤害/最大生命×tcr) ≥ 1`，setTp 值真变了才 refresh）会把待刷新标记消耗在渡鸦 apply 包装加黑暗侵蚀**之前**，于是黑暗侵蚀（特性 11：全元素有效度 ×1.5，经 YEP_ElementCore 加算池）要到再下一个 refresh（下一击伤害后）才进元素有效度，增伤晚一击：第二击读到 ×1，第三击才 ×1.5。TP 加 0（伤害不到最大生命 2%）时加状态当场重建，第二击就 ×1.5。
- 为什么神话形态才触发：探针里渡鸦最大生命被 paramMax 夹在 99999999，普通形态一击 1.67M（1.7%，TP 加 0），神话形态一击 2.85M（2.8%，TP 加 1）。用 tcr 强设扫过边界证实：普通形态 tcr 1.5／2 同样晚一击，神话形态 tcr 0.01 同样第二击生效（`reflect.tcr.*` 七例）。真实对局里渡鸦最大生命小得多，普通形态被反射打到 2% 也会晚一击。
- 重制照做（`modes/xiyou/core/raven.gd`、`core/actor.gd`、`battle/battle_logic.gd`）：`_execute_hp_damage` 里受伤充 TP 且 TP 真变时调 `XRaven.on_tp_refresh`（记「本次 apply 已 refresh」，并解除之前遗留的陈旧标记）；渡鸦 apply 包装新加黑暗侵蚀后，若本次已 refresh，则标 `rv_erosion_stale`；`XActor.trait_objects` 在陈旧期间不把黑暗侵蚀算进特性（只影响元素有效度这一类读取）；回合末清标记。只建模渡鸦自加的黑暗侵蚀、只对角色目标（敌人的缓存路径不同，多段技能对敌人每段只一次 apply，用不上）。
- 探针 `raven_reflect_probe.cjs`：恢复 10124 神话 `myth`、`hunt+myth` 两例，加 `reflect.tcr.*` 七例（记 TP、最大生命）。专项 `xiyou_raven_reflect` 加**绝对值**逐段比（原来只比比例），并让 `reflect.edge.*` 与参照一样不加魔防（原先 edge 两例靠比例掩盖了设置不一致）。300／300。

## 验证

- 语法检查通过；本地专项 `xiyou_raven_reflect` 300/300（含 tcr 七例、神话两例、全部绝对值）；反向验证：把陈旧标记改成永不置位后该专项 8 项失败，改回后通过。
- `工具回归.py` 全部通过。
- 选测相对 main 249 个场景（超过 40），走云端选测：提交 fc6fdf639c 全部通过（7 片，https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41947513695）。之后只改了交付单。
- 同步 `--accept-additions` 已在本工作树跑完（exit 0）。

## 待交叉核查

- 改了战斗核心：`battle_logic.gd`（`_execute_hp_damage` 加 7 行）、`actor.gd`（`trait_objects` 陈旧期间滤掉黑暗侵蚀）、`core/raven.gd`。请重点看：(1) `_execute_hp_damage` 的 TP 判定 `t.tp != tp_before` 与原版 `old + amount != old` 一致；(2) 陈旧标记只在渡鸦自加黑暗侵蚀、目标为角色时置位，回合末清；(3) 绝对值比对新加后 edge 两例改成不加魔防。

## 原版疑似缺陷

- 原版加状态后立刻读特性（元素有效度、能力值等）会读到旧的 krz 状态缓存，是否看得到取决于同一次 apply 里有没有 TP 变化把待刷新标记提前消耗。本次只照做渡鸦自加黑暗侵蚀一例（影响：反射回渡鸦的多段）；同一机制对别的「apply 内加状态后同一目标又被命中」的场景（多段技能打同一角色、反射）理论上都有，未逐个量，也未泛化到 `XActor`，没有擅改。建议：派一条量「多段／反射 + 加状态」的探针，看还有没有别的状态受影响（预计很少，因为敌人路径不同）。

## 插件备注覆盖（第 5 条，只列不做）

- 工具现状：「拿不准」一类已经没有了（之前的 12 项都已被前人核成「已核」）；现在 240 项有用量的里：已读 218、已核 21、没读 1。
- 唯一「没读」：`CodexWeakNewGame`（Skills#10357，弱者挑战技能「本质高手」）。核实：原版 `installWeakChallengeRuntime` 里这个标签只用来把物品说明里「品质：」那行显示成「品质：神话」；但弱者挑战整体——弱者角色学／忘 10357、伤害钩子 `finalMultiplier ×3`（`window.CodexDamageHooks` 的 `weak-new-game`）、成就 142——重制没有对应（`rg 10357 weak_challenge` 只在成就相关处有名字，没有伤害钩子）。结论：**真缺（弱者挑战模式整体），不是标签漏读**；是否做取决于用户是否要这个模式，建议登记进优化登记／后续清单，由总装决定。

## 交接板

- 下一步：无（渡鸦反射收口）；可选：弱者挑战（见上）、多段／反射加状态探针。
- 用户试玩说明：无可见变化（只影响魔法反射打到渡鸦自己时黑暗侵蚀的增伤第几击生效）。
- 需要用户决定：弱者挑战模式是否要做（见上，默认不做）。

## 可优化（流程／工具／效率）

- 建议：`插件备注覆盖.py` 的 `没读` 一行没有区分「标签没读」和「整个玩法没做」；`CodexWeakNewGame` 这类带玩法的需要人工看一眼（工具侧可加「玩法缺失」提示，归工具车道，收益小）。

## 本分支提交

- WIP 渡鸦反射黑暗侵蚀晚一击：krz 状态缓存时序，重制照做，探针恢复神话两例并加 tcr 扫描，专项比绝对值

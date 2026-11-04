# 交付：cc/bajie-rules3

- 车道／工作者：C 规则／八戒（cc，唐僧总装十九派）
- 状态：可合并
- 基于 cc/bajie-rules2b（含护盾一族），合并时先合 rules2b 或直接合本分支。

## 变更记录草稿

## 2026-11-04 【cc·八戒·未经审查】自动复活 17 块翻成原生实现（dev.待定）

- **原版行为**（`state_effects_probe` 新用例 `revive.blocks` 实测）：切片可达 11 块（114、252、1099、1164、1178、1191、1270、1683、1725、1837、2560）与同模板的全游戏可达 6 块（163、494、1255、1258、1733、2712），都是 Custom Deselect Effect。条件四种：倒下（`hp<=0 或 isDead`）；倒下且抽一次随机；`hp<=0 且抽 || isDead 且抽`（真实倒下时最多抽两次，实际概率比字面高）；`hp<=0 且变量大于阈值`。动作按原顺序逐句执行。1683 写的变量号超出 System 范围，写入被忽略、读回 0，所以 **1683 绯红之夜在原版永远不触发**；照原版保留（见「需要用户决定」）。1191、1733 回血不取整，血量可以带小数，照原版。
- **热列表**（`resource_context.gd`）：非 `<Permanent>` 的状态（114、252、2560 等）被死亡清掉后，deselect 还跑不跑取决于 krz 缓存：出手前列表标脏时，致死那次 refresh 只标脏，用时重建，已清掉的状态不再触发；没标脏时旧列表照用，已清掉的状态仍触发复活。原来 `param_refresh` 在死亡之前就存快照，脏的情况也会触发，现在脏且这次 refresh 加上死亡时让列表作废。
- **转换器**（`xiyou_export.py`）：`revive_state_effect` 只认 deselect 阶段，条件和每一句都整句比对（`REVIVE_CONDS`、`REVIVE_GAIN`、`REVIVE_STEP_RE`），有一句不认识就退回 js。译成 `{op: revive, cond, steps}`。生成数据 `op: js` 301 → 284。
- **运行时**（`state_effects.gd`）：`revive` 按 `steps` 执行；原来只认 1270 原文的 `REVIVE_JS` 去掉。动画经 `_note_anim` 进命中记录 `state_anims`，`battle_logic.apply` 在 deselect 后并入结果，由 `battle_scene` 播。变量写入范围检查抽成 `_variable_writable`，与 `set_variable` 共用。
- **报数**：`xiyou_state_effects_tp` 的 `inventory.untranslated_159` 改 `untranslated_142`（换装 142 不变）。
- 测试：`xiyou_state_effects` 加 `_revive_blocks`（552 行单块，比随机次数、三种资源、状态、动画、变量、弹字、结果槽；136 例真实 `apply`，含标脏与否）；`测试状态js翻译.py` 加 `ReviveTranslationTests`；`测试未翻译块清单.py` 不再写死块数和快翻掉的族。

## 交接板

- 下一步：未翻译状态块剩 284（换装 142 不用翻，真未翻 142）；切片可达明细见 `未翻译块清单.py --detail`，复活族只剩 1 块。
- 用户试玩说明：龙涎、七星续命、预感的庇护、疯癫韧性、拼命守护、执念和声、死而复燃、不朽、恨魂不屈、绯红之夜（2560）等现在受致命伤时会按原版概率复活。刚加上还没刷新过的非永久状态（龙涎、七星续命）和原版一样，死亡时不一定来得及触发。
- 需要用户决定：状态 1683 绯红之夜在原版因变量号超范围永远不触发，现在照原版不触发。要不要作为优化改成能触发（同名的 2560 能用）？默认不改；需要优化登记号时请总装分配。

## 进度账

- 战斗规则：未翻译状态块 301 → 284（真未翻 159 → 142）；切片可达复活 11 块清零。

## 可优化（流程／工具／效率）

- `value_query` 副作用拆 op 评估（rules2 草稿提的）：不拆。护盾只有「清零＋破盾」一个组合，已有 441 行对照锁住，拆了只是搬代码。这次复活走单独的 `revive` op、内部 `steps` 按原顺序跑，下一族要「条件＋几步副作用」时可以照这个写法或直接复用，等真有第二族用到再抽公共部分。
- `测试未翻译块清单.py` 原来写死总块数，每个规则期都要挂一次，已改成和数据自比。
- 云端选测的产物快照这次上传约 25 分钟，比跑测试本身（约 13 分钟）还久，且多条车道同时传；哪吒 tools56 已动 upload 推送设置，合入后可再量一次。

## 验证

- 云端选测：提交 adbe5adfd4，210 个场景 7 片，全过（Actions run 41745576213）；`xiyou_rules` 按选测抽样，没关抽样。
- 专项（本机）：`xiyou_state_effects` 22681、`xiyou_state_effects_tp` 538、`xiyou_state_js` 1733、`xiyou_honghuang_curse_battle` 344、`xiyou_boss_state_origin` 15723、`xiyou_state_merge_context` 866、`xiyou_review135` 85、`xiyou_determinism` 372、`xiyou_battle_events` 108、`xiyou_death_admission` 37，全过。
- 工具：`测试状态js翻译.py`、`测试未翻译块清单.py` 过；`语法检查.py` 0 问题；`内容覆盖检查.py` hard 0、new 0。
- 同步：`同步正式西游.py --accept-additions` 退出码 0，只新增 `query.shield_blocks`、`revive.blocks` 两个用例；之后只提交了测试文件和本交付单，产物指纹仍有效，可用 `--from-worktree`（若先合 rules2b，就照常重跑）。

## 本分支提交

- adbe5adf 未翻译块清单测试不写死块数与快翻掉的族（rules2／rules3 合入后会挂）
- 24a9e452 Merge branch 'main' into cc/bajie-rules3
- 8ab3ba9a WIP: rules3 自动复活 17 块翻成 revive（条件＋步骤），探针 revive.blocks，死亡后列表按 krz 标脏重建
- 64e3b4bf 合并 cc/review-35
- e2ffc3d8 合并 cc/nezha-tools56（dev.298）收尾
- 2ce429d2 合并 cc/nezha-tools56
- f01c81e7 合并 cc/nezha-tools55（dev.298）收尾
- e4c1a255 审查第 35 期报告：改正提交号与块数
- f8e40b21 审查第 35 期：核 tools54、rules1b、tools53b（P2 两条、P3 两条、P4 四条）
- a1e5edab 交付单：cc_nezha-tools56（可合并）
- 07e06a52 云端选测：推产物带网络设置；回退开关覆盖认工具开关（JSON 字段／环境变量）
- 5aad1d8b 合并 cc/nezha-tools55
- f1f8eb54 合并 cc/wukong-xuan4b（dev.298）收尾
- 0cd6c8bd tools55: 交付单措辞
- a4313c26 tools55: 未翻译状态块 × 切片可达清单脚本、测试、交付单
- 本交付单收尾提交

## 待交叉核查（核心文件）

- `state_effects.gd`（`revive`）、`resource_context.gd`（致死 refresh 让列表作废，影响所有状态的 deselect 等热列表）、`battle_logic.gd`（`state_anims` 并入）。

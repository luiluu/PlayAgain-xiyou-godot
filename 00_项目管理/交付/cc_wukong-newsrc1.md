# 交付：cc/wukong-newsrc1

- 车道／工作者：C 规则·探针＋转换器／BL（cc，悟空）
- 状态：可合并

## 变更记录草稿

## 2026-11-05 【cc·BL·未经审查】换源前置：8 个探针在新源 v0.62.12 跑通，转换器认注释行与 (v[N]||0)（dev.待定）

依据 BF 交付的[换源测量变化_v0.62.12](../../03_再刷重制_Godot/02_内容与素材/冻结正式源/换源测量变化_v0.62.12.md)第一节。没换源、没改默认路径、没登记、没出接受单。每个探针都在新源（`XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`，`XIYOU_GENERATED` 指向新源转换产物）跑到退出码 0、用例无报错；改完在旧源 v0.28 再跑，产物与改前**逐字节相同**（`cmp`，8 份都比了；改前旧源产物也和本树 `generated/oracle` 逐字节相同）。

- **alien_workshop／alien_config**：按 Kyo 新口径量前不装 `installAlienationHide`。做法是探针启动时临时包一层 `fs.readFileSync`，把 `main.js` 安装序列里那一行去掉再交给 `hboot`（v0.28 的 main.js 没这行，读到的内容不变）；启动后断言 `CodexAlienationHide` 不存在。没改 `hboot.cjs`／`shared/`，免得全部探针缓存键失效、下次同步整轮重跑。
- **battle_event**：`scan.inventory` 的期望敌群／页数改成按冻结源版本查表（v0.28：35／47，v0.62.12：51／73），没登记的版本直接报错，不放行。
- **raven_artifact**：v0.30 起法宝成长从生命改魔法，`R.artifactHpBonus` 换成 `R.artifactMpBonus`；有哪个量哪个（旧源写 `hpBonus`、新源写 `mpBonus`），魔攻照旧。
- **item_marks**：v0.40 起（`installSafeSellRuntime`）商店一键出售先弹确认窗。新源上探针建出正式的一键出售窗与确认窗、按「确认出售」走正式交易，并把确认窗各行与保留原因记进 `onekey[].confirm`；旧源没有确认窗，照旧直接卖。新源结果的差别（供换源时对账）：第 0 档 `reward`（专属武器 73）保留为「专属」、`zero`（0 价无其他货币）保留为「不可出售」、`missing`（没品质标签）改为卖出；第 6 档多卖 `q15`。
- **weapon_unleash**：武器 93 是利姆露 166 的专武，v0.30 起 166 在 `CodexImportedBalance.disabledActorIds`（停用角色），上不了场、`canMove` 为假，没人能装。新源上没人能装的武器，临时把装它的停用角色从名单里拿掉再量，量完放回，用例输入记 `enabledDisabledActor`（只量专武的解放机制；重制跟不跟停用另说）。旧源全部武器都有人能装，不走这里。
- **attack_query**：`actorCase` 改成先 `addActor` 再标 `_inBattle`。原因见下「OTB 崩溃」：不是正式版的真 bug，是探针造出「战斗中但 BattleManager 没 setup」的假状态。
- **event_state**：v0.30 起深渊商人改成脚本 `CodexAbyssMerchant.openCurrent(this)`，原来的第 3 页（`p2`）删掉了，`event_presets.json` 里 23 个以这些页为基础的预设（`b1`／`b2`：m107／110／113／141／152／162／164／165／167／168／176、m37／38／50～53／56～59／160／161）在新源找不到。给这 23 个预设加 `"goneIn": ["v0.62.12"]`：该版本跳过并记进产物 `skippedPresets`；没标却找不到、标了却还在，都报错。旧源产物不变（`skippedPresets` 只在非空时写）。新源量出 1781 个用例（1804－23），全部跑完。
- **转换器**（`equipment_rules.custom_params`）：① 去掉 `<Custom Parameters>` 里的 JS 行注释（`// KYO专武成长`），② `(v[N]||0)` 当 `v[N]`（v0.52 起极品双持武器 74／75／1926／1927 这样写，变量值是数，两者等价）。新源转换器问题 83→8（剩 4 条 Items 170／242～244 升级行、4 个缺音频，旧源本来就有同类），旧源转换产物（db、maps、slice.json、manifest.json）与改前逐字节相同。BF 清单说的「另 4 条 Items 升级行」其实旧源就有，新增的那 4 条是这几把武器的 `||` 写法。

**OTB 崩溃（attack_query 栈里的 `installOtbRestoreCapRuntime`）**：结论是**正式版没有这个崩溃**，不用告诉正式版维护。复现（新源）：`newGame()` 后 `$gameParty._inBattle = true`，再 `$gameParty.addActor(154)` → `Game_Party.addActor`（OTB 包装）→ `otbAddBattler` → `otbInsertActionOrders(battler, BattleManager._actionBattlers)`，此时数组是 `undefined`（BattleManager 没 setup），`installOtbRestoreCapRuntime.js:12` 见 `!array` 就转给原函数，原函数 `Olivia_BattleSysOTB.js:870` 的 `array.contains` 崩。对照：① 直接拿插件原函数（不经包装）用 `undefined` 调，同样崩，所以包装没引入新崩溃；② 真战斗里 `BattleManager.setup`→`initMembers` 先把 `_actionBattlers`／`_nextTurnActionBattlers` 建成数组，这时中途 `addActor(154)` 正常。旧源不崩只是因为 v0.28 里这种入队不会让 154 立刻进出战成员（`allBattleMembers` 不含它，`otbAddBattler` 不往下走）；v0.62.12 空位入队当场进出战成员。

**smart_ai_probe 新源慢**（只定位，没改）：取 5 个敌群（2、677、161、630、72）×各场景、`node --cpu-prof` 对比：旧源 24.6 秒、新源 58.6 秒；多出的时间几乎全在每个场景开头的 `setup()`→`DataManager.setupNewGame`（17.7→50.5 秒），AI 选择本身只多约 1 秒。新局变慢的两处：`installUniqueEffectMarkRuntime.js`（v0.56「◆唯一」，`createGameObjects` 后 `sweepLive`＋`sweepDatabase` 遍历整份对象图，约 19 秒）、`installAbyssMerchantRuntime.js`（`isAbsorbActor` 每次对全部武器跑 `absorbOwners`，缓存前先做 `<CodexHiddenEquipment>` 正则，约 12 秒）。BF 推测的 dsPassiveSkill 只多 0.2 秒，不是原因。同一原因也让 event_state_probe 在新源从约 4.5 分钟变成 24 分钟（1441 秒）。凡是每个用例都开新局的探针都会这样慢 2～5 倍。

## 交接板

- 下一步：BL 合进 main 后，总装照[换源操作单](../../03_再刷重制_Godot/02_内容与素材/冻结正式源/换源操作单_v0.28-v0.62.12.md)换源；接受单里 alien_workshop／alien_config 两份按新口径应当变化很少（没装隐藏），event_states 会少 23 个变体（`skippedPresets`），换源后决定这 23 个预设删掉还是改到新的深渊商人脚本上。
- 用户试玩说明：无（探针与转换器，游戏不变）。
- 需要用户决定：无（停用角色 166 等跟不跟、深渊商人改脚本跟不跟，属换源后的内容跟进，按盘点表分期）。

## 进度账

- 无

## 可优化（流程／工具／效率）

- 建议：换源后同步里开新局多的探针（smart_ai、event_state、slice 等）会慢 2～5 倍。可以在 `shared/host.cjs` 的 `newGame` 或探针里，对不需要唯一特效说明的用例跳过 `installUniqueEffectMarkRuntime` 的整图扫描（只影响说明文字，不影响数值），或给 smart_ai 按敌群复用一次新局再按场景只改血量；预计 smart_ai 回到 1 小时以内。要改 `shared/` 会让全部探针缓存失效一次，最好和换源那轮同步一起做（归 C 车道）。

## 待交叉核查

- 探针：`alien_workshop_probe.cjs`、`alien_config_probe.cjs`、`battle_event_probe.cjs`、`raven_artifact_probe.cjs`、`item_marks_probe.cjs`、`weapon_unleash_probe.cjs`、`attack_query_probe.cjs`、`event_state_probe.cjs`；输入 `event_presets.json`（23 条加 `goneIn`）；转换器 `equipment_rules.py`（`custom_params`／`_linear`）。未改战斗核心文件。
- 重点：weapon_unleash 临时解除停用角色是否合适；item_marks 新源走确认窗的做法；event_state 的 `goneIn` 口径。

## 验证

- 8 个探针：新源全部退出码 0、无报错用例；旧源改后产物与改前 `cmp` 逐字节相同（8 份）。
- 转换器：旧源转换产物 db／maps／slice.json／manifest.json 与本树 generated 逐字节相同；新源问题 83→8。
- `工具回归.py` 全过（47 秒）；`语法检查.py` 0 问题。
- `选测.py main --list` 列出的 75 个场景（`xiyou_alien_config`、`xiyou_alien_workshop`、`xiyou_attack_query`、`xiyou_battle_events`、`xiyou_event_compare`、`xiyou_item_marks`、`xiyou_raven_artifact`、`xiyou_rules`、`xiyou_rules10`、`xiyou_rules_d1b`～`xiyou_rules_d6p` 全部分片、`xiyou_status_power_panel`、`xiyou_transform_params`、`xiyou_weapon_unleash`）全部通过（3196 秒，并行 2），无偶发。
- 工作树 `同步正式西游.py --accept-additions`：重跑改过的 8 个探针，结果「测量不变」，退出码 0，已留产物指纹。

## 本分支提交

- 见 `git log main..cc/wukong-newsrc1`

# 交付：cc/wukong-nanoha2

- 车道／工作者：A 内容·楼层／悟空（cc，悟空 nanoha2，Opus medium）
- 状态：进行中

本期做到派单第 2 条（1774／1780 公共事件预约）；第 1 条（自定义 MP 消耗＋伤害后多段）、第 3 条（小魔炮）没开工。上下文到交接线，按车道须知停手，接续要点在文末。分支从 `cc/wukong-nanoha1` 切出，**还没合 main**（开工时 nanoha1 尚未并入 main）。

## 变更记录草稿

## 2026-11-03 【cc·悟空·未经审查】奈叶二期：领域与身经百战的公共事件预约（dev.待定）

- **原版参照**：新探针 `mv_oracle/nanoha2_probe.cjs`（真实 `Scene_Battle.prototype.start`，含 `BattleManager.startBattle` 和 dsPassiveSkill 其后加的被动 StartPushState；再奈叶、队友各行动一次，回合结束；记每步 `$gameTemp.reserveCommonEvent`），产物拷成 `tests/fixtures/nanoha2_oracle.json`。结论：
  - 领域 1774 的 `<Custom Battle Effect>`（预约 2478）在原版**从不触发**：被动状态是在 `startBattle` 跑完开战效果之后才加的。开战只预约 1320。所以「魔法领域：全员按奈叶等级加全属性」在原版是死内容。
  - 身经百战 1780：只有奈叶行动开始时预约 2481（防转换）；action_end 的 2480（攻转换）在 OTB 下不触发；队友行动、回合结束都不预约。
- **转换器**：`parse_state_effects` 把 battle／action_start／action_end 三个阶段里单独一句的 `$gameTemp.reserveCommonEvent(N)` 翻成 `{op: reserve_common_event, id}`（全库只命中 1774、1780 两块；带条件的 887、1318、2007 等和 apply 阶段的 2033 不动）。
- **Godot**：`XStateEffects` 新 op `reserve_common_event`，把编号存进静态整数表；`battle_logic.gd` 新 `_take_state_reserves()`，在开战 battle 分发后和两处 `action_start` 之后取出，交给 `XBattleCommonEvent.reserve`（单槽）。`NEVER_FIRED` 没动：action_end 照旧不触发，2480 不会被预约。重制开战次序本来就是「开战效果→被动状态」，和原版一致，1774 翻了也不会触发。
- 切片 `extraCommonEvents` 加 2481（2478、2480 原版走不到，不加）。
- 专项 `xiyou_nanoha` 加 field 段（开战状态与 1320、奈叶行动 2481、队友与回合结束不预约），44/44；反向验证：去掉 `_reserves.append` 后 field.nanoha.attack 挂。

## 交接板

- 下一步：奈叶二期剩 ①自定义 MP 消耗＋伤害后多段、③小魔炮六选一（见「接续」）。
- 用户试玩说明：奈叶每次行动前，身经百战会把双防的一部分转成双攻（CE2481），跟原版一样。
- 需要用户决定：（可选，默认不做）领域 1774 在原版是死内容，「魔法领域」说明写的全员加成玩家永远拿不到。要不要当作原版缺陷做活（登记优化、可回退）？默认照原版不做。

## 进度账

- 不改数（二期未完）。

## 可优化（流程／工具／效率）

- 无新增。

## 接续（给新会话）

- 现场：分支 `cc/wukong-nanoha2`，工作树 `.claude/worktrees/pensive-ishizaka-dad20c`，已全部提交，工作区干净。改了切片和转换器，**还没跑同步**，选测也没跑，只跑了 `xiyou_nanoha` 44/44、`xiyou_state_effects` 19949/19949、`xiyou_state_js` 1733/1733、语法检查。
- 开工：nanoha1 已并入 main 后 `git merge main`，再 `新建工作树.sh --补齐 <路径>`。
- ① 自定义 MP 消耗＋伤害后多段（5703～5706、5708、5709）：转换器现在把 `<Custom MP Cost>`／`<Post-Damage Eval>` 块拆成乱 meta 键（如 `' user._costmp; i++) {…': True`），先在 `xiyou_export.py` 解析出这两块（比例、`_costmp = floor(mp*比例/2000)`、多段 `gainHp(-value)`＋弹字，重复 `_costmp-1` 次），再接消耗与多段；先写 `mv_oracle` 参照（各档 MP、单体／全体，逐段 HP 与弹字）。ACS 插件 `Bailong_NaiyeACS_FastSettlement..js` 在段数超过 512 时把尾段合并（数学等价，只影响弹字个数），对照时注意。
- ③ 小魔炮 5692：技能效果 44 调 CE2483（已在 extraCommonEvents），内容是 102 六选一→339 强制奈叶用 5703～5709。先确认战斗事件解释器在战斗里支持 102 选择窗（手动战斗可能已经能用），再做 `smart_ai.gd` 的 `cannonOptions`（`Codex_SmartBattleAI.js`：六档候选，`cannonHits = max(1, floor(beforeMp*power/2000))` 估伤害；现在 `smart_ai.gd:479` 只是把 5692 排除）。
- 最后：一轮 `同步正式西游.py --accept-additions`（`长任务.py start`＋`等待任务.sh --timeout 540`，开始前先提交），`内容覆盖检查.py`，`选测.py main --list`＋`并行测试.py --jobs 2`。
- 原版次序上的小差：原版 startBattle 先预约 1320、再跑开战效果；重制 `setup` 是先跑开战效果、末尾才预约 1320。只有开战效果里预约公共事件时才分得出来，全库唯一的 1774 走不到，没改，只记下。

## 本分支提交

- 见 `git log cc/wukong-nanoha1..cc/wukong-nanoha2`

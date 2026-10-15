# 交付：claude/bajie-wtype

- 车道／工作者：B 规则／八戒（Claude，重制_八戒_4 → 重制_八戒_5 接手收尾）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-wtype`
- 状态：可合并（已合 main ed88443；检查.sh --oracle 只有 xiyou_opening_branches B 分支 4 项失败，是 v0.27 新轮回入口模块所致，唐僧已派悟空补，不是本分支）
- 任务（唐僧 2026-10-15 派）：XBattleLogic.can_use 补 MV isSkillWtypeOk（技能要求武器类型），XPower 改用同一实现；严格级参照探针逐例比对 canUse。
- 预分配编号 O-031～O-033：未用（本轮只照正式版补规则，没有优化项）。

## 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】技能武器类型要求（dev.待定）

- XBattleLogic.can_use 补 MV Game_Actor.isSkillWtypeOk：技能的 requiredWtypeId1/2 有值时要装着其中一种武器（敌人恒真）。isWtypeEquipped 照 dsPassiveSkill 改写：被动 <SkETypeAll: t> 装着任一列出类型时全部类型算装着；<SkEquipType: t> 有值时只认该类型（正式数据未用）；否则看身上武器。实现为 XBattleLogic.wtype_ok／wtype_equipped，XHangUpAuto.wtype_ok 改为转调，XPower 去掉另判（挂机、战力、战斗共用一处）。
- 新参照探针 mv_oracle/wtype_probe.cjs（已加进同步正式西游.py 的 PROBES，输出 wtype.json）：切片角色 10 级 × 默认／裸装／12 种武器类型第一件 × 已学技能＋几招有武器要求的技能，共 1036 例，记 isSkillWtypeOk、战斗中满 MP/TP 与 MP/TP 清零时的 canUse、MP 上限。tests/xiyou_wtype 逐例比对 1039/1039（676 例被武器要求拦下，339 例被费用拦下）。
- 查清：重制_八戒_4 看到的「10 级 MP 上限 Godot 480、正式版 200」是探针搭法问题——正式版 krz_state_re 在战斗中用 _ParamCache2 缓存属性，只在 need_refresh 时重算，探针先把 inBattle 设真再 changeLevel，缓存停在 1 级值。真实游戏只在胜利结算时于战斗中升级，战后即按新等级算，不影响玩法。探针改为战斗外搭装备、升级，并照正式版 Z.refresh 的写法清缓存后再量。
- 旧测试夹具按正式版改（不改规则）：xiyou_battle_ui 先手美娜的唯一战技「寒锋」要求武器类型 1，默认水果刀是类型 0，正式版同样放不了，开战前换类型 1 的剃须刀（装武器后打完一战约需 62 轮，「真实打完这一战」的循环上限 60 放宽到 200）；xiyou_combat 冷却与反击用的击木楔(401) 要求类型 5，狗逍遥的练习剑是类型 2，换指虎。
- 验证：检查.sh --oracle 在 v0.26 产物下除「西游来源/转换/参照不一致」（正式版 16:30 前后更新到 v0.27）外全部通过（45 项）；在 worktree 跑同步正式西游.py 换成 v0.27 产物后，来源项通过，只有 xiyou_opening_branches（b_hub/b_switches/b_items/b_suppression）失败——v0.27 改了 Map221，与本分支无关。xiyou_wtype 1039/1039、xiyou_battle_ui 35/35、xiyou_combat 34/34、xiyou_power 102/102。
- 提交：508a101、8e4ed39、b82f6e1、123f54e 及交付提交
- 已知：krz 战斗中属性缓存本身未移植（只影响胜利结算画面里刚升级角色的上限显示，未核对正式版画面）。
```

## 正式源 v0.27

- 唐僧已在 main 登记 v0.27（65047ed）。本分支合 main（ed88443）、--补齐 后跑 检查.sh --oracle：45 项通过，只有 xiyou_opening_branches 的 b_hub／b_switches／b_items／b_suppression 失败（v0.27 新轮回入口模块，已派悟空）。v0.27 下 wtype.json 不变，xiyou_wtype 1039/1039。

## 交接板

- 下一步：删掉第 7 条「技能武器类型要求」。
- 用户试玩说明：没装对应类型武器时，要求武器的技能（如 101 御剑术要剑）在战斗、挂机里都不能用，技能列表里显示为灰色（与原版一致）。
- 需要用户决定：无。
- 待交叉核查：508a101、8e4ed39、b82f6e1 及合并提交（八戒）——核查重点：wtype_equipped 的 SkETypeAll／SkEquipType 优先次序；wtype_probe 清缓存的写法是否完整；两个夹具改法是否只换武器。

## 进度账

- 战斗规则：本条是规则缺口修补，不单独加进度（照实记初值，由沙僧复核）。

## 本分支提交

- ee7a353 开工交付单
- 508a101 XBattleLogic.can_use 补 isSkillWtypeOk，挂机与战力共用；wtype_probe 与 xiyou_wtype
- 4d54a13 WIP：交付单写停在哪里
- 41a80c8 合并 main（e9f306a）
- 8e4ed39 改 xiyou_battle_ui／xiyou_combat 夹具
- b82f6e1 wtype_probe 战斗外搭法并清 krz 属性缓存、加 MP/TP 清零时 canUse；xiyou_wtype 逐例比 canUse 与 MP 上限
- 123f54e xiyou_battle_ui 打完一战的循环上限 60→200
- 020ce92 合并 main（2b8f4bd）
- 145eae4 交付单可合并
- 52a0504 合并 main（ed88443，v0.27 登记）
- （本提交）交付单注明 opening_branches

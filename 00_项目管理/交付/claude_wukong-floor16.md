# 交付：claude/wukong-floor16

- 车道／工作者：A 内容·楼层／悟空（Claude，重制_悟空_4）
- 状态：进行中（楼层跑拆法、十六层、十七层、数值链修复已完成；交付检查中）

## 变更记录草稿

### 2026-10-15 【Claude·悟空·未经Codex检验】扩十六层 Map033、十七层 Map045；共用数值链：敌人被动缓存与固定减伤顺序（dev.待定）

- **xiyou_floor_run 拆法**：原来按 ceil 均分（parts），第 4 段 13～15 层已到 199.5 秒，parts 加一仍是同一段。改为按层指定段 `SEGMENTS := [1, 5, 9, 13, 15]`（场景只设 part，最后一段到楼层表末尾，新层自动落进最后一段；单场景过约 170 秒就在末尾再切一段）；加 `xiyou_floor_run_e`（第 5 段）。实测第 4 段（13～14 层）163 秒、第 5 段（15～17 层）146 秒。
- 切片加 Map033（变量 20＝16 → (20,22)）、Map045（变量 20＝17 → (14,35)）；敌群 133～137、172（十六层守层者海王子）、171、175～178、173（十七层守层者妖精公主）；`maxLevel` 43 → 48。keepEvents "33" 放 2～8（闲谈村民、守层者、辛德瑞、两处空事件、坤坤找人的信徒（公共事件 819）、宝物），副本入口 1 未放；"45" 放 1、3～9（守层者、宝箱、商贩、辛德瑞、装饰、宝物），副本入口 2 未放。两层守层者敌群事件与 111／118／138 相同；`troop_event_probe` 加 172／173，`xiyou_troop_events` 656 → 748。
- **共用数值链（严格级，参照对上）**：十七层妖精仙子（敌人 180）、妖精公主（181）带被动技能「伤害抵抗(1000)／(2000)」（`<passiveHarmRe01～04>`），放在行动列表里。① 正式 dsPassiveSkill `Game_Enemy.refreshPassiveCache` 扫的是 `Game_Enemy.skills()`（行动列表逐条，重复的也算）与状态，不扫敌人自身备注；Godot `XEnemy.refresh_passive` 原来扫敌人备注＋状态，漏了这类被动 → 改照原版。② 正式 installDamageElementRuntime 的固定减伤（harmRe、种族减免）在 entered 阶段扣——状态脚本（Confirm/React）之后，按比例摊回各属性候选、各减固定减伤取最大、四舍五入；Godot 原来在 `calculate` 里先扣再乘状态脚本。改为 `calculate` 只算扣之前（吸收照原版仍先扣），新增 `XDamage.finish`／`apply_fixed_mitigation`，战斗（`_damage_value`）与战力估算（power.gd）都改用。之前参照里没有对角色攻击生效的固定减伤，所以没暴露。
- `xiyou_floor_run` 测试队伍攻击／魔攻 5e9 → 5e11：十六层海王子生命 1.5e12、每回合回复约 20%，原来一回合只打掉 0.4%，战斗打不完（数值与正式版一致，`xiyou_rules` 敌人能力值全过）。
- 验证：`同步正式西游.py`（v0.27 不变）「有变化」只来自切片扩大；`godot --import`；`xiyou_event_compare` 392/410 → 427/445（新增 35 例全部一致，baseline 不用改）；`xiyou_rules` 44288/44288（修之前 260 项 stateEffects 不一致，全在敌群 173／178）；`xiyou_smart_ai` 15815/15815；`xiyou_troop_events` 748/748；`xiyou_map` 43/43；`xiyou_power`、`xiyou_combat`、`xiyou_battle`、`xiyou_hangup_auto`、`xiyou_review_regressions` 全过；`xiyou_floor_run_d` 167/167、`_e` 205/205。
- 未完成／已知问题：十六、十七层守层者开关 2302 等各页（敌群 751／752 等）未接；守层者「索要礼物」商店的 `ShopInventory` 限购照旧跳过；坤坤找人（公共事件 819）只放了信徒事件本身。

## 交接板

- 下一步：「扩楼层」条改为已到十七层主图（加 Map033、Map045），事件对照 427/445；十八层＝Map046 (21,49)。`xiyou_floor_run` 改为 SEGMENTS 按层指定段，加层后看最后一段时间，过约 170 秒在末尾再切一段并加场景。
- 待交叉核查加本分支（核查重点：`XEnemy.refresh_passive` 改扫行动列表；`XDamage.apply_fixed_mitigation` 的候选摊回与吸收／抗性 0 分支；keepEvents "33"、"45"）。
- 用户试玩说明：新增十六层亚特兰蒂斯遗迹、十七层妖精湖；十七层妖精类敌人有固定伤害抵抗（每次伤害先算加成再减 1000／2000），与正式版一致。
- 需要用户决定：（如有）

## 进度账

- 楼层：8% → 9%（地图 19/231 → 21/231，加 Map033、Map045），悟空初值，待沙僧复核。

## 本分支提交

- （进行中）

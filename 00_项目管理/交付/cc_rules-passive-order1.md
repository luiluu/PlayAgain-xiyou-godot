# 交付：cc/rules-passive-order1

- 车道／工作者：C 规则／八戒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-10 【cc·八戒·未经审查】右侧状态格轮换顺序对齐原版：异常→增益→常驻、同类按拼音（dev.待定）

- 接 rules-battle-pixel2 留下的「状态格里多个被动状态轮换顺序与原版不同」。查原版后，当时记的「原版按被动来源顺序」不对：`installEquipmentStatusRuntime` 的 stateRows 最后有一步 `result.sort`，先按类别（stateKind：被动＝不在 `_states` 里的一律「常驻」；否则看 `<BuffType>`、行动限制、1 号、名字里的诅咒／中毒等、特性 21／22 降低与 42 封印，再看 `<Permanent>`）排「异常→增益→常驻」，同类按名字 `localeCompare(…,'zh-Hans')`（拼音序），强弱化行（「物攻强化」「敏捷弱化」）一起排；V8 稳定排序，同类同名保持 states() 原顺序。敌群 2 的原版读数 995→1691→1631 正好是「破阵——天道诅咒」名含诅咒算异常、另两个常驻按拼音「难度适应」在「普通难度」前，与来源无关。
- 改：`XSideStatus.cell_rows` 照这套排序（新 `XSideStatus.state_kind`）。Godot 没有 ICU 排序，新增 `XZhCollate`（`core/zh_collate.gd`）＋生成的字表 `core/zh_collate_data.gd`：`07_开发环境/生成中文排序表.cjs` 用 Node 的 `Intl.Collator('zh-Hans')` 给 2.3 万个字定一级／三级序，生成时用同一算法排原版全部 1770 个状态名＋强弱化名、与 ICU 逐项相同才写文件；另用 Chrome 157 核过同序。正式源换版后重跑这条脚本即可。
- 复现原版，不登 O 号、不加新开关；原有回退 `XSideStatus.CELL_FILTER = false` 时也不排序（回到改之前的整套旧行为）。
- 玩家可见：右侧头像左边的小状态格轮换先后与原版一致——先轮异常（含弱化），再增益（含强化），最后常驻／被动，同类按名字拼音。
- 验证：新专项 `xiyou_side_status_order` 12/12（1770 个名字排序逐项等于 ICU；全部状态的类别逐个等于原样调用原版 stateKind 的结果；995／1691／1631＋强弱化的实际轮换顺序；CELL_FILTER 回退）；`xiyou_battle_pixel` 的 `cell_icons_layout` 由比集合改为比顺序 1035→579→4210，`cell_buff_stack` 改为在行里找强化（排序后不再是最后一行）；本机选测（`选测.py main --list` 的 8 个：ui_smoke、xiyou_battle_pixel、xiyou_battle_ui、xiyou_event_compare／_b／_c／_d、xiyou_side_status_order）全过（battle_pixel 改测试后单跑重过）；语法检查 0 问题；工具回归全过。
- 未完成／已知问题：见交付单「没做的」（YEP 自动被动状态没移植）。

## 交接板

- 下一步：可派一条规则车道补 YEP_AutoPassiveStates（见「没做的」第 1 条），先查护摩之杖、终级平A 在重制里能不能拿到。
- 用户试玩说明：战斗里右侧头像旁的小状态格，轮换先后按「异常→增益→常驻」、同类按名字拼音，和原版一样。

## 进度账

- 战斗画面像素对照：状态格轮换顺序补齐（不改完成度百分比，只补依据）。

## 没做的

- **YEP_AutoPassiveStates 的自动被动状态重制没有**（查顺序时顺带发现，不在本期范围）：原版 `<Passive State: n>` 有武器 79 护摩之杖→1640「神魔压制·天灾1」（`<Custom Confirm Effect>` 造成伤害×10%、`<Permanent>`）、技能 7769 终级平A→1347「平A」（战斗中额外攻击次数 +2，`<Custom Passive Condition>` 只在战斗中）、防具 49／3834 般若→2498（空状态）；状态 1068／1069 备注里也有这个标签，但 YEP 只读角色、职业、装备、敌人、技能，状态上的不生效。重制 `XActor.states()` 只接了 GT_EquipSuit 套装状态，这几条不进状态表也不生效。原版 states() 顺序是 `_states` ＋ 被动状态 → 按优先级降序稳定排（YEP sortPassiveStates）→ 吸收护盾状态（YEP_AbsorptionBarrier，再排）→ 末尾接套装状态；补的时候结算（dsPassiveSkill 按 equips＋skills＋states 读，PushState 概率掷骰顺序随 states() 顺序）要按这个顺序。没查这三件东西在重制里能不能拿到。
- 原版状态格还能点开看状态详情（弹窗，按「异常／增益／常驻／全部」分页，用的是同一个 stateRows）；重制没有，没做。
- NW.js 里 Chromium 的 ICU 版本没单独核（核的是 Node 26／ICU 78.3 和 Chrome 157，两者对全部状态名同序）。

## 可优化（流程／工具／效率）

- 已做：中文排序做成通用的 `XZhCollate.compare`／`stable_sort`（Godot 的 sort_custom 不稳定，原版 V8 稳定），以后别处要对原版的 `localeCompare(…,'zh-Hans')`（图鉴、背包按名字排等）可直接用。回退：删 `core/zh_collate*.gd`、`cell_rows` 去掉排序段。
- 建议：原版 runtime 里另有 `localeCompare(…,'zh-Hans')` 的只在同一文件（installEquipmentStatusRuntime 的状态／属性详情弹窗，按名字排），重制还没有这个弹窗；哪天做弹窗时直接用 `XZhCollate`（界面车道）。

## 本分支提交

- （见 git log cc/rules-passive-order1）

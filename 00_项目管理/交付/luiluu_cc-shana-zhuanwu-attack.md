# 交付：luiluu/cc-shana-zhuanwu-attack

- 车道／工作者：T074 夏娜专武贽殿遮那普攻用不了、显示成科比「八秒肘击」（cc 车道，Opus 5.5＋medium，P8）
- 状态：可合并

## 变更记录草稿

## 2026-11-16 【cc·战斗·未经审查】西游档夏娜专武贽殿遮那普攻改回天破壤碎（原版数据错，D133）（dev.待定）

- 依据：Kyo 11-16 19:27 转群里玩家反馈（v0.03 手机端，夏娜 Lv35 带贽殿遮那「普攻用不了」「显示的普攻像是科比的」「八秒肘击 24 是什么鬼」），截图在私密仓 `协作交接/附图/T074/玩家截图.jpg`；Kyo 拍板 D133：西游档修，开关默认开。
- 根因（原版 MOD 数据错，重制 1:1 照搬了，不是串数据）：冻结正式源 v0.62.12 `data/Weapons.json` 武器 77「贽殿遮那」备注原文 `<Replace Attack: 5769>`＋`<Weapon Unleash 100%: 5769>`（另有 `<KyoUnique: 天破壤碎>`），武器 83「天外天·贽殿遮那」同样两行。`data/Skills.json` 里：
  - 5769＝「8秒肘击24下」（科比的被动）：occasion 3（永不可用）、scope 0、stypeId 4、伤害公式 0、`<Hide in Battle>`；
  - 10556＝「天破壤碎」：occasion 1（战斗中）、scope 1（敌方单体）、stypeId 1、火焰属性、可暴击。
  - 说明行写「天破壤碎(普通攻击变为释放天破壤碎 攻击有几率魅惑敌人)」，夏娜法宝贽殿遮那（防具 116）写 `<SkillPass10556: 150%>`，天启篇 `skill_rework.json` weapon:77／83 也早已把 5769 改成 10556——都指向 10556 才是本意。
  - 所以西游档 `XBattler.attack_skill_id()`（`modes/xiyou/core/battler.gd` `replace_attack_of`）按原文返回 5769：指令窗普攻显示「8秒肘击24下」，`XBattleLogic.can_use`（`battle_logic.gd:688` occasion 不是 0／1 就否）判不能用，普攻灰掉。
- 复现条件：西游档，夏娜带武器 77 或 83 → 普攻＝5769 八秒肘击、不能用（跟队里有没有科比无关，5769 只是同一张技能表里的号）；不带专武 → 技能 1 普通攻击；天启篇 → 改写后的 10556，本来就对。
- 改法：`battler.gd` `replace_attack_of`／`weapon_unleash_of` 外包一层，只对武器 77／83（认 `wtypeId`＋`base`／`id`），把 Replace Attack 5769 换成 10556、去掉 Weapon Unleash 5769（与天启篇同口径）；原解析拆成 `_replace_attack_raw`／`_weapon_unleash_raw`，缓存不变。别的武器、防具同号、科比学 5769 都不受影响。
- 开关：O-待定 `XBattler.SHANA_ZHUANWU_ATTACK_FIX`（默认开），关掉逐字回原版。
- T046（AgainUse／atkk）不加重：数据里没有 `AgainUse5769`／`AgainUse10556`，5769 的 `passiveAPLUS` 只对学了它的人（科比）生效，夏娜普攻是不是 5769 都不读它。
- 玩家可见：西游档夏娜带贽殿遮那／天外天·贽殿遮那时，普攻变成「天破壤碎」并能正常使用（之前显示成科比的「8秒肘击24下」且灰掉）。

## 优化登记草稿

| 编号 | 位置 | 原版行为 | 优化 | 理由 | 恢复方法 | 执行者 | 状态 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| O-待定 | `modes/xiyou/core/battler.gd` `replace_attack_of`／`weapon_unleash_of`（`_is_shana_zhuanwu`） | 贽殿遮那（武器 77）、天外天·贽殿遮那（83）写 `<Replace Attack: 5769>`＋`<Weapon Unleash 100%: 5769>`，5769 是科比被动「8秒肘击24下」（occasion 3），夏娜普攻显示成八秒肘击且用不了 | 西游档只对这两把把 5769 换成天破壤碎 10556、去掉 5769 的武器解放（同天启篇 skill_rework 口径） | 原版数据错（说明、法宝 SkillPass10556 都指向 10556），玩家 v0.03 反馈；D133 Kyo 11-16 定修 | `XBattler.SHANA_ZHUANWU_ATTACK_FIX = false` | cc | 保留 |

## 验证

- 新专项 `xiyou_shana_zhuanwu_attack` 27/27：原版数据证据（`data.w77/w83_note_5769`、`data.5769_passive` occasion 3、`data.10556_tianpo`）；开关开：77／83 普攻＝10556、名字天破壤碎、`can_use` 真、`is_attack` 真、无 5769 武器解放；开关关：普攻 5769、不能用、有 5769 解放（逐字原版）；不带专武普攻 1；科比学 5769 被动照旧、普攻不随开关变；假造武器 78 写 5769 不改、防具同号 77 不改；别的武器（火精灵文书 1109 → 1004）不变。
- 反向验证（`反向验证.py`）三项都咬住：去掉普攻替换修正（＝修前）、去掉武器解放修正、修正不限武器号。
- `xiyou_replace_attack_motion` 36/36；语法检查通过。
- `xiyou_attack_query`（原版参照逐例比普攻）：第一轮云端选测它挂了 6 条，正是原版 154＋武器 77／83 的 attackSkillId／setAttack／挂机行动／指令窗（原版 `{"enabled":false,"name":"8秒肘击24下"}`，修后 `{"enabled":true,"name":"天破壤碎"}`）——这就是修前修后指令窗的直接证据；该测试是 1:1 比原版，开头设 `XBattler.SHANA_ZHUANWU_ATTACK_FIX = false` 后 381/381。
- `检查.sh --affected main --cloud` 退出码 0（云端选测 181 个场景全过，提交 e66237d08；非 Godot 检查全过）。第一轮（20e62977b）只挂 `xiyou_attack_query`，处理见上。
- `工具回归.py` 全部通过（129 秒）。

## 我不同意的地方

- 派单把独占文件定在 `battle_logic.gd`，实际普攻替换解析在 `battler.gd`；已 ask 协调批了扩到 `battler.gd`，`battle_logic.gd` 没改。
- 原版 Math.floor(random×180) 的天破壤碎伤害倍率（可能掷到 0）照原版没动，不在本单范围。

## 交接板

- 下一步：无
- 用户试玩说明：西游档夏娜带贽殿遮那，普攻变成「天破壤碎」、能正常用。
- 需要用户决定：无（D133 已定）

## 进度账

- 无

## 可优化（流程／工具／效率）

- 无

## 本分支提交

- 20e62977b T074 修正＋专项
- e66237d08 attack_query 比原版时关开关＋交付单

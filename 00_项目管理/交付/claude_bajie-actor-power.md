# 交付：claude/bajie-actor-power

- 车道／工作者：B 规则·界面／八戒（Claude，重制_八戒_4，沿用；用户 2026-10-15 允许本会话上下文到 60%）
- 位置：worktree `.claude/worktrees/bajie-flow-test-3b9e3c`，分支 `claude/bajie-actor-power`
- 状态：可合并
- 预分配编号：O-031～O-033（未用）

## 独占文件

- `core/power.gd`（角色战力 evaluate／actor／cached_actor／status_text／menu_text）、`tests/xiyou_power.gd`、`mv_oracle/power_probe.cjs`
- `ui/equip_scene.gd`、`ui/skill_scene.gd`（状态窗战力文字）、`ui/menu.gd` 主菜单行的战力参数一处

## 变更记录草稿

```
## 2026-10-15 【Claude·八戒·未经Codex检验】角色战力：对上正式版并接技能页/装备页/主菜单（dev.待定）

- 移植 installCombatPowerRuntime v2 的角色战力：孤立角色（裸装/整套）× 三档中性敌人（防御 100／1 万／100 万），10 回合按期望伤害挑技能（前 8 候选、冷却、预热、费用、再生、额外行动），3 回合爆发＋10 回合持续、有效生命、最大单次治疗，curve 折成输出/生存/辅助；自身＝裸装，装备差＝整套−裸装。
- 界面：技能页、装备页状态窗「战力 N」（原来写「战力 …」）；主菜单角色行在技能/装备页算过之后显示「战斗力 N」，没算过「战力见状态」；设置里关掉战力时不画。
- 差异定位（之前偏大的原因）：
  - 正式版新开局等级上限 10，探针里「30 级」实际是 10 级——不是升级规则问题。
  - 正式版伤害预演含五乘区成长修正 growth（installNativePowerZonesRuntime）；按 数值平衡.md（用户 2026-10-12）重制版不移植，探针设 CodexZones.ENABLED=false，与伤害对照去掉 growth 的做法一致。
  - 段数：正式版战力只数整体/逐目标序列里大写的「ACTION EFFECT」（小写写法的序列算 1 段），与实战段数 yepEffects 不同；照正式版。
  - 能否出手含 MV isSkillWtypeOk（技能要求武器类型）：XBattleLogic.can_use 没查，战力里另判（借 XHangUpAuto.wtype_ok）。
- 严格级参照：power_probe 加切片 10 个角色 1/10 级（新开局初始装备）20 例，总分、自身、三项、爆发/持续/有效生命/辅助、出手顺序全部一致（xiyou_power 102/102，含装备 72 件与界面文字）。
- 验证：检查.sh --oracle 全部通过（40 个 Godot 测试，xiyou_rules 33482/33482）。
- 未完成／已知问题：passive_cache 的 againUse 由 XPower 自己扫 <AgainUse…> 备注，atkk（dsPassiveSkill 攻击次数加成）未计——切片角色没有；状态页（Scene_Status）顶部战力条、装备变更后的战力提示（右下浮窗）未做；特殊角色的变身路线（formHooks）、谷雨、种族、引入角色平衡未移植（切片没有）。
- 发现（给唐僧）：XBattleLogic.can_use 没有检查技能的武器类型要求（MV Game_BattlerBase.isSkillWtypeOk），实战里没装对应武器也能放这类技能（如 101 御剑术要求武器类型 2）。属规则缺口，建议 C 车道补并加对照。
```

## 交接板

- 下一步：删掉「战力估算」相关条目；新增「XBattleLogic.can_use 补技能武器类型要求（isSkillWtypeOk）」待派；状态页战力条、装备变更战力提示可并入界面逐页复现。
- 用户试玩说明：技能页、装备页会显示角色战力；去过这两页后主菜单显示「战斗力 N」。设置里可关掉。

## 本分支提交

- 53e097a 开工；6cd8bb1、2df545c 差异定位与交付单；839d261 角色战力对上；（UI 提交）接界面；（本提交）交付单可合并

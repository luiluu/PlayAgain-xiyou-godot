# 交付：claude/project-thread-47bcr5

- 车道／工作者：云端项目线程「完成法宝完整升级」（Claude，云端）
- 状态：进行中

## 变更记录草稿

## 2026-10-25 【Claude·云端·未经Codex检验】法宝完整升级：经验、升级、胜利结算、经验丹、升级特性、按等级学技能（dev.待定）

- 做了什么：照 CP_MagicWeapon 1.10+ 与 CP_X_MagicWeaponLearnSkill 1.00 补齐 dev.111 留下的法宝升级部分，新模块 `modes/xiyou/core/magic_weapon.gd`（`XMagicWeapon`）。等级、经验写在装备实例上（`level`／`exp`，对应原版独立装备 `object().level／exp`），随存档走；没有这两个字段的实例照旧读 `<Init Level>`／`<Init Exp>`，读取不写回。
  - 下一级所需：`round(eval(<Exp Formula> 或插件「经验公式」))`，v0.28 插件为 `(1 + level) * (1 + level) * 0.08 + 75`、上限 888；公式出错时退回插件内置 `3*level*level+40*level+50`。`gain_exp` 加完按所需逐级升（升级前的等级算所需，扣掉后余数留到下一级），满级后不再得经验；`level_up` 对满级法宝只把经验设成所需（同原版）。
  - 战斗胜利（`XBattleLogic.grant` 末尾，原版包在 `BattleManager.gainRewards` 之后）：全队每件法宝得敌群全体成员（含没出场的隐藏成员）的 `<Magic Weapon Exp>` 之和，缺省「敌人提供最小经验」1；不在出战栏的乘「后援经验比率」0.5 后四舍五入；`<Cannot Gain Exp After Victory>` 不得。
  - 插件指令（`MVEventCore._plugin_command`）：`MagicWeaponAllGainExp exp`（全队全部法宝，不看上一条限制；公共事件 1188～1192、1215～1217 法宝经验丹）、`MagicWeaponLevelUp 角色 槽 级数`。
  - 升级特性 `<Equip LevelUp Trait Weapon|Armor|State: id>`：那条记录按法宝等级重复进 `XActor.trait_objects`（1 级就算 1 次；v0.28 只有麒麟对剑 73～75 → 防具 4409「暴击*1，闪避*1」，每级命中、暴击各 +1%）。
  - 按等级学技能 `<Magic Weapon Learn Skill x: ALL|y1, y2>` 进 `XActor.skills()`（v0.28 只有烽舞 3550：10～19 级天熄乱舞 7510，20～29 级 7511，30～39 级 7512，40 级起 7513）。
  - 战力说明行改为「等级取实例等级」（`XPower.equipment` 缓存键早已含 `level`）。
- 参照：新探针 `mv_oracle/magic_weapon_level_probe.cjs`（冻结 v0.28，新游戏，只写 `.sandbox/magic_weapon_level.json`，复制成 `tests/fixtures/magic_weapon_level_oracle.json`，不登记进同步）。七组：全部 221 件法宝的初始等级／经验／上限／所需／升级特性／学技能表／标记；四件法宝 1～888 级所需；大罗剑胎逐次得经验到满级；公共事件 1190 与两条插件指令；敌群 824（1 个出场＋5 个隐藏）胜利结算、6 人队第 6 人后备；麒麟对剑 1／3／10 级特性与 xparam；烽舞各等级技能及经 gainExp 升级后的技能。
- 测试：新专项 `tests/xiyou_magic_weapon_level` 51 项全过（冻结 v0.28 转换产物）。分别去掉升级特性、学技能、胜利结算、插件指令接线时各有 3～11 项失败（确认测得到）。
- 验证：（待写：检查.sh 结果）
- 没做：`<Magic Weapon LevelUp Effect>`（任意 JS；v0.28 没有装备用到，遇到时记进 `XMagicWeapon.unsupported_effects`，专项检查为空）；原版战斗中法宝特性的整场缓存（战斗中法宝等级不变，结果相同）；主动法宝「使用经验」在原版本来就注释掉了。渡鸦冥河断罪镰 4001 的成长：Codex_Raven 写进 `paramPlusPerLevel` 的值与它自己备注里的 `<… Param … per Level>` 相同，dev.111 的解析已经对上，不另做。
- 可用范围：法宝能升级，能力值、特性、技能随等级变化；**battleReady** 不变。

## 交接板

- 下一步：无新增；进度账「装备系统」行去掉「法宝完整升级／经验／成长未完成」。
- 用户试玩说明：法宝打完胜仗会得经验并升级（每场得敌人数那么多经验，后备减半）；法宝经验丹能用；麒麟对剑升级加暴击、命中，烽舞 10 级起领悟天熄乱舞。
- 需要用户决定：无。

## 进度账

- 装备系统：75% → 80%，依据：法宝完整升级（经验、升级、胜利结算、经验丹、升级特性、按等级学技能）补齐，原注「法宝完整升级／经验／成长未完成」可删（局部估值，请沙僧核算）。

## 可优化（流程／工具／效率）

- 待登记优化（请总装分配 O 号）：原版 `CP_X_MagicWeaponLearnSkill` 用 `concat` 把法宝技能接在 `skills()` 后面，不去重，角色本来就会的技能会在技能栏出现两次；Godot 去重。恢复方法：`XActor.skills()` 里法宝技能那一段去掉 `if not ids.has(id)`（且 ids 改成允许重复）。v0.28 只有烽舞的 7510～7513，没有角色本来就会，实际不触发。
- 发现的问题（不在本车道，未改）：`XZhenqi.troop_members` 假定 `enemies` 不含隐藏成员，但 `XBattleLogic.setup` 早已把隐藏成员建进 `enemies`，所以有隐藏成员的敌群会把隐藏成员算两次（如敌群 824 得 11 个而不是 6 个）。真气胜利结算里只用来解锁灵根／本命兵，重复不改结果；以后若按人数算就会错。建议归真气所在车道：`troop_members` 在 `enemies.size() == 成员数` 时直接返回 `enemies`。
- 云端环境：`/mnt/project-files/` 里的冻结正式源分片解出来带 6644 个 macOS `._*` 附属文件（不在 `files.sha256` 里），不删的话 `sourceIdentity` 多出 250 项、与登记不符；解包后要 `find app.nw -name '._*' -delete`。`xiyou_export.py` 转换图片要 macOS 的 `sips`，云端用 PIL 写个同名小脚本放进 PATH 即可。建议把这两点补进 `07_开发环境/云端测试.md`（归车道 D）。

## 本分支提交

- 见 `git log main..claude/project-thread-47bcr5`

## 暂停现场（2026-10-25 16:05 UTC，用户要求先把额度留给其他审查）

- 整轮同步（`--full --no-register --no-import --accept-additions`）跑了约 10 分钟后按要求停掉，没写缓存、没改 `generated/`。前一次整轮同步因 event_probe 内存不足失败，堆上限已修（本分支最后一条提交）。
- 接着做：① 重跑整轮同步（`CHECK_GLOBAL_JOBS=3`，约 2～3 小时）；② `检查.sh` 全量，修失败项，填上面的「验证」行并把状态改成可合并；③ 更新 PR #9 说明并推送（不合并）。
- 其后：`-actor-cmds` 分支（角色指令，专项 48/48）开 PR；`-reach-lamps`（灯笼地图 68/185/67/138、71～74、95～99，专项 reach068 未跑）叠在它后面开 PR；`-sky`（天之上，待做飞艇）未开 PR。

# 交付：claude/bailong-actors-f2575c

- 车道／工作者：C 角色·机制／白龙（Claude，重制_白龙_1）
- 状态：可合并（分支 `claude/project-thread-gwws80`＝原 claude/bailong-actors-f2575c ＋ 云端 172 宿傩接线 ＋ 本机收尾；只开 PR，不合并）

## 变更记录草稿

## 2026-10-26 【Claude·白龙·未经Codex检验】专属角色第一期：173 饿狼、167 渡鸦、168 米拉、172 宿傩加回切片（dev.待定）

- 依据 [协助预检_专属模块167-178](../协助预检_专属模块167-178_20261022.md)：每人第一期只做招募＋开机数据＋能力值／被动＋公式，伤害行对上即加回切片，战斗机制放第二期。三人的伤害公式都是整条调模块（`CodexGarou.base`、`CodexMira.damage`、渡鸦 `CodexRaven.legionStrikeRate×skillCoefficient`），但都是只读能力值／技能／阶位的纯计算，照 178 哈基米先例（`MODULE_FORMULAS`＋`XFormulaExecution.run_item` 按 module 分派）做成模块公式，不算停手判据里的「要战斗机制才能对上」。
- 新模块（`modes/xiyou/core/`）：
  - `actor_modules.gd` XActorModules：XActor 上的公共挂点，按角色分派；非模块角色（IDS 以外）走快速路径，行为不变。文件头写明每个挂点对应原版包的哪一层。
  - `garou.gd` XGarou（173）：形态＝进阶次数（XAdvance.rank）；开机／升降级同步（形态状态 2644～2650、按形态学忘拳法、被动 10265～10269 按 CodexUnlockRank／Level 准入）；learnSkill 包装挡未准入被动；公式 `CodexGarou.base`；号角 CE9009 招募（生成并装上破限之心 7904，提示文字）。
  - `raven.gd` XRaven（167）：阶位＝进阶次数；setupRaven（开机与升级后按 SKILL_GATE 重排技能）；整条公式；魂海刻度暴伤／终伤池（initPassiveCache）；伤害钩子 raven（魔法、冥河穿刺减魔防、黑羽淬魂、冥河冠冕、成长倍率 GROWTH）；号角 CE9002 招募（入队、无则给冥河断罪镰 4001、右上角提示）。
  - `mira.gd` XMira（168）：能力值包装（10144／10145／10166）、公式 `CodexMira.damage`、号角 CE9003 招募（生成并装上黑龙心鳞 4577）。
  - `number_boost.gd` XNumberBoost：MiraRavenNumberBoost 的面板暴击（xparam 2）与伤害钩子 native-number-pools。
  - `actor_damage_hooks.gd` XActorDamageHooks：raven／mira／native-number-pools／sukuna 四个原版伤害钩子合成一条，在 XModuleRegistry 的 damage.before（order 3：原版这四个排在 cat-sword 之前，重制序号＝2×序＋1）；宿主侧 capture 算好帧操作。
- 开机数据复现（转换器 `xiyou_export.py` 新函数 `boot_database_records`）：渡鸦 finishRavenDatabaseCompatibility 给原版角色进阶表补的 5 行（渡鸦 0～4 次，表尾 Advanced 473～477），写进 db/Plugins.json，XAdvance 照常读。饿狼、米拉的 isDatabaseLoaded 只做校验，无数据改动。
- 改动别处（各一两行）：`formula_program.py` 的 MODULE_FORMULAS 加 garou／mira／raven 条目；`formula_execution.gd` 加三条分派；`module_registry.gd` standard() 加 XActorDamageHooks、capture_facts 改成可同时给 cat 与 actorModules；`mv_script.gd` 认 `CodexMira.recruit()`、`CodexRaven.recruit()` 语句与 `try { if (!CodexX.recruit()) 还号角 } catch…` 整段写法（目前分派到 CodexGarou，以后的甚尔／宿傩同写法直接加分派）。
- **改沙僧独占 actor.gd：10 行挂点（9 行调用＋change_level 记旧等级 1 行），均调用 XActorModules**（setup 末尾、learn_skill 开头、_level_up 末尾、change_level_mv 降级循环里、change_level 末尾、param、xparam、refresh_passive 写回前）。总装 2026-10-25 批准。沙僧以后改 actor.gd 时请保留这些挂点。
  - 挡技能放在 learn_skill 开头：只有饿狼原版包了 `Game_Actor.learnSkill`（10265～10269 未准入不学），所以事件学技能、技能共享／羁绊／领袖、进阶学技能对饿狼也一样被挡，与原版同层。渡鸦原版不包 learnSkill，只在 setup／levelUp 后重排，所以放在 setup／level_up 挂点。
  - 升降级：原版 changeLevel／changeExp 都逐级走 levelUp／levelDown；饿狼两个都包（G.sync），渡鸦只包 levelUp。重制 `_level_up`（gain_exp、change_level_mv 升级都走它）、change_level_mv 的降级循环、直接设等级的 change_level（读档与测试夹具）三处都挂上。
- 172 宿傩（`core/sukuna.gd` XSukuna）：技能同步 S.sync（setup／levelUp／changeLevel）、能力值与被动（二十指 param ×3、xparam 命中／暴击、十指／二十指终伤与暴伤）、公式 `CodexSukuna.damage`（MODULE_FORMULAS 8 条）、伤害钩子 sukuna（物理／魔法、空间斩次元斩真伤属性 13、物防魔防率、stage 3 结算 ×1.5 与 makeDamageValue ×1.99）、号角 CE9007 招募（装神武解 4581）。切片 actors 加 172，actor_p0 RECRUIT_8 加 9007。
- 渡鸦／米拉技能解锁同步 `core/skill_progression.gd` XSkillProgression（原版 installNativeSkillProgressionRuntime）：本人专属技能按 CodexUnlockLevel／CodexUnlockRank／CodexUnlockMaxRank／CodexRetired 学忘，挂在 XActorModules 的 setup／level_up／level_down。米拉 10162／10163（要进阶 3 次）原先会按职业习得表学到，现与参照一致不学。
- XActorModules.level_changed 同级也同步：XActor.change_level 会补学职业习得表，同级时原先跳过同步，渡鸦 1 级会多出 10127／10170。
- **slice_probe 修正**：measure 量完原只还原 hp／mp／tp 与新增状态，`b.addShield` 公式（5648 轰鸣鼓墙等）留下的护盾会带到后面的行；宿傩捌 10230「目标有盾 ×1.5」因此全部量成 2.4 倍。现一并还原双方 `_shield`（`测试切片探针还原.py` 通过）。同步对 main 基线只有新增（172 行按无盾 1.6 倍），其余行不变。
- 专项期望更新：xiyou_actor_advanced 进阶表 462→467 行（渡鸦开机补的 5 行）；xiyou_module_hooks 默认宿主钩子序列加 actor-modules（order 3，在 cat-sword 前）；xiyou_actor_modules 宿傩 1 级不含 10238（参照如此，10238 是普攻替换，同步里本就排除）。
- 切片 `xiyou_slice.json` actors 加 167、168、173；`xiyou_actor_p0` RECRUIT_8 加 9002／9003／9009。
- 专项 `tests/xiyou_actor_modules`（25 项）。
- 各模块文件头列了未移植项（第二期起）：饿狼形态倍率／行动次数／进阶／法宝进化／进化解析反击追击；渡鸦灵魂积累与铸印、神话形态、追加伤害、法宝运行时字段与固定加成；米拉解放黑龙与黑龙形态、禁忌减耗扣血；NumberBoost 的必中不闪避；三人的 Map132 商店补号角、技能分类与界面、旧档迁移（不迁移）。

## 交接板

- 下一步：白龙接着做 169 黄泉／170 镜流 → 171 伏黑甚尔 …（新分支；169／170 草稿在共享笔记 `白龙_草稿_yomi_jingliu.gd`，还要 actor.gd 加 param_base／param_plus／action_plus_set 三个单行挂点）。
- 用户试玩说明：伙伴号角「饿狼／渡鸦／黑龙米拉／宿傩」可用，四人可入队；第一期没有进阶形态、灵魂、黑龙变身、领域展开等战斗机制。
- 需要用户决定：无

## 进度账

- 角色：切片具名角色 150 → 154（加 167、168、172、173）。

## 可优化

- 扩角色每期都要跑一整轮同步（6 个难度的 slice_probe 各约 7 分钟，全是旧角色×全部敌群）。可以让增量同步对「只加角色」只量新角色的行（slice_probe 按角色分片，旧角色行从上次产物取回），一期能省掉大半同步时间。属转换工具／增量同步，建议派给管同步的车道。
- 同步槽位抢不到：几条车道都在「看没人跑就开」，常常前后脚撞上。建议 `同步正式西游.py` 加 `--queue`（自己等到没有别的同步再开始，等待时每 30 秒打心跳，免被长任务空闲超时停掉），白龙用过一个临时脚本版本可行。注意 pgrep 用 `'Python.*同步正[式]西游'` 这类写法，免得匹配到等待脚本自身的命令行。

## 验证

- **与 main 种族异化（#12）冲突的解决（2026-10-26）**：① `actor.gd` param 按原版安装先后由内到外套：XActorModules（米拉 main.js 98、宿傩 113）→ XCat（115）→ XRaceBattle（148），即 `XRaceBattle.param(XCat.param(XActorModules.param(super)))`；② `module_registry.gd` 标准列表两个描述符都放，actor-modules 顺序号由 41 改 3（原版 raven 1 等在 cat-sword 9 前），race-blessings 保持 41；伤害捕获 actorModules 与 race 两段都保留；③ `xiyou_module_hooks` 默认宿主序列为 actor-modules 3、cat-sword 18／19、orb-sets 39、race-blessings 41。合并后重跑：`--补齐`＋同步（只增，退出码 0）；xiyou_module_hooks 1310、xiyou_race_battle 436、xiyou_alien_battle 330、xiyou_actor_modules 37、xiyou_actor_p0 3300、xiyou_rules 难度 1 四段全过；`检查.sh --affected main` 通过（Godot 125 项）。

- 同步 `同步正式西游.py --no-register --accept-additions`（合 main 8de0204b 后、含 slice_probe 护盾修正）：退出码 0，对 main 基线只有新增用例（actor_passive、help_cards、slice_d1～d6、wtype 等），核对 0 问题。
- 专项（`并行测试.py --full`）全过：xiyou_actor_modules 37/37、xiyou_actor_p0 3300/3300、xiyou_rules 难度 1 四段（109704／109619／109508／109673 全过）、xiyou_party_skills 214、xiyou_module_hooks 1310、xiyou_actor_advanced 33、xiyou_cat 992、xiyou_qiyu 231。
- 内容覆盖检查：new 0、resolved 0（基线不用更新）。
- `检查.sh --affected main`：通过（选测 Godot 120 项全过、工具自测与内容覆盖全过）。选测选中了同源检查但未加 `--oracle`，未跑；合并时 `合并车道.sh --affected` 会带 `--oracle`。

## 本分支提交

- 白龙一期：4fa9c108、1dcd25f9、9546ea2e、30eff20f、3399f1f0、7ba84da2、2627e98c、a799a65f、7c81d5d2、290098a1
- 云端 172 宿傩接线：fd4a9539、d035caf5
- 本机收尾：1a5d0576（XSkillProgression、同级同步、专项期望）、a45391c0（slice_probe 还原护盾）、a84191d1／12547d20（交付单）
- 合 main 解冲突：33400fb9（param 套序、actor-modules 顺序号 3）、本次交付单提交

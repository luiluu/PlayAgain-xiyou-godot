# 交付：claude/bailong-actors-f2575c

- 车道／工作者：C 角色·机制／白龙（Claude，重制_白龙_1）
- 状态：进行中

## 变更记录草稿

## 2026-10-25 【Claude·白龙·未经Codex检验】专属角色第一期：173 饿狼、167 渡鸦、168 米拉加回切片（dev.待定）

- 依据 [协助预检_专属模块167-178](../协助预检_专属模块167-178_20261022.md)：每人第一期只做招募＋开机数据＋能力值／被动＋公式，伤害行对上即加回切片，战斗机制放第二期。三人的伤害公式都是整条调模块（`CodexGarou.base`、`CodexMira.damage`、渡鸦 `CodexRaven.legionStrikeRate×skillCoefficient`），但都是只读能力值／技能／阶位的纯计算，照 178 哈基米先例（`MODULE_FORMULAS`＋`XFormulaExecution.run_item` 按 module 分派）做成模块公式，不算停手判据里的「要战斗机制才能对上」。
- 新模块（`modes/xiyou/core/`）：
  - `actor_modules.gd` XActorModules：XActor 上的公共挂点，按角色分派；非模块角色（IDS 以外）走快速路径，行为不变。文件头写明每个挂点对应原版包的哪一层。
  - `garou.gd` XGarou（173）：形态＝进阶次数（XAdvance.rank）；开机／升降级同步（形态状态 2644～2650、按形态学忘拳法、被动 10265～10269 按 CodexUnlockRank／Level 准入）；learnSkill 包装挡未准入被动；公式 `CodexGarou.base`；号角 CE9009 招募（生成并装上破限之心 7904，提示文字）。
  - `raven.gd` XRaven（167）：阶位＝进阶次数；setupRaven（开机与升级后按 SKILL_GATE 重排技能）；整条公式；魂海刻度暴伤／终伤池（initPassiveCache）；伤害钩子 raven（魔法、冥河穿刺减魔防、黑羽淬魂、冥河冠冕、成长倍率 GROWTH）；号角 CE9002 招募（入队、无则给冥河断罪镰 4001、右上角提示）。
  - `mira.gd` XMira（168）：能力值包装（10144／10145／10166）、公式 `CodexMira.damage`、号角 CE9003 招募（生成并装上黑龙心鳞 4577）。
  - `number_boost.gd` XNumberBoost：MiraRavenNumberBoost 的面板暴击（xparam 2）与伤害钩子 native-number-pools。
  - `actor_damage_hooks.gd` XActorDamageHooks：raven／native-number-pools／mira 三个原版伤害钩子在 XModuleRegistry 的 damage.before（order 41）；宿主侧 capture 算好帧操作。
- 开机数据复现（转换器 `xiyou_export.py` 新函数 `boot_database_records`）：渡鸦 finishRavenDatabaseCompatibility 给原版角色进阶表补的 5 行（渡鸦 0～4 次，表尾 Advanced 473～477），写进 db/Plugins.json，XAdvance 照常读。饿狼、米拉的 isDatabaseLoaded 只做校验，无数据改动。
- 改动别处（各一两行）：`formula_program.py` 的 MODULE_FORMULAS 加 garou／mira／raven 条目；`formula_execution.gd` 加三条分派；`module_registry.gd` standard() 加 XActorDamageHooks、capture_facts 改成可同时给 cat 与 actorModules；`mv_script.gd` 认 `CodexMira.recruit()`、`CodexRaven.recruit()` 语句与 `try { if (!CodexX.recruit()) 还号角 } catch…` 整段写法（目前分派到 CodexGarou，以后的甚尔／宿傩同写法直接加分派）。
- **改沙僧独占 actor.gd：10 行挂点（9 行调用＋change_level 记旧等级 1 行），均调用 XActorModules**（setup 末尾、learn_skill 开头、_level_up 末尾、change_level_mv 降级循环里、change_level 末尾、param、xparam、refresh_passive 写回前）。总装 2026-10-25 批准。沙僧以后改 actor.gd 时请保留这些挂点。
  - 挡技能放在 learn_skill 开头：只有饿狼原版包了 `Game_Actor.learnSkill`（10265～10269 未准入不学），所以事件学技能、技能共享／羁绊／领袖、进阶学技能对饿狼也一样被挡，与原版同层。渡鸦原版不包 learnSkill，只在 setup／levelUp 后重排，所以放在 setup／level_up 挂点。
  - 升降级：原版 changeLevel／changeExp 都逐级走 levelUp／levelDown；饿狼两个都包（G.sync），渡鸦只包 levelUp。重制 `_level_up`（gain_exp、change_level_mv 升级都走它）、change_level_mv 的降级循环、直接设等级的 change_level（读档与测试夹具）三处都挂上。
- 切片 `xiyou_slice.json` actors 加 167、168、173；`xiyou_actor_p0` RECRUIT_8 加 9002／9003／9009。
- 专项 `tests/xiyou_actor_modules`（25 项）。
- 各模块文件头列了未移植项（第二期起）：饿狼形态倍率／行动次数／进阶／法宝进化／进化解析反击追击；渡鸦灵魂积累与铸印、神话形态、追加伤害、法宝运行时字段与固定加成；米拉解放黑龙与黑龙形态、禁忌减耗扣血；NumberBoost 的必中不闪避；三人的 Map132 商店补号角、技能分类与界面、旧档迁移（不迁移）。

## 交接板

- 下一步：白龙接着做 172 宿傩 → 169 黄泉／170 镜流 → 171 伏黑甚尔 …（新分支 claude/bailong-actors-f2575c-2）。
- 用户试玩说明：伙伴号角「饿狼／渡鸦／黑龙米拉」可用，三人可入队；第一期没有进阶形态、灵魂、黑龙变身等战斗机制。
- 需要用户决定：无

## 进度账

- 角色：切片具名角色 150 → 153（加 167、168、173）。

## 可优化

- 扩角色每期都要跑一整轮同步（6 个难度的 slice_probe 各约 7 分钟，全是旧角色×全部敌群）。可以让增量同步对「只加角色」只量新角色的行（slice_probe 按角色分片，旧角色行从上次产物取回），一期能省掉大半同步时间。属转换工具／增量同步，建议派给管同步的车道。
- 同步槽位抢不到：几条车道都在「看没人跑就开」，常常前后脚撞上。建议 `同步正式西游.py` 加 `--queue`（自己等到没有别的同步再开始，等待时每 30 秒打心跳，免被长任务空闲超时停掉），白龙用过一个临时脚本版本可行。注意 pgrep 用 `'Python.*同步正[式]西游'` 这类写法，免得匹配到等待脚本自身的命令行。

## 接续要点（2026-10-25 16:05 云端接手后暂停：用户要先做完小小鱼审查）

- 云端分支 `claude/project-thread-gwws80`＝本分支 9c288311 ＋ fd4a953（172 宿傩第一期接线，**未跑测试**）。宿傩已接进 XActorModules（setup／levelUp／levelDown 同步、param／xparam／passive_cache）、XActorDamageHooks（descriptor writes 加 kind／elements／physicalDefenseRate）、formula_program MODULE_FORMULAS（8 个 CodexSukuna.damage）、formula_execution、mv_script 号角 CodexSukuna（toast）；切片 actors 加 172，actor_p0 RECRUIT_8 加 9007；xiyou_actor_modules 加 13 项宿傩检查。草稿修正：神灶：开权重×准备层数（第一期 0）、stage 3 makeDamageValue ×1.99 并进钩子 settlementMultiplier。
- **同步仍未跑完**：云端同步跑到 slice_probe 时被停（PROBE_PLAN 53 个全跑、0 复用，共用槽 2）。云端跑同步要先放 sips 替身（见团队记忆 cloud-sync-sips-shim）。
- 接着做：① 还原素材（/mnt/project-files/云端素材还原说明.md）→ `云端准备.sh` → sips 替身 → `同步正式西游.py --app <冻结 app.nw> --no-register --accept-additions`（现已含 172，一轮同步覆盖两期）；② 跑原「接续要点」②的专项（含 xiyou_actor_modules）与内容覆盖；③ 宿傩伤害行对不上就看 slice_probe 的 172 行（1 级 0 进阶、无施放帧）；④ 全过开 PR（不合并）。
- 车道还没做：169 黄泉／170 镜流（共享笔记草稿 `白龙_草稿_yomi_jingliu.gd`，云端读不到）、171 伏黑甚尔。

## 接续要点（2026-10-25 08:15 额度 80% 收尾时）

- 代码三人（173／167／168）都已写完并提交；已合入 main 到 6a28e127（无冲突）。`core/sukuna.gd`（172 宿傩）是下一期草稿，已提交但**未接线、未测**，留到新分支 `-2` 再接（XActorModules、XActorDamageHooks、formula_program、mv_script 的 CodexSukuna 分派）。
- 169 黄泉／170 镜流模块草稿在共享笔记目录 `白龙_草稿_yomi_jingliu.gd`（未进仓库、未测）；还要 actor.gd 加 param_base／param_plus／action_plus_set 三个单行挂点。
- **还差同步**：本分支尚未跑 `同步正式西游.py --accept-additions`（槽位一直被悟空／主工作区的同步占着；排队任务已撤，没开始过）。接着做：① 没有别的同步时跑 `新建工作树.sh --补齐` ＋ 同步；② 跑 `xiyou_actor_p0`、`xiyou_rules.tscn xiyou_rules_d1b xiyou_rules_d1c xiyou_rules_d1d`、`xiyou_actor_modules`、`xiyou_party_skills`、`xiyou_module_hooks`、`xiyou_actor_advanced`、`xiyou_cat`、`xiyou_qiyu`；③ 内容覆盖检查 ＋ `--update-baseline`；④ 标可合并。
- 同步前的手动预跑（只难度 1，合 main 之前）：`xiyou_rules` 难度 1 四段全过（含 173 的伤害行）；`xiyou_actor_p0` 因读难度 2 参照（还没 173）失败，属预期。

## 验证

- `xiyou_actor_modules` 25/25（单跑通过）。
- 难度 1 手动参照下 `xiyou_rules.tscn`／`d1b`／`d1c`／`d1d` 全过（只含 173，渡鸦／米拉加入前）。
- 其余见「接续要点」，同步后补齐。

## 本分支提交

（待写）

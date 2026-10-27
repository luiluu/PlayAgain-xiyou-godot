# 交付：codex/rng-compare-review

- 车道／工作者：规则核查／沙僧（Codex，重制_沙僧_62）
- 状态：可合并；基线2g026f6ee3，依赖四零散→2g；只用已有state-effects-2b树，共用登记只读。
- 范围：复核敌群事件other_状态44放宽、军团676～693／739两类随机比较豁免，以及recover_all保留Permanent。没有新功能或随机数框架改造。
- 初读发现：状态44已有第1回合末严格有无／回合数断言，末态只在Godot确实走完第2回合时容许44到期；不是任意忽略。recover_all已调用clear_states，后者保留Permanent，先补边界证据再判断是否需改生产。
- 军团旧测试保留五种种子；拟另加原版Math.random=0.5等价的测试专用本场流与单轮场景，试恢复被略过的行动者集合和命中附伤比较。流只注入测试，不改游戏侧分布、存档或真实玩家数据；发现额外差异先分析，不放宽参照。
- 未完成前不可报可合并；自己的改动待Claude核查。旧证据/.sandbox/generated及整树保留。

- 新半值场景首测2951/2951，包含恢复军团行动者集合与命中附伤比较，没有新豁免。原五种种子场景保留，最终还要回归。Permanent原版四例（actor/enemy×clearStates/recoverAll）errors为空；保留686及5回合、清普通状态2，TP37和buff／剩余回合原样，recoverAll才回满HP／MP。stdin首测因原版插件依赖主脚本filename启动失败，改用实体脚本后4例通过；不是游戏失败。下一步补对应Godot对照。

## 变更记录草稿

## 2026-10-25 【Codex·沙僧·未经Claude检验】随机对照豁免与Permanent核查（无需开发编号，仅测试／证据）

- 状态44历史放宽已收窄为严格第一回合末检查＋第二回合末到期差；同采样时点可对上，不给生产固定随机数，不增加豁免。
- 加独立原版0.5抽样场景（整数floor(n*0.5)，不是uint32%n），原种子场景不变。19次军团行动者集合＋19次命中附伤严格对照通过，补上历史跳过的覆盖；测试注入不影响游戏随机流、随机分布或存档。
- 原版Permanent四例（角色／敌人×clearStates/recoverAll）与Godot逐字段一致：686及剩余5回合保留，普通2清除，TP37、buff及buff回合原样；只有recoverAll回满HP/MP。既有生产实现正确，不重复修。

## 验证与交付

- 原版四例errors空；Godot Permanent34/34、半值2951/2951（严格军团19＋19）、原种子两场6574/6574和6450/6450，首次全部通过、无偶发。Godot导入成功；只改测试／fixture，无需重跑正式同步或全量。
- 精简证据见[专项结果](../核查范围/随机对照_专项结果_20261025.json)。本期临时输出已清理，原版实体测量脚本与输出在.sandbox保留，旧原版证据／generated／整树保留。自己的测试补充待Claude核查，不自销核。
- 合并顺序：四零散b135ee33→2g026f6ee3→本期；50%审查二期0b00c374仍由唐僧另合，不夹带或重做。
- 下一步：actor-bonus（永久加算＋宠物出战属性／命中加成／整队重学）→passive-content→race-battle；本期不自评完成度，不改共用登记。

## 可优化

- 固定参照与多种子测试职责各自明确：相同抽样只验证严格测量比较，多种子保留随机分支覆盖。单轮半值场景32秒，最终与原种子合跑100秒；不替换或减掉原检查。

## 沙僧62→63（同工作区自动接力）

- 62已完成三份独立交付，当前codex/rng-compare-review、HEAD95c2f1c5（本节提交后以前进后的HEAD为准），工作区干净，无任何在途长任务或前台等待。62创建63后停止，63为唯一执行者。不是额度停手：最后五小时64%、周25%。
- 合并顺序：四零散codex/four-loose-fixes b135ee33→2g codex/state-effects-2g 026f6ee3→本随机核查分支。后两分支已依次并入前一分支作为依赖，无需cherry-pick/reset。自己的所有改动待Claude，不能自销核。50%审查二期codex/stage-review-50-phase2 0b00c374仍交唐僧另合，不夹带或重做。
- 四零散真正已完成：最终全部58条探针记录exit0（53计划含六难度）；初轮因新增图鉴cases/id未登记而exit2，补oracle_additions.py一行稳定键并验证五种拒收保护后，缓存收尾0执行/53复用、同步及导入exit0。范围恰为cat元数据1＋slice6条既有变化，enemy_book_defeat新增34（旧4原样，总38）；没有放宽接受单。rules基础105856/105856、cat994/994、enemy_book86/86、loose126/126首次全过，另外11依赖与power137仍有效。不可再执行apply_production.py或重跑旧同步。
- 2g首批真正可合并：原bf585fdc两处capState_buffs失败由4f7cad5b改resource_context.refresh guard为非XEnemy的add锁基类分支解决；formula_effects908/908、TP537/537及另12场依赖共14场首次全过，8条翻译测试、来源核验issues空。并四零散只一处资源死亡冲突，保留2g add_state_with_context，note_death经battler._add_state计数，loose死亡回归126/126。只重生成＋导入，没再全量同步，原state_effects26例SHA256仍7eff2c8a0c7632f25f9b419cfe5e2edb6e363094ee5f0ee6af57f2293a2160ad。三个Battle块交付，不把两个Apply／完整预览空槽接口说成完成；停手范围详2g交付单，别顺手改formula_execution/mv_event_core等未交接接口。
- 随机核查本期真正完成：状态44第一回合末已有严格有无＋回合数比较，第二回合后到期例外是采样时点差，不改生产随机。新独立oracle_half场景等价Math.random0.5、整数floor(n*0.5)，恢复军团19次行动者集合＋19次附伤检查2951/2951；原五种种子两场6574/6574、6450/6450保留且全过。原版actor/enemy×clearStates/recoverAll四例errors空，Godot逐字段34/34（Permanent686剩5回合保留、普通2清除、TP37/buff不变、recoverAll回满HP/MP）。没有生产代码改动。
- 三期精简证据均在00_项目管理/核查范围对应JSON。三个本期临时目录four-loose-fixes/state-effects-2g/rng-compare-review均已清理；自动同步报告与备份、.sandbox内原版脚本和输出、旧原版证据、generated与整树永久保留。文档登记检查从检查.sh提取，均exit0，dev.173；车道未跑全量。不重复这些专项或旧阶段审查。
- 下一步新建本期分支codex/actor-bonus（从当前已验基线），先读XPets接口与原版再补参照：永久加算（现有XParamPlus/mv_param_plus/actor.param_base挂点已由悟空接，要复用）、宠物出战属性war_param_plus、命中加成、整队重学共享技能。定位core/pets.gd 13行说明、161行分发技能、209行refreshGTWar、250行war_param_plus；actor.gd的param_plus/_param_plus约454/463行。actor.gd独占交给本期，但保留XTraining、XParamPlus及XActorModules例外挂点。还没开始本期实现，不要把初读当验收。必要时只合main中真正相关新变更，不追无关main。
- 后续既定actor-bonus→passive-content（技能书／军团科技4555～／霸体2651）→race-battle（等八戒接口），完成且额度足再核他人待核项。额度五小时95%WIP保存停、周98%收尾；不是旧59的96%停手。上下文到40%同树自动接力。疑难设计按实际难度调强度，不虚称切换。
- 第一条及所有文件命令显式workdir=/Users/kyo/Documents/再刷项目资料库/.claude/worktrees/state-effects-2b，只用此已有树，不在main改，不创建/清理worktree，不reset/cherry-pick、不建automation。共用交接板/变更记录/步骤清单/当前状态只读，登记仅自己的交付单。小步提交尾注执行者: Codex（沙僧）与核查: 待Claude。

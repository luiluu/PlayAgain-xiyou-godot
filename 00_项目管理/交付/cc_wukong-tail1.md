# 交付：cc/wukong-tail1

- 车道／工作者：C 规则／悟空（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-04 【cc·悟空·未经审查】奈叶预定小魔炮、绝缘×云裳实测；璇跳过回合与棱光目标（审查 35b）（dev.待定）

派单：角色专属尾项第一批四项（先查真缺），总装插单审查 35b P2-1、P3-1。全部是照原版修，没有新优化，没有新回退开关。

### 一、四项核实结果

| 项 | 结论 | 依据 |
| --- | --- | --- |
| ① 奈叶 scheduledSkill | **同一张表已移植，只缺一段，已补** | `XHangUpAuto.scheduled_skill` 读的就是 `_XdRsData_hangUp_ActSkill`；缺 makeAction 里「预定 5692 时只在魔炮里挑」 |
| ② 绝缘×云裳 | **判断已接（dev.280 白龙读码），本轮补原版实测，没改代码** | 见下 |
| ③ 饿狼进阶原因、追击／反击日志 | ~~已做~~（dev.255） | `actor_advanced.gd:289`、`garou_trigger`＋`battle_scene.gd:1447`，`xiyou_battle_log` 覆盖 |
| ④ 宿傩技能分类指令窗 | ~~已做~~（dev.255） | `XActorModules.MENU_SKILL_TYPES`／`BATTLE_SKILL_TYPES`，`xiyou_battle_log` 覆盖；原版 [2,1,5,3,4]／[2,1,5,3] 对过 |

交接板「下一步」第 1 条（奈叶）和第 5 条（角色专属尾项）里这几处可以划掉。`nanohaFallback` 不用移植：只在 choose 返回空又能普攻时才有用，而 choose 自己就退回攻击、防御，走不到。

### 二、奈叶挂机预定小魔炮

- 原版：智能 AI 开着、顺序表这回合排了 5692（能用且学会）：`choose(this,true)`，只在六档魔炮里挑；没得挑才走普通智能选择。5692 本身只开六选一公共事件，自动战斗不能用。
- 重制原来：照表直接放 5692，挂机时会走到选择事件。
- 修：`XSmartAI.choose(l, a, cannon_only)`（不看物品、不退回攻击防御）、`XHangUpAuto.scheduled_id`、`_auto_battle_action` 加分支。智能 AI 关着照原版放 5692。
- 参照：`nanoha3_probe` 加 10 例 `sched.*`。同是 23000 MP：不预定选 5710，预定选 5704；队友残血时不预定去治愈，预定照放 5704；不能用、没学会都算没预定。

### 三、绝缘×云裳原版实测

- `yunshang_probe` 加 `p2.insulation.a／ally`（绝缘者分别是云裳、队友），`xiyou_yunshang` 比对：外来的 wake、addActions 挡，自己来的照常；freeGift 不看来源一律挡，且不耗每回合一次；真放赠行 10284 也不加行动；同一回合赠不绝缘的 8 号照常成功。重制全部一致。

### 四、审查 35b P2-1：璇在跳过的回合放回光（battle_logic.gd）

- 原版量到（`xuan_auto` `skip_turn`）：敌人没有行动、不能行动、行动无效，三种都不救援；同样残血，事件强制行动走 endAction 才救援（星契 1→0，MP 1193→1122，1 号 145→485，审查报的数字）。修：`XXuanBattle.end_action` 对敌人只在真行动时走。
- **审查单没提的一点**：角色不一样（`skip_actor`、`skip_host`）。OTB 的 processTurn 对角色走 startOTBInput，不能输入也 makeActions＋startAction，照走 endAction，所以**被控角色的回合原版照样救援、列星**，只是没有行动，宿主被控不放棱光。所以门写成 `u.is_actor() or (started and not skipped)`，被控时不把技能传进去。照单全挡反而错，反向验证咬得住。
- `_forced_run` 路径原来就对：强制行动原版照走 endAction。

### 五、审查 35b P3-1：棱光跟打目标被内部行动覆盖（battle_logic.gd）

- 查实是错的。原版把目标记在这次 Game_Action 上：甚尔溅射、屠苏支援、宿傩 perform 是新建的子行动；黄泉扩散、镜流补段用 oldApply 绕过璇的包装。主行动打 1 号敌，棱光就打 1 号敌（`last_toji`、`last_yomi`，都实测）。重制记在 `apply` 里，每个内部 apply 都覆盖，会打到最后一个被溅射的敌人。
- 修：`note_target` 挪到选完替身之后的主行动入口。屠苏、镜流、宿傩三家这轮只读了码（走的同一入口），没单独开探针例。

### 六、验证

- 专项：`xiyou_nanoha` 272、`xiyou_yunshang` 1675、`xiyou_xuan_auto` 3789 项全过；选测 134 场景走云端，结果写在下面。
- 反向验证 11 项：10 项咬住；「预定不看能否使用」没咬住，是等价改动（不能用时 `cannon_options` 也空，一样退回普通智能选择）。
- 探针 `nanoha3`、`yunshang`、`xuan_auto` 都不进同步，夹具重生成后旧用例逐例比过没变；没动切片和转换器。
- 改了共用核心文件：`battle_logic.gd`（`act`、`_invoke` 一带、`_auto_battle_action`），`smart_ai.gd`、`hang_up_auto.gd`。

选测结果：云端 134 个场景全过（提交 05ab259b，基准 6c79d5d3，运行页 https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/41750991261）。合并 main（含 xuan4c、tools57）之后跑的。

## 交接板

- 下一步：第 1 条划掉奈叶预定表；第 5 条划掉饿狼进阶原因、追击／反击日志、宿傩指令窗、绝缘×云裳。
- 用户试玩说明：奈叶在挂机顺序表里排小魔炮时，会自己挑一档魔炮放。有璇的队伍里，敌人晕住或没行动的回合，璇不再白花星契放回光。甚尔万里锁、黄泉扩散之后，璇的棱光打主目标。
- 需要用户决定：无

## 进度账

- 无变化（尾项，不单独计）。

## 可优化（流程／工具／效率）

- 建议（规则车道，下批查，别当成已确认的 bug）：`act` 里 `if started and not skipped` 这个门对角色也拦（饿狼、宿傩、黑闪、镜流、甚尔、渡鸦、云裳 finish，绑定 end_action）。这轮量到被控角色原版照走 endAction，这些包装可能和璇有同样的差异，只是方向相反，这轮没量。门外的屠苏、谷雨、狂妄、心钢、种族、小猫、异化 finish 对敌人跳过回合也照跑，同样没量。
- 建议（合并工具或审查）：`反向验证.py` 清单里写 `\t` 才行，直接贴代码里的制表符会 JSON 报错、整份退出；可以在报错时提示一句。

## 本分支提交

- 7aec7bd0 WIP: tail1 交付单草稿
- f1ce9ce2 璇：敌人跳过的回合不走 endAction；棱光目标只记主行动（审查 35b P2-1、P3-1）
- eaa4884d 绝缘×云裳补原版实测：wake／addActions 只挡外来，freeGift 一律挡且不耗次数
- 36997b38 奈叶预定小魔炮：参照 10 例进 nanoha3，专项比对
- a0b00ddc WIP: 奈叶挂机预定小魔炮只在六档魔炮里挑（Codex_SmartBattleAI makeAction）

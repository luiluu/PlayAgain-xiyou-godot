# 交付：cc/bailong-yunshang1

- 车道／工作者：E 角色专属／白龙_8（cc，项目线程「做渡鸦第三期战斗机制」）
- 状态：WIP（只做了盘点；上下文接近 70% 停手线，交下一个白龙会话接）
- 分支从 cc/bailong-jingliu2 末端 8740add3 切出，还没有代码改动。

## 接续要点（下一个会话从这里开工）

1. 开工：`新建工作树.sh --补齐 <自己的路径> --branch cc/bailong-yunshang1 --from <本分支末端>`，或在本工作树 heuristic-wing-4e9b42 直接接（分支已在）。
2. 原版：`冻结正式源/app.nw/js/codex/runtime/installNativeYunshangRuntime.js`，772 行但多是压成一行的长行（第 5 行配置 C 就 4000 字），读时用 `cut -c` 分段，别整行打印。云裳是 174（职业 172），天衣是防具本体 7920～7934（序号 key＝本体−7920，共 15 件，**谁穿谁吃效果**，不只云裳）。
3. 本期范围（总装八）：入切片 → 招募、能力值／被动、公式、伤害钩子 → 战斗内机制盘点（量小就一起做）。做法照镜流一期（交付单 cc_bailong-jingliu1.md）：slice 加 174、formula_program 加模块公式、XActorModules 挂点、mv_oracle 新探针、专项、反向验证、同步一轮、内容覆盖检查、选测（规则对照用 `RULES_ONLY_ACTORS=174` 跑 xiyou_rules 与 d2～d6 六个）。

## 原版盘点（按行号，行号是 installNativeYunshangRuntime.js 的）

| 行 | 内容 | 归哪期 |
| --- | --- | --- |
| 5～6 | 配置 C：actor 174、class 172、skills（pin 10270、cut、mountain、shop…）、gates（技能解锁 [等级, 进阶]）、robes（天衣表、等级与进阶门槛）、robeDamageCoefficients、advance、relic、unknownBattles、visual | 一期要读 |
| 24～49 | 工具：robe(a)（身上天衣）、key、relic、normalizeRobe（天衣备注品质）、data(a)（每件天衣的战斗数据 _yunBattle：wakeUntil、bank、debts、captured、stored、ghost…）、awake、unlocked、damageAction、sourceOriginal（gift／stored 行动来源） | 一期（基础）＋二期 |
| 51～56 | Y.sync（按 gates 学忘专属技能）、setup／levelUp／changeLevel 包装 | 一期 |
| 57～70 | Game_Actor.param 包装（云裳 0／4／6 按等级 25／30／35… 倍率）等能力值 | 一期 |
| 71～145 | 账本 ledger／profile／transaction／replay（天衣制作、订单，存在独立日志里） | 养成，另期 |
| 146～187 | 天衣铺：advance（进阶）、pool、equipmentCap、submit／claim／progress（订单） | 养成／界面，另期 |
| 188～205 | setupNewGame／extractSaveContents／loadGame／gainItem／tradeItemWithParty 包装（账本恢复、天衣进出背包） | 养成，另期 |
| 206 | Y.recruit（入队、进阶取账本、sync） | 一期 |
| 207～213 | 商店追加、天衣图标 | 商店已由 Map132 期接；图标归界面 |
| 214～247 | Y.wake（觉醒）、settleDebt／repay、resetRound、startBattle／startTurn／endTurn／endBattle 包装、isImmortalClear（未知战斗免死清除） | 二期 |
| 248～265 | skills（借技能 borrowable）、meetsSkillConditions、testApply、itemHit／itemEva／itemCri、numRepeats、makeTargets 包装 | 二期（itemHit 等若只看云裳本人可提到一期） |
| 266～283 | offensiveGrowth（25 级起暴击＋1.88×(等级−24)、终伤＋0.1888×…）、refreshPassiveCache 包装、Y.formula | 一期 |
| 284～345 | storedDamage、nativeDamage、makeDamageValue 包装（注意：installDamageElementRuntime 后装会整个换掉 makeDamageValue，先核这层生不生效，同黄泉／镜流）、derived、burst、ghost 结束 | 二期（先核生效与否） |
| 346～379 | die／revive／deadMembers／smoothDeadTarget／removeState／addState／executeHpDamage 包装（幽灵、捕获、状态复制） | 二期 |
| 380～436 | prepareAction／startAction／applyCommand／apply／executeDamage／finishAction／endAction 包装 | 二期 |
| 437～447 | **addActions、getNextSubject、freeGift、storeActions、release、cut**（赠行、储行、放行、拆段） | 二期 |
| 448～468 | evaluate 与自动战斗 AI（aiBattle／aiAwake／aiGather…） | 二期 |
| 469～607 | 选择窗 Window_YunChoices、Scene_Yunshang（天衣铺界面、配置） | 界面（重制已有选择窗与提示，进度 0.1 的那部分） |
| 608～772 | 法宝显示、天衣名、图标；749～772 伤害钩子 yunshang（带 split：拆段） | 钩子一期，split 二期 |

## 别的模块等着云裳的点

- 异化（八戒 dev.234 清账时留下）：绝缘对云裳 `wake`／`addActions`／`freeGift` 的拦截（`alien_battle.gd:1670`、`1804` 注释写着「重制没有赠行／储行这两种行动来源」），要等二期的行动来源（`_yunActionSource` gift／stored）。`alienation.gd` 的 `CodexYunshang.key`（297）、`lifeCompatible` 不穿第 3 件（338）已按读码接了，入切片后要用真天衣核一次。
- 悟空 PushState 二期：「云裳拆段整体只挂一次」——对应伤害钩子 `split`（749 行起）与 `Y.cut`（447），二期做。
- 界面：`actor_book.gd:465`、`character_help.gd` 的云裳 dyn2 行，等天衣与进阶数据在了再接。

## 探针宿主清不掉队伍（总装八让写清怎么改）

- 现象：`w.eval('$gameParty._actors=[];')` 不生效，新局的 1、8、9、10 还在（渡鸦三期、镜流一二期的探针都踩到，见 cc_bailong-jingliu2.md）。
- 正确写法：`w.$gameParty._actors.length = 0;` 然后逐个 `w.$gameParty.addActor(id)`，再 `w.$gameParty.members().map(b => b.actorId())` 打出来核一次。重制专项照同一个队伍建（`s.party.clear()` 后 `s.add_actor`）。
- 已有探针（raven_battle、jingliu、jingliu2）的夹具按「1、8、9、10＋角色」量的，专项也照这个比，结论不受影响；不用回头改。

## 本分支提交

- 本提交：盘点与接续要点（无代码）

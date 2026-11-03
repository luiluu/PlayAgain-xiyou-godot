# 交付：cc/nezha-tools55

- 车道／工作者：D 工具／哪吒（cc）
- 状态：可合并

## 变更记录草稿

## 2026-11-03 【cc·哪吒·未经审查】未翻译状态块 × 切片可达清单（dev.待定）

- 新增 `07_开发环境/未翻译块清单.py`（只读；`--detail` 附切片明细表，`--json` 每块一行）：读生成数据里 315 个 `op: js` 状态块，按原文模板归 9 族，判「切片可达／全游戏可达／不可达」并列出加状态的路径。切片口径用 `manifest.json` 的 `slice`（`xiyou_export.collect_slice` 的产物）与 `slice.json` 的地图，不另发明；道具／武器／防具 manifest 没列表，按切片角色初始装备、切片敌人掉落、切片地图／公共事件／敌群里 126～128 与商店估算。
- 加状态的路径：效果 code 21、特性 14、备注与状态 js 里 `addState(n)`、`<Passive State>`、装备套装、指令 313／333 与脚本；**另加了 rules1b 粗查漏掉的插件备注标签 `*PushState0123: 100%`**（PushState／StartPushState／StartWTPushState／StartAEPushState／RecPushState／PushsubState，补零状态号，约 1000 处），状态再加状态沿链传递；切片技能并上特性 43、指令 318／脚本 `learnSkill(n)`、CE1442 洪荒诅咒教的 7201～7215。
- 配 `07_开发环境/测试未翻译块清单.py`（7 例：族归类、PushState／被动标签解析、313 增删、链传递，生成数据上锁 315 块、142 换装、14 护盾、1270 复活、105 护盾、112 切片可达、1270／1840 切片可达、494 不可达）。没碰 Godot，未跑 Godot 选测。

## 交接板

- 下一步：八戒排后续规则期时读本单「清单」节。切片可达（不含换装）共 75 块，大头：伤害 react／confirm 15、其它 17、复活 11、reserveCommonEvent 9、护盾 8、改属性／变量 8、回合／行动钩子 5、regenerate 2。护盾 8 块（112、612、614、641）与复活 11 块（114、252、1099、1164、1178、1191、1270、1683、1725、1837、2560）已在切片里，rules2／rules3 的价值比 rules1b 估的高；105、647、1039 在切片外。
- 用户试玩说明：无（工具）。
- 需要用户决定：无。

## 进度账

- 无变化。

## 可优化（流程／工具／效率）

- 已做：本清单脚本一次约 1.5 秒；以后 rules 期开工前跑 `python3 03_再刷重制_Godot/07_开发环境/未翻译块清单.py --detail` 就能看到剩余的切片可达块（翻掉一块它自动少一块的不在内：它读的是生成数据里还是 `op: js` 的块）。
- 建议：`xiyou_state_effects_tp` 的 `inventory.merged_315` 把 142 块换装也算进去，可顺手分两项（rules1b 已提过，收益小，归八戒下一期）。

## 清单（未翻译状态块 × 切片可达，生成数据 315 块）

与 rules1b 粗查的差别：rules1b 的「其余可达约 95」我这边是 90（全部可达 257 − 换装 138 − 护盾 14 − 复活 15），数对得上；「不可达约 40」我这边 54（不含换装的 4），没逐块对差在哪（口径不同：我加了备注标签与 `learnSkill`，装备按估算放宽）。**主要差别：派单点名的 1840 武痴执念2 我这边是切片可达**（技能 6042 武痴执念的备注 `<StartPushState1840: 100%>`），rules1b 当不可达是漏了这类插件备注标签；测试里锁的不可达例子改用 494 九命。1270 在切片内（诅咒技能 7208 备注 `<StartAEPushState1270>`，7208 由切片 CE1442 教）。查不到的路径：插件 js 里硬编码加状态（只数了 `addState(` 的整数字面量，11 处参数是变量的见下「未解析」）、2712 这类权能由未移植的 `installReincarnationRandomRuntime` 加（本清单把它记成全游戏可达，因为技能 7244 的备注标签在全游戏里能找到，实际仍不会触发）。

未翻译 `op: js` 块共 315 块，分布在 204 个状态。

### 按族汇总（块数）

| 族 | 切片可达 | 全游戏可达 | 不可达 | 合计 |
| --- | ---: | ---: | ---: | ---: |
| 换装 | 12 | 126 | 4 | 142 |
| 护盾 | 8 | 6 | 0 | 14 |
| 复活 | 11 | 4 | 3 | 18 |
| regenerate | 2 | 4 | 4 | 10 |
| reserveCommonEvent | 9 | 2 | 1 | 12 |
| 伤害 react／confirm | 15 | 14 | 14 | 43 |
| 回合／行动钩子 | 5 | 4 | 7 | 16 |
| 改属性／变量 | 8 | 6 | 13 | 27 |
| 其它 | 17 | 4 | 12 | 33 |
| **合计** | 87 | 170 | 58 | 315 |

### 切片可达明细（换装已不用翻，另列在汇总里）

| 状态 | 名称 | phase | 族 | 路径（最多 3 条） |
| ---: | --- | --- | --- | --- |
| 112 | 流沙护体 | react | 护盾 | 技能 1112 |
| 112 | 流沙护体 | remove | 护盾 | 技能 1112 |
| 612 | 闪电护盾 | react | 护盾 | 武器 1673（备注 PushState） |
| 612 | 闪电护盾 | remove | 护盾 | 武器 1673（备注 PushState） |
| 614 | 真诚祷告 | react | 护盾 | 武器 1675（备注 PushState） |
| 614 | 真诚祷告 | remove | 护盾 | 武器 1675（备注 PushState） |
| 641 | 杏黄大阵 | react | 护盾 | 防具 4137（备注 PushState） |
| 641 | 杏黄大阵 | remove | 护盾 | 防具 4137（备注 PushState） |
| 114 | 龙涎 | deselect | 复活 | 技能 1122；技能 2450；技能 4218 |
| 252 | 七星续命 | deselect | 复活 | 技能 2516；技能 2546（备注 PushState） |
| 1099 | 预感的庇护 | deselect | 复活 | 技能 5605（备注 PushState） |
| 1164 | 疯癫韧性1 | deselect | 复活 | 技能 5640（备注 PushState） |
| 1178 | 拼命守护 | deselect | 复活 | 技能 5654（备注 PushState） |
| 1191 | 执念和声1 | deselect | 复活 | 技能 5666（备注 PushState） |
| 1270 | 死而复燃 | deselect | 复活 | 技能 7208（备注 PushState） |
| 1683 | 绯红之夜 | deselect | 复活 | 技能 5745（备注 PushState） |
| 1725 | 不朽1 | deselect | 复活 | 防具 4968（备注 PushState） |
| 1837 | 恨魂不屈1 | deselect | 复活 | 技能 6043（备注 PushState） |
| 2560 | 绯红之夜 | deselect | 复活 | 技能 9936 |
| 260 | 附骨之疽 | regenerate | regenerate | 技能 2556；技能 2660；技能 4071；…共 4 条 |
| 1006 | 破阵——附骨之疽 | regenerate | regenerate | 技能 6188 |
| 1306 | 小爱莉被动通用 | turn_start | reserveCommonEvent | 技能 7304（备注 PushState） |
| 1307 | 崩坏能 | remove | reserveCommonEvent | 技能 7305（备注 PushState）；状态 1306 |
| 1317 | 亲朋好友 | deselect | reserveCommonEvent | 技能 7480 |
| 1318 | 鼬被动通用 | turn_start | reserveCommonEvent | 技能 7470（备注 PushState） |
| 2007 | 太极反击 | react | reserveCommonEvent | 技能 5861（备注 PushState） |
| 2009 | 太极进攻 | react | reserveCommonEvent | 技能 5861（备注 PushState） |
| 2011 | 乾坤大挪移反击 | react | reserveCommonEvent | 技能 5854（备注 PushState） |
| 2026 | 向我看齐 | react | reserveCommonEvent | 技能 5933（备注 PushState） |
| 2568 | 神的力量竟如此渺小 | confirm | reserveCommonEvent | 技能 9947（备注 PushState） |
| 1060 | 甘露护体 | react | 伤害 react／confirm | 技能 5571；技能 5573 |
| 1061 | 混元护体 | react | 伤害 react／confirm | 技能 5570（备注 PushState） |
| 1299 | 半步真仙效果 | establish | 伤害 react／confirm | 状态 1298 |
| 1302 | 永世乐土 | react | 伤害 react／confirm | 技能 7302（备注 PushState） |
| 1405 | 太乙 | establish | 伤害 react／confirm | 防具 4994（备注 PushState） |
| 1450 | 智识1 | establish | 伤害 react／confirm | 防具 4975（备注 PushState） |
| 1580 | 不死之躯 | respond | 伤害 react／confirm | 技能 5825（备注 PushState） |
| 1642 | 千刃乱雨 | confirm | 伤害 react／confirm | 技能 5546（备注 PushState） |
| 1666 | 半步真仙效果 | confirm | 伤害 react／confirm | 状态 1665；状态 2566 |
| 1731 | 均衡 | confirm | 伤害 react／confirm | 防具 4965（备注 PushState） |
| 1828 | 五绝神功 | react | 伤害 react／confirm | 技能 6033 |
| 2554 | 不死之躯 | respond | 伤害 react／confirm | 技能 10052（备注 PushState） |
| 2559 | 血梅香 | confirm | 伤害 react／confirm | 技能 10069（备注 PushState） |
| 2562 | 护体罡气 | react | 伤害 react／confirm | 技能 9927（备注 PushState） |
| 2575 | 剑道争锋 | confirm | 伤害 react／confirm | 技能 10078（备注 PushState） |
| 1306 | 小爱莉被动通用 | turn_end | 回合／行动钩子 | 技能 7304（备注 PushState） |
| 1450 | 智识1 | action_start | 回合／行动钩子 | 防具 4975（备注 PushState） |
| 1711 | 秩序0 | turn_start | 回合／行动钩子 | 防具 4972（备注 PushState） |
| 1716 | 同谐0 | turn_start | 回合／行动钩子 | 防具 4971（备注 PushState） |
| 2575 | 剑道争锋 | turn_end | 回合／行动钩子 | 技能 10078（备注 PushState） |
| 541 | 必爆 | deselect | 改属性／变量 | 技能 2766（备注 PushState） |
| 541 | 必爆 | select | 改属性／变量 | 技能 2766（备注 PushState） |
| 755 | 必爆 | deselect | 改属性／变量 | 公共事件 1022 |
| 755 | 必爆 | select | 改属性／变量 | 公共事件 1022 |
| 1423 | 欠债 | victory | 改属性／变量 | 技能 8091（备注 PushState） |
| 1840 | 武痴执念2 | apply | 改属性／变量 | 技能 6042（备注 PushState） |
| 2003 | 太极破坏效果 | apply | 改属性／变量 | 技能 5860；技能 5862 |
| 2003 | 太极破坏效果 | remove | 改属性／变量 | 技能 5860；技能 5862 |
| 83 | 命之诅咒 | respond | 其它 | 敌群 160 |
| 1060 | 甘露护体 | apply | 其它 | 技能 5571；技能 5573 |
| 1067 | 戮仙印记 | apply | 其它 | 技能 5576；技能 5577 |
| 1067 | 戮仙印记 | remove | 其它 | 技能 5576；技能 5577 |
| 1068 | 金剪追加 | apply | 其它 | 技能 5577 |
| 1068 | 金剪追加 | crit | 其它 | 技能 5577 |
| 1068 | 金剪追加 | remove | 其它 | 技能 5577 |
| 1072 | 挨打反击 | react | 其它 | 技能 5580（备注 PushState） |
| 1301 | 往世乐土 | deselect | 其它 | 技能 7301（备注 PushState） |
| 1452 | 存护2 | respond | 其它 | 防具 4973（备注 PushState） |
| 2544 | 剑终伤 | confirm | 其它 | 技能 10013（备注 PushState） |
| 2545 | 太刀终伤 | confirm | 其它 | 技能 10013（备注 PushState） |
| 2548 | 装备落月弓防御 | confirm | 其它 | 技能 10023（备注 PushState）；技能 10028（备注 PushState） |
| 2574 | 非天逆斩 | apply | 其它 | 技能 10080（备注 PushState） |
| 2575 | 剑道争锋 | apply | 其它 | 技能 10078（备注 PushState） |
| 2575 | 剑道争锋 | battle | 其它 | 技能 10078（备注 PushState） |
| 2575 | 剑道争锋 | remove | 其它 | 技能 10078（备注 PushState） |

未解析的 `addState(非整数字面量)`：11 处（来源 11 个），例：状态 292×1、状态 299×1、状态 301×1、状态 305×1、状态 307×1、状态 309×1、状态 311×1、状态 313×1。

只靠弱匹配（备注「状态 n」✱）判可达的状态 0 个：[]。

切片集合：actors 166，enemies 818，skills 2957，troops 778，commonEvents 1237，Items 1631，Weapons 841，Armors 1737（道具／武器／防具为估算）。

## 本分支提交

- 见 git log（头提交在回报里）。

执行者: cc（哪吒）

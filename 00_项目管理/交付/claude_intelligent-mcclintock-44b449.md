# 交付：claude/intelligent-mcclintock-44b449

- 车道／工作者：C 规则·机制／八戒_75（Claude）
- 状态：可合并

## 变更记录草稿

## 2026-10-26 【Claude·八戒_75·未经Codex检验】状态效果 js 剩余 322 块盘点：收益到头，期一不翻译

- **结论**：按派单停手条件（可达块最大一类 <15 块就不翻译）停在盘点。剩余 322 块按形状（数字、字符串归一）分 146 类，切片可达合计 92 块；单一形状可达最多 7 块，连同成对的另一阶段（同一批状态的 Apply／Remove）也只有 14 块，而且可达口径偏宽（全部武器、防具、物品都算可达，不管切片里能不能拿到）。其余可达块散在一两块一类的长尾里，每类都要单独的新 op。
- **盘点脚本**：新增 `00_项目管理/盘点脚本/state_js_census.py`（只读转换产物 `generated/db` 与 manifest 切片，打印前 N 类表格）。可达口径：切片技能、角色与职业、敌人与其行动技能、全部武器防具物品的特性 32、效果 21 与备注里的状态号；公共事件、地图、敌群的 313 指令；再沿状态备注闭包。
- 没改游戏代码、转换器、探针，不用同步。

### 前 10 类（块数、可达、需要的新 op）

未翻译 js 块 322，可达 92，形状 199 类（字符串、数字归一后 146 类）
| 阶段 | 形状（开头） | 块数 | 可达 | 可达状态（来源） |
| --- | --- | --- | --- | --- |
| apply | `if (user.isActor()) { user._prevBattlerName = user._prevBattlerName ¦¦ user._battlerName; ` | 71 | 7 | 66 佛陀真身(skill/w)、125 佛陀真身(skill/w)、208 牛头人(i)、226 牛头人附体(a)、270 狗(a)、284 怒目金刚(a)、1223 破阵——变身[萧萧](a) |
| remove | `var battlerName = user . _prevBattlerName ; user . setBattlerImage ( battlerName ) ; user ` | 71 | 7 | 66 佛陀真身(skill/w)、125 佛陀真身(skill/w)、208 牛头人(i)、226 牛头人附体(a)、270 狗(a)、284 怒目金刚(a)、1223 破阵——变身[萧萧](a) |
| react | `if ( this . isHpEffect ( ) && value > N ) { var elements = this . getItemElements ( ) ; va` | 7 | 5 | 105 神圣护盾(enemy-skill/skill)、112 流沙护体(skill)、612 闪电护盾(w)、614 真诚祷告(w)、641 杏黄大阵(a) |
| remove | `user . _bubbleWrapCooldown = N ;` | 7 | 5 | 105 神圣护盾(enemy-skill/skill)、112 流沙护体(skill)、612 闪电护盾(w)、614 真诚祷告(w)、641 杏黄大阵(a) |
| react | `if ( value >= N ) { $gameTemp . reserveCommonEvent ( N ) }` | 4 | 4 | 2007 太极反击(skill)、2009 太极进攻(skill)、2011 乾坤大挪移反击(skill)、2026 向我看齐(skill) |
| deselect | `if ( target . hp <= N ¦¦ target . isDead ( ) ) { target . startAnimation ( N ) ; var rate ` | 4 | 3 | 114 龙涎(enemy-skill/skill)、163 免死(w)、252 七星续命(skill) |
| select | `var skill = this . item ( ) ; if ( skill && skill . damage . critical ) { this . _prevForc` | 4 | 2 | 541 必爆(skill)、755 必爆(event) |
| deselect | `if ( this . _prevForcedCriticalHit !== undefined ) { $gameSystem . _forceCritical = this .` | 4 | 2 | 541 必爆(skill)、755 必爆(event) |
| deselect | `if ( target . hp <= N && Math . random ( ) > N ¦¦ target . isDead ( ) && Math . random ( )` | 3 | 2 | 1099 预感的庇护(skill)、1178 拼命守护(skill) |
| deselect | `if ( target . hp <= N && $gameVariables . value ( N ) > N ) { target . gainHp ( N ) ; targ` | 2 | 2 | 1683 绯红之夜(skill)、2560 绯红之夜(skill) |

需要的新 op（估计）：
1. 换战斗图 Apply／Remove（14 可达）：`battler_image`（set／restore，存 `_prevBattlerName`、存档字段），并要 Godot 战斗界面按状态换角色侧视图、Remove 时还原；71 块里 Apply 的图名各不相同，但都是同一形状。视觉效果，不影响数值。
2. 泡泡护盾 react＋Remove（10 可达）：`bubble_wrap`（非雷属性伤害归零、播动画、去掉本状态；Remove 写冷却回合），要 `getItemElements` 查询与冷却字段。
3. 受击后预约公共事件 react（4 可达）：`reserve_common_event`，要战斗中公共事件队列在 react 时机接得上（太极反击类）。
4. 濒死自救 deselect 三种形状（3＋2＋2 可达）：`revive_heal`（hp≤0 或死亡时按比例回血、去状态、弹字；随机版、按变量扣次数版），要和倒下判定的时序对照原版。
5. 必爆 select／deselect（2＋2 可达）：`force_critical` 存取 `._forceCritical`。
6. 远程武器加伤 confirm（2 可达）：`ranged_weapon_bonus`（主手武器类型在名单里时加伤）。
7. 半步真仙 establish（1 可达）：命中后再扣一次同值并去状态。

## 交接板

- 下一步：状态效果 js 剩 322 块（可达 92）收益到头，建议砍掉批量翻译；以后只在某个可达状态被玩家报出问题时单独翻那一类（换战斗图 14 块、泡泡护盾 10 块是最大两类）。盘点重跑：`python3 00_项目管理/盘点脚本/state_js_census.py 10`
- 用户试玩说明：无（本轮没改游戏）
- 需要用户决定：无（砍不砍由总装定）

## 进度账

- 状态效果 js：不变（未翻译 322 块，其中切片可达 92 块）

## 可优化（流程／工具／效率）

- 已做：盘点脚本入库，下次派状态效果 js 前先跑一遍看收益（删文件即回退）。
- 建议：派「按块数翻译」类任务时，交代里直接给可达块数（本脚本一秒出表），免得车道开工后才发现收益不够。

## 验证

- `python3 00_项目管理/盘点脚本/state_js_census.py 10` 输出如上；只改文档与盘点脚本，未跑 Godot 测试与同步。
- 已清理：本车道临时输出 `04_验证/本地结果/bj75/` 已删。

## 本分支提交

- （见下）盘点脚本与交付单

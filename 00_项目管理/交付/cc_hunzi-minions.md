# 交付：cc/hunzi-minions

- 车道／工作者：C 规则·机制／cc（Orca worker，claude-opus-5-5＋medium）
- 状态：可合并

## 变更记录草稿

## 2026-11-15 【cc·混子小弟·未经审查】天启篇瘟疫骑士混子小弟 A／B／C 实装（v0.2，Kyo 11-15 D10～D13 全按推荐）（dev.待定）

- **依据**：私密仓 `重制设定/天启篇_混子小弟ABC设计_v0.2.md` 第 7 节实装清单；Kyo 11-15 拍板：D10 名字组一（板砖／喷嚏／喇叭）、D11 选甲（只改站位，机制沿用全体挑衅）、D12 数值和出手照稿、D13 辅助 C 不打伤害。
- `tianqi_data/horsemen.json`：`knights.plague` 加 `minions`（`order` A→B→C、`respawn_gap` 2、A／B／C 各一条：名字、生命、防御、魔防、招名、系数／目标／全体／魔法、C 的 `defiance_targets` 2 与 `taunt_reduce` 0.33；可选 `shell` 给每只单独借外观）；`defiance` 加注 `per_add` 现只用于打混子；`adds` 注释改写；`nice_number_exempt` 加 `respawn_gap`、`defiance_targets`。
- `core/tianqi_horsemen.gd`（`XTianqiHorsemen`）：
  - 瘟疫本体战三个小怪位按 A／B／C 建（`_minion_rec`：生命 × 本档敌人血量，攻击、魔攻是共用 `adds.atk` × 本档敌人攻击，防御、魔防照表）；**站位**：混子 x 600 靠我方，小弟排一列在 x 420（A 上 B 中 C 下）；**生存战、35 层影子瘟疫线不再建小怪位**（v0.2 第 4.4 节）。
  - 外观接口：`minion_shell(key)`（表里 `shell` 有就用，没有回落 `shell_enemy.add` 占位），co 画好后在表里每只填一个敌人号即可，不用改代码；另有 `minions()`／`minion()`／`minion_key_at()`／`minion_key_of()`。
  - **出手**（`decide`→`_minion_pick`，`perform` 三种）：A「拍板砖」单体物理系数 1.0，出手时挑不服层数最多的人（同层带标签随机 `horseman_minion_target`）；B「打喷嚏」全体魔法系数 0.5（打魔防）；C「起哄」随机两名不同的活人各 +1 不服（沿用 `horseman_defiance` 标签），不打伤害。日志带显示名（「混子小弟A·板砖拍了…一板砖」「混子小弟C·喇叭起哄：…不服 +1」），出场、倒下各一句台词。
  - **重混**（`_next_minion`）：第二阶段起每 `adds.every` 回合最多混出一只；第 T 回合倒下的最早 T＋3 回合开始回来；同时能回来时没出过场的先出（照 order），其次倒下最早的。倒下回合在 `_check_kills` 记（骑士已倒时不记）。
  - 混出（含重混）时 `_join_orders` 把小弟补进本回合行动顺序末尾和下回合顺序（回合开始时顺序已排完，不补要到 T＋2 才第一次出手）。
  - 回合末「每只活着的小怪给一人 +1 不服」删掉（C 起哄代替）；`taken_mult`：C 活着且嘲讽在时削伤用 0.33（0.89×0.67），否则照旧 0.22；`after_action` 打混子 +不服改读 `defiance.per_add`（值仍 1）。
  - 盾碎提示：碎时「混子之盾碎了！下一回合他挡不住身后的小弟。」，下一回合嘲讽解除时有小弟在场加一句「小弟们露出来了。」。`filter_targets` 不改（全体挑衅就是「混子挡在前面」）。
- `tests/xiyou_tianqi_horsemen_battle`：新节「五b」32 条断言（106→138 条）：三只名字、生命、防御、站位在混子身后、外观接口回落；出场 A→B→C、真实 run_turn 里出场当回合就出手；A 打不服最多的人且按物防算、不加不服；B 打全体且按魔防算；C 20 次都给两个不同的人、不打伤害；回合末不再给不服；C 在场削伤 0.89×0.67、清掉后回 0.89×0.78；嘲讽在时单体、群攻都只打得到混子，窗口回合都打得到；倒下回合记录、T＋1／T＋2 不回来 T＋3 回来且当回合起哄；没出过的先出、倒下最早的先出、空回合内不出；骑士倒下小弟一起散；生存战、影子没有小弟位。
- 测算（私密仓，`数值测算/骑士.py` 补小弟模型，参数在 `参数.json`「骑士/瘟疫/小弟」）：艰险中位 10.6 → **11.7 回合**（≤12，B 不调轻）；手气差 12.8，最差阵容 15.7 → 18.1，九死中位 13.0 → 15.0。
- 玩家可见：天启篇 36 层瘟疫骑士战的三只小怪改叫「混子小弟A·板砖／B·喷嚏／C·喇叭」，站在混子身后，每回合都会出手（拍不服最多的人、全体喷嚏、起哄加不服）；喇叭在场时打混子更不疼；被清掉的小弟至少隔 2 回合才回来。生存战和 35 层影子没有小弟。
- 提交：见本分支提交
- 未完成／已知问题：外观仍借 2 号敌人占位（等 co 画，填 `minions.<键>.shell`）；稿里「选目标提示改成『混子挡在前面』」没做——游戏里现在没有这条提示（嘲讽时目标列表直接只剩混子），要做得在战斗界面加，归界面车道；测算的「治疗折出手」是占位，模型下窗口不清小弟反而最快，实战再校。

## 返修（co 甲档核 a37967e44、0fe6bc0e0 的 2 条 P2，协调 ctx_591ef650a1ac）

- ① 小弟出场当回合不出手：`BattleLogic.start_turn` 先排行动顺序（`_make_action_orders`，藏着／倒下的不在里面）再调 `XTianqiHorsemen.start_turn`，召出的小弟要到 T＋2 才第一次动。已修：`_plague_turn_start` 召出（含重混）后调新函数 `_join_orders`，把小弟补到本回合 `current_order` 末尾、并补进 `next_order`，出场当回合就出手（以稿为准）。专项加 2 条真实 `run_turn` 断言：`minion_act_on_appear`（A、B、C 出场回合＝第一次出手回合）、`minion_respawn_acts`（C 重混那回合就起哄）；反向验证「召出不补顺序」「只补下回合顺序」两项都咬住。战争援军也是同一类时机（召出当回合不动），不在本单范围、没改，见「可优化」。
- ② 窗口回合措辞：代码不改（盾在回合中途碎，下一整回合嘲讽解除才是窗口，和 v0.5 稿、骑士.py 一致）；私密仓 v0.2 稿、骑士.py 报告文字、参数.json 说明里「盾碎那一回合／破盾那回合」统一改成「盾碎后的下一回合（窗口回合）」（私密仓 d2ff4f7）。
- 返修验证：语法检查通过；本机跑 xiyou_tianqi_horsemen_battle（138／138）、_plague、_war、_famine、_death、xiyou_tianqi_horsemen 全过（只改了瘟疫召出那一处＋测试，别的选测沿用上轮）。
- 测算：模型本来就是出场当回合出手、窗口在盾碎下一回合，口径不变；重跑结果不变（艰险中位 11.7 回合）。

## 交接板

- 下一步：co 画混子小弟 A／B／C 三张图（v0.2 第 6 节），画好后在 `horsemen.json` `knights.plague.minions.A/B/C.shell` 填敌人号；实战校准小弟数值（测算余量 0.3 回合）
- 用户试玩说明：天启篇 36 层瘟疫骑士战（地图入口还没做，测试里开）：三只小弟有名字、会出手、站在混子身后
- 需要用户决定：无

## 进度账

- 天启篇四骑士·瘟疫线：本体战小弟机制按 v0.2 落地；美术占位

## 可优化（流程／工具／效率）

- 建议：战争线援军（`_reinforce`）、饥荒线「饿」召出的小怪也是回合开始后召出、不补进行动顺序，召出当回合不动、下一回合也不在顺序里（要到 T＋2）；是否要同样补顺序得看那两条线的稿，归天启篇战斗车道（可直接复用 `_join_orders`）。

- 建议：私密设计仓有别的会话用 `git add -A` 一类整仓暂存，62f6d23（D14 黑龙审图）顺带把本车道没提交的 `骑士.py`／`参数.json`／测算报告一起提交了；设计仓提交建议只 add 自己的文件（归协调提醒各车道）。

## 待交叉核查

- cc 写的天启篇战斗（新机制接线）→ co 甲档核：`modes/xiyou/core/tianqi_horsemen.gd`（未动 battle_logic 等核心文件）、`horsemen.json`、`tests/xiyou_tianqi_horsemen_battle.gd`

## 验证

- 语法检查：通过（876 个 .gd，0 问题）
- 专项：`xiyou_tianqi_horsemen_battle` 通过；反向验证 11 项改坏全部咬住（名字写死、出场顺序反、A 改随机、B 只打一人、C 可能同一人、回合末仍给不服、C 不加削伤、重混不空回合、只按位置先后、影子仍有小弟位、嘲讽不挡群攻）
- 选测（`选测.py main --list` 列出 20 个）：本机跑 15 个全过——xiyou_fabao_rework、xiyou_tianqi_death、_elements、_ending、_famine、_horsemen、_look、_plague、_qiyin_endgame、_rewards、_sect_b、_seg_alien、_summit、_war、_weak_clear；`xiyou_event_compare` a～d 四份没跑：本单只改天启篇骑士战（只在 `XTianqiHorsemen.prepare` 后才生效），不碰地图事件，建议合并时 `--affected --cloud` 带上
- `天启篇数据校验.py --params`：horsemen.json 规则自检、对照参数.json 都通过
- 工具回归：全部通过
- 不跑 `--oracle`：没碰原版移植来的底层公式（只改天启篇骑士模块和它的数据表、测试）

## 本分支提交

- 见 `git log main..cc/hunzi-minions`

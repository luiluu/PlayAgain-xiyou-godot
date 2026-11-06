# 交付：cc/wukong-newsrc7

- 车道／工作者：CX C 规则续（换源 v0.62.12；cc，悟空）
- 状态：**完成，可交总装合集成分支**（不合 main）
- 基线：从 `cc/newsrc-switch` 451012b6 切出；工作树 `.claude/worktrees/amazing-moser-37b7ce`。产物 `generated/` 取集成分支工作树那份（新源参照），再用 `xiyou_export.py --app …/冻结正式源/v0.62.12/app.nw` 重出、`godot --import`。跑测试设 `XIYOU_APP=…/冻结正式源/v0.62.12/app.nw`、`XIYOU_SKIP_GENERATED_CHECK=1`（本树产物是新源的，跟主工作区比必然不同）。
- 注：本分支的 `xiyou_export.py` 还不认 `XIYOU_APP`（那是 main 上 tools80 才加的），重出时要显式传 `--app`，否则会按 v0.28 出。

## 先分类（派单 ① 那 9 个）

| 场景 | 451012b6 本机 | 类别 | 处理 |
|---|---|---|---|
| weak_challenge、honghuang_reward、unlock_chain×4、cat_help | 全过 | 27ccba6a 之后集成分支已追平 | 不用动 |
| equipment | 13 条挂 | 新源新增机制 2 个 | 照原版做（带开关） |
| reincarnation_entry | 3 条挂 | 夹具还是 v0.28（新源角色多一个，8105 知者 166→167） | 夹具按新源重出 |
| alien_affix | 4 条挂 | **原版代码错误**（流萤遮住 setHp 包装） | 开关修，参照照原版比 |
| yunshang p8.clear | `xiyou_yunshang` 里本来就不比（p8 交给 `xiyou_yunshang_shop`），所以新旧参照都「过」 | 在 `yunshang_shop` 里真挂 8 条：新源数值＋新增 1 处 | 照原版做（带开关） |
| （顺带）guyu_battle | 2 条挂（失败表归 rules） | 同 alien_affix 的原版错误 | 同一开关，参照照原版比 |

新机制一共 3 个（专武不当词缀、符文之语挂起、胜利补记订单回合），没有超过 3 个。

## 变更记录草稿

## 2026-11-06 【cc·悟空·未经审查】换源集成：真气 v0.45 开关、装备词条与符文之语、流萤遮住 setHp、云裳天丝（dev.待定）

- ⓪ 真气 v0.45 回退开关 `XZhenqi.V045`（默认 true，**O-待定·真气 v0.45**）：false 时五条都回到 v0.28——神兵之仙不按类去重也不分页（菜单按序号 k）、神兵试炼照常记真气、经验金钱不清零、灵根不认 `<CodexZhenqiLinggen>`、指定道法不保留掷出结果也没有「稍后再选」。v0.28 的函数原样留在 `zhenqi.gd` 末尾（`_weapon_masters_v028` 等 6 个，取自 d1b41749）。幻化之战清物品两版都有，不受开关管。
- 装备词条（跟到 v0.62.12 `installIntegratedV029Runtime.js` exclusiveAffix，v0.37／v0.56.01）：名字「天外天·」开头或备注带 `<req_actors:>` 的装备不再当随机词缀（`XGear.valid_affix`，`gear.gd` 和测试模式加速 `test_mode.gd` 两处）。开关 `XGear.EXCLUSIVE_V056`（**O-待定·专武不当词缀**）。原版另有读档把已掉落的专武前缀装备转回普通装备（`U.revertExclusiveAffixes`，v0.57），**没做**：重制存档里有没有这种装备要看玩家，留给下一单定要不要做。
- 符文之语挂起（跟到 v0.62.12 `installNativeRunewordRuntime.js` RW.decide／canGrow，用户 2026-10-27 在原版定）：刚做成的配方若是更长配方的开头、剩余孔位还够镶完，先挂起（`runewordPending` 随装备存档），下一颗没接上或孔用完时再结算。开关 `XRunewords.PENDING_V062`（**O-待定·符文之语挂起**）。原版读档补匹配（RW.catchUp）重制本来就没有，没做。
- 流萤遮住角色 setHp（**原版代码错误**，**O-待定·流萤遮住角色 setHp**）：v0.62.12 `installLiuyingRuntime.js`（模块 33）在 `Game_Actor.prototype` 上另定义了 `setHp`，此后装在 `Game_BattlerBase.prototype.setHp` 上的包装——异化 Runtime（35）、异化 Advanced（37：生命池／嫁祸／空壳／舍身／绝缘）、谷雨（40：归根中抬不起生命）、护盾账本（41）——对角色全都走不到。`XResourceContext.o_actor_sethp_wrappers` 默认 true＝照旧对角色生效（加流萤之前的行为）；false＝照原版跳过。alien_affix、guyu_battle 按 false 比新参照，另加默认值的断言。
- 云裳（跟到 v0.62.12 `installNativeYunshangRuntime.js`）：不朽天丝每场 1→2 份（天丝成锦偶数次多给的也 1→2）；胜利时补记最后没走完的回合的订单进度（v0.49，一击结束的战斗也算 1 格）。开关 `XYunshangOrders.V062`（**O-待定·云裳天丝与订单回合**）。
- reincarnation_entry 夹具按 v0.62.12 重跑 `reincarnation_entry_probe.cjs` 换掉（只有 sourceIdentity 和 8105 知者数 166→167 变）。

## 结果（本机，新源）

| 场景 | 前 | 后 |
|---|---|---|
| equipment | 挂 13 | 全过（含新增 5 条：两个开关两头＋单颗符文挂起） |
| reincarnation_entry | 56/59 | 59/59 |
| alien_affix | 2113/2117 | 全过（含新增 2 条默认值断言） |
| guyu_battle | 1635/1637 | 全过（含新增 `oliuying.rooted_sethp_blocked`） |
| yunshang_shop | 挂 8 | 全过（含新增 `p8.clear.v028`） |
| zhenqi_break／zhenqi_daofa | 85/85、69/69 | 全过（含新增 `v028_daofa_no_keep`、`v028_weapon_menu`、`v028_weapon_exp_gold`） |

## 验证

- 语法检查 0 问题。
- 本机：上表；另跑 test_mode、gear_ui、orb_ui、shield_ledger、alien_battle、binding、state_operation、yunshang_ui 全过；item_marks（3 条，界面车道 Safe Sell）、zhenqi 6 条 `page.*`（界面车道）本来就挂，没变。
- 云端选测（提交 06e93d54，基准 451012b6，149 个场景，[运行页](https://github.com/luiluu/PlayAgain-xiyou-godot/actions/runs/42213100259)）：126 过，23 挂。挂的 23 个都在集成分支失败表里、归别的车道，通过数和表里相同或更好：custom_params 159/160（表 158）、script 25/26（表 24）、param_states 581/582、wtype 17366/17367、floor_odds 173/185、floor_reach109 367/443、help_card 1057/1073、state_effects 29958/30133，其余与表同数（enemy_book、event_compare、floor_reach004／107、gear_search、guide、hangup_auto、item_marks、life_steal、power、qiyu、skill_mastery、state_effects_tp）；weapon_unleash 953/963（归 rules-newsrc2）；zhenqi 6 条 `page.*`（归界面 CV）。本单动过的 equipment、reincarnation_entry、alien_affix、guyu_battle、yunshang_shop、zhenqi_break、zhenqi_daofa、test_mode 云端全过。
- 工具回归：只挂「探针登记检查」3 条（module_equipment_view、recover_permanent 没登记，death_admission 没关五乘区），都不是本分支的文件，集成分支上原样就有。
- `事件空绿扫描.py --check` 不过：4747 条「在 event_states.json 里但预设已删（产物过期）」，跟 newsrc6 交付时同类（4739 条）。本树的事件状态产物落后，本分支没碰预设和事件，请总装在集成分支同步后再看。

## 交接板

- 下一步：专武前缀装备读档还原（v0.57 revertExclusiveAffixes）要不要做，待定；power、gear_search 等穿透口径；敌人复活、weapon_unleash 归规则车道。
- 需要用户决定：五个 O-待定开关的默认值（都按「跟原版新行为／修原版错误」开着）。
- 用户试玩说明：无（集成分支）。

## 进度账

- 无变化。

## 可回退

- `XZhenqi.V045`、`XGear.EXCLUSIVE_V056`、`XRunewords.PENDING_V062`、`XResourceContext.o_actor_sethp_wrappers`、`XYunshangOrders.V062`：都是 static var，测试里两头都有字面量赋值。

## 待交叉核查

- `zhenqi.gd`（开关分支与 v0.28 函数）、`gear.gd`、`test_mode.gd`、`runewords.gd`、`resource_context.gd`（原沙僧核心文件之外，但 setHp 是战斗核心，请甲档细核）、`yunshang_orders.gd`；测试 `xiyou_zhenqi_break`、`xiyou_zhenqi_daofa`、`xiyou_equipment`、`xiyou_alien_affix`、`xiyou_guyu_battle`、`xiyou_yunshang_shop`；夹具 `reincarnation_entry_oracle.json`。

## 本分支提交

- `git log 451012b6..cc/wukong-newsrc7`

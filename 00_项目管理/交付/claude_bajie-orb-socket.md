# 交付：claude/bajie-orb-socket

- 车道／工作者：B 界面·宝珠镶嵌／八戒（Claude，重制_八戒_10）
- 状态：进行中——功能与文档都已提交，只差交付前全量检查（唐僧_3 因周额度 98% 叫停，Claude 停在这里，供沙僧接力）。
  - 已做：合并 main（9454d5d，PROBES 中 orb_probe 与 shared_system_probe 两行都保留）→ `新建工作树.sh --补齐` 通过 → worktree 里 `同步正式西游.py` 结果「测量不变」（orbs.json 早已在 generated/oracle）→ `检查.sh --oracle` 的「文档与登记」一段通过，Godot 测试段跑到一半被停。
  - 合并 main 前已过的专项：xiyou_orbs 62/62、xiyou_orb_ui 39/39，以及 xiyou_battle/combat/power/equipment/formulas/rules（50,912）/smart_ai（18,063）/panels/status/gear*/otb/action_sequence/item*/shop_buy/help_card/party/settlement/review_regressions/ui_smoke 全部通过。
  - 接力下一步：在本工作树跑 `zsh 03_再刷重制_Godot/07_开发环境/检查.sh --oracle`；全过后把下面「验证」行补上结果、本行改「可合并」并提交（执行者 Codex（沙僧）、核查 待Claude）。若有失败，先看是否与 traits_pi 加算（battler.gd）或物品页孔行（item_scene.gd、xiyou_gear_ui）有关。
- 提醒唐僧：开工时交接板车道表还没有本车道一行（B 界面行写着「八戒_9 已结束」），请补登：.claude/worktrees/bajie-orb-socket／claude/bajie-orb-socket，预分配 O-042～O-044（本轮未用）。
- 合并时注意：`dev.待定` 除变更记录外还在 `03_再刷重制_Godot/00_设计/框架维护约定.md`（2 处）与 `界面风格.md`（1 处），合并工具目前只替换变更记录里的占位，需手动换。
- 本分支改了参照探针（新增 `orb_probe.cjs`，接进 `同步正式西游.py` PROBES），合并后 main 要跑一次同步：测量变化应只有新增的 `orbs.json`。

## 变更记录草稿

## 2026-10-16 【Claude·八戒·未经Codex检验】宝珠镶嵌：孔数、可镶、镶嵌效果、同类上限、套装与物品页界面；特性倍率改为 CP_StateFloor 加算（dev.待定）

- 规则（严格级）：新增 `core/orbs.gd`（XOrbs），照正式 installNativeOrbRuntime v2＋YEP_X_AttachAugments＋Star_EquipmentMosaic。装备实例在 `XState.register_gear` 时按存档种子 `orb_seed`（新游戏随机，随存档保存；没有种子的旧档按存档内容算出固定值）＋实例编号的 32 位哈希排孔：武器、副手、神武（etype 1/2/17）0～3 个「武器宝珠」孔（15/35/35/15），其余 0～2 个「防具宝珠」孔（35/45/20）。照搬两处正式细节：获得时实例尚未放进数据库，无类型武器（wtypeId 0）的哈希键用 a＋编号；<继承词缀> 的标签正则带 g 标志跨行续用 lastIndex（紧接命中的下一行通常落空）。
- 可镶：只列注明了这种孔的物品（按 ID），新宝珠只能镶自己的孔类型、同一件装备同类只能一颗（另一孔已有同类则灰显，替换本孔同类可以）；原作宝珠不查；孔里有宝珠时首行「取下镶嵌物」。镶嵌／替换／取下执行宝珠备注的效果行：Element Amplify（装备元素增幅）、参数 ±x%（特性 21／XPARAM 22／SPARAM 23）、参数 ±x（装备属性），卸下行按 reverseAugmentAutoLine 反转；数据未用的其余 YEP 效果行未移植。新宝珠特性带「类:阶」标记，`XActor.all_traits` 去掉同类超过 3 件时低阶（同阶按装备栏靠前优先）的标记特性。套装：全身集齐 2／3 种组件按最低阶，通用效果只取最高一套，`XDamage.orb_set_multiplier` 乘进 terminal（技能含普通攻击；恢复类不受影响）。
- 修正（全局）：正式版 CP_StateFloor（State Added Type: true）把 MV traitsPi 改成加算 1＋Σ(值−1)（小于 0 取 0），Godot `XBattler.traits_pi` 原是连乘——同类多条能力值比率（如两件装备各 +x% 攻击）此前算多了。改后战斗／能力／装备／智能 AI／规则等 18 个相关测试全部通过（xiyou_rules 50,912 项、smart_ai 18,063 项不变）。
- 界面（标准级，正式 v0.28 浏览器读数 `tests/fixtures/orb_ui_oracle.json`，截图 `04_验证/本地结果/原版参照/宝珠镶嵌/`，Godot 对照截图在其 `godot/` 子目录）：物品页装备操作菜单「使用、升级、每孔一行、出售锁定、取消」，孔行 `\c[16]孔类型:\c[0] 宝珠／- 空 -`；确定打开宝珠列表（占列表位置 (0,172,640,548)，行同物品页，不可选半透明、确定蜂鸣，取下行图标 1348＋文字 x 36，选中取下行不显示说明卡），确定即镶嵌（装备音效）回到操作菜单原行；信息窗插槽信息后画「镶嵌物」（x −32 宽 600 居中、系统色）与每孔一行（x 226）；装备页信息窗同样画（正式版同一个 Window_ItemInfo）。取了武器 3 孔（一孔已镶）、副手 2 空孔、神武 1 孔已镶、防具 0 孔、防具 2 孔都镶五种。
- 参照：`mv_oracle/orb_probe.cjs`（接进同步 PROBES，输出 orbs.json）：6 个种子 × 武器/防具 × 64 个编号的孔数、21 种装备类型的孔类型、28 件获得即排孔、4 组可镶列表、19 例镶嵌／替换／取下／错孔（属性、特性与标记、元素增幅、meta、背包数量、提示）、5 组角色同类上限（保留特性、能力值比率、XPARAM、套装、伤害 terminal）。
- 验证：`tests/xiyou_orbs` 62/62、`tests/xiyou_orb_ui` 39/39；`xiyou_gear_ui` 操作菜单期望加孔行（46/46）；检查.sh --oracle 待接力者补（合并 main 后 同步正式西游.py 测量不变）。
- 提交：e128fb5、1349ce9、363bcef、ea0447b、a628723、3032084、0375a74 及合并 main（d04bb9a、9454d5d）。
- 未完成／已知问题：宝珠来源（副本 Boss 神秘珠掉落、宝珠坊鉴定／残片兑换／分解／暂存）未移植，测试里直接给宝珠，所以玩家当前拿不到新宝珠；原作宝珠靠 <继承词缀> 的 ShareLearnSkill（Star_SkilsShare 共享学技能）未移植，镶上只记标签不出技能；旧档孔位重排（layoutAll 退珠）Godot 不需要（从来没有旧孔位）；套装技能专属加成数据全为空未接；同类上限只管特性（正式版同样不管元素增幅；武器孔每人最多 3 件，实际不会超出，所以不登记优化）。

## 交接板

- 下一步（第 5 项「逐页复现原版界面」）：把「宝珠镶嵌（按实例随机插槽数）」改为「宝珠镶嵌已做（dev.待定：孔数/可镶/效果/同类上限/套装与物品页界面；宝珠坊与神秘珠掉落未做，玩家暂时拿不到新宝珠）」；宝珠坊（鉴定、残片兑换、分解、暂存、套装图谱）可作为下一项界面＋规则任务，需要 installNativeOrbRuntime 的 roll 流与 CE1439 bossReward 掉落。
- 第 6 项「特殊角色、法宝、宝珠机制随内容接入」里的宝珠改为「宝珠镶嵌已接，宝珠坊未接」。
- 待交叉核查加一行：claude/bajie-orb-socket 各提交及合并提交（dev.待定），Claude（八戒、唐僧），宝珠镶嵌规则与界面、traits_pi 加算修正；装备系统 60%→68% 初值。请沙僧特别复核 traits_pi 全局改动。
- 用户试玩说明：物品页选武器或防具，操作菜单多出宝珠孔（每件装备 0～3 个，读档不变），可以把背包里的宝珠镶进去、替换或取下，效果立即算进能力；集齐宝珠套装组件时全部伤害提高。目前游戏里还拿不到新宝珠（宝珠坊未做）。
- 需要用户决定：无新增。

## 进度账

- 装备系统：60% → 68%（权重 4，+0.32；宝珠镶嵌规则与界面完成，宝珠坊/神秘珠、法宝成长/唤醒、制作仍未做）。合计原始 22.67%＋0.32 ≈ 22.99%（显示 23.0%），初值待 Codex 复核。

## 本分支提交

- e128fb5 车道开工，建交付单
- 1349ce9 宝珠镶嵌规则 XOrbs 与正式参照 orb_probe；特性连乘改为 CP_StateFloor 加算
- 363bcef 补宝珠脚本 uid
- ea0447b 物品页宝珠镶嵌界面与正式读数夹具 orb_ui_oracle
- a628723 宝珠套装通用效果接进伤害结算
- 3032084 框架维护约定、界面风格补宝珠镶嵌与特性加算
- 0375a74 镶嵌/取下后穿着者 HP/MP 不超过新上限
- d04bb9a、9454d5d 合并 main

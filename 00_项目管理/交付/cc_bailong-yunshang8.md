# 交付：cc/bailong-yunshang8

- 车道／工作者：E 角色专属／白龙_11（cc）
- 状态：可合并
- 分支从 cc/bailong-yunshang7 末端 193233e4 切出（总装十派单），**包含 yunshang7（与 4、6）**，那几张交付单照它们自己的合。还没合 main（第六批进 main 后总装通知再合）。
- 范围：云裳天衣铺一期——首页与「配置天衣神纹」三项（借用技能、针眼、元素组），设置进存档。制作、领取、角色进阶下一期（盘点见文末）。

## 变更记录草稿

## 2026-11-01 【cc·白龙_11·未经审查】云裳天衣铺一期：配置天衣神纹（dev.待定）

照原版 installNativeYunshangRuntime.js 第 519～533、554 行（Scene_Yunshang、Y.openCrafting）：

1. **入口**：天衣铺技能 10287（技能菜单被动栏）→公共事件 9011 `CodexYunshang.openCrafting()`：云裳在队、20 级以上时打开 `XYunshangShop`（`map_scene.open_yunshang_shop`），不够照旧提示。
2. **首页**：说明 4 行（「天衣铺　云裳 N级　进阶x/2　不朽天丝 n」「当前没有制作订单」与两行规则）＋制作天衣　不朽天丝×15、领取已完成的天衣、角色进阶、配置天衣神纹、返回；取消＝返回。**制作、领取、角色进阶一期灰显**（原版制作 35 级起、进阶够等级时能选），下一期接。
3. **配置天衣神纹**：先选穿天衣的队员（「名字｜天衣名」，全部队员）；再按天衣——空袖藏星选 3 个借用技能（队员会的可借技能「主人：技能」，说明「选择借用技能 n/3（首个为常驻）」，选过的不再列）、九曲回针选针眼（编号在山河击之前、不是不能用、名字不含唤醒／复活／制作／进阶）、七曜流霞选 3 个元素（物理与治疗不列，首个为当前元素）；别的天衣提示「这件天衣无需战前配置」。任何一步取消回首页、什么都不改。窗口沿用一期的 `XYunChoicesWindow`（这回用上说明行）。
4. **设置进存档**：`XYunshang.setting(a)` 改成按身上那件天衣存（原版 a._yunSettings[_yunUid 或 native:id]），放在 `flags._yunSettings[角色号][天衣]`，随存档走；读档后数字是浮点，用到的地方都取 int（七曜元素组补了一处）。
- 参照：`yunshang_probe.cjs` 加 p7.shop——拦 SceneManager.push 拿到闭包里的 Scene_Yunshang，建不进场景树的实例，逐页读 Window_YunChoices 的说明行与各行、选一项照 Window_Command 调 'choose' 处理器，记各步设置。新专项 `xiyou_yunshang_shop`。

## 优化登记草稿

无（针眼候选里「有冷却」那条在原版恒真——YEP_X_SkillCooldowns 给每个技能都建了 `cooldown = {}`——照抄，没冷却的技能也列出；见「可优化」）。

## 验证

- 新专项 xiyou_yunshang_shop 42/42：照 p7.shop 走 15 步，每页比说明行、各行文字与能不能选（首页前三行一期灰显，只比文字），选完比设置，寸光留仙的提示；再存档→清掉内存里的设置→读档，三件天衣的设置都回来，读档后空袖藏星的借用技能（万剑诀）照样在云裳的技能里。
- 反向验证 6 处全抓到：借用不去掉选过的、元素不去掉治疗、首页说明文字、取消也存、不提示、当前元素取末个。
- xiyou_yunshang 1576/1576（covers_all 算上 p7）、xiyou_yunshang_ui 照旧。语法检查通过。
- 选测（CHECK_JOBS=3，22 个场景写全名，18 分钟）全过、没有偶发：xiyou_yunshang、xiyou_yunshang_ui、xiyou_yunshang_shop、xiyou_autosave、xiyou_battleback_save、xiyou_save_events、xiyou_save_page、xiyou_common_scripts、xiyou_script、xiyou_panels、xiyou_options_basic、xiyou_options_misc、xiyou_race_menu、xiyou_power_books_menu、xiyou_help_card、xiyou_battle_ui、xiyou_battle、xiyou_smart_ai、xiyou_smart_ai_b、xiyou_smart_ai_c、xiyou_smart_ai_d、xiyou_actor_modules。

## 交接板

- 下一步：云裳天衣铺二期——制作、领取、角色进阶（见下面盘点）。
- 用户试玩说明：云裳的天衣铺能打开了（技能菜单被动栏的「天衣铺」）：可以给空袖藏星选借用技能、给九曲回针选针眼、给七曜流霞选元素，存档后还在。制作、领取、进阶这次还是灰的。
- 需要用户决定：无新增。

## 进度账

- 角色与专属机制：云裳完成度 0.9 → 0.93（天衣铺配置；剩制作、领取、进阶），按工作量估。

## 可优化（流程／工具／效率）

- 发现（原版写法）：九曲回针选针眼时原版想只列有冷却的技能（`s.cooldown`），可 YEP_X_SkillCooldowns 给每个技能都建了 `cooldown` 对象，条件恒真，没冷却的技能也能选成针眼（选了也没用）。照抄没改；要改成只列有冷却的，建议用户定。
- 发现（工具，已做）：闭包里的原版场景类（Scene_Yunshang 这类）可以拦 `SceneManager.push` 拿到构造函数，`Object.create(C.prototype)` 补空 `addWindow`／`popScene`，不建窗口树也能逐页量（p7.shop）。

## 待交叉核查

- `core/yunshang.gd`：`setting` 改存 flags（按天衣）；`split` 元素组取 int。新文件 `ui/yunshang_shop.gd`。`map/mv_script.gd` 天衣铺打开页面一处；`map/map_scene.gd` 加 `open_yunshang_shop`。
- 留意：原版设置挂在角色上、按天衣 uid 分开，换回同一件天衣时设置还在；重制同样按 instanceId（原生天衣按 native:编号）。没穿天衣时原版 key 是 "undefined"，重制同。

## 天衣铺二期盘点

1. **订单账本**（第 102～200 行）：独立文件 `yunshang_orders_v1.json`（同步已登记 EVENT_LEDGERS），profile／replay／transaction／journal；Y.pool（按等级、进阶开放的天衣）、Y.submit（扣不朽天丝 15，开工时定属性与词条）、Y.progress（每场战斗每回合 token 记 1 格，满 10；在 endTurn 包装里调）、Y.claim（发天衣，带 _yunUid）。首页订单行「制作中：名字　n/10回合」。
2. **角色进阶**：C.advance＝[{35 级、天衣 3 件、人道意志碎片 50}, {50 级、天衣 9 件、碎片 188}]；Y.advanceRequirements 的提示文字、Y.advance(selected) 选要消耗的天衣，原版进 Scene_ActorAdvanced。重制进阶次数用存档里的 XAdvance.rank（一期定），账本里的进阶要对上。
3. 首页出错时的兜底页（「制作记录暂不可用，请恢复配套记录后重试」）、天衣图标（Yunshang_Icons）、织神天梭升级经验（relicNextLevelExp、relicDisplayParams）、Y.equipmentCap。

## 本分支提交

- 30aa25c5 天衣铺一期、参照 p7.shop、专项 42/42（WIP）
- 本提交：选测全过，交付单可合并

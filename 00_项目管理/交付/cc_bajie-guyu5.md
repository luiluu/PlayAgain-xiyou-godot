# 交付：cc/bajie-guyu5

- 车道／工作者：C 规则＋B 界面小件（总装十派给八戒）／八戒（cc，八戒）
- 状态：可合并
- 分支从 cc/bajie-guyu4 末端 42211124 切，工作树 `.claude/worktrees/ecstatic-archimedes-4ef973`。要先合 guyu4（本分支含它的全部提交）。

## 变更记录草稿

## 2026-11-01 【cc·八戒·未经审查】谷雨 itemEva／itemCri 包装、站姿归一补谷雨的档（dev.待定）

- 审查第 18 期 P3③：原版 `installNativeGuyuRuntime.js` 315 行是 itemHit、itemEva、itemCri 三个一起包，绽放、终结、治疗分别恒 1、0、0；重制原来只包了 itemHit。补上 `item_eva` 首行、并把 `_apply` 里的暴击率抽成 `item_cri`（甚尔、哈基米、云裳三个包装原样搬进去，谷雨在最外层）。西游的闪避公式是 0、这三个技能原表不暴击，所以平常本来就是 0，这一项只防别的来源加上去；结算次序与随机数抽取次数不变。
- 「CodexSV 新角色立绘归一」：悟空 battlelog3（dev.257）的战斗站姿归一就是这一处（`XAppearance.profile`、`XBattlerSprite._place_body`），guyu4 交付单里「重制按 0.75、都偏大」是我在合 main 之前查的，已过时，撤回那条建议。但那张表少了谷雨：原版的谷雨档不在 Codex_MiraRavenMultiFrame 的 normProfiles 里，是 `installNativeGuyuRuntime` 的 installVisualHooks 开机时登记进同一张表（160×160，可见 [23,45,137,145]）；重制没登记就走 inferProfile 量图，量成 [52,45,137,145]，缩放一样（0.72），左右偏约 10px。补进 `appearance.gd` 的 PROFILES。菜单头像、图鉴大图不归这张表管，没动。
- 归根反馈画在身体原点（站姿归一后原点就是可见脚底中点，同原版），去掉 guyu4 里按未归一图算的偏移。
- 改了原沙僧独占的核心文件：`battle_logic.gd`（item_eva 首行、item_cri 抽出），请重点核；`appearance.gd` 是悟空 battlelog3 的文件，只加一行档。
- 验证：见下。

## 交接板

- 下一步：谷雨这一摊做完。
- 用户试玩说明：谷雨在战斗里的站位和原版一样了（之前略偏左右）；其余看不出变化。
- 需要用户决定：无。

## 进度账

- 谷雨 175：命中三包装补齐、站姿档补齐；无别的遗留。

## 验证

- 专项：`xiyou_guyu_battle` 1528/1528（新加 local.sure_10288／10292／10299：闪避公式改成 1、技能复制改成会暴击，照样不闪避不暴击；对照普攻照常闪避、暴击）；`xiyou_guyu_ui` 791/791（新加 scene.guyu_profile）。
- 反向：去掉 itemEva／itemCri 两个包装 → local.sure_* 三条都抓到（闪避 1、暴击 0.19）；去掉 Codex_Guyu 档 → scene.guyu_profile 抓到（量成 [52,45,137,145]）。
- 选测 17 个（CHECK_JOBS=3）：xiyou_guyu、xiyou_guyu_battle、xiyou_guyu_ui、xiyou_actor_looks、xiyou_appearance、xiyou_battle_ui、xiyou_sequence_visual、xiyou_cat、xiyou_toji_battle、xiyou_yunshang、xiyou_battle、xiyou_event_compare（必跑）、xiyou_rules.tscn、xiyou_rules_d1b、xiyou_rules_d1c、xiyou_rules_d1d 共 16 个通过；xiyou_determinism 仍是 early_inventory_rule 那一条（总装十说已在 main 第六批收尾里修了测试，本分支还没合到）。
- `语法检查.py` 0 个问题。没改切片、转换器、探针，不用同步。

## 可优化（流程／工具／效率）

- 无。

## 本分支提交

- 46b92291 谷雨 itemEva／itemCri 包装＋专项反向；Codex_Guyu 档；归根反馈原点
- 专项加站姿档断言（反向抓到）
- 交付单（本提交）

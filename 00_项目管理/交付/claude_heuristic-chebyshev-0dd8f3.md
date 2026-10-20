# 交付：claude/heuristic-chebyshev-0dd8f3

- 车道／工作者：B 养成／八戒（Claude，重制_八戒_34）
- 状态：进行中

## 变更记录草稿

## 2026-10-20 【Claude·八戒·未经Codex检验】成就系统首期（dev.待定）

- 原版查明（冻结 v0.28）：`Star_AchievementSystem`（122 条参数成就＋`installWeakChallengeRuntime` 注册 142「本质高手」＋`installKyoAchievementRuntime` 注册 143「kyo专属」，共 124 条；8 类）、`Star_AchievementShowPic`（获得弹窗）。124 条全都没有物品／装备／脚本奖励，「获得称号…」只是说明文字。记录分两层：全局 `ConfigManager.SAchievementS`（ID→true、`<ID>Time` 首次完成时间，所有存档共用）与本局 `$gameParty.SAchievementS`。`GetAcReward(N)`：本局已有就跳过，否则记全局（时间只记第一次）、记本局、弹窗。17 张物品清单在 `gainItem` 里自动达成 104～119。事件里 626 处调用全是 `Star.AchievementSystem.GetAcReward(N)` 一种写法；主菜单「成就」是公共事件 431 `SceneManager.push(Scene_AchievementBook)`。
- 参照：新探针 `03_转换工具/mv_oracle/achievement_probe.cjs`（已加进 `同步正式西游.py` PROBES，产物 `achievements.json`）：定义表、物品清单、类型表、GetAcReward 七步（首次、重复、新开局补记、多条）、配置存取、160 次物品得失（含 CodexEconomy 改记后的判定）、全局有本局无时得物品、143 未开测试模式、弹窗六连位置、成就界面三窗口矩形与行高、8 类列表、逐项绘制调用、确定／取消后的状态。
- Godot：`XAchievement`（核心，定义从 Plugins.json 读）、`XConfig` 新增 `SAchievementS`（`achievements()`／`save_achievements()`）、`XState.achievements`（随存档，读旧档为空）与 `gain_item` 里的物品判定；`MVScript` 认 `GetAcReward(N)` 与 `SceneManager.push(Scene_AchievementBook)`（地图 host 新增 `open_achievements`）；`XAchievementScene` 成就界面（类型窗 0,0,320,648 行高 72；列表窗 320,0,960,720 行高 108、一页 6 项；计数窗 0,656,320,64；未得只写「未获得」）；`XAchievementPopup` 获得弹窗（300×50，x 485、y 480 起往下叠 60，30 帧淡入、停 300 帧、30 帧上移淡出，音效 Saint5；菜单类画面里框与底 30）；主菜单「成就」可用（预约公共事件 431，关闭回地图）。
- 优化 O-076（待用户决定，可回退）：① 失去物品不再触发成就（原版 gainItem 负数也触发）；② 魂灯 184～187 改记成 188 前也判定，108～111 可正常拿到（原版只会给 112）；③ 达成即写配置（原版要等设置等页面关闭才写盘，中途退出就丢）；④ 十二层两张图的守层者（Map023 事件 1、Map065 事件 2）原版给的是 13「十三层通关」，改给 12。开关 `XAchievement.GAIN_ONLY`／`BEFORE_REDIRECT`／`SAVE_NOW`／`FLOOR12_FIX`。
- 验证：新测试 `tests/xiyou_achievement`（与参照逐项比对＋O-076 各项单独核对＋事件里每种成就脚本都认得＋存读档与配置写盘＋十二层改号）；原版界面截图（ui_reference，挑战页、事件页滚动、弹窗）与 Godot 截图对照，窗口、行位置、图标、文字、光标、滚动箭头、计数一致；`xiyou_script` 的「认不出的脚本」样例从 GetAcReward 换成虚构语句。检查.sh --oracle：待写
- 按已开放内容能触发：72 条有事件来源在已转换地图或公共事件里（神魔之塔 1～11、13～19 层，26～30、33、35～37、39～42、47 副本，51～54、57～62、70、73、74、77～82、84、87、90、96、101～103、121、122、127、129～139），加上物品达成 104～119（看对应物品能否拿到）。
- 触发不到（登记）：12、20 原版没有任何事件给（12 已由 O-076 ④ 补上，20 层喜乐天的守层者也不给 20，未改）；21～25（Map060／070 未转换）、31、34、38、43、45、46、55、63～66、71、72、75、76、85、86、92、93、95、120、123、125、126、128、140、141（所在地图未转换或原版无事件）；142 要混沌难度最终战；143 要测试模式（重制没有测试模式，只有全局已得时才照常记）。Map004 事件 55「全图鉴获取」是一次性给全部成就的调试事件，未计入。
- 未完成／已知问题：142、143 的专用徽章图（`img/codex_achievements/`）未转换，界面里按普通条目画（143 原版未得时画半透明徽章）；kyo 名牌渐变与弹窗徽章未做。

## 交接板

- 下一步：成就第二期可随楼层扩展补上未转换地图里的成就（见变更记录「触发不到」）；142／143 徽章图需转换器加 `img/codex_achievements/`。
- 用户试玩说明：主菜单「成就」可以打开成就界面；打倒守层者、使用指路灯等会弹出「获得新成就！」，得到药水、古董等物品会自动达成收集类成就。成就是所有存档共用的。
- 需要用户决定：O-076 四项（失去物品不触发、魂灯改记前也算、达成即写配置、十二层守层者给 12）是否保留。

## 进度账

- 成就：0% → 首期（核心、脚本、界面、弹窗）完成，按已开放内容验收

## 本分支提交

- 9ee21da 成就参照探针 achievement_probe
- 27bb303 成就核心、GetAcReward 翻译、弹窗与成就界面、测试
- b72d25e 弹窗照 MOG_MenuBackground；测试截图对照
- 8da55f1 O-076 登记、文档更新、成就脚本全识别测试
- （待写：十二层改号与收尾提交）

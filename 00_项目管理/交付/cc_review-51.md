# 交付：cc/review-51
- 状态：可合并
- 车道／工作者：cc（审查）

只有文档，没有游戏代码。

## 变更记录草稿

## 2026-11-07 【cc·审查】核查 11-07 夜里的存档、战斗规则、长任务、界面几批及 11-05～11-06 积压，补销审查 50 漏销的 15 批（审查第 51 期）

- 核查覆盖：cc/platform-fix2、cc/nezha-save1、cc/rules-bugfix1、cc/rules-bugfix2、cc/ui-battlefix1、cc/ui-input1、cc/nezha-tools81、cc/nezha-tools82、cc/bailong-ui11、cc/bajie-battlefx1、cc/platform-pc-android1、cc/platform-fix1、fb31ab0、cc/bajie-events13
- 核查覆盖（审查 50 已核、当时条目写了短名没销掉，见审查 50 报告）：cc/platform-android3、cc/bajie-events10、cc/wukong-newsrc1、cc/rules-ui16、cc/nezha-tools74、cc/platform-android4、cc/platform-keys3、cc/rules-ui17、cc/platform-release1、cc/platform-release2、cc/bajie-events11、cc/nezha-tools75、cc/nezha-tools71、cc/platform-shop1、cc/nezha-tools72
- 报告：`核查报告_20261107_审查第51期.md`。P1 0、P2 1、P3 2。
  - P2-1：O-221 的「开战前」检查点放在 `start_battle` 第一行，但随机遇敌、事件战斗、小猫试炼、真气瓶颈之战调它之前都置了 busy，`blocker` 一律返回 event，开战前一次都不存；专项只查源码文本。建议挪到 `_encounter()` 的 `_set_busy(true)` 之前，专项真走一次遇敌。
  - P3-1：百谷生招募不管开关都写 `_o137Dup`，跟着存档走。P3-2：`on_restrict` 调了「行动限制解除」换状态，注释和交付单说原版被锁挡住；数据里没有这个标签，无可见影响。
- 审查 50 P2-1（标题导出存档被存档键盖住）已由 platform-fix1 收。
- 甲档待核查 33 → 8（剩 newsrc3、version1、input-crash、size1、crash1、android6、tools1、meta1）。

## 已核／未核清单
已核：派单点名的 tonight 各批（platform-fix2 的 O-221、nezha-save1 的 O-222 与 write_text_safely、rules-bugfix1／2 的 O-219／220／223／224、tools81／82、ui-battlefix1、ui-input1），以及 bailong-ui11、bajie-battlefx1、platform-pc-android1、platform-fix1（含 fb31ab0）、bajie-events13。补销审查 50 已核的 15 批。
未核（甲 8）：cc/wukong-newsrc3、cc/platform-version1、cc/input-crash、cc/platform-size1、cc/platform-crash1、cc/platform-android6、cc/platform-tools1、cc/platform-meta1。ui-battlefix2 还没合进 main，不在本期。

## 交接板
- 下一步：P2-1 派平台车道：开战前检查点挪到 `map_scene._encounter()` 的 `_set_busy(true)` 之前，删掉 `start_battle` 第一行那次调用；`xiyou_pause_save` 换成真走一次遇敌的断言。顺手定挂机时每场都存要不要限频。P3-1、P3-2 交规则车道，随下一批顺手改。
- 需要用户决定：无。

## 待交叉核查
无（审查线程自己的文档分支）。

## 可优化
- `待核查.py` 只认 `cc/` 全名或提交号，审查 46～50 写的都是短名，靠标题里的 dev 号碰巧销账，审查 50 因此漏销 15 批，`检查.sh` 报了 33 批其实只有 21 批真没核。建议：`待核查.py` 对审查条目里出现、但没匹配到任何批的短分支名打一行警告（比如「审查条目写了 android4，没认出来，要写 cc/platform-android4」），或者把「- 核查覆盖：」行里不带前缀的名字按 `cc/` 补全再匹配。归工具车道。
- P2-1 这类「检查点有没有存」的测试，查源码文本测不出调用方的状态。凡是加在公共入口第一行、靠 blocker 过滤的逻辑，专项要从真实调用方走一次。

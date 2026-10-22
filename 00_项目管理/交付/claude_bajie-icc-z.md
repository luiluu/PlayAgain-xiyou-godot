# 交付：claude/bajie-icc-z

- 车道／工作者：B 界面／工具／八戒（Claude，重制_八戒_49）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】伪 PNG 转码输出稳定化；伤害数字压到窗口层之下（dev.待定）

- 转换器 `xiyou_export.py` 新增 `normalize_png`，`copy_assets` 里 sips 转出的伪 PNG（小诛仙、guanxi7_1 一类）转码后再正规化：只留 IHDR／PLTE／tRNS／IDAT／IEND 与颜色块 sRGB／gAMA／cHRM／iCCP，丢掉 tIME／eXIf／文本块；iCCP 的 ICC 头日期（24..36）清零并用固定参数重压，CRC 重算，IDAT 不动，像素与原转码一致。不加依赖（只用 zlib／struct）。
- 实测：本地 2×2 JPEG 与 1×1 WebP 夹具连跑两次 sips（隔 2 秒）字节相同——夹具里 sips 写的是 sRGB＋eXIf 而不是 iCCP，所以夹具复现不出日期；带内嵌 ICC 的真实原图才会有 iCCP 日期（沙僧核查所述）。因此正规化按「清 ICC 头日期＋丢 tIME／eXIf／文本」一并处理，单测用合成的带 tIME／iCCP 的 PNG 验证。
- 回归 `测试转换器写入.py` 新增两条：真调 sips、隔 1.2 秒两次导出输出字节相同；`normalize_png` 对两份仅 ICC 日期与 tIME 不同的 PNG 输出相同、只剩 IHDR／iCCP／IDAT／IEND。22 项全过。
- 战斗：伤害数字 `z_index` 20 → 常量 `POPUP_Z = 7`。原版弹出数加在 Spriteset_Battle 里（LGP_BetterDamagePopup.js:665 `BattleManager._spriteset.addChild`），Scene_Battle 先加 spriteset、后加 WindowLayer（rpg_scenes.js:2348–2350），所以原版数字在所有窗口之下。z 对照（调整前→后）：战斗图 0；敌人血条 5；伤害数字 20→7；行动顺序条／消息窗 8；帮助卡 10。数字仍在战斗图、血条、动画之上。`xiyou_battle_ui` 加断言 `popup_below_windows`（5 < POPUP_Z < 消息窗 z）。

## 交接板

- 下一步：无新增
- 用户试玩说明：战斗里伤害数字不会再盖在 101 消息窗上
- 需要用户决定：无

## 进度账

- 无变化（工具稳定性与界面小修，不动完成度）

## 验证

- `测试转换器写入.py` 22 项全过。
- 并行测试：xiyou_battle_ui 59/59、xiyou_drop_dh 12/12。
- 在工作树跑 `同步正式西游.py --accept-additions`：退出码 0，「测量不变」，探针 executed 11／reused 34。两张伪 PNG 的输出 SHA 是否变动未单独比对（generated 产物不入 Git）。

## 本分支提交

- 转换器：sips 伪 PNG 转码输出正规化
- 战斗：伤害数字 z 20→7（对齐原版 Spriteset 层级）

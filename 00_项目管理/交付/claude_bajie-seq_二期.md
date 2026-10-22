# 交付：claude/bajie-seq（二期：脚本正则缓存、转换器转码回归）

- 车道／工作者：B 界面·工具／八戒（Claude，八戒_46）
- 状态：可合并

## 变更记录草稿

## 2026-10-22 【Claude·八戒·未经Codex检验】事件脚本翻译正则静态缓存；转换器伪 PNG 转码补回归（dev.待定）

- 事件脚本翻译（`modes/xiyou/map/mv_script.gd`）：原来每条语句都把十几种写法的正则现编译一遍（全文件 28 处 `RegEx.create_from_string`），改成 `MVScript._re(模式)` 按模式串缓存在静态字典里，同一模式只编译一次；写法、匹配顺序不变。回归 `tests/xiyou_script` 17→19 项：多条语句连跑两遍，第二遍缓存不再增加、结果相同，同一模式取到同一个 RegEx。
- 转换器伪 PNG 转码（总装 0a5ec4c，后收窄为只认 JPEG／WebP 文件头）补回归：`07_开发环境/测试转换器写入.py` 新 `FakePngTranscodeTests`，夹具是真图 `07_开发环境/测试夹具/红色_2x2.jpg`（sips 生成）与 `1x1.webp`（1×1 无损 WebP）。验：扩展名 .png 的 JPEG、WebP 转成真 PNG（PNG 文件头、IHDR 宽高 2×2／1×1，manifest 输入记原文件摘要、输出记转换后摘要）；测试里的假字节图（`image-a` 等）、真 PNG、.jpg 原样复制且不调 sips；转码结果可重复，重跑写入 0。该类继承原写入生命周期 8 项，在有转码图时再跑一遍。8→20 项。
- 验证：`测试转换器写入.py` 20 项通过；`并行测试.py` 跑 `xiyou_script` 19、`xiyou_achievement`（50／34）、`xiyou_event_compare` 5、`xiyou_floor30_gifts` 30、`xiyou_opening_branches` 16、`xiyou_hud` 34、`xiyou_map` 175、`xiyou_dungeon` 6954、`xiyou_floor16_dungeon` 25、`xiyou_floor28_dungeon` 93，全过。没改切片、转换器本体、探针，不用重跑同步。
- 未完成：无。

## 交接板

- 下一步：无新增（性能小项与总装追加的转码回归已做）。
- 用户试玩说明：无可见变化。
- 需要用户决定：无

## 进度账

- 不加点（性能与测试）。

## 本分支提交

- 0f58f16 mv_script：正则按模式串静态缓存，补回归
- 35d6056 转换器：伪 PNG 转码补回归，真 JPEG／WebP 夹具，假图不转码
- 本交付单

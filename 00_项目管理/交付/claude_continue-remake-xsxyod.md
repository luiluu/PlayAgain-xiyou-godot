# 交付：claude/continue-remake-xsxyod

- 车道／工作者：云端小修（Claude 云端会话；不占本机车道名额，只改不在悟空、八戒独占文件里的代码）
- 状态：可合并

## 变更记录草稿

## 2026-10-18 【Claude·云端·未经Codex检验】云端审查遗留三处小修：代购显示、宝珠元素名增伤、地图动画目标（dev.待定）

- 来源：dev.082 云端代码审查「只记录、未修」里不在车道独占文件的四项。
- `ui/shop.gd` `_buy_data` 改用 `shop_rec`（装备带 kind/base）求显示记录；`XItemMarks.shop_display` 参数改成商品记录，返回表里的原始记录或其副本。防具 1991、2495～2520 与带 `<Proxy Buy>` 的物品同号时，不再显示代购物品的名字和图标（购买本来就对）。
- `core/orbs.gd` `effect`：Element Amplify 两种写法分开取组。元素号写法不变；元素名写法原来把数值当键、`%` 当数值（实际不生效），改为按 System.elements 名字（不分大小写）找元素号，找不到不生效。目前没有宝珠用名字写法。
- `battle/battler_sprite.gd`：场景外观子节点材质 main 已在 9509398 修好（本分支接到 main 后合并为同一写法）；这里只把 BODY_SHADER 抽成 `XBattlerSprite.body_shader()`，供地图角色共用。
- `map/map_scene.gd` `show_animation` 设 `MVAnimation.target`；`map/mv_character.gd` 补 `set_anim_blend`（身体材质染色，只作用在行走图上）与 `set_anim_hidden`（flashScope 3），气泡挪到单独子节点（MV 的 Sprite_Balloon 加在角色精灵的父节点上，不受闪光、隐藏影响）。地图动画的目标闪光与隐藏从此生效（原来是缺功能）。
- 测试：新 `tests/xiyou_review_fixes`（桩表，不依赖转换产物）16 项全过；改动前 7 项失败（商店列表名字、元素名增伤、子节点材质、地图目标等）。
- 验证：本分支已接到 Mac main（6915e2e，dev.088）上；云端用 Mac main 的转换产物（sync_stamp v0.28 测量不变）跑 `检查.sh`：Godot 测试 72/72 通过（`xiyou_review_fixes` 16/16），工具检查全过；只报云端缺本地文件的 49 条失效链接和本交付单两项（车道分支应有）。`--oracle` 未跑（云端没有冻结正式源）。
- `ui/gear_search.gd` 关闭也存排序未改：要对照原版，云端没有冻结正式源。

## 交接板

- 下一步：第 1 项「云端审查转来的小问题」里删掉八戒的 `battler_sprite._body_material`（main 已修）与 `show_animation` 两条，以及 `shop._buy_data`、`orbs` 两条；`gear_search` 那条保留。
- 用户试玩说明：地图上播放的技能动画，目标闪光、隐藏效果开始生效。
- 需要用户决定：无

## 进度账

- 不变（修复与缺功能补齐，量很小）。

## 本分支提交

- 见分支

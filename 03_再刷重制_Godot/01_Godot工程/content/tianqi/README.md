# 天启篇四线画面素材

游戏用的成品图，接入代码 `modes/xiyou/core/tianqi_look.gd`（`XTianqiLook`），用在选线竖卡（`ui/tianqi_line_cards.gd`）、大厅方桌裂纹（`map/tianqi_table.gd`）。
源文件在本机新美术目录（Git 排除，原稿不进仓库），这里只放游戏真正读的文件。回退开关见 `XTianqiLook` 头注释。

| 文件 | 美术编号与版本 | 尺寸 | 处理 |
| --- | --- | --- | --- |
| `knight_war.png` | T15 战争骑士·莉co 全身立绘 v1（`TianqiWar_v1/source/T15_war_knight_portrait_v1_1024x1536.png`） | 512×768 透明 | sips 缩一半 |
| `knight_death.png` | T13 死亡骑士·勇者 全身立绘 v1（`TianqiDeath_v1/source/T13_death_knight_portrait_v1_1024x1536.png`） | 512×768 透明 | 同上 |
| `knight_plague.png` | T16 瘟疫骑士·混子 全身立绘 v2（`TianqiPlague_v1/source/T16_plague_knight_portrait_v2_1024x1536.png`） | 512×768 透明 | 同上 |
| `knight_famine.png` | T14 饥荒骑士·小镇做题家 三阶全身立绘 v1（`TianqiFamine_v1/source/T14_famine_knight_portrait_v1_1024x1536.png`） | 512×768 透明 | 同上 |
| `mark_war.png` | O12 异化纹路·赤·裂痕（`TianqiGemini_v1/processed/12_异化纹路/02_赤_裂痕.png`） | 512×512 透明可平铺 | 原样拷贝 |
| `mark_death.png` | O12 异化纹路·灰白·断印灰痕（`04_灰白_断印灰痕.png`） | 512×512 透明可平铺 | 原样拷贝 |
| `mark_plague.png` | O12 异化纹路·白·菌丝（`01_白_菌丝.png`） | 512×512 透明可平铺 | 原样拷贝 |
| `mark_famine.png` | O12 异化纹路·黑·食痕（`03_黑_食痕.png`） | 512×512 透明可平铺 | 原样拷贝 |

- 四张立绘都还是待看稿：游戏里默认只取透明度画成本线颜色的剪影（设计稿「立绘画好之前用剪影」），`XTianqiLook.CARD_PORTRAIT = true` 才画原图。定稿后换同名文件。
- 纹路贴图是按旧稿「白、赤、黑、灰白」四色画的，v0.8 改成骑士主色后，游戏里只取亮度当遮罩、染成本线主色（`XTianqiLook.mark_material`）。

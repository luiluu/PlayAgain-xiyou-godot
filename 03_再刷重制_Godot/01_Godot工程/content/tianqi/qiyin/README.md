# 天启篇七印祭坛美术

2026-11-12 定稿的 26 项（美术交付清单报告、美术交接都在源目录里）。源文件在本机 `03_再刷重制_Godot/02_内容与素材/新美术/TianqiQiyin_v1/`（Git 排除，原稿不进仓库），这里只放游戏读的成品图。重出：`python3 03_再刷重制_Godot/03_转换工具/天启七印美术导出.py`（会自己解 zip，然后跑一次 `godot --import`）。

七印键：bai 白、hong 红、hei 黑、hui 灰、xun 殉、zhen 震、mo 默（`qiyin_show.json` seals 顺序，美术文件 01～07）。

| 目录／文件 | 美术编号 | 尺寸 | 处理 | 谁读 |
| --- | --- | --- | --- | --- |
| `battlers/Tianqi_Qiyin_Dragon.png`、`_<印>.png` | E1 七首之龙（躯干＋七首，同画布原位） | 512×464 | 2048 母版裁到基线 y1856，lanczos ×0.25 | `XTianqiQiyinArt`（断首藏头） |
| `battlers/Tianqi_Qiyin_WhiteSoul.png` | E2 白衣的魂 | 256×232 | 1024 母版裁到基线 y928，×0.25；`appearances.json` 藏影子 | 殉印里副本 Boss |
| `battlers/Tianqi_Qiyin_Silent.png`、`_lit.png` | E3 守默者 平时／香炉燃起 | 256×232 | 同上 | 默印里副本 Boss（单数回合燃起） |
| `seals/<印>.png` | S1 七印徽记（亮态） | 256×256 | 原样 | `XTianqiQiyinShow`（掉落、揭开） |
| `artifacts/<神器键>.png` | P1～P5 神器掉落大图 | 512×512 | 原样 | `XTianqiQiyinShow`（神器演出） |
| `rift.png` | P6 龙隙裂缝 | 1280×720 | 原样 | `XTianqiQiyinShow`（龙隙演出） |
| `frames/<印>.png` | P7 七印头像框（头像区 x34 y38 宽高 60） | 128×128 | 原样 | 还没接（外观系统没做） |
| `circles/<印>.png` | P8 七印战斗法阵（俯视正圆） | 512×512 | 原样 | 还没接（同上） |
| `icons/set_<印>_<部位>.png` | I1～I7 套装 42 件 | 32×32 | 原样 | `XTianqiQiyinArt` 图标号 310000 起 |
| `icons/weapon_<类>.png`、`weapon_overlay_16.png` | I8A／I8B 毕业武器 12 类、「不立文字」卷轴叠层 | 32×32、16×16 | 叠层从 128 母版按面积缩到 16 | 图标号 310100、310120 起 |
| `icons/artifact_<神器键>.png` | I9 神器 5 件 | 32×32 | 原样 | 图标号 310200 起 |
| `icons/item_*.png` | I10 印钥、印屑、残页、龙血、封着的装备 | 32×32 | 原样 | 图标号 310300 起（文字里 `\I[310300]` 印钥、`310301` 印屑、`310303` 龙血）；祭坛台词里用上 |
| `icons/rule_*.png`、`effect_*.png` | O1 里副本规则、O2 套装武器效果状态图标 | 32×32 | 原样 | 图标号 310500、310600 起；界面还没接 |
| `icons/relic_*.png`、`badge_*.png` | O3 骑士遗物（完整／残）、骑士徽记 | 32×32 | 原样 | 图标号 310700（完整）、310710（残）、310800（徽记）起；遗物数据未定，界面没接 |

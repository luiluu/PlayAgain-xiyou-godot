# D164 云裳完整像素美术接续

Kyo 已认可u1形象，u2修正切攻击时人物变小、行走裙摆偏短，并接入游戏。尚待换家核查与 Kyo 审图，未自标定稿。

## 产物

- `Yunshang_SV_u2.png`：576×384、9×6、64格，18动作各3帧，没有复制待机填空。完整动作的4倍览图 `SV_all_4x.png`。
- `$Yunshang_u2.png`：144×192、48格四向三帧。`walk_4x.png` 可检查裙摆，现在裙摆盖住小腿到鞋面，侧步只露鞋头。
- `idle_attack_same_scale.gif`：待机→紧凑伸梭→恢复待机，4倍最近邻。
- `screenshots/battle_phone.png`：Godot OpenGL 实际1280×720战斗帧，云裳、米拉、五条悟同屏，未用合成图冒充实机；这是桌面Godot按手机横屏分辨率渲染，**不是安卓设备实测**。
- `screenshots/render_evidence.json`：同帧实际精灵的贴图、缩放和过滤枚举；云裳scale=1.0，filter=1即NEAREST。米拉与五条悟仍沿用原来的约1.24/1.22归一，云裳按本单目标60px原大显示，因此比两位的屏幕可见高略小。

## 出图与后处理

内置image_gen，透明RGBA，未调用CLI/API。三个旧动作参考 `reference_0/1/2.png` 各6列3行；按旧MV位置抽出动作0～5、6～11、12～17，每动作三帧。生成母图 `battle0_raw.png`、`battle1_raw.png`、`battle2_raw.png`、`walk_raw.png` 保留。

共用提示：`Transparent RGBA JRPG pixel-art Yunshang, long ankle-length white Chinese robe navy collar sash long sleeves, silver-white loose bun long hair gold hairpin navy tassel blue eyes, compact two-head chibi, large deliberate sharp pixel clusters, selective dark outlines cool blue-violet shadows upper-left light restrained rim. No texture dithering noise gradients text shadows haze. Exact eighteen sprites six columns three rows equal cells landscape2:1, same standing body scale; crouched and fallen poses stay naturally lower, never enlarged.`

母图0：旧0～5姿态参考+u1认可身份+五条悟风格，行序 walk/wait、chant/guard、damage/evade；去掉旧盾与光效只画身体。母图1：旧6～11姿态参考+新母图0身份，行序thrust/swing、missile/skill、spell/item；关键追加 `compact attacks, elbow bent, shuttle close to hand within body footprint, hair flowing down not spreading sideways, no silhouette wider than standing height`，除thrust里一只小青梭外不画武器/光效。母图2：旧12～17姿态+新母图0身份，escape向右、victory向左抬手、dying跪坐、abnormal垂肩、sleep闭眼坐着、dead闭眼侧躺，强调 `same body scale as standing victory; lying silhouette gently curled to fit square`。

行走：旧图只参考裙长、u1参考身份，追加 `skirt reaches ankles, only tiny shoes visible beneath, no exposed calves or knees anywhere; extend skirt to ankles in all twelve poses; step animation mostly skirt sway`；3×4，下左右上，每向步/站/步，上排不画脸。

`export.py`先alpha128二值化、清除极小独立噪点（主连通块0.1%以下，不删除人物主体），再按格切图。54帧只使用**同一个全局倍率0.23484848**；以待机60px为目标并确保最大宽度≤62。先BOX到目标4倍，再BOX到目标，alpha再次二值化，脚底统一y=61。最长宽度61，待机60px，伸梭约60px，已取消u1的攻击组单独缩小。低姿势保留自然矮高度。无强制色板量化；保留已生成的选择性描边。行走母图行距仍需明确边界0/350/700/1050/1448，统一倍率导出46px站姿。

## 接线与回退

`XYunshang.ART` 默认true；XDB.img_path优先取本目录的新行走、SV及u1头像，文件缺失或开关false回旧图。没有动正式源、旧图或真实存档。

调查发现：云裳备注中的`sv:yunshang`会在载入侧视图后重新覆盖成旧逐帧图；所以只改路径仍然加载旧图。本次在`XAppearance.for_look`仅对实际有新图的Yunshang剥离旧SV备注，换装卡路径仍走原逻辑。新贴图使用独立asset键`Yunshang_u2`与scale=1.0归一档（底锚61）；旧图的192格档和旧逐帧归一不改。

`XBattlerSprite._apply_smooth`只对新档native_pixels标记显式NEAREST并关闭可选crisp柔边着色器；其它角色和旧图保持现状。进阶窗口同样新图1.0，回退时仍旧归一。战斗装备SvPngFd仍照规则生效，本次普通装备场景fd=1。

## 证据

- 测试先在改代码前运行：0/164（新路径/格子/归一/采样均失败）。补齐回退检查后无头168/168；窗口截图模式169/169，包括三位角色实际出场。
- 八项相关回归全部通过：xiyou_yunshang_art、xiyou_sv_smooth、xiyou_appearance、xiyou_actor_looks、xiyou_mira_art、xiyou_actor_advanced、xiyou_actor_book、xiyou_battle_pixel。日志在本工作树04_验证/本地结果/并行测试/20261116_235242_o7zk3m7k。不存在的xiyou_sv_normalize未运行，不计入通过数。
- 工具快速回归22项通过（108秒）。54格非空、精灵alpha仅0/255、尺寸专项通过。
- 选测器因新美术目录尚未映射而给出全量；本车道按影响面跑上述外观/图鉴/战斗像素专项，未改伤害、掉落或存档逻辑，未跑全量与oracle。总装可在并入时做全量例行检查。

截图fixture使用内存临时新档，绕过招募/章节门槛把三位放进实机battle场景；五条悟数据先加载再在fixture禁用章节隐藏开关，仅为三位同屏，不写用户配置或存档。

## 审查关注

请检查步态裙长、攻击手势是否足够明确、异常/濒死/睡眠/倒地语义以及原大脸部可读性。动作54帧已齐，但仍是待审美术；本次采样证据证明没有LINEAR缩小，不能替代人在手机屏幕上的审美判断。头像继续用已认可u1，本单未重出头像。旧新图的开关切换应由交叉核查方再验。

语法检查988文件0问题（28秒），git diff空白检查通过。完整交付说明见项目管理交付目录的gpt_yunshang_v2_D164.md。

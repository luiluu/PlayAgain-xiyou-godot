# D164 云裳完整动作与原生像素接入

执行者 co，基于 abbd426f3；核查待审查。交付范围为D164，不将u1样板当完整游戏资源。

已补齐18组三帧SV、长裙四向行走，54帧统一倍率；待机与伸梭各帧均60px，最大轮廓宽61px。新图仅Yunshang启用1.0归一和显式NEAREST，关闭可选crisp柔边；旧逐帧与旧归一保留、XYunshang.ART=false回退。新图优先查找覆盖行走/SV/头像，处理了旧sv备注二次覆盖，进阶窗口新图不再按旧192格缩小。

实机证据：`03_再刷重制_Godot/01_Godot工程/content/yunshang_v2/u2/screenshots/battle_phone.png`（桌面Godot真实1280×720渲染，云裳/米拉/五条悟同屏，不是安卓设备截图）。旁边render_evidence.json记录云裳scale=1/filter=NEAREST；美术与生成提示见u2/README.md，动作完整预览与统一倍率GIF同目录。

验证：先红0/164；接入专项168/168，真实战斗截图模式169/169；八项相关回归全部通过（70秒）：xiyou_yunshang_art、xiyou_sv_smooth、xiyou_appearance、xiyou_actor_looks、xiyou_mira_art、xiyou_actor_advanced、xiyou_actor_book、xiyou_battle_pixel。语法988文件0问题；工具快速回归22项通过（108秒）；54格非空、二值alpha、尺寸及暂存空白检查通过。旧SV平滑专项显式关闭新图开关测冻结旧路径，另用新专项守新图，不删除旧断言。选测器对新增美术目录保守报全量，本车道只跑直接影响的八专项，未跑全量/oracle（无伤害、存档或掉落改动）。

待交叉核查：appearance.gd、battler_sprite.gd、xdb.gd、yunshang.gd、actor_advanced.gd与新/旧专项；重点看备注覆盖、旧图回退和换装卡不被错误接管。需要Kyo审原大人物大小、裙长与完整动作清晰度，当前未自行定稿。总装维护交接板/变更记录并分配开发编号；本分支可供核查合并，未推送或改共用登记。

可优化：新美术目录加入选测对照的资源路径映射，避免纯图触发整轮；属于工具车道范围，本单未动选测器。

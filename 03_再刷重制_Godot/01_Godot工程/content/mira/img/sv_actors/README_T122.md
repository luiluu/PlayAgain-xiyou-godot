# T122 米拉人形战斗待机双脚

实际战斗默认播放 `walk`（左上三格），不是第二排名为 `wait` 的三格。原 walk 靴子重叠；本次仅在三格局部 x=17..35、y=51..60 内移除暖棕靴像素，取原 wait 第零帧同部位靴像素，三帧站位完全一致，身体保留原呼吸。

我不同意的地方：不需要改裙摆、披风或换播放行；问题是 walk 原来单列叠脚。沿用本角色已有的分腿靴造型，保留上身、尾巴和每帧外接框。

顺查全部18组54格：wait、chant、guard、damage、evade、thrust、swing、missile、skill、spell、item、escape、victory、dying、abnormal、sleep、dead 都已看过。其余站立动作能看出两只靴；escape 的迈步交错和 sleep/dead 的低姿不是同类缺陷，未改。sv/ 当前只有黑龙多帧，不是人形 u2 的运行来源，未改。

复现（Pillow）：从仓库根目录运行 `python3 03_再刷重制_Godot/01_Godot工程/content/mira/fix_mira_feet.py --source 00_项目管理/交付/附图/gpt_mira-feet/T122/before.png --output 03_再刷重制_Godot/01_Godot工程/content/mira/img/sv_actors/Codex_Mira_SV_u2.png`。生成式工具输出未采用，协调者授权后采用原图像素确定性修补。

证据在仓库根目录 `00_项目管理/交付/附图/gpt_mira-feet/T122/`：before.png 为修改前完整原图；comparison_1x.png、comparison_4x.png 为上旧下新整表；idle_comparison_4x.gif 为左旧右新三帧往返；validation.json 含54格外接框逐格记录。576×384、二值alpha、原调色板子集、全部外接框和脚底均保持。注意脚底最后有像素的是 0-based y=60，外接框下界为61，与原图完全一致。

第三帧原靴底有一枚深色残点，另在 y=60、x=24..28 清空原脚间隙后贴入原图靴部；另清除索引1帧(26,57)旧靴暗点，总改动405像素。复验与重建对照图：`python3 content/mira/validate_mira_feet.py`（相对 Godot 工程根目录；脚本也可在任意目录按绝对路径运行）。三帧底行左靴 x17..23、右靴 x29..33，脚间隙 x24..28 均透明。

`battle_godot.png` 为最终素材在 Godot 真实战斗场景的窗口视口截图；`xiyou_mira_art` 窗口模式最终重跑30/30通过（含实际walk行检查和旧靴残点断言）。修图未改动任何播放逻辑。

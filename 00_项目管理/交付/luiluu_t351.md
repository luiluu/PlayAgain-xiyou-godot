# 交付：luiluu/t351

- 车道／工作者：小o（co），sol＋medium，P6 确定性像素修补
- 状态：可合并

## 变更记录草稿

## 2026-11-21 【co·未经审查】T351 米拉战斗待机裙底连接修补（dev.待定）

- walk 三格仅补回 33 个透明像素，颜色逐点取自 T122 修补前同位置，范围 x21..32、y51..53；上身、尾巴、54 格外接框与 y60 脚底不变。
- 证据及独立复现／validate 脚本：`00_项目管理/归档/交付截图/gpt_t351/`。
- 扫描全部 54 格：T122 仅动 walk 三格，其他51格与 T122 前逐像素相同；顺查透明区域，未见同类裙底断靴缺口。角、尾巴环内、动作轮廓留白不填。

## 验证

- repair.py --validate：通过，33像素仅由透明变不透明，54外接框、上身／尾巴／底线不变，alpha 0/255。
- 复现：`python repair.py before.png ../gpt_mira-feet/T122/before.png OUT.png`；验证：`python repair.py --validate before.png OUT.png`（Pillow）。
- 窗口 Godot `xiyou_mira_art`：30/30，通过；音频 Dummy；battle_new.png 为真实战斗截图。
- 4倍纯绿底前后对比 comparison_4x.png。
- 工具回归：23项全部通过（112秒）；复现 PNG 与目标逐字节一致。
- 云端选测及检查：本轮运行 44891052073，最终结果见交付回执。
- PR：https://github.com/luiluu/PlayAgain-xiyou-godot/pull/34 。

## 交接板

- 下一步：跨模型核查后总装合并；不自行标完成。
- 需要用户决定：无。
- 玩家可见文字：不涉及。

## 可优化（流程／工具／效率）

- 附独立脚本而不覆盖 T122 历史脚本；可回退素材提交。

## 本分支提交

- 见本分支 T351 提交。

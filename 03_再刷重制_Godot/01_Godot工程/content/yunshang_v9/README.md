# 云裳第六轮整套接入（T160）

运行图：`$Yunshang_v9.png`（144×192）、`Yunshang_SV_v9.png`（576×384，18动作×3帧）。

已认可 v8 行走逐字节冻结；wait保留同一认可raw内容、整人统一0.072缩放以匹配其他动作头区（原成品约0.089～0.092）；其余 51 帧同一整人 0.09 缩放，最近邻、共用 v8 的48色、二值 alpha；仅平移以谷雨对应动作脚底为参照。高姿势在必要时整体上移/下移到格内，不裁人物。thrust按透明列分割，伸手跨越名义三等分线的像素保留。组装脚本及记录位于 `00_项目管理/归档/交付截图/gpt_t160_yunshang/battle/`。

`XYunshang.RESKIN=false` 回退原 u2；`ART=false` 回退原版；新图缺失走 u2。头像继续 u1。新SV复用旧原生64格profile与图鉴key，最近邻1:1显示。

审样入口：battle/assembled_native.png 原尺寸18行；assembled_3x.png仅辅助。head_measurements.json是头区可见轮廓的粗量（人工顶/下缘带＋亮色轮廓，±2px、不等同颅部精准标点），head_measure_view0/1.png为原尺寸素材最近邻放大对照。wait返修后粗量32～33×24px，与walk/skill同档；姿势投影的差异见量表，不局部拉伸或复用头，不冒称所有动作精确误差≤1px。

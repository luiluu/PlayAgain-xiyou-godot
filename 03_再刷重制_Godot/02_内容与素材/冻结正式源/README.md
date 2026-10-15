# 冻结正式源

用户 2026-10-15 决定：同步到正式西游 v0.28 之后，重制期间**暂停跟随正式版更新**，等重制完成再统一同步。

- `app.nw/`：正式 Mac 应用 `/Users/kyo/Applications/再刷一把：西游（mod_KYO）.app/Contents/Resources/app.nw` 在 2026-10-15 23:44（v0.28）的 APFS 克隆，只读（`chmod -R a-w`），不入 Git。来源身份（251 个数据输入、382 个运行脚本）与当时正式应用逐项相同；指纹以[来源登记](../../../00_项目管理/来源登记.json)为准。
- 转换器 `xiyou_export.py` 的 `DEFAULT_APP`、`mv_event_dump.py` 与 `mv_oracle/*.cjs` 的默认来源都指向这里（`XIYOU_APP`／`--app` 仍可覆盖），所以 `同步正式西游.py`、`验证西游来源.py`、`检查.sh --oracle` 和各车道 worktree 都读这份副本，正式应用之后的更新不会混进来。
- 不要改动或删除这份副本；正式应用再更新时也不要覆盖它。界面参照服务 `ui_reference/serve.py` 也以这里为根目录启动。
- 重制完成后的统一同步：先按当时的正式应用重新克隆到这里（或用 `同步正式西游.py --app <正式应用 app.nw>` 比较），按「有变化」报告逐项跟进，再登记新版本。

# 交付：xa/t517-key-godot2

- 车道／工作者：小A（Neon＋high，P8）· T517 第 1/2/3 步（含 `xa/t517-sign-guard`）：签名守卫＋换新 RSA-4096 公钥＋`godot2/` 物理隔离清单路径＋三段递增补丁编号方案 A
- 状态：可合并

## 变更记录草稿

## 2026-11-25 【小A·T517·未经审查】补丁签名防覆写守卫、换新 RSA-4096 公钥、`godot2/` 清单通道与三段递增编号方案 A（dev.待定）

- 依据：Kyo 11-25 事项 74（换新签名密钥重出 0.04.05 三平台整包）＋协调批准 `godot2/` 物理隔离方案与方案 A 补丁编号；cc Opus 换家核过第 1 步守卫（`T517_签名守卫_cc核.md`，P1/P2 0）与第 3 步（`T517_godot2_cc核.md`，P1/P2 0）。
- 第 1 步 `sign()` 硬守卫（`03_再刷重制_Godot/07_开发环境/发布补丁.py`、`生成更新清单.py`）：`sign(*, key, data, sig)` 改为强制关键字参数；调用 `openssl` 前拦死敏感后缀（`.pem/.key/.keystore/.p12/.pfx/.jks`）、`发版密钥/` 目录、同路径覆写及非 PEM 私钥；签名改先写同目录临时文件、`chmod 0644` 后原子 `os.replace`，失败自动清残片。
- 第 2 步新公钥接入（`03_再刷重制_Godot/01_Godot工程/core/update_check.gd`）：`PUBLIC_KEY` 替换为 2026-11-25 新生成 RSA-4096 公钥（`.pem` 文件字节 SHA-256 `62862961fa25dd4a358f17bde2795e535129bd6e3bfa925e6756fea8a3b4b094`；DER 指纹 `58ce1352…ea383`），并用新私钥经加固 `sign(key=..., data=..., sig=...)` 重签测试样例 `tests/fixtures/update_channel_sample.sig`。
- 第 3 步 `godot2/` 物理隔离路径（`03_再刷重制_Godot/01_Godot工程/core/update_client.gd`、`03_再刷重制_Godot/07_开发环境/发布补丁.py`、`玩家资料包.py`）：新包 4 条清单源统一指向 `/godot2/channel.json`，`发布补丁.py` 的 `SUBDIR = 'godot2'` 且 `DEFAULT_KEY` 指向新私钥 `godot_update_private_20261125.pem`，确保线上旧 `godot/channel.json` 与 `godot/channel.sig` 一字节不动（老包继续无报错验签）。
- 第 3 步补丁编号方案 A（`03_再刷重制_Godot/01_Godot工程/core/update_check.gd` `version_of`）：当发行版本名本身为三段 `X.Y.Z`（如 `0.04.05`）时，后续补丁末段直接累加两位补零（`0.04.06`、`0.04.07`…）；两段名（如 `0.01`、`0.04`）保持 `X.Y.01` 兼容不变。另给 `发布补丁.py` 新增 `--version` 选项并收口两份核查报告全部 P3。
- 玩家可见：新整包（`0.04.05` 及后续版本）切换至新签名密钥与独立更新通道，后续热更补丁依次显示为 `0.04.06`、`0.04.07`……

## 验证

- `测试发布补丁.py`：29/29 OK
- `测试生成更新清单.py`：14/14 OK
- `测试玩家资料包.py`：43/43 OK
- `xiyou_update_check`（98/98）、`xiyou_force_update`（55/55）、`xiyou_update_install`（64/64）：全部通过

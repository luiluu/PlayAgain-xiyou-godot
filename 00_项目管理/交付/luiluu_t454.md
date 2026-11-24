# 交付：luiluu/t454

- 车道／工作者：T454 发行工具加密后四处补漏（T452 核 P2×4、P3×2）／cc（Claude Sonnet 5.5＋medium，P6）
- 状态：可合并

## 变更记录草稿

## 2026-11-24 【cc·T454·未经审查】发行工具加密后补漏：独立自导出带密钥、补丁叠加验证认预设实际加密、测试资源加密进门禁（dev.待定）

- 依据：T452 小A Neon 核查 P2×4、P3×2（11-24）。只改 `07_开发环境/` 下工具，游戏代码、`export_presets.cfg` 一行没动。
- P2-1 `发行入口冒烟.py`：新增 `export_env()`，独立自导出发行预设（macOS／Windows／安卓，含 `检查.sh --release-keys`）都注入 `GODOT_SCRIPT_ENCRYPTION_KEY`（环境变量或私密仓，同 `资源加密.export_env`）；没密钥直接报错退出 2，不出明文包；`资源加密.ENCRYPT＝False` 回退时不注入。三处导出和包内按键运行补 `--audio-driver Dummy`。
- P2-2 `补丁叠加验证.py`：`_env()` 看 `export_presets.cfg` 里实际有没有 `encrypt_pck=true`（不只看 ENCRYPT 开关）；要加密而没密钥时 `main` 开头报人话并退出 1（`--make-only` 也一样，不抛堆栈、不静默跳过、不降级成明文）；`png_set_pixel` 的 Godot 与 `run_game` 的包内运行补 `--audio-driver Dummy`。
- P2-3 `检查.sh`：tools 门禁加 `测试资源加密.py`。
- P2-4 `发布补丁.py`：`--export-patch` 补 `--audio-driver Dummy`。
- P3 `资源加密.py`：apk 包外明文检查补 `.scn/.res/.cfg/.remap`；抽查解密改均匀步长（`i*n//sample`，首尾覆盖，apk 与 pck／zip 同一写法，原来 apk 只取前 N 个）。
- 提交说明补列：T452 的 `a1231bae2`（导出与替身打包的 Godot 命令带 `--audio-driver Dummy`）当时没列进 T452 交付单，补在这里。T452 交付单合并时已按规矩删除，故本单不改 `luiluu_t452.md`。

## 交接板

- 下一步：无。
- 用户试玩说明：玩家看不出变化（只是出包／补丁工具）。
- 需要用户决定：无。

## 验证（命令输出里抄的）

| 项 | 结果 |
| --- | --- |
| 专项 | 测试资源加密 19 项 OK、测试发布补丁 21 项 OK、测试发行出包 33 项 OK、测试发行入口冒烟 21 项 OK；`zsh -n 检查.sh` 通过 |
| 无密钥行为 | `补丁叠加验证.py --make-only`、`发行入口冒烟.py --keys` 在无密钥环境下都打印「没有资源加密密钥…」后退出（补丁叠加验证退出 1），无堆栈 |

没测：带真密钥的整包导出与补丁叠加全流程（本机只验了无密钥分支，密钥在私密仓不上云）；apk 包外明文新增后缀对真实 apk 有无误报（只过了专项夹具，没拿真 apk 扫）；云端选测没跑（见回执）。

## 可优化（流程／工具／效率）

无。

## 动了的共用函数和开关

无。

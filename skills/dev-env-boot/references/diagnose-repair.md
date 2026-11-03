# 模式 3：诊断与修复

环境坏了/进目录版本不对/direnv 不生效时的排查流程。

## 流程

1. **第一步永远是审计**：`bash scripts/env-audit.sh <出问题的目录>`，
   按 FAIL/WARN 定位；audit 本身跑不起来 → 停止并报告（前置依赖自检）。
2. 对照下方**症状速查**找到候选陷阱，按修法处理。
3. **修复守则**（铁律 5）：改 shell 配置先备份（`cp ~/.bashrc ~/.bashrc.bak-<日期>`）
   → 最小修改 → 新 shell 验证 → 失败立即回滚。
4. 修 `.envrc` 后必须 `direnv allow .` 重授权（direnv 按内容哈希放行）。
5. 验证修复：用铁律 3 的双向验证（进目录断言 + 出目录还原），
   **严禁 `bash -ic 'cd ...'`**——它不触发 PROMPT_COMMAND，direnv hook 不执行，
   会得出"环境没生效"的假阴性结论。

## 症状速查

| 症状 | 候选陷阱 |
|------|----------|
| 进目录 node 版本不对 | #1、#4、#5 |
| "验证时 direnv 没生效" | #2（先怀疑验证方法本身） |
| .venv 里 Python 版本不对/来源不明 | #6 |
| 提交后文件神秘缺失/新文件不被跟踪 | #7 |
| 版本切换悄悄失败、环境回落默认 | #8 |
| direnv 装完 command not found / 装错位置 | #3 |
| 进目录毫无反应（无 loading、无报错、环境不变） | #9（先查 `direnv status`），再查 #1/#2 |
| pyenv 版本对但 python 命令是别的 | #5 类遮蔽：`which -a python` 查 PATH 顺序 |
| 版本文件指向未安装/根本不存在的版本 | audit 会直接 FAIL 报出；修法=铁律2：重钉到已装版本并向用户报告偏差，确需原版本则请求授权安装 |

## 陷阱清单（实战沉淀）

| # | 陷阱 | 症状 | 修法 |
|---|------|------|------|
| 1 | direnv stdlib 无 `use nvm`（2.38.2 实测；仅有 use node，其会自行下载 Node 绕开 nvm） | node 版本不切换、无报错（静默无效） | `.envrc` 直接 `source "$NVM_DIR/nvm.sh" --no-use` 后 `nvm use`，失败 `exit 1` |
| 2 | `bash -ic 'cd ...'` 不触发 direnv hook（hook 挂在 PROMPT_COMMAND） | 验证时环境"没生效"（假阴性） | 用 `printf 'cd ...\n<验证>\nexit\n' \| bash -i` 或 `direnv exec . <cmd>` 验证 |
| 3 | direnv 官方 install.sh 用 `bin_path` 环境变量、忽略位置参数 | 二进制落入 PATH 首个可写目录（可能在他人管辖区如 sdkman candidate bin） | `export bin_path=~/.local/bin` 后安装；装后 `command -v direnv` 验证落点 |
| 4 | `nvm alias default` 指向解析 N/A 的别名（如 lts/* 无已装 LTS） | 删硬编码 PATH 后新 shell 无 node | 先 `nvm alias default <明确已装版本>` 验证接管，再清理 |
| 5 | bashrc 硬编码 node PATH（安装脚本残留） | nvm/direnv 切版本被遮蔽或混淆 | 备份→确认 default 别名生效→删行→新 shell 验证，失败回滚 |
| 6 | uv 默认偏好自下载 Python（managed） | `.venv` 解释器非 pyenv 版本，双版本源打架；变体：托管解释器事后被删，`.venv` 只剩 pyvenv.cfg 空壳 | `UV_PYTHON_PREFERENCE=only-system`（项目 `.envrc`，不写全局）；`grep '^home' .venv/pyvenv.cfg` 验证指向 `~/.pyenv/versions/`；空壳 venv 直接删除后在正确环境下重建 |
| 7 | gitignore 非锚定模式（如 `docs/` 匹配任意层级） | 嵌套同名目录被静默忽略、提交丢文件 | 仅根意图写 `/docs/`；`git check-ignore -v` 抽查嵌套路径 |
| 8 | 版本切换命令 `\|\| true` | 目标版本未装时静默回落全局默认 | 失败大声：`\|\| { nvm use >&2; exit 1; }` |
| 9 | `.envrc` 处于 blocked/denied 授权态（改过内容未重新 allow，或被 `direnv deny` 封禁） | 进目录**完全静默跳过** `.envrc`（denied 时无任何输出/报错） | `direnv status` 看 `Found RC allowed N`（0=已授权 1=blocked 2=denied）；`direnv allow .` 是唯一正解，改文件内容只会使旧授权失配 |
| 10 | `direnv exec DIR cmd` **不切换 cwd**（DIR 只用于定位 .envrc） | `uv venv` 等相对路径命令把产物落在调用方 cwd（可能误建到别的仓库里） | 先 `cd DIR` 再 `direnv exec . cmd`，或用 `direnv exec DIR bash -c 'cd DIR && ...'`；发现误建产物：核实为空壳后删除并向用户披露 |

## 修复后

- 重跑 audit 确认全绿
- 把新发现的陷阱**回写上表**（技能自我进化约定），回写仓库源码后重跑
  `bash install.sh` 发布新快照

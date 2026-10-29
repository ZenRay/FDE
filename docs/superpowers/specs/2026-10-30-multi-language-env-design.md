# FDE 课程仓库多语言环境管理设计

日期：2026-10-30
状态：已与用户对齐方向（方案 B），待用户审阅

## 1. 目标与背景

本仓库（`/home/ray/Documents/Private/FDE`）管理 FDE 课程各周的学习内容与工程作业。
需要建立一套可复用的多语言环境管理机制，首个落地对象是 W01 工程包
`fde-student-w01-0.2.0`（Python 3.11+，依赖精确锁定于 `requirements.txt`；
Node.js ≥ 22.22.0 用于 Promptfoo 0.122.2 评估）。

工具链职责划分（用户指定）：

| 工具 | 职责 | 不做什么 |
|------|------|----------|
| pyenv | Python **版本**管理（唯一版本来源） | 不管包 |
| uv | Python **包**与 venv 管理 | 不下载/管理 Python 版本（`UV_PYTHON_PREFERENCE=only-system`） |
| nvm | Node.js 版本管理 | — |
| sdkman | Java 版本管理（**本周不配置**，W01 无 Java 需求；约定预留） | — |
| direnv | 进入项目目录自动激活环境（方案 B 核心） | — |

成功标准：`cd projects/fde-student-w01` 后无需任何手动命令，`python`（3.11.15）、
已激活的 `.venv`（含全部锁定依赖）、`node`（v22.23.4）即刻可用；课程 README 的
官方自检命令通过。

## 2. 目录结构

```
FDE/
├── .python-version            # 3.11.15（仓库基线，pyenv）
├── .nvmrc                     # v22.23.4（仓库基线，nvm）
├── .gitignore                 # 见 §6
├── ENVIRONMENT.md             # 环境约定文档，后续每周沿用
├── docs/superpowers/specs/    # 本设计文档
├── W01 材料包 20261023/        # 原始材料，保持只读、不修改
└── projects/
    └── fde-student-w01/       # 工程工作副本（从材料包复制，作业在此进行）
        ├── .python-version    # 3.11.15（工程级显式声明 = 隔离生效点）
        ├── .nvmrc             # v22.23.4
        ├── .envrc             # direnv 自动激活（见 §4）
        ├── .venv/             # uv 创建，gitignore，不入库
        └── （课程工程原有文件）
```

约定：以后每周工程复制进 `projects/`，沿用同一套版本文件 + `.envrc` 模式；
周目录（如 `W01/`）放课程文档与笔记，不放可运行工程。

## 3. 初始化步骤

0. **基础框架整理**（审计结果，2026-10-30）：
   - pyenv hook：`~/.bashrc` 已就绪（`PYENV_ROOT` + `pyenv init -`）✅
   - nvm hook：已就绪 ✅，但存在两处需清理：
     - `~/.bashrc` 第 1 行硬编码 `PATH="~/.nvm/versions/node/v24.14.1/bin:..."`，
       绕过 nvm 版本管理（安装脚本残留）；
     - `nvm alias default` 指向 `lts/*` 但解析为 N/A（无已安装 LTS 别名可解析）。
     处理：安装 Node 22.23.4 后执行 `nvm alias default v24.14.1`（全局默认仍为 24，
     项目内由 `.nvmrc`+direnv 切到 22），验证新交互 shell 中 `node` 可用后，
     删除硬编码 PATH 行。
   - sdkman hook：已就绪 ✅（本周不用，不动）
   - uv：`~/.local/bin` 已在 PATH，补全已加载 ✅；**不设全局 uv 配置**，
     `UV_PYTHON_PREFERENCE=only-system` 仅放在项目 `.envrc`（项目级隔离原则）
   - direnv：未安装、无 hook ❌ → 见步骤 3
   - git：未配置全局 excludesFile，忽略规则全部放仓库级 `.gitignore`（见 §6）
1. **pyenv**：`pyenv install 3.11.15`（已确认在 pyenv 候选列表中）。
   根目录与工程目录写入 `.python-version` = `3.11.15`。
2. **nvm**：`nvm install 22.23.4`（已确认存在，满足 ≥ 22.22.0）。
   根目录与工程目录写入 `.nvmrc` = `v22.23.4`（精确锁定，保证可复现）。
3. **direnv**：安装 direnv（优先 `sudo apt install direnv`；若无 sudo 权限则
   官方安装脚本装到 `~/.local/bin`），并在 `~/.bashrc` 追加 `eval "$(direnv hook bash)"`。
4. **复制工程**：`W01 材料包 20261023/W01/工程/fde-student-w01-0.2.0` →
   `projects/fde-student-w01/`（完整复制，材料包原件不动）。
5. **Python 环境**（在 `projects/fde-student-w01/` 内）：
   - `uv venv --python 3.11`（`only-system` 偏好下解析到 pyenv 的 3.11.15）
   - `uv pip install -r requirements.txt`（安装到 `.venv`，不改课程依赖声明）
6. **`.envrc`**：见 §4，随后 `direnv allow`。
7. **ENVIRONMENT.md**：记录工具职责表、每周新工程的接入步骤、Java 约定
   （出现需求时用 sdkman 安装并在工程目录写 `.sdkmanrc`，direnv 可配合自动切换）。

## 4. `.envrc` 内容

```sh
# 强制 uv 使用 pyenv 提供的 Python，不下载 uv 托管版本
export UV_PYTHON_PREFERENCE=only-system

# 按 .nvmrc 自动切换 Node
use nvm

# 自动激活 uv 创建的虚拟环境
if [ -d .venv ]; then
  source .venv/bin/activate
fi
```

说明：`use nvm` 是 direnv 标准库函数，自行加载 `$NVM_DIR/nvm.sh` 并读取 `.nvmrc`；
pyenv 依靠 shim 机制随 `.python-version` 自动切换，无需 direnv 参与。

## 5. 验证（不依赖模型密钥）

在 `projects/fde-student-w01/` 新开 shell（触发 direnv）：

1. `python --version` → 3.11.15，`which python` → 指向 `.venv`
2. `node --version` → v22.23.4
3. `python tools/product.py init` → 成功初始化样例数据
4. `python tools/check_product.py --dry-run` → 课程官方环境自检通过
5. 回归测试：`python -m pytest tests/test_product_v2.py tests/test_product_interaction.py`
6. 离开目录再进入，确认 direnv 自动加载/卸载无报错

不执行 `verify_product.py --live` 与 Promptfoo 评估（需要用户自己的
`FDE_MODEL_URL/KEY/NAME`，属于作业阶段动作）。

## 6. `.gitignore`（仓库根，按工程实际产物初始化）

依据对 W01 工程的审计（`tools/product.py` 运行态路径、README/evals 的产出说明）：

```
# Python（uv venv 与运行产物）
.venv/
__pycache__/
*.pyc
.pytest_cache/

# direnv：缓存默认在全局 ~/.cache/direnv，仓库内无产物；
# 此条目仅防御未来在 .envrc 中声明 direnv_layout_dir 的情况
.direnv/

# W01 产品运行态：product.py 默认 --home 为 .runtime/product/
# （sample.sqlite、tag-system.sqlite、checkpoint、动作账本），重启保留但不入库
.runtime/

# Node（Promptfoo 经 npx 运行，正常不落地；防本地 npm install 意外入库）
node_modules/

# 模型密钥等本地环境变量文件（产品只读显式环境变量，此文件防误提交）
.env
```

**明确不忽略**（需入库跟踪）：
- `projects/fde-student-w01/` 工程源码本体——作业与证据需要版本跟踪；
- `artifacts/w01/**`（四份 JSON 证据、promptfoo-results.json）——课程作业产出，
  工程自带 `.gitattributes`（`artifacts/** -text`）已按二进制处理，复制时保留；
- `.python-version`、`.nvmrc`、`.envrc`——环境定义本身就是要提交的配置。

后续每周新工程接入时，按其实际运行产物**增补**对应条目，不预先堆砌通用模板。

## 7. 错误处理

- pyenv 编译 3.11.15 失败（缺系统构建依赖）：报告缺失依赖清单，不静默换版本。
- uv 安装锁定依赖冲突：原样报告冲突包与版本，不擅自升级/降级课程锁定版本。
- direnv 安装无 sudo：回退到 `~/.local/bin` 二进制安装；仍失败则报告，
  其余步骤不受阻（手动 `nvm use` + `source .venv/bin/activate` 可替代）。
- 材料包目录任何写操作视为错误，立即停止。

## 8. 范围外（YAGNI）

- Java/sdkman 实际安装（无需求，仅留约定）
- direnv 之外的 shell 钩子（nvm cd-hook 等）
- uv 项目化改造（pyproject/uv.lock 转换）——课程工具链以 requirements.txt 为准
- W01 作业内容本身（fit-gap、评估、立项报告）

# 多语言环境管理初始化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 FDE 课程仓库建立 pyenv(版本)+uv(包)+nvm+direnv 的项目级隔离环境，并让 W01 工程副本通过课程官方自检。

**Architecture:** 仓库根放版本基线文件（`.python-version`/`.nvmrc`），工程工作副本放 `projects/fde-student-w01/`，内含自己的版本文件 + `.envrc`（direnv 自动激活 `.venv`、自动 `nvm use`、强制 uv 只用系统/pyenv Python）。uv 只创建 venv 和安装锁定依赖，不改课程 `requirements.txt`。Java 本周不配置，仅在 `ENVIRONMENT.md` 留约定。

**Tech Stack:** pyenv 2.6.27、uv 0.11.6、nvm 0.40.1、direnv（待装）、Python 3.11.15、Node v22.23.4

**Spec:** `docs/superpowers/specs/2026-10-30-multi-language-env-design.md`

> **勘误（2026-10-30，执行完毕后追加）**：① 文中材料包路径为执行当时的仓库根
> `W01 材料包 20261023/`，该目录现已由用户移至 `projects/W01 材料包 20261023/`；
> ② Task 4 的 `.envrc` 模板中 `use nvm` 在 direnv 2.38.2 stdlib 不存在，实际执行
> 改为 `source nvm.sh --no-use` + `nvm use`（失败即报错退出，不静默回落），详见
> 规格 §4 勘误与执行台账 Ruling。本计划正文保持原样作为历史执行记录。

## Global Constraints

- Python 固定 **3.11.15**，只经 pyenv 安装；uv 不得下载托管 Python（`UV_PYTHON_PREFERENCE=only-system` 仅写在项目 `.envrc`，不写全局配置）
- Node 固定 **v22.23.4**（满足课程 ≥22.22.0）；全局 nvm default 保持 **v24.14.1**
- `W01 材料包 20261023/` 目录**只读**，任何写操作视为错误立即停止
- `requirements.txt` 锁定版本**不得增删改**；安装冲突原样上报
- 不运行 `verify_product.py --live`、不运行 Promptfoo 评估、不设置任何 `FDE_MODEL_*` 变量（需要用户模型密钥，属作业阶段）
- 所有 shell 初始化文件（`~/.bashrc`）修改前必须先备份
- **严禁自动 git commit / push**：仅当用户明确要求时才执行；commit 信息**严禁**添加任何协作者署名（Co-Authored-By 等）。本计划所有任务只改工作区，不产生任何 commit
- 仓库根目录：`/home/ray/Documents/Private/FDE`（下文相对路径均基于此）

## Review Focus

1. **uv 绕过 pyenv 私自下载 Python** → Task 5 用 `.venv/pyvenv.cfg` 的 `home` 指向 `~/.pyenv/versions/3.11.15/bin` 钉死
2. **材料包被意外修改** → Task 4 用 `diff -rq` 对比副本与原件、`git status` 确认材料包无变更
3. **删除 bashrc 硬编码 PATH 后新 shell 丢失 node** → Task 2 在新交互 shell 验证 `node --version` 后才删行，且删前备份
4. **direnv 未生效导致进目录环境不自动加载** → Task 6 用全新 `bash -ic` 进入目录验证 `which python`/`node --version`/`$UV_PYTHON_PREFERENCE`
5. **运行态产物（`.runtime/`、`.venv/`）误入库** → Task 6 运行 `product.py init` 后 `git status` 必须无未忽略产物

---

### Task 1: pyenv 安装 Python 3.11.15 + 仓库根版本基线

**Files:**
- Create: `.python-version`（仓库根）

**Interfaces:**
- Consumes: 无（首个任务）
- Produces: pyenv 管理的 3.11.15 解释器（路径 `~/.pyenv/versions/3.11.15/bin/python`，Task 5 的 uv venv 依赖它）；根 `.python-version` 基线（Task 4 的工程级文件与其同值）

- [ ] **Step 1: 确认 3.11.15 尚未安装**

Run: `pyenv versions`
Expected: 输出中无 `3.11.15`（若已有则跳过 Step 2 的安装命令）

- [ ] **Step 2: 安装 Python 3.11.15**

Run: `pyenv install 3.11.15`（编译需数分钟，Bash timeout 设 600000）
Expected: 末尾输出 `Installed Python-3.11.15 to /home/ray/.pyenv/versions/3.11.15`
若编译失败（缺系统构建依赖）：**停止并报告缺失依赖清单，不换版本、不静默降级**（规格 §7）。

- [ ] **Step 3: 写仓库根 `.python-version`**

创建 `/home/ray/Documents/Private/FDE/.python-version`，内容恰好一行：

```
3.11.15
```

- [ ] **Step 4: 验证 pyenv 在仓库根解析到 3.11.15**

Run: `cd /home/ray/Documents/Private/FDE && pyenv version && pyenv exec python --version`
Expected: `3.11.15 (set by /home/ray/Documents/Private/FDE/.python-version)` 和 `Python 3.11.15`

（不 commit，见 Global Constraints；下同。）

---

### Task 2: nvm 安装 Node v22.23.4 + 清理 bashrc 硬编码 + 根 `.nvmrc`

**Files:**
- Create: `.nvmrc`（仓库根）
- Modify: `~/.bashrc`（仓库外：设 default 别名、删第 1 行硬编码 PATH；先备份）

**Interfaces:**
- Consumes: 无
- Produces: nvm 管理的 v22.23.4；`nvm alias default` = v24.14.1（删硬编码行后新 shell 的 node 来源）；根 `.nvmrc`（Task 4 工程级 `.nvmrc` 与其同值，direnv `use nvm` 读取它）

- [ ] **Step 1: 安装 Node 22.23.4**

Run: `bash -c 'source ~/.nvm/nvm.sh && nvm install 22.23.4'`
Expected: `Now using node v22.23.4 (npm v...)`

- [ ] **Step 2: 固定 nvm 全局默认为 v24.14.1（当前 default→lts/* 解析为 N/A）**

Run: `bash -c 'source ~/.nvm/nvm.sh && nvm alias default v24.14.1 && nvm use default >/dev/null && nvm current'`
Expected: `default -> v24.14.1` 且 `nvm current` 输出 `v24.14.1`

- [ ] **Step 3: 备份 bashrc 并验证新交互 shell 的 node 来自 nvm 而非硬编码行**

Run: `cp ~/.bashrc ~/.bashrc.bak-20261030 && grep -n 'v24.14.1/bin' ~/.bashrc`
Expected: 备份成功；仅第 1 行命中硬编码 PATH：`1:export PATH="/home/ray/.nvm/versions/node/v24.14.1/bin:$PATH"`
（nvm.sh 在 120-122 行加载，default 别名生效后即接管版本选择。）

- [ ] **Step 4: 删除第 1 行硬编码 PATH（仅当该行内容精确匹配时删）**

Run: `sed -i '1s|^export PATH="/home/ray/.nvm/versions/node/v24.14.1/bin:\$PATH"$||' ~/.bashrc && sed -i '1{/^$/d}' ~/.bashrc && head -3 ~/.bashrc`
Expected: 输出中不再包含 `v24.14.1/bin`（第一条 sed 只在整行精确匹配时清空该行，第二条删除遗留空行）

- [ ] **Step 5: 验证新交互 shell node 仍可用且来自 nvm**

Run: `bash -ic 'which node && node --version' 2>/dev/null`
Expected: `/home/ray/.nvm/versions/node/v24.14.1/bin/node` 和 `v24.14.1`
若 node 不可用：**立即用备份回滚** `cp ~/.bashrc.bak-20261030 ~/.bashrc` 并报告，不继续 Task 3。

- [ ] **Step 6: 写仓库根 `.nvmrc`**

创建 `/home/ray/Documents/Private/FDE/.nvmrc`，内容恰好一行：

```
v22.23.4
```

- [ ] **Step 7: 验证仓库根 `nvm use` 切到 22.23.4**

Run: `cd /home/ray/Documents/Private/FDE && bash -c 'source ~/.nvm/nvm.sh && nvm use && node --version'`
Expected: `Now using node v22.23.4` 和 `v22.23.4`

---

### Task 3: 安装 direnv 并挂接 bash hook

**Files:**
- Modify: `~/.bashrc`（仓库外：追加 direnv hook；Task 2 已有备份）

**Interfaces:**
- Consumes: `~/.bashrc`（nvm/pyenv hook 段之后追加）
- Produces: 可用的 `direnv` 命令与新 shell 自动 hook（Task 6 的 `direnv allow`/自动激活依赖它）

- [ ] **Step 1: 安装 direnv（优先 apt，需 sudo；失败则官方脚本装到 ~/.local/bin）**

Run: `sudo apt-get install -y direnv`
（若 sudo 不可用/无权限，回退：`curl -sfL https://direnv.net/install.sh | bash -s -- ~/.local/bin`，`~/.local/bin` 已在 PATH）
Expected: 安装无报错

- [ ] **Step 2: 验证二进制可用**

Run: `direnv version || ~/.local/bin/direnv version`
Expected: 输出版本号（如 `2.xx.x`）

- [ ] **Step 3: 在 `~/.bashrc` 末尾追加 hook（幂等：已存在则跳过）**

Run: `grep -q 'direnv hook bash' ~/.bashrc || printf '\n# direnv\neval "$(direnv hook bash)"\n' >> ~/.bashrc; tail -3 ~/.bashrc`
Expected: 末尾出现 `eval "$(direnv hook bash)"`

- [ ] **Step 4: 验证新交互 shell 加载 direnv hook**

Run: `bash -ic 'type _direnv_hook' 2>/dev/null | head -1`
Expected: `_direnv_hook is a function`
（本任务无仓库文件变更，不产生 commit。）

---

### Task 4: 根 `.gitignore` + 复制工程副本 + 工程级环境文件

**Files:**
- Create: `.gitignore`（仓库根）
- Create: `projects/fde-student-w01/`（整目录，从材料包复制）
- Create: `projects/fde-student-w01/.python-version`
- Create: `projects/fde-student-w01/.nvmrc`
- Create: `projects/fde-student-w01/.envrc`

**Interfaces:**
- Consumes: 材料包原件 `W01 材料包 20261023/W01/工程/fde-student-w01-0.2.0/`（只读）；Task 1/2 的版本号（3.11.15 / v22.23.4）
- Produces: 工作副本目录结构；`.envrc` 定义的环境变量 `UV_PYTHON_PREFERENCE=only-system`（Task 5 的 uv venv 依赖）；`.gitignore`（Task 5/6 的 git status 验证依赖）

- [ ] **Step 1: 写仓库根 `.gitignore`**

创建 `/home/ray/Documents/Private/FDE/.gitignore`，内容（依据规格 §6，按工程实际产物）：

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

- [ ] **Step 2: 复制工程到 `projects/fde-student-w01/`（材料包原件不动）**

```bash
mkdir -p projects
cp -a "W01 材料包 20261023/W01/工程/fde-student-w01-0.2.0" projects/fde-student-w01
```

- [ ] **Step 3: 验证副本与原件一致（Review Focus #2）**

Run: `diff -rq "W01 材料包 20261023/W01/工程/fde-student-w01-0.2.0" projects/fde-student-w01 && echo COPY-OK`
Expected: `COPY-OK`（无差异输出）

Run: `git status --porcelain -- "W01 材料包 20261023" | wc -l`
Expected: `0`（材料包无任何变更）

- [ ] **Step 4: 写工程级 `.python-version` 与 `.nvmrc`**

创建 `projects/fde-student-w01/.python-version`，内容恰好一行：

```
3.11.15
```

创建 `projects/fde-student-w01/.nvmrc`，内容恰好一行：

```
v22.23.4
```

- [ ] **Step 5: 写工程级 `.envrc`**

创建 `projects/fde-student-w01/.envrc`，内容（与规格 §4 一致）：

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

---

### Task 5: uv 创建 `.venv`（pyenv 3.11.15）+ 安装锁定依赖

**Files:**
- Create: `projects/fde-student-w01/.venv/`（被 gitignore，不入库）

**Interfaces:**
- Consumes: Task 1 的 `~/.pyenv/versions/3.11.15/`；Task 4 的 `.envrc` 中 `UV_PYTHON_PREFERENCE=only-system` 与工程内 `.python-version`、`requirements.txt`（58 个锁定包）
- Produces: `projects/fde-student-w01/.venv/bin/python`（3.11.15，含全部依赖；Task 6 的官方自检与 direnv 激活对象）

- [ ] **Step 1: 创建 venv（强制只用系统/pyenv Python）**

Run: `cd projects/fde-student-w01 && UV_PYTHON_PREFERENCE=only-system uv venv --python 3.11`
Expected: `Using CPython 3.11.15` 与 `Creating virtual environment at: .venv`
**若 uv 输出出现 `Downloading python` 或解析到非 pyenv 路径：停止并报告**（Review Focus #1 失败）。

- [ ] **Step 2: 验证 venv 解释器来自 pyenv（Review Focus #1 的钉死测试）**

Run: `grep '^home' projects/fde-student-w01/.venv/pyvenv.cfg`
Expected: `home = /home/ray/.pyenv/versions/3.11.15/bin`

- [ ] **Step 3: 安装锁定依赖（版本不得改动，规格约束）**

Run: `cd projects/fde-student-w01 && UV_PYTHON_PREFERENCE=only-system uv pip install -r requirements.txt`（timeout 600000）
Expected: `Installed 58 packages in ...`（无 resolution 冲突；若有冲突：**原样报告冲突包与版本，停止**）

- [ ] **Step 4: 验证关键依赖与解释器版本**

Run: `projects/fde-student-w01/.venv/bin/python --version && projects/fde-student-w01/.venv/bin/python -c "import langgraph, pydantic, pytest; print(pydantic.VERSION)"`
Expected: `Python 3.11.15` 和 `2.13.5`

- [ ] **Step 5: 验证 git 不跟踪 .venv（Review Focus #5 前置）**

Run: `git status --porcelain -- projects/fde-student-w01/.venv | wc -l`
Expected: `0`

（`.venv` 不入库，本任务无 commit。）

---

### Task 6: direnv allow + 端到端验证（官方自检 + 回归测试）

**Files:**
- 无新建（运行验证；`direnv allow` 产生 `~/.cache/direnv` 与本地 `.direnv` 状态，均不入库）

**Interfaces:**
- Consumes: Task 3 的 direnv hook；Task 4 的 `.envrc`/版本文件；Task 5 的 `.venv`
- Produces: 验证通过的环境（后续每周工程复用同一接入流程的事实依据）；`.runtime/` 运行态数据（gitignore 覆盖验证）

- [ ] **Step 1: 授权 `.envrc`**

Run: `cd projects/fde-student-w01 && direnv allow .`
Expected: 无报错（可能提示 `.envrc` 加载信息）

- [ ] **Step 2: 全新交互 shell 验证自动激活（Review Focus #4）**

Run: `bash -ic 'cd /home/ray/Documents/Private/FDE/projects/fde-student-w01 && which python && python --version && node --version && echo UV_PREF=$UV_PYTHON_PREFERENCE' 2>/dev/null`
Expected:
- `which python` → `/home/ray/Documents/Private/FDE/projects/fde-student-w01/.venv/bin/python`
- `python --version` → `Python 3.11.15`
- `node --version` → `v22.23.4`
- `UV_PREF=only-system`

- [ ] **Step 3: 课程官方自检①——初始化样例数据**

Run: `cd projects/fde-student-w01 && .venv/bin/python tools/product.py init`
Expected: 输出一段 JSON（样例导入统计），退出码 0

- [ ] **Step 4: 课程官方自检②——环境检查 dry-run**

Run: `cd projects/fde-student-w01 && .venv/bin/python tools/check_product.py --dry-run`
Expected: 退出码 0（若因缺作业 JSON 报警告属正常，`--dry-run` 不应失败；如失败，原样报告输出）

- [ ] **Step 5: 回归测试（README 指定的两个测试文件）**

Run: `cd projects/fde-student-w01 && .venv/bin/python -m pytest tests/test_product_v2.py tests/test_product_interaction.py`
Expected: 全部通过（`N passed`），退出码 0

- [ ] **Step 6: 验证运行态产物全部被 gitignore（Review Focus #5）**

Run: `git status --porcelain | grep -cE '\.runtime|\.venv|__pycache__|\.pytest_cache' ; ls projects/fde-student-w01/.runtime/product/ | head -3`
Expected: 计数 `0`（`.runtime/`、`.venv/`、`__pycache__`、`.pytest_cache` 均不出现在 git status；其余未跟踪的本计划新增文件属正常），且 `.runtime/product/` 内实际存在 `sample.sqlite` 等文件

- [ ] **Step 7: 验证离开目录后 direnv 卸载**

Run: `bash -ic 'cd /home/ray/Documents/Private/FDE/projects/fde-student-w01 && cd .. && which python; echo UV_PREF=[$UV_PYTHON_PREFERENCE]' 2>/dev/null`
Expected: `which python` 不再指向工程 `.venv`（指向 pyenv shim 或系统），`UV_PREF=[]` 为空

（若 Step 6 计数非 0，修根 `.gitignore` 补对应条目后重跑验证。）

---

### Task 7: `ENVIRONMENT.md` 环境约定文档 + 收尾

**Files:**
- Create: `ENVIRONMENT.md`（仓库根）

**Interfaces:**
- Consumes: Task 1-6 的最终事实（版本号、命令、验证结果）
- Produces: 后续每周新工程接入的标准流程文档（用户与未来会话的操作依据）

- [ ] **Step 1: 写 `ENVIRONMENT.md`**

创建 `/home/ray/Documents/Private/FDE/ENVIRONMENT.md`，内容（外层四反引号仅为计划排版，实际文件从 `# 环境管理约定` 开始）：

````markdown
# 环境管理约定

本仓库用以下工具链管理多语言环境，全部项目级隔离：

| 工具 | 职责 | 项目级隔离载体 |
|------|------|----------------|
| pyenv | Python 版本（唯一版本来源） | `.python-version` |
| uv | Python venv 与包（不下载 Python，`UV_PYTHON_PREFERENCE=only-system`） | `.venv/` + `requirements.txt` |
| nvm | Node.js 版本 | `.nvmrc` |
| direnv | 进入目录自动激活以上环境 | `.envrc` |
| sdkman | Java 版本（**尚未启用**：W01 无 Java 需求；出现需求的那周安装 JDK 并在工程目录写 `.sdkmanrc`，direnv 配合自动切换） | `.sdkmanrc` |

仓库基线：Python 3.11.15、Node v22.23.4（根目录版本文件）；全局 nvm default 为 v24.14.1。

## 每周新工程接入流程

1. 复制工程到 `projects/<工程名>/`（课程材料包目录保持只读，绝不修改）
2. 工程目录写 `.python-version`、`.nvmrc`（按该周课程要求，可与根基线不同）
3. 复制 `projects/fde-student-w01/.envrc` 作起点，按需调整
4. `uv venv --python <版本> && uv pip install -r requirements.txt`（在工程目录内）
5. `direnv allow .`
6. 验证：新 shell 进入目录，`which python`、`node --version` 符合预期
7. 按该工程的实际运行产物增补根 `.gitignore`（不预先堆通用模板）

## W01 已验证命令（2026-10-30）

```sh
cd projects/fde-student-w01        # direnv 自动激活
python tools/product.py init
python tools/check_product.py --dry-run
python -m pytest tests/test_product_v2.py tests/test_product_interaction.py
```

模型相关（`verify_product.py --live`、Promptfoo 评估）需自行配置
`FDE_MODEL_URL` / `FDE_MODEL_NAME` / `FDE_MODEL_KEY` 后按工程 README 执行。
````

- [ ] **Step 2: 最终检查**

Run: `git status --short | head -20 && git status --porcelain -- "W01 材料包 20261023" | wc -l`
Expected: 未跟踪项仅为本次新增（`.python-version`、`.nvmrc`、`.gitignore`、`ENVIRONMENT.md`、`projects/`、`docs/superpowers/plans/`），材料包变更计数为 `0`。**不 commit**——向用户汇报结果，由用户决定是否提交及提交内容。

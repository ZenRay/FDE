# 模式 1：既有工程接入

把一个已存在的工程（第三方分发/课程材料/clone 来的项目）接入本地环境，
产出项目级隔离环境：进目录即得正确版本的语言运行时与依赖。

## 前置

先跑只读审计，FAIL 先修（修复走 `diagnose-repair.md`）：

```sh
bash scripts/env-audit.sh <工程目录>
```

## 七步流程

### ① 读工程文档提取需求

从 README 安装节、CI 配置、`pyproject.toml`/`package.json` 的 engines 字段提取：
- 语言版本要求（如 "Python 3.11+"、"Node >= 22.22.0"）
- 依赖声明文件（requirements.txt / pyproject.toml / package.json）
- 官方自检/测试命令（后续验证用）

文档没写版本 → 问用户，不拍脑袋（铁律 2）。

### ② 审计基础框架

按 audit 第 1-3 节输出处理：工具缺失按需求安装；hook 缺失/遗留问题按
`diagnose-repair.md` 修复（改 shell 配置遵守铁律 5：备份→最小修改→验证→可回滚）。

### ③ 安装缺失的语言版本

```sh
pyenv install <ver>          # 编译需数分钟，timeout 设 600000
bash -c 'source ~/.nvm/nvm.sh && nvm install <ver>'
```

编译失败（缺系统构建依赖）→ 报告缺失依赖清单，**不换版本、不静默降级**。
已装版本满足要求 → 直接用，不重复安装。

### ④ 复制工程到工作区（分发材料只读，铁律 4）

适用条件：工程来自只读分发材料（第三方包/课程材料）。若目标目录本身就是
用户指定的工作区（如刚 clone 的仓库），跳过复制、就地配置。

```sh
cp -a "<原始工程目录>" "<工作区目标目录>"
diff -rq "<原始工程目录>" "<工作区目标目录>" && echo COPY-OK
```

### ⑤ 写项目级隔离三件套

在工作副本内创建 `.python-version`、`.nvmrc`（内容=选定版本，各一行），
以及 `.envrc` 标准模板：

```sh
# 强制 uv 使用 pyenv 提供的 Python，不下载 uv 托管版本
export UV_PYTHON_PREFERENCE=only-system

# 按 .nvmrc 自动切换 Node（nvm 仍由 ~/.nvm 管理；direnv 2.38.2 stdlib 无 use nvm）
# 失败不吞错：.nvmrc 指向未安装版本时报错退出，防止静默回落到全局 default
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  source "$NVM_DIR/nvm.sh" --no-use
  nvm use --silent >/dev/null || { nvm use >&2; exit 1; }
fi
# .nvmrc 变更时自动重估 .envrc（文件不存在时跳过）
[ -f .nvmrc ] && watch_file .nvmrc

# 自动激活 uv 创建的虚拟环境
if [ -d .venv ]; then
  source .venv/bin/activate
fi
```

然后建 venv 装依赖（在工程目录内）：

```sh
uv venv --python <主次版本>            # only-system 下解析到 pyenv 的解释器
uv pip install -r requirements.txt     # 依赖声明所有权在工程方时（不改写其声明）
# 自有工程（自己维护 pyproject.toml）则用: uv sync
```

建完立即验证解释器来源（铁律 1）：

```sh
grep '^home' .venv/pyvenv.cfg          # 必须指向 ~/.pyenv/versions/<ver>/bin
```

### ⑥ direnv allow + 双向验证 + 官方自检

```sh
direnv allow .
```

进目录验证（真交互 shell，铁律 3；四断言）：

```sh
printf 'cd <工程目录绝对路径>\nwhich python && python --version && node --version && echo UV_PREF=$UV_PYTHON_PREFERENCE\nexit\n' | bash -i 2>/dev/null
```

预期：python 指向工程 `.venv`、版本正确；node 为 `.nvmrc` 版本；UV_PREF=only-system。

出目录还原验证：

```sh
printf 'cd <工程目录绝对路径>\ncd ..\nwhich python; echo UV_PREF=[$UV_PYTHON_PREFERENCE]\nexit\n' | bash -i 2>/dev/null
```

预期：python 不再指向工程 `.venv`，UV_PREF 为空。

再跑 ① 中提取的官方自检与回归测试，全绿才算接入完成。

### ⑦ 按实际运行产物增补 gitignore

运行自检后看磁盘上多了什么（运行态目录、缓存），增补进 gitignore 并注明依据；
遵守铁律 6（锚定意识）与铁律 9（只增补功能性条目，不创建约定文档）。
验证：`git status --porcelain | grep -cE '<运行态目录名>'` 应为 0。

## 常见偏差（无技能基线实测的自然失败，逐条对照避免）

1. **`use nvm` 报错后改用 `use node` + `NODE_VERSIONS` 指向 nvm 目录**：
   版本已装时能用，但 `.nvmrc` 指向未装版本时 `use node` 会**自行下载 node
   进 direnv 缓存、绕开 nvm 且无报错**（Node 版的版本管理权旁落）。
   → 坚持本文件 ⑤ 的模板：source `nvm.sh --no-use` + `nvm use` + 失败大声。
2. **跳过前置审计直接动手**：框架恰好健康时看不出问题，坏框架（hook 缺失、
   别名失效、硬编码 PATH）下必踩坑。→ 七步流程的 ② 不可省。
3. **不声明 `UV_PYTHON_PREFERENCE=only-system`，只靠给 `uv venv` 传显式解释器
   路径**：当次侥幸正确，但后续任何不带显式路径的 uv 命令（`uv venv --python 3.11`、
   `uv add`、`uv sync`）会在 uv 缓存存在 managed Python 时**静默优先 managed 版本**，
   背离 pyenv。→ 环境变量必须写进 `.envrc`（铁律 1），不依赖操作习惯。
4. **建 venv 后不验证 `.venv/pyvenv.cfg` 的 home**：无法发现偏差 3 的静默错误。
   → ⑤ 的 `grep '^home'` 验证是必做步骤，不是可选检查。
5. `.nvmrc` 版本格式不统一（如 `22.14.0` vs `v22.14.0`）：nvm 两者都接受，
   但模板统一带 `v` 前缀，与 `nvm ls`/`nvm use` 输出一致，减少比对歧义。

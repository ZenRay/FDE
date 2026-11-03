# dev-env-boot SKILL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建单一通用 dev-env-boot SKILL（源码 `skills/dev-env-boot/`，仓库内迭代），沉淀已验证的多语言环境初始化方法论；install.sh 复制快照到 `~/.claude/skills/` 全局生效。

**Architecture:** 单一通用技能，**无项目封装层、不依赖 ENVIRONMENT.md 等约定文档**（项目差异运行时从工程文档提取或问用户）。SKILL.md（模式路由 + 九条铁律 + 前置依赖自检）+ 4 个按模式加载的 reference + 只读审计脚本 env-audit.sh + 复制式 install.sh（`.installed-from` 标记防覆盖用户目录）。按 writing-skills 的 RED-GREEN-REFACTOR：先跑无技能基线场景记录失败，再写技能内容针对失败，最后带技能复测。

**Tech Stack:** Markdown SKILL（Claude Code skills 规范）、bash（env-audit.sh / install.sh）、子代理场景测试

**Spec:** `docs/superpowers/specs/2026-10-30-dev-env-boot-skill-design.md`

## Global Constraints

- **严禁自动 git commit / push**；commit 信息严禁署名（用户规则，高于本计划一切步骤）
- **零项目特定信息**：`skills/dev-env-boot/` 内 grep `fde|FDE|3\.11\.15|22\.23\.4|材料包|W01|ENVIRONMENT` 必须零命中（Task 6 钉死）；技能不得依赖或创建约定文档类文件
- **简洁初始化（铁律9）**：技能指导产生的文件仅限功能性必需（版本文件、`.envrc`、`.venv`、gitignore 条目）；Task 5 场景 A 验证产物中无约定文档
- SKILL.md frontmatter：`name: dev-env-boot`（仅字母数字连字符）；description 第三人称、只写触发条件、**不得概述工作流**（writing-skills SDO 规则）；SKILL.md 正文 < 500 词
- reference 中脚本一律以 `bash scripts/env-audit.sh` 形式引用（不用裸路径）
- env-audit.sh **严格只读**：不写任何文件、不改任何状态（stdout 除外）
- install.sh 为**复制**安装（非 symlink）：全局副本是快照，仓库源码是迭代处；重跑 = 更新快照；无 `.installed-from` 标记的已有目录拒绝覆盖
- 测试只在 `/tmp/dev-env-boot-test/` fixture 内进行；**不安装任何未安装的语言版本**（只用已装的 Python 3.11.15 / Node v22.23.4）；结束后删除 fixture
- 子代理场景测试的提示词按本计划原文使用，结果逐字记录到工作区文件
- 仓库根：`/home/ray/Documents/Private/FDE`

## Review Focus

1. **通用技能被项目信息/约定文档依赖污染**（纯通用性核心承诺）→ Task 6 purity grep（含 ENVIRONMENT）零命中钉死
2. **env-audit.sh 误报/漏报**（假阳性让用户修没坏的东西，假阴性放过真问题）→ Task 2 双向测试：已知良好仓库 exit 0 全 PASS + 构造坏状态 fixture 逐项 FAIL/WARN
3. **install.sh 覆盖用户已有真实目录**（破坏性）→ Task 4 用无标记预置目录测试拒绝覆盖；带标记旧快照可更新
4. **技能不触发或错误触发**（description 触发词失效）→ Task 5 检索场景：3 个任务描述让带技能子代理判断是否适用
5. **.envrc 模板缺陷回归**（`use nvm` / `|| true` 被重新写入模板）→ Task 3 模板全文钉死 + Task 5 场景 A 断言 node 实际切换成功

---

### Task 1: 测试 fixture + 无技能基线场景（RED）

**Files:**
- Create: `/tmp/dev-env-boot-test/project-a/`（boot 目标 fixture）
- Create: `/tmp/dev-env-boot-test/broken/`（坏环境 fixture）
- Create: `<workspace>/baseline-scenario-a.md`、`baseline-scenario-b.md`（基线记录，workspace = `.superpowers/sdd/<plan>/`）

**Interfaces:**
- Consumes: 无
- Produces: 两个 fixture 目录（Task 2 的 audit 测试、Task 5 的 GREEN 复测复用）；基线失败清单（Task 3 技能内容必须针对性覆盖）

- [ ] **Step 1: 建 fixture A（待 boot 的工程）**

```bash
mkdir -p /tmp/dev-env-boot-test/project-a/tools
cat > /tmp/dev-env-boot-test/project-a/README.md <<'EOF'
# 测试工程 project-a
要求：Python 3.11+（依赖见 requirements.txt）；Node.js >= 22.22.0（运行 tools/check.mjs）。
官方自检：python tools/hello.py 与 node tools/check.mjs 都应输出 ok。
EOF
echo 'six==1.17.0' > /tmp/dev-env-boot-test/project-a/requirements.txt
echo "print('ok')" > /tmp/dev-env-boot-test/project-a/tools/hello.py
echo "console.log('ok')" > /tmp/dev-env-boot-test/project-a/tools/check.mjs
```

- [ ] **Step 2: 建 fixture B（坏环境，含 4 个已知陷阱）**

```bash
mkdir -p /tmp/dev-env-boot-test/broken/.venv
cd /tmp/dev-env-boot-test/broken
echo 'v19.9.0' > .nvmrc                      # 陷阱：未安装的 Node 版本
echo '3.11.999' > .python-version            # 陷阱：未安装的 Python 版本
cat > .envrc <<'EOF'
use nvm                                       # 陷阱1：direnv stdlib 无此命令
nvm use || true                               # 陷阱8：静默吞错
EOF
cat > .venv/pyvenv.cfg <<'EOF'
home = /home/ray/.local/share/uv/python/cpython-3.13.0-linux-x86_64-gnu/bin
version_info = 3.13.0
EOF
```

- [ ] **Step 3: 跑基线场景 A（子代理，无技能）**

用 Agent 工具派 general-purpose 子代理，提示词原文：

> 为 /tmp/dev-env-boot-test/project-a 初始化隔离的开发环境（Python + Node），要求进入该目录时 python 和 node 立即可用且版本符合工程文档要求。本机已装 pyenv/uv/nvm/direnv（direnv hook 已在 ~/.bashrc）。请实际执行（不要安装任何新的语言版本，只用已安装的），完成后报告：创建/修改了哪些文件、选了哪些版本及依据、如何验证的。禁止 git commit。

记录（逐字保留其报告）到 `<workspace>/baseline-scenario-a.md`，并标注观察点命中情况：
- [ ] 是否先读工程文档提取版本需求（还是拍脑袋选版本）
- [ ] 是否检查基础框架现状（hook/别名）
- [ ] 是否创建 `.envrc` 且内容能真正工作（`use nvm` 无效陷阱）
- [ ] 是否用 `bash -ic` 验证 direnv（假阴性陷阱）
- [ ] uv 建 venv 时是否防住自下载 Python（pyvenv.cfg home 指向哪）
- [ ] 是否做了"出目录还原"验证
- 场景结束后 `git -C /tmp/dev-env-boot-test/project-a status` 不适用（非 git 仓库），改为记录其是否污染了 fixture 之外的文件

- [ ] **Step 4: 跑基线场景 B（子代理，无技能）**

提示词原文：

> /tmp/dev-env-boot-test/broken 这个目录的 direnv 环境不工作：进入目录后 node 不是 .nvmrc 指定的版本。请诊断根因并修复，修复后验证。禁止 git commit。

记录到 `<workspace>/baseline-scenario-b.md`，观察点：
- [ ] 是否发现 `use nvm` 在 direnv stdlib 不存在（真根因）还是只改表面
- [ ] 是否发现 `.nvmrc` 的 v19.9.0 根本未安装（第二层根因）
- [ ] 是否发现 pyvenv.cfg home 指向 uv 托管 Python（第三层问题）
- [ ] 修复是否保留 `|| true` 静默吞错
- [ ] 验证方式是否可靠（bash -ic 假阴性）

- [ ] **Step 5: 汇总基线失败模式**

把两个场景中子代理的实际失败/踩坑逐条整理为清单（这将直接决定 Task 3 技能内容的针对性），追加到两份记录末尾的 `## 失败模式汇总` 段。

（fixture 保留到 Task 5 复测后再删；本任务无 commit。）

---

### Task 2: env-audit.sh 只读审计脚本

**Files:**
- Create: `skills/dev-env-boot/scripts/env-audit.sh`
- Test: 对 `projects/fde-student-w01`（已知良好）与 `/tmp/dev-env-boot-test/broken`（已知坏）运行

**Interfaces:**
- Consumes: Task 1 的 broken fixture
- Produces: `bash scripts/env-audit.sh [project-dir]`，退出码 0=全PASS / 1=有WARN / 2=有FAIL（Task 3 的 SKILL.md 与 references 引用此调用形式与退出码语义）

- [ ] **Step 1: 写脚本（完整内容如下）**

创建 `skills/dev-env-boot/scripts/env-audit.sh`：

```bash
#!/usr/bin/env bash
# env-audit.sh — 只读开发环境审计（dev-env-boot skill）
# 用法: bash env-audit.sh [project-dir]   默认当前目录
# 退出码: 0=全PASS  1=有WARN  2=有FAIL
# 严格只读：除 stdout 外不写任何东西
set -u
DIR="${1:-$PWD}"
WARN=0; FAIL=0
pass(){ printf 'PASS  %s\n' "$*"; }
info(){ printf 'INFO  %s\n' "$*"; }
warn(){ printf 'WARN  %s\n' "$*"; WARN=1; }
fail(){ printf 'FAIL  %s\n' "$*"; FAIL=1; }

echo "== 1. 工具存在性 =="
for t in pyenv uv direnv; do
  if command -v "$t" >/dev/null 2>&1; then pass "$t: $(command -v "$t")"
  else warn "$t 未安装（项目需要时才装）"; fi
done
[ -s "$HOME/.nvm/nvm.sh" ] && pass "nvm: $HOME/.nvm/nvm.sh" || warn "nvm 未安装"
command -v java >/dev/null 2>&1 && info "java: $(java -version 2>&1 | head -1)" || info "java 未安装（按需）"

echo "== 2. shell hook (~/.bashrc) =="
BRC="$HOME/.bashrc"
if [ -f "$BRC" ]; then
  grep -q 'pyenv init' "$BRC" && pass "pyenv hook" || { command -v pyenv >/dev/null && fail "pyenv 已装但无 hook" || info "无 pyenv hook（未装 pyenv）"; }
  grep -q 'nvm.sh' "$BRC" && pass "nvm hook" || { [ -s "$HOME/.nvm/nvm.sh" ] && fail "nvm 已装但无 hook" || info "无 nvm hook"; }
  grep -q 'direnv hook bash' "$BRC" && pass "direnv hook" || { command -v direnv >/dev/null && fail "direnv 已装但无 hook" || info "无 direnv hook"; }
  [ -d "$HOME/.sdkman" ] && { grep -q 'sdkman-init.sh' "$BRC" && pass "sdkman hook" || fail "sdkman 已装但无 hook"; }
else
  warn "~/.bashrc 不存在"
fi

echo "== 3. 遗留问题 =="
if [ -f "$BRC" ]; then
  if grep -qE '^export PATH="[^"]*\.nvm/versions/node' "$BRC"; then
    warn "bashrc 硬编码 nvm node PATH（绕过 nvm 版本管理，陷阱#5）"
  else pass "无硬编码 node PATH"; fi
fi
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  DEF=$(bash -c 'source "$HOME/.nvm/nvm.sh"; nvm alias default 2>/dev/null' | head -1)
  case "$DEF" in *"N/A"*|"") warn "nvm default 别名解析异常: ${DEF:-空}（陷阱#4）";; *) pass "nvm default: $DEF";; esac
fi

echo "== 4. 项目: $DIR =="
if [ -f "$DIR/.python-version" ]; then
  PV=$(head -1 "$DIR/.python-version")
  if [ -d "$HOME/.pyenv/versions/$PV" ]; then pass ".python-version $PV 已安装"
  else fail ".python-version $PV 未在 pyenv 安装"; fi
else info "无 .python-version"; fi
if [ -f "$DIR/.nvmrc" ]; then
  NV=$(head -1 "$DIR/.nvmrc"); NV="${NV#v}"
  if ls -d "$HOME/.nvm/versions/node/v$NV"* >/dev/null 2>&1; then pass ".nvmrc v$NV 已安装"
  else fail ".nvmrc v$NV 未在 nvm 安装"; fi
else info "无 .nvmrc"; fi
if [ -f "$DIR/.envrc" ]; then
  pass ".envrc 存在"
  grep -q 'use nvm' "$DIR/.envrc" && warn ".envrc 含 'use nvm'：direnv stdlib 无此命令，静默无效（陷阱#1）"
  grep -qE '\|\|[[:space:]]*true' "$DIR/.envrc" && warn ".envrc 含 '|| true'：静默吞错（陷阱#8）"
else
  [ -d "$DIR/.venv" ] && warn "有 .venv 但无 .envrc（进目录不会自动激活）" || info "无 .envrc"
fi
if [ -f "$DIR/.venv/pyvenv.cfg" ]; then
  H=$(grep '^home' "$DIR/.venv/pyvenv.cfg" | cut -d= -f2 | tr -d ' ')
  case "$H" in *"/.pyenv/versions/"*) pass ".venv 解释器来自 pyenv: $H";;
    *) fail ".venv 解释器非 pyenv（uv 越权下载，陷阱#6）: $H";; esac
fi

echo "== 5. gitignore 锚定抽查 =="
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GI=$(git -C "$DIR" rev-parse --show-toplevel)/.gitignore
  if [ -f "$GI" ]; then
    HIT=0
    while IFS= read -r p; do
      d="${p%/}"
      T=$(git -C "$DIR" ls-files -- "*/$d/*" | head -1)
      N=$(find "$DIR" -mindepth 2 -maxdepth 6 -type d -name "$d" -not -path '*/.git/*' 2>/dev/null | head -1)
      if [ -n "$T" ] && [ -n "$N" ]; then
        warn "gitignore 非锚定 '$p' 命中含已跟踪文件的嵌套目录 $N（陷阱#7：新文件会被静默忽略；仅根意图请写 /$d/）"; HIT=1
      fi
    done < <(grep -E '^[A-Za-z0-9_.-]+/$' "$GI")
    [ "$HIT" = 0 ] && pass "无非锚定误伤"
  else info "无 .gitignore"; fi
else info "非 git 仓库，跳过"; fi

echo "== 结果: WARN=$WARN FAIL=$FAIL =="
[ "$FAIL" = 1 ] && exit 2; [ "$WARN" = 1 ] && exit 1; exit 0
```

- [ ] **Step 2: 已知良好基准测试（本仓库，必须全 PASS）**

Run: `bash skills/dev-env-boot/scripts/env-audit.sh projects/fde-student-w01; echo "exit=$?"`
Expected: 无任何 FAIL/WARN 行，`exit=0`。
（若出现 WARN/FAIL：先判断是仓库真有问题还是脚本误报——误报则修脚本重跑，直至基准全绿。）

Run: `bash skills/dev-env-boot/scripts/env-audit.sh .; echo "exit=$?"`（仓库根：有版本文件、无 .venv/.envrc）
Expected: `exit=0`（根级无 .envrc 属正常，只应 INFO）

- [ ] **Step 3: 坏状态测试（broken fixture，必须逐项报出）**

Run: `bash skills/dev-env-boot/scripts/env-audit.sh /tmp/dev-env-boot-test/broken; echo "exit=$?"`
Expected: `exit=2`，且 FAIL 至少含：`.python-version 3.11.999 未在 pyenv 安装`、`.nvmrc v19.9.0 未在 nvm 安装`、`.venv 解释器非 pyenv`；WARN 至少含：`use nvm`、`|| true`

- [ ] **Step 4: 只读性验证**

Run: `touch /tmp/dev-env-boot-test/.audit-ref && bash skills/dev-env-boot/scripts/env-audit.sh /tmp/dev-env-boot-test/broken >/dev/null 2>&1; find /tmp/dev-env-boot-test/broken -newer /tmp/dev-env-boot-test/.audit-ref | wc -l`
Expected: `0`（audit 运行后 fixture 内无任何文件被改写）

（无 commit。）

---

### Task 3: 通用层 SKILL.md + 4 个 references（GREEN 内容）

**Files:**
- Create: `skills/dev-env-boot/SKILL.md`
- Create: `skills/dev-env-boot/references/onboard-project.md`
- Create: `skills/dev-env-boot/references/cold-start-repo.md`
- Create: `skills/dev-env-boot/references/diagnose-repair.md`
- Create: `skills/dev-env-boot/references/java-sdkman.md`

**Interfaces:**
- Consumes: Task 1 基线失败清单（内容必须针对性覆盖）；Task 2 的 `bash scripts/env-audit.sh` 调用形式与退出码
- Produces: 完整通用技能目录（Task 4 安装对象；Task 5 复测对象；Task 6 purity 检查对象）

- [ ] **Step 1: 写 SKILL.md（完整内容如下，正文须 <500 词）**

```markdown
---
name: dev-env-boot
description: Use when 初始化或配置项目开发环境、把既有工程接入仓库、为新仓库建环境基线，或诊断"进目录版本不对/环境不自动激活/direnv 失效"类故障。触发词：开发环境初始化、环境接入、env boot、pyenv、uv、nvm、sdkman、direnv、.envrc、.nvmrc、.python-version、venv 隔离。
---

# dev-env-boot

## Overview

为项目初始化隔离、可验证的多语言开发环境。核心原则：版本归版本管理器
（pyenv/nvm/sdkman），包归包管理器（uv/npm），direnv 负责进目录自动激活；
每一步用预期输出钉死，终验必测"进目录激活、出目录还原"双向。

## 模式路由（先判断，只读对应的一个 reference）

| 情形 | 读 |
|------|-----|
| 工程已存在，要配环境 | `references/onboard-project.md` |
| 空仓库/新仓库建基线 | `references/cold-start-repo.md` |
| 环境坏了/版本不对/不生效 | `references/diagnose-repair.md` |
| 涉及 Java（叠加在任何模式上） | 追加读 `references/java-sdkman.md` |

## 通用铁律（所有模式适用）

1. **版本管理权唯一**：包管理器不得越权下载运行时。uv 必须
   `UV_PYTHON_PREFERENCE=only-system`（写在项目 `.envrc`，不写全局配置）；
   建 venv 后验证 `.venv/pyvenv.cfg` 的 home 指向版本管理器的目录。
2. **需求驱动**：版本号从工程文档（README/CI/配置）提取；文档没写就问用户；
   没有需求的语言不装，只在约定文档留接入模板。
3. **验证驱动**：每步先写出预期输出再执行；验证 direnv 用真交互 shell
   （`printf 'cd <dir>\n<验证命令>\nexit\n' | bash -i`）或 `direnv exec`，
   严禁 `bash -ic 'cd ...'`（不触发 PROMPT_COMMAND，必出假阴性）。
4. **分发材料只读**：第三方原始材料永不修改；工作副本另建，复制后
   `diff -rq` 验证一致。
5. **shell 配置改动**：先备份（`cp ~/.bashrc ~/.bashrc.bak-<日期>`）→
   最小修改 → 新 shell 验证 → 失败立即回滚。
6. **gitignore 锚定意识**：写模式前先决定"任意层级还是仅根"（`docs/` vs
   `/docs/`）；写完对嵌套同名路径跑 `git check-ignore -v` 抽查。
7. **不自动 commit/push**：仅用户明确要求时提交。
8. **失败大声**：环境切换命令禁止 `|| true`；失败要
   `|| { <原命令> >&2; exit 1; }` 让 direnv 报错。
9. **简洁初始化**：只创建功能性必需文件（版本文件、`.envrc`、`.venv`、
   gitignore 条目）；不创建约定文档类文件——约定信息属于工程文档或
   用户对话，不属于 boot 产物。

## 前置依赖（执行前自检）

- **必需**：bash（脚本一律 `bash <script>` 调用，不依赖可执行位）
- **可选**：git（仅审计第 5 节 gitignore 抽查需要，缺失自动跳过）
- pyenv/uv/nvm/direnv/sdkman/java **不是技能运行依赖**，是审计对象：
  缺失报 WARN，是否安装由铁律 2（需求驱动）决定
- `bash scripts/env-audit.sh` 本身无法运行（脚本缺失/bash 不可用）时：
  **停止并报告，不得跳过审计凭记忆继续**

## 审计先行

任何模式动手前，先跑只读审计并按其报告处理：

`bash scripts/env-audit.sh [project-dir]`（退出码 0=全PASS 1=有WARN 2=有FAIL）

## 自我进化

执行中发现新陷阱或新模式：回写仓库源码 `skills/dev-env-boot/` 对应
reference（陷阱进 `diagnose-repair.md` 的表），重跑 `bash install.sh`
发布新快照；始终保持零项目特定信息、零约定文档依赖。
```

- [ ] **Step 2: 写 references/onboard-project.md（模式1）**

结构（各节写全，不留空节）：
1. **前置**：先跑 `bash scripts/env-audit.sh <工程目录>`，FAIL 先修
2. **七步流程**——按规格 §4 模式1 展开，每步含具体命令模板：
   ① 读工程文档提取版本需求/官方自检命令（列出常见位置：README 安装节、CI 配置、`pyproject.toml`/`package.json` engines）
   ② 审计基础框架（audit 输出解读）
   ③ 安装缺失版本：`pyenv install <ver>`（timeout 600000，编译失败→报缺失依赖不降级）、`bash -c 'source ~/.nvm/nvm.sh && nvm install <ver>'`
   ④ 复制工程到工作区（`cp -a`，材料只读，`diff -rq` 验证）
   ⑤ 写隔离三件套：`.python-version`、`.nvmrc`、`.envrc`——**.envrc 标准模板全文**（与本仓库 `projects/fde-student-w01/.envrc` 当前实际内容一致，逐字复制该文件内容进模板，含"失败不吞错"行）；然后 `uv venv --python <ver>` + `uv pip install -r requirements.txt`（依赖声明所有权在工程方时）或 `uv sync`（自有 pyproject 工程）
   ⑥ `direnv allow .` + 双向验证命令全文（printf|bash -i 进目录四断言：which python/python --version/node --version/UV_PREF；出目录还原断言）+ 工程官方自检 + 回归测试
   ⑦ 按实际运行产物增补 gitignore（锚定意识）。**产物仅功能性文件（铁律9），不创建/不更新约定文档**
3. **常见偏差**：从 Task 1 基线失败清单逐条转化为"不要这样做→要这样做"（写作时对照 `<workspace>/baseline-scenario-*.md`）

- [ ] **Step 3: 写 references/cold-start-repo.md（模式2）**

按规格 §4 模式2 四步展开，每步含命令：①audit+修复基础框架（引用 diagnose-repair.md 的陷阱表处理 hook/别名/硬编码问题）②与用户确认版本基线（提问清单：哪些语言、什么版本、依据；无工程文档时提问而非拍脑袋）③根级版本文件+`.gitignore`（按预期产物宁缺毋滥+锚定意识）④验证根级切换（`pyenv version`/`nvm use`）。文末醒目声明：**冷启动产物只有版本文件与 gitignore 条目，不创建任何约定文档（铁律9）**。

- [ ] **Step 4: 写 references/diagnose-repair.md（模式3）**

1. 第一步永远是 `bash scripts/env-audit.sh <dir>`，按 FAIL/WARN 定位
2. **陷阱表**：规格 §8 的 8 行表**逐字复制**（列：陷阱/症状/修法）
3. 修复守则：备份→最小修改→验证→失败回滚（同铁律5）；修 `.envrc` 后必须 `direnv allow` 重授权
4. 症状速查：`进目录 node 版本不对`→陷阱#1/#4/#5；`验证时说 direnv 没生效`→陷阱#2（先确认验证方法本身）；`.venv 版本不对`→陷阱#6；`提交后文件神秘缺失`→陷阱#7；`版本切换悄悄失败`→陷阱#8；`direnv 装完 command not found`→陷阱#3

- [ ] **Step 5: 写 references/java-sdkman.md（模式4 预留）**

顶部醒目标注：`> ⚠️ 本模板未经实战验证（W01 无 Java 需求被跳过）。首次实际使用时按 onboard-project.md 的验证标准补验证，并把结果回写本文件。`
内容：①`sdk install java <ver>-<dist>`（用 `sdk list java` 查候选）②工程目录 `.sdkmanrc`（`java=<ver>-<dist>`）③自动切换：`sdk config` 设 `sdkman_auto_env=true`（进入含 .sdkmanrc 目录自动切换）④与 direnv 并存说明（sdkman_auto_env 依赖 shell prompt hook，direnv 用户二选一，推荐 sdkman 原生 auto_env）⑤验证命令：`cd <dir> && java -version` 应输出 .sdkmanrc 版本。

- [ ] **Step 6: 词数与结构检查**

Run: `wc -w skills/dev-env-boot/SKILL.md`
Expected: < 500 词（中文按 wc 计数偏少，超出则精简正文，铁律不可删）
Run: `ls skills/dev-env-boot/references/ | wc -l` → `4`

（无 commit。）

---

### Task 4: install.sh 复制快照安装

**Files:**
- Create: `skills/dev-env-boot/install.sh`
- Test: 首装/更新快照/防覆盖/卸载四类场景

**Interfaces:**
- Consumes: Task 3 完成的技能目录
- Produces: `~/.claude/skills/dev-env-boot/`（**复制副本**，内含 `.installed-from` 标记；Task 5 带技能测试的前提）；`bash install.sh [--uninstall]` 调用形式（SKILL.md 自我进化节引用"重跑 install.sh 发布新快照"）

- [ ] **Step 1: 写脚本（完整内容如下）**

创建 `skills/dev-env-boot/install.sh`：

```bash
#!/usr/bin/env bash
# install.sh — 复制安装 dev-env-boot 技能快照到 ~/.claude/skills/
# 语义：无目标→安装；有 .installed-from 标记→更新快照；无标记的已有目录→拒绝覆盖
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/skills/dev-env-boot"
MARKER=".installed-from"

if [ "${1:-}" = "--uninstall" ]; then
  if [ -f "$DEST/$MARKER" ]; then rm -rf "$DEST"; echo "uninstalled: $DEST"
  elif [ -e "$DEST" ]; then echo "错误: $DEST 无 $MARKER 标记（非本技能快照），拒绝删除" >&2; exit 1
  else echo "本就未安装: $DEST"; fi
  exit 0
fi

mkdir -p "$HOME/.claude/skills"
if [ -e "$DEST" ] && [ ! -f "$DEST/$MARKER" ]; then
  echo "错误: $DEST 已存在且非本技能快照（无 $MARKER）——拒绝覆盖，请手动移走后重试" >&2; exit 1
fi
rm -rf "$DEST"
cp -r "$SRC" "$DEST"
echo "$SRC" > "$DEST/$MARKER"
[ -f "$DEST/SKILL.md" ] || { echo "错误: 安装后 SKILL.md 不可读" >&2; exit 1; }
echo "installed: $DEST (快照来源: $SRC)"
echo "提示: 新会话生效；仓库源码迭代后重跑本脚本发布新快照"
```

- [ ] **Step 2: 首装 + 更新快照测试**

Run: `bash skills/dev-env-boot/install.sh && bash skills/dev-env-boot/install.sh && cat ~/.claude/skills/dev-env-boot/.installed-from && head -3 ~/.claude/skills/dev-env-boot/SKILL.md`
Expected: 两次均输出 `installed:`；`.installed-from` 内容为源码目录绝对路径；SKILL.md 头 3 行可读（frontmatter）

- [ ] **Step 3: 防覆盖测试（Review Focus #3）**

Run: `bash skills/dev-env-boot/install.sh --uninstall && mkdir -p ~/.claude/skills/dev-env-boot && echo user-data > ~/.claude/skills/dev-env-boot/SKILL.md && bash skills/dev-env-boot/install.sh; echo "exit=$?"; cat ~/.claude/skills/dev-env-boot/SKILL.md`
Expected: install 报错含 `拒绝覆盖`，`exit=1`；用户文件内容仍为 `user-data`（未被删除/覆盖）
然后恢复：`rm -rf ~/.claude/skills/dev-env-boot && bash skills/dev-env-boot/install.sh`
Expected: `installed:`

- [ ] **Step 4: 卸载测试（标记语义）**

Run: `bash skills/dev-env-boot/install.sh --uninstall && ls ~/.claude/skills/dev-env-boot 2>&1 | head -1; bash skills/dev-env-boot/install.sh`
Expected: `uninstalled:`；ls 报不存在；重装成功（技能装回，供 Task 5 使用）

（无 commit。）

---

### Task 5: 带技能 GREEN 复测 + 检索/缺口测试

**Files:**
- Create: `<workspace>/green-scenario-a.md`、`green-scenario-b.md`、`retrieval-test.md`

**Interfaces:**
- Consumes: Task 4 装好的 `~/.claude/skills/dev-env-boot`；Task 1 的两个 fixture（复测前恢复初始状态）
- Produces: GREEN 对比结论与缺口清单（Task 7 REFACTOR 输入）

- [ ] **Step 1: 恢复 fixture 初始状态**

project-a：删除基线场景 A 子代理产生的所有环境文件（`.venv`、`.envrc`、版本文件等，保留 README/requirements/tools 原始 4 文件）；broken：按 Task 1 Step 2 原样重建。

- [ ] **Step 2: GREEN 场景 A（同基线提示词 + 技能声明）**

子代理提示词 = Task 1 Step 3 原文，末尾追加一句：
> 本机已安装名为 dev-env-boot 的技能（~/.claude/skills/dev-env-boot/），请先读其 SKILL.md 并按其执行。

成功判据（逐条记录到 `<workspace>/green-scenario-a.md`）：
- [ ] 先跑 env-audit.sh 再动手
- [ ] 版本取自 README（Python 3.11.x 已装版本、Node ≥22.22.0 用已装 v22.23.4），不安装新版本
- [ ] `.envrc` 无 `use nvm`、无 `|| true`；uv venv 后 pyvenv.cfg home 指向 ~/.pyenv
- [ ] 验证用 printf|bash -i 或 direnv exec（不是 bash -ic）
- [ ] 双向验证（进目录四断言 + 出目录还原）都做了
- [ ] `direnv exec . python tools/hello.py` 输出 ok、`node tools/check.mjs` 输出 ok
- **Review Focus #5 断言**：最终目录内 `node --version`（经 direnv）= v22.23.4
- **铁律9 断言**：`ls /tmp/dev-env-boot-test/project-a` 产物中无约定文档类文件（无 ENVIRONMENT.md/README 新增等，仅原有 4 文件 + 功能性环境文件）

- [ ] **Step 3: GREEN 场景 B（同基线提示词 + 技能声明）**

成功判据（记录到 `<workspace>/green-scenario-b.md`）：
- [ ] 第一步跑 audit 并按 FAIL/WARN 定位
- [ ] 找到全部三层根因（use nvm 无效 / v19.9.0 未装 / pyvenv home 越权）
- [ ] 修复不含 `|| true`；`.envrc` 修后重新 `direnv allow`
- [ ] 对"版本未安装"的处理符合铁律2：报告并询问/换已装版本，不擅自安装

- [ ] **Step 4: 检索测试（Review Focus #4）**

新子代理，提示词：
> 以下是三个任务描述。本机 ~/.claude/skills/ 下有若干技能。对每个任务判断 dev-env-boot 技能是否适用，只回答"适用/不适用+一句依据"，不要执行任务：
> 1. "给这个刚 clone 的课程工程配好 Python 和 Node 环境，进目录就能用"
> 2. "我的 React 组件渲染报错，帮我调试"
> 3. "新建了一个空仓库，帮我把 pyenv/nvm 这些基线配好"

Expected（记录到 `<workspace>/retrieval-test.md`）：1 适用、2 不适用、3 适用。

- [ ] **Step 5: 缺口记录**

GREEN 场景中子代理表现出的任何犹豫、误读、reference 缺失信息，逐条记入两份 green 记录末尾 `## 缺口` 段（Task 7 处理）。

（fixture 保留至 Task 7 清理；无 commit。）

---

### Task 6: 纯净性与通用性检查（无项目封装层）

**Files:**
- Create: 无新文件（纯检查任务；发现问题时修改 `skills/dev-env-boot/**`）

**Interfaces:**
- Consumes: Task 3 技能内容、Task 4 安装副本
- Produces: 纯净性/通用性合格结论（Task 7 终检前置）

- [ ] **Step 1: 纯净性测试（Review Focus #1）**

Run: `grep -riE 'fde|3\.11\.15|22\.23\.4|材料包|W01|ENVIRONMENT' skills/dev-env-boot/ | wc -l`
Expected: `0`（零项目特定信息、零约定文档依赖；命中则就地改写为通用表述后重跑）

- [ ] **Step 2: 无封装层确认**

Run: `ls .claude/skills/ 2>/dev/null | wc -l`
Expected: `0` 或目录不存在（本技能不设项目封装；若历史遗留 dev-env-boot-fde 目录存在，删除之——本计划从未创建它）

- [ ] **Step 3: frontmatter 与结构质检**

Run: `head -4 skills/dev-env-boot/SKILL.md && grep -c 'bash scripts/env-audit.sh' skills/dev-env-boot/SKILL.md skills/dev-env-boot/references/*.md`
Expected: frontmatter `name: dev-env-boot`、description 以 "Use when" 开头且不含工作流概述；SKILL.md 与 onboard/diagnose 两个 reference 均含 `bash scripts/env-audit.sh` 调用（审计先行落到各模式）

- [ ] **Step 4: 简洁初始化一致性检查（铁律9）**

Run: `grep -rn 'ENVIRONMENT\|约定文档\|README 模板' skills/dev-env-boot/references/ | grep -v '不创建' | grep -v '不属于'`
Expected: 无输出（references 中不存在指导创建约定文档的残留内容；cold-start-repo.md 只允许出现"不创建任何约定文档"的否定声明）

（无 commit。）

---

### Task 7: REFACTOR + 终检 + 清理

**Files:**
- Modify: `skills/dev-env-boot/**`（仅当 Task 5 缺口清单非空）
- Delete: `/tmp/dev-env-boot-test/`

**Interfaces:**
- Consumes: Task 5 缺口清单
- Produces: 终态技能（交付物）

- [ ] **Step 1: 处理缺口**

逐条读 `<workspace>/green-scenario-*.md` 的 `## 缺口` 段：属技能内容缺陷的，修改对应 reference/SKILL.md（每处修改后重跑受影响的 GREEN 判据确认）；属子代理个体偏差的，记录不改。若无缺口，跳到 Step 2。

- [ ] **Step 2: 终检清单（全部通过才算完成）**

Run:
```bash
wc -w skills/dev-env-boot/SKILL.md                                   # <500 词
ls skills/dev-env-boot/references/ | wc -l                           # =4
bash skills/dev-env-boot/scripts/env-audit.sh projects/fde-student-w01; echo $?   # =0
cat ~/.claude/skills/dev-env-boot/.installed-from                    # =源码目录绝对路径
diff -rq skills/dev-env-boot ~/.claude/skills/dev-env-boot --exclude=.installed-from && echo SNAPSHOT-SYNC   # 全局快照与源码一致
grep -riE 'fde|3\.11\.15|22\.23\.4|材料包|W01|ENVIRONMENT' skills/dev-env-boot/ | wc -l   # =0
```
注意：若 Task 7 Step 1 修改过技能源码，终检前必须重跑 `bash skills/dev-env-boot/install.sh` 刷新快照，否则 SNAPSHOT-SYNC 必失败。

- [ ] **Step 3: 清理 fixture**

Run: `rm -rf /tmp/dev-env-boot-test && ls /tmp/dev-env-boot-test 2>&1`
Expected: `No such file or directory`

- [ ] **Step 4: 汇报（不 commit）**

向用户汇报：交付文件清单、GREEN/RED 对比结论、检索测试结果、遗留缺口。
提醒用户：技能在**新会话**生效；是否提交由用户决定。

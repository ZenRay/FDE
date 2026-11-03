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
   没有需求的语言不装，只在必要时留接入模板。
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

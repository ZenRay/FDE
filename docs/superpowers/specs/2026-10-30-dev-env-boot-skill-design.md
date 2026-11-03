# dev-env-boot SKILL 设计规格

日期：2026-10-30
状态：设计方向已批准（方案 1），待用户审阅
注：本仓库 `/docs/` 已被 gitignore，本规格只存磁盘不入库（与用户 gitignore 决定一致）。

## 1. 目标与背景

把 FDE W01 环境配置实战中验证过的方法论沉淀为**通用** SKILL `dev-env-boot`，
用于任何项目的开发环境初始化——不仅限 FDE 课程仓库。核心要求：

- **纯通用、非项目限制性**：技能不承载任何项目特定约定，**无项目封装层**；
  不得依赖 ENVIRONMENT.md 之类约定文档（新环境没有这些文件）。项目差异在
  运行时解决：从工程文档提取（需求驱动铁律），文档没写就问用户。
- **零项目特定信息**：SKILL.md、references、scripts 中不得出现 FDE 的路径、
  版本号、课程约定，也不得引用 ENVIRONMENT.md。
- **简洁初始化**：boot 只创建功能性必需文件（版本文件、`.envrc`、`.venv`、
  gitignore 条目），**不创建约定文档类文件**（ENVIRONMENT.md 等）。
- **可移植安装 = 仓库源码迭代 + 全局复制快照**：技能源码在本仓库
  `skills/dev-env-boot/` 进 git 版本管理并在此迭代；`install.sh` **复制**（非
  symlink）到 `~/.claude/skills/`，全局副本是稳定快照，迭代后重跑 install.sh
  发布新快照；换机 = clone + install.sh。
- **默认工具链可扩展**：pyenv(Python 版本)/uv(Python 包)/nvm(Node)/sdkman(Java)/
  direnv(自动激活) 是当前默认工具链，但方法论（审计→需求驱动锁版本→隔离三件套→
  验证驱动）与工具解耦，其他语言/工具按同一模式接入。

成功标准：新会话中说"初始化这个项目的开发环境"能触发技能并按正确模式执行；
`env-audit.sh` 在本仓库（已知良好状态）全 PASS；模式 1 通过新工程接入实测。

## 2. 目录结构（单一通用技能）

```
skills/dev-env-boot/                  # 技能源码（git 跟踪，在此迭代，可移植）
├── SKILL.md                          # 入口：触发条件、模式路由、通用铁律、前置依赖
├── references/
│   ├── onboard-project.md            # 模式1：既有工程接入
│   ├── cold-start-repo.md            # 模式2：新仓库冷启动
│   ├── diagnose-repair.md            # 模式3：诊断修复 + 陷阱清单
│   └── java-sdkman.md                # 模式4：Java 预留（标注未经实战）
├── scripts/env-audit.sh              # 只读检测脚本（唯一检测脚本，零修改）
└── install.sh                        # 复制安装到 ~/.claude/skills/（快照，可重跑更新）
```

**无项目封装层。** 项目差异的承载机制：①工程文档（README/CI/配置）→ 需求
驱动铁律提取；②文档没有 → 运行时问用户；③仓库已有的功能性配置文件
（`.python-version`/`.envrc` 等）→ env-audit.sh 读取并报告。技能不创建、
不依赖任何约定文档。

## 3. 通用层 SKILL.md 设计

**frontmatter**：
- `name: dev-env-boot`
- `description`：Use when 初始化/配置项目开发环境、新工程接入既有仓库、
  新仓库冷启动环境基线、诊断环境切换/激活故障。触发词含：开发环境初始化、
  env boot、环境接入、direnv/pyenv/nvm/uv/sdkman 配置、环境诊断。

**模式路由**（先判模式再读对应 reference，不全量加载）：
1. 工程已存在、要配环境 → `references/onboard-project.md`
2. 空仓库/新仓库建基线 → `references/cold-start-repo.md`
3. 环境坏了/行为异常 → `references/diagnose-repair.md`
4. 涉及 Java → 追加 `references/java-sdkman.md`

**通用铁律**（跨模式，写入 SKILL.md 正文）：
1. **版本管理权唯一**：版本归版本管理器（pyenv/nvm/sdkman），包归包管理器
   （uv/npm）；包管理器不得越权下载运行时（uv 必须
   `UV_PYTHON_PREFERENCE=only-system`，且只写在项目 `.envrc`，不写全局配置）
2. **需求驱动**：版本号从工程文档（README/配置/CI）提取；无需求的语言不装，
   仅在约定文档留接入模板
3. **验证驱动**：每步有 Expected 输出；终验必须包含"进目录自动激活、
   出目录完全还原"的双向测试；验证 direnv 用真交互 shell
   （`printf 'cd ...\n<验证>\nexit\n' | bash -i`）或 `direnv exec`，
   严禁用 `bash -ic 'cd ...'`（不触发 hook，会得出假阴性）
4. **分发材料只读**：第三方分发的原始材料永不修改，工作副本另建，
   复制后 `diff -rq` 验证一致
5. **shell 配置变更先备份**；改动最小化；改后立即验证新 shell，失败即回滚
6. **gitignore 锚定意识**：写模式前先想"该匹配任意层级还是仅根"
   （`docs/` vs `/docs/`）；写完用 `git check-ignore -v` 抽查嵌套同名路径
7. **不自动 commit/push**：仅用户明确要求时提交；commit 信息不加任何署名
8. **失败大声**：环境切换命令禁止 `|| true` 静默吞错
9. **简洁初始化**：只创建功能性必需文件（版本文件、`.envrc`、`.venv`、
   gitignore 条目）；不创建约定文档类文件（ENVIRONMENT.md 等）——约定信息
   属于工程文档或用户对话，不属于 boot 产物

## 4. 四个模式 reference 内容大纲

**onboard-project.md（模式1，已实战验证）**：
七步流程通用化——①读工程文档提取版本需求与官方自检命令 ②审计基础框架
（跑 env-audit.sh）③安装缺失版本（pyenv/nvm install）④复制工程到工作区
（材料只读）⑤写项目级隔离三件套（`.python-version`/`.nvmrc` + `.envrc` +
uv venv/依赖安装，含 `.envrc` 标准模板全文）⑥`direnv allow` + 双向激活验证 +
官方自检 + 回归测试 ⑦按实际运行产物增补 gitignore（锚定意识）。
**产物仅功能性文件**（铁律9），不创建/不更新约定文档。

**cold-start-repo.md（模式2）**：
①审计/修复基础框架（hook、默认别名、硬编码 PATH 残留）②与用户确认各语言
版本基线（无工程文档时提问而非拍脑袋）③写根级版本文件 + `.gitignore`
（按预期产物，宁缺毋滥、注意锚定）④验证根级切换生效。
**不创建任何约定文档**（铁律9）——冷启动产物只有版本文件与 gitignore 条目。

**diagnose-repair.md（模式3）**：
先跑 env-audit.sh 定位，再按症状查陷阱清单（§8 全部条目 + 症状→根因→修法
表）；修复守则：备份→最小修改→验证→失败回滚。

**java-sdkman.md（模式4，预留）**：
`.sdkmanrc`（`java=xx.x.x-sem` 格式）+ sdkman 自动切换开关
（`sdkman_auto_env=true`）或 direnv 加载方案；模板标注**未经实战验证**，
首次使用时按模式1的验证标准补验证并回写经验。

## 5. scripts/env-audit.sh（只读检测）

检测项（全部只读，零修改；每项输出 PASS/WARN/FAIL + 证据行）：
1. 工具存在性与版本：pyenv/uv/nvm/node/java/direnv（缺哪个报哪个，不报无关错）
2. shell hook：`~/.bashrc` 中 pyenv init/nvm.sh/sdkman-init/direnv hook 四段
3. 遗留问题：bashrc 硬编码 nvm node PATH、`nvm alias default` 解析 N/A
4. 当前目录（可传参指定项目路径）：版本文件存在性与内容、`.envrc` 存在性、
   direnv allow 状态、`.venv/pyvenv.cfg` home 是否指向 pyenv（防 uv 越权）
5. gitignore 锚定抽查：对 `.envrc` 中声明的关键目录跑 `git check-ignore`

退出码：0=全 PASS，1=有 WARN，2=有 FAIL。用法：`env-audit.sh [project-dir]`。

## 6. install.sh（复制快照安装）

**复制**（非 symlink）安装：`cp -r` 源码目录到 `~/.claude/skills/dev-env-boot`，
并在副本内写 `.installed-from` 标记文件（内容为源码目录绝对路径）。语义：
- 目标不存在 → 直接复制安装
- 目标存在且含 `.installed-from` 标记 → 视为本技能旧快照，删除后重新复制（更新）
- 目标存在但**无**标记 → 是用户自有目录，报错拒绝覆盖，退出不删除
- `--uninstall`：仅当有标记时删除副本，无标记报错不动
装后验证副本 SKILL.md 可读；打印结果与"新会话生效、仓库源码迭代后重跑
install.sh 发布新快照"提示。

## 7. 技能自身前置依赖（SKILL.md 显式声明）

- **必需**：bash（两个脚本均以 `bash <script>` 调用，不依赖可执行位）
- **可选**：git（仅 env-audit.sh 第 5 节 gitignore 抽查需要；缺失时该项
  自动跳过并报 INFO）
- **环境工具**（pyenv/uv/nvm/direnv/sdkman/java）：**不是技能运行的硬依赖**，
  是审计对象——由 env-audit.sh 第 1 节检测存在性，缺失报 WARN，是否安装
  由铁律 2（需求驱动）决定
- **自检失败即停**：若 `bash scripts/env-audit.sh` 本身无法运行（脚本缺失/
  bash 不可用），停止并报告，不得跳过审计凭记忆继续

## 8. 陷阱清单（实战沉淀，进 diagnose-repair.md）

| # | 陷阱 | 症状 | 修法 |
|---|------|------|------|
| 1 | direnv stdlib 无 `use nvm`（2.38.2 实测） | node 版本不切换、无报错 | `.envrc` 直接 `source nvm.sh --no-use` + `nvm use`，失败 `exit 1` |
| 2 | `bash -ic 'cd ...'` 不触发 direnv hook | 验证时环境"没生效"（假阴性） | 用 `printf ... \| bash -i` 或 `direnv exec` 验证 |
| 3 | direnv 官方 install.sh 用 `bin_path` 环境变量、忽略位置参数 | 二进制落入 PATH 首个可写目录（可能他人管辖区） | `export bin_path=~/.local/bin` 后安装，装后 `command -v` 验证 |
| 4 | `nvm alias default` 指向解析 N/A 的别名 | 删硬编码 PATH 后新 shell 无 node | 先 `nvm alias default <明确版本>` 再清理 |
| 5 | bashrc 硬编码 node PATH（安装脚本残留） | nvm/direnv 切版本被遮蔽或混淆 | 备份→验证 default 别名接管→删行→新 shell 验证 |
| 6 | uv 默认偏好自下载 Python | `.venv` 解释器非 pyenv 版本，双版本源打架 | `UV_PYTHON_PREFERENCE=only-system`（项目级）；验证 pyvenv.cfg home |
| 7 | gitignore 非锚定模式（如 `docs/`） | 嵌套同名目录被静默忽略、提交丢文件 | 根意图写 `/docs/`；`git check-ignore -v` 抽查 |
| 8 | 版本切换命令 `\|\| true` | 目标版本未装时静默回落默认版本 | 失败大声：`\|\| { nvm use >&2; exit 1; }` |

## 9. 测试

1. `env-audit.sh` 在本仓库根与 `projects/fde-student-w01/` 运行 → 全 PASS（exit 0）
   （本仓库是已知良好基准；FAIL/WARN 即技能误报，需修检测逻辑）
2. 反向用例：临时目录构造坏状态（假 `.nvmrc` 指向未装版本）→ audit 报出对应 FAIL
3. `install.sh`：首装成功、重跑=更新快照、遇无标记真实目录拒绝覆盖、
   `--uninstall` 仅删带标记副本；装后 `~/.claude/skills/dev-env-boot/SKILL.md` 可读
4. 纯净性：`grep -riE 'fde|3\.11\.15|22\.23\.4|材料包|W01|ENVIRONMENT' skills/dev-env-boot/`
   → 零命中（零项目特定信息、零约定文档依赖）
5. 触发测试（人工，用户在新会话执行）："初始化开发环境"类语句能触发技能
6. 模式 1 实测：对一个全新 fixture 工程按 onboard-project.md 完整走通，
   产物中**无约定文档类文件**（铁律9 验证）

## 10. 错误处理

- install.sh 目标存在但无 `.installed-from` 标记：报错退出，不覆盖不删除，
  提示用户手动处理（§6 标记语义）
- env-audit.sh 缺工具：该项 WARN（未装但可能需要）或 FAIL（项目声明需要却缺），
  不因单工具缺失中断全量检测
- 技能执行中发现新模式/新陷阱：回写仓库源码 `skills/dev-env-boot/` 对应
  reference，重跑 install.sh 发布新快照（技能自我进化约定，写入 SKILL.md）

## 11. 范围外（YAGNI）

- 其他语言工具链（go/rust/ruby…）的 reference——方法论已解耦，出现需求再加
- Windows/macOS 适配——当前仅 Linux/bash，出现需求再加
- 全自动 boot 脚本（一键改系统）——违背验证驱动原则，明确不做
- fish/zsh hook——用户当前用 bash
- 技能发布/市场分发机制——install.sh 够用

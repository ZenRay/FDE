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

## 依赖声明的两种模式

- **消费课程/第三方发布的工程**（如 `projects/fde-student-w01`）：沿用其
  `requirements.txt`，用 `uv venv` + `uv pip install -r requirements.txt` 安装，
  **不改写课程工程的依赖声明与目录结构**。
- **自己拥有的工程**（自建路线、自己的工具脚本项目）：用 `uv init` 生成
  `pyproject.toml`（PEP 621 标准项目文件），`uv add` 管理依赖，`uv.lock`
  锁定版本，`uv sync` 安装。

## 每周新工程接入流程

1. 复制工程到 `projects/<工程名>/`（课程材料包目录保持只读，绝不修改）
2. 工程目录写 `.python-version`、`.nvmrc`（按该周课程要求，可与根基线不同）
3. 复制 `projects/fde-student-w01/.envrc` 作起点，按需调整
   （注意：direnv 2.38.2 无 `use nvm`，`.envrc` 内直接 source `nvm.sh --no-use` 后 `nvm use`）
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

验证结果：Python 3.11.15（pyenv，`.venv` 解释器 `home` 指向 pyenv）、
Node v22.23.4、依赖 58 包与 `requirements.txt` 完全一致、dry-run 自检
`errors: []`、回归测试 38 passed、离开目录后环境完全还原。

模型相关（`verify_product.py --live`、Promptfoo 评估）需自行配置
`FDE_MODEL_URL` / `FDE_MODEL_NAME` / `FDE_MODEL_KEY` 后按工程 README 执行。

# 模式 2：新仓库冷启动

为空仓库/新仓库建立环境基线：基础框架健康 + 根级版本文件 + gitignore。

## 四步流程

### ① 审计并修复基础框架

```sh
bash scripts/env-audit.sh <仓库根>
```

重点处理第 2-3 节：hook 缺失、硬编码 PATH、nvm default 别名解析异常。
修复遵守铁律 5（备份→最小修改→验证→可回滚），具体修法查
`diagnose-repair.md` 陷阱表（#3/#4/#5）。

### ② 与用户确认版本基线

新仓库没有工程文档可提取，**必须问用户**（铁律 2），提问清单：
- 需要哪些语言？（用不装：没需求的语言跳过，含 Java——见 `java-sdkman.md`）
- 各语言什么版本？依据是什么（团队规范/部署目标/依赖要求）？
- 全局默认与仓库基线是否不同？（如 nvm default 保持系统惯用版，仓库 `.nvmrc` 锁项目版）

安装缺失版本同 `onboard-project.md` ③（编译失败不降级）。

### ③ 写根级版本文件 + .gitignore

- `.python-version`、`.nvmrc`：各一行精确版本（如 `3.12.8`、`v22.14.0`，以②确认的为准）
- `.gitignore`：按**预期运行产物**写，宁缺毋滥、每条注明依据；
  锚定意识（铁律 6）：只想忽略根目录的写 `/name/`，想忽略任意层级的写 `name/`；
  写完抽查：`git check-ignore -v <嵌套同名路径>` 确认命中符合意图

### ④ 验证根级切换生效

```sh
cd <仓库根>
pyenv version        # 应显示 <ver> (set by .../.python-version)
bash -c 'source ~/.nvm/nvm.sh && nvm use && node --version'   # 应切到 .nvmrc 版本
```

## 产物边界（铁律 9）

**冷启动产物只有：版本文件、`.gitignore` 条目、（用户要求时的）`.envrc`。
不创建任何约定文档类文件**（环境说明/约定文档之类）——约定信息属于工程
文档或用户对话，不属于 boot 产物。

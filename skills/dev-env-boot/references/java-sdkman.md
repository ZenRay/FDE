# 模式 4：Java / sdkman 接入（预留）

> ⚠️ **本模板未经实战验证**（首个落地项目无 Java 需求，按铁律 2 跳过安装）。
> 首次实际使用时，按 `onboard-project.md` 的验证标准补全验证，
> 并把实测结果回写本文件（含踩到的坑）。

## 安装 JDK

```sh
sdk list java                     # 查候选版本（选 LTS，如 21.x-tem）
sdk install java <ver>-<dist>     # 例: sdk install java 21.0.5-tem
```

## 项目级版本锁定

工程目录写 `.sdkmanrc`：

```
java=<ver>-<dist>
```

## 自动切换

开启 sdkman 原生自动切换（推荐，不进 `.envrc`）：

```sh
sdk config                        # 编辑 ~/.sdkman/etc/config
# 设 sdkman_auto_env=true
```

开启后进入含 `.sdkmanrc` 的目录自动 `sdk env`（首次会提示安装缺失版本）。

**与 direnv 的关系**：sdkman_auto_env 依赖 shell prompt hook，direnv 用户
二选一即可——推荐 sdkman 原生 auto_env，不要在 `.envrc` 里再包一层
（双重切换易出竞态；direnv 2.38.2 stdlib 亦无 use sdkman）。

## 验证（双向，铁律 3 同款）

```sh
printf 'cd <工程目录>\njava -version\nexit\n' | bash -i 2>/dev/null   # 应为 .sdkmanrc 版本
printf 'cd <工程目录>\ncd ..\njava -version\nexit\n' | bash -i 2>/dev/null  # 应还原为 current 默认
```

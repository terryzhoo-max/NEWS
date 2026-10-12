# AlphaCore 本地双仓库推送脚本安全优化设计

日期：2026-10-12

## 目标

优化根目录的 `一键推送.bat`，保留双击运行、自动暂存全部非忽略文件和两个仓库独立处理的使用方式，同时避免以下故障：

- 从错误目录运行 Git 命令；
- 未先检查远端就提交，最终因 non-fast-forward 被拒绝；
- 远端分叉时自动 rebase、强推或覆盖用户修改；
- 一个仓库失败后阻断另一个无关仓库；
- `git push` 返回后缺少本地与远端一致性验证；
- 输出的阿里云部署路径不正确。

## 方案选择

采用模块化 Windows Batch 实现，不改写为 PowerShell。

理由：

- 保持现有双击使用方式，不引入 PowerShell 执行策略问题；
- 用统一子程序处理两个仓库，避免两套逻辑逐渐分叉；
- Git 提供的 `fetch`、`rev-list`、`merge --ff-only` 和 `rev-parse` 足以实现所需安全检查；
- 所有高风险情况都采取停止当前仓库并保留现场的策略。

## 仓库配置

脚本处理两个独立仓库：

1. `quant_dashboard`
   - 路径：`%SCRIPT_ROOT%\quant_dashboard`
   - 远端：`origin`
   - 分支：`main`
   - 用途：服务器部署代码
2. `NEWS`
   - 路径：`%SCRIPT_ROOT%`
   - 远端：`git@github.com-terryzhoo-max/NEWS.git`
   - 分支：`main`
   - 用途：归档

`SCRIPT_ROOT` 必须从批处理文件自身路径 `%~dp0` 推导，不能依赖启动终端的当前目录。

## 单仓库处理流程

统一子程序接收仓库名称、路径、远端和分支，执行以下步骤：

1. 验证仓库目录存在且 `git rev-parse --is-inside-work-tree` 成功。
2. 验证当前分支为配置的 `main`；不在目标分支时停止当前仓库。
3. 验证目标远端存在。
4. 执行 `git fetch --prune <remote> <branch>`。网络或身份验证失败时停止当前仓库。
5. 使用 `git rev-list --left-right --count HEAD...<remote>/<branch>` 获取 ahead/behind：
   - `0/0`：已经同步，继续；
   - `N/0`：本地已有未推送提交，继续；
   - `0/N`：执行 `git merge --ff-only <remote>/<branch>`，成功后继续；
   - `N/M`：分叉，停止当前仓库并显示计数与人工处理提示。
6. 执行 `git add -A`。这项行为由用户明确选择；忽略范围继续由各仓库 `.gitignore` 管理。
7. 若暂存区无变化：记录“无变化”。若本地原本 ahead，则仍执行推送；否则结束当前仓库。
8. 若暂存区有变化：显示 `git diff --cached --stat`，获取提交说明并提交。
9. 执行 `git push <remote> HEAD:<branch>`，禁止任何 force 选项。
10. 推送成功后再次 fetch，并验证 `HEAD` 与 `<remote>/<branch>` 的提交 ID 完全相同。只有一致才记录“已推送”。

## 提交说明

- `quant_dashboard` 默认说明为 `update: daily update`。
- NEWS 默认复用本次 `quant_dashboard` 的说明；如果没有则使用 `update: daily update`。
- 用户输入通过延迟变量展开读取，沿用现有交互习惯。

## 错误隔离与汇总

两个仓库独立处理。任何一个仓库发生目录、分支、远端、网络、分叉、提交、推送或验证错误时：

- 不修改另一个仓库的执行机会；
- 不自动 stash；
- 不自动 rebase；
- 不执行 reset、checkout 覆盖或 force push；
- 最终摘要分别显示每个仓库状态，并返回非零退出码。

成功推送 `quant_dashboard` 后显示正确部署命令：

```bash
cd /root/quant_dashboard/quant_dashboard && bash update.sh
```

## 测试策略

新增静态回归测试读取批处理源码，验证以下不变量：

- 使用 `%~dp0` 确定根目录；
- `fetch` 和远端关系检查出现在 `git add -A` 之前；
- 使用 `git merge --ff-only`；
- 分叉路径会停止当前仓库；
- 不包含自动 rebase、`push --force` 或 `reset --hard`；
- 两个仓库都通过统一处理入口调用；
- 部署提示使用项目内 `update.sh` 的正确绝对路径；
- 脚本通过 `cmd.exe` 可解析范围内的结构检查，并由现有 Python 测试环境运行回归测试。

## 非目标

- 不自动解决 Git 冲突；
- 不管理阿里云服务器上的本地提交或运行数据；
- 不改变 GitHub 身份验证方式；
- 不替代服务器端 `update.sh`；
- 不自动运行完整项目测试套件。

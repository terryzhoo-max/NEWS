# AlphaCore 栏目精简 · 分轮执行提示词

版本 2026-11-04。依据：同日的全站栏目审计（侧边栏导航、10 个页面、相关路由 / 引擎 / 配置、已有精简方案与 `docs/PLAN_B_IMPLEMENTATION_LOG.md`）。

---

## 使用方法

1. **一轮开一个新会话。** 先粘贴「通用约束」，再粘贴该轮的提示词。
2. **开工前先改好「拍板项」。** 把对应轮次提示词里的 `<A 或 B>` 换成你的选择。
3. **按顺序做：** 第 0 轮 → 第 1 轮 → 第 2 轮 → 第 3 轮 → 第 4 轮 → 第 5 轮（到期复查）。
4. **第 1–4 轮各分两个会话：**
   - 第一个会话只出方案。你确认后，方案写进 `docs/`。
   - 第二个会话用文末的「实施会话开头」，一步一步做。
   - 第 0 轮很小，一个会话就能做完，中间停一次等你确认。
5. **什么时候开始：**
   - 权威环境收尾轮第 4 步（读取鉴权）观察 1–2 天、收尾之后，再开第 1 轮。
   - 第 0 轮可以收尾后立刻做，最好在 **12-01 02:00 月度 CI 运行之前**完成。
6. **行号会偏移。** 提示词里的文件行号是 11-04 本机代码的位置，代码改动后可能变；提示词已要求会话先核实。

---

## 拍板项（默认是推荐选项）

| 编号 | 问题 | A（推荐） | B |
|---|---|---|---|
| Q1 | 首页怎么处理 | 并入「宏观背景」，决策中枢设为默认首页 | 保留首页，只放决策中枢摘要，不自己算任何数字 |
| Q2 | 红利趋势、GEM 两个策略 | 隐藏页签；引擎继续跑，攒前向记录 | 页签和引擎一起停 |
| Q3 | 在仓个股的深研页（不在仓的一律下线） | 先隐藏，第 4 轮改成研究卡 | 一并下线，不再做 |
| Q4 | AI 模块（首页 AI 情报流、AI 助手、日报 AI 叙事） | 下线：开关隐藏，代码保留 | 充值后保留 |

---

## 通用约束（每轮都先粘贴）

```
你在协助我维护个人量化看板 AlphaCore（个人项目，测试阶段）。请用简体中文，先给结论；区分事实、推断和建议；没验证的明确说明。

【项目与环境】
- 应用目录：D:\FIONA\google AI\quant_dashboard\quant_dashboard（仓库 terryzhoo-max/quant_dashboard，私有）
- 推送：D:\FIONA\google AI\一键推送.bat（推送前会跑本机全量 pytest 和前端测试）
- 服务器：/root/quant_dashboard/quant_dashboard，部署命令 bash update.sh，由我执行
- 地址约定：localhost:8000 = 本机开发（非权威）；localhost:18000 = 服务器权威数据（SSH 隧道）。账户数据只以服务器为准
- /api/ 读取需要 X-API-Key（读取鉴权已开）。Claude 内置浏览器不支持 prompt()，令牌用页面底部的输入条
- 如果有其他会话在并行，重启任何服务前先告诉我，等我确认它没在抓数据

【开工前】
1. 读 docs/PLAN_B_IMPLEMENTATION_LOG.md 末尾，确认没有未收尾的轮次；有就先报告，不要开工
2. 读本轮提示里列出的方案文档和配置
3. 在服务器隧道（18000）记录基线：
   - 执行目标
   - 合规结论（阻断条数和规则名）
   - 跟踪止盈状态（RED / YELLOW / GREEN 各几个）
   - 买入门控 / 加仓权限
   - 当前仓位（含数据时间）
   关键页面截图存 D:\FIONA\alphacore_baselines\<日期>_<轮次>\；关键数字写进本轮方案文档

【固定规则，不得违反】
1. AIAE 执行目标是全站唯一的仓位数字
2. 合规引擎是唯一的风险判定；其他地方只读它的结果，不另设阈值
3. 跟踪止盈是唯一的止损执行入口
4. JCS / AIAE / ERP / 海外读数只作背景：不出仓位、不出配置比例，也不出"买入 / 观望 / 清仓"之类的操作措辞
5. 降仓节奏统一写"分 3–5 个交易日"
6. "当前仓位"全站只有一个来源，每处显示都带数据时间；买入门控不得比现在更松
7. 已预注册的模型和参数不改，包括 ERP v4、AIAE V6-A（及 V5 影子）、industry-alpha-v3、行业挑战者 v2、利率 V2 结论

【工作方式】
- 先审计、出方案：列出涉及的模块和它们的依赖（接口、定时任务、大模型调用、还有谁在读），写明改动影响、拟改文件、提交怎么拆。等我确认后，才把方案写进 docs/ 并开始实施
- 下线一律"先隐藏、不删代码"：
  - 用中心开关，格式照 config/decision_modules.json：enabled=false、label、hidden_on、reason、restore_if、review_on
  - 观察 4 周，到期由我决定是否删除
  - 被隐藏模块的后台任务 / 接口 / 大模型调用，如果别处不用，一并暂停（任务开关用 config/job_switches.json）
- 每步单独提交；行为提交和界面提交分开；口径改动和隐藏分开
- 每个提交都带测试：新测试对改前代码失败、对改后代码通过；全量 pytest 和前端 .cjs 测试全部通过
- 测试守卫原则：
  - 不放宽真实数据写入守卫，不为过测试加白名单（确有例外，先告诉我理由）
  - 测试把数据路径重定向到临时目录，数据源打桩、不联网，种子文件来自 fixtures
  - 不靠推送去试 CI；CI 出问题先在本地复现
- 每个提交前后做 5 项核对：执行目标、合规结论、跟踪止盈、买入门控、当前仓位都不变（本步本来就要改其中一项的，先说明）
- 界面风格：
  - 专业克制的金融终端，红涨绿跌
  - 不用 emoji、渐变背景、重阴影、大圆角
  - 颜色只引用 static/css/ac_tokens.css 的变量，阻断 / 否决色用 --status-block（洋红）
  - 改了 JS / CSS，同步升页面引用的版本号
- 每步完成后在 docs/PLAN_B_IMPLEMENTATION_LOG.md 追加记录：做了什么、测试结果、5 项核对、推送时间

【每次推送】
给我一行可直接粘贴的 PowerShell，备注写清本次改动：
$env:ALPHACORE_COMMIT_MSG = "<备注>"; & "D:\FIONA\google AI\一键推送.bat"; Remove-Item Env:ALPHACORE_COMMIT_MSG
推送后提醒我在服务器执行 cd /root/quant_dashboard/quant_dashboard && bash update.sh；部署完成后，你经隧道核对 5 项

【收尾汇报】
做了什么、怎么验证的、还有哪些没解决、改了哪些文件
```

---

## 第 0 轮 · 月度 CI 停止自动发布参数，去掉外链头像

```
本轮目标：
- 策略参数只有经我人工批准才会改变
- 去掉侧边栏引用第三方网站的头像

【已知线索（11-04 静态阅读，请先核实）】
- main.py 约 253 行：定时任务 strategy_ci_monthly，每月 1 日 02:00 运行 services/strategy_pipeline.run_full_ci
- strategy_pipeline.py 约 312 行（MR，冻结样本外检验）和约 416 行（ERP，网格搜索最优）：
  状态为 ACCEPT / REVALIDATED 时调用 _publish_accepted_run → services/strategy_params.publish_ci_parameters，直接改写 config/strategy_runtime.json
- routers/ci.py 约 83 行：POST /api/v1/ci/accept/{run_id}；量化回测页（static/js/backtest.js）有"批准"按钮调用它
- 头像：static/js/sidebar.js 约 164 行、index.html 约 93 行、byd_audit.html 约 57 行引用 https://i.pravatar.cc/150?img=11，
  旁边写着"基金经理 Pro / 顶级投研权限"。其他页面也请全文搜一遍

【先核实，再给方案】
1. 月度 CI 历史上是否自动发布过参数？查 SQLite 的 ci_runs 表、config/param_versions/、strategy_runtime.json 的 revision
2. ERP 这部分 CI 参数现在影响哪些输出：ERP v4 仓位规则、旧综合分（仅参考），还是别的？MR 参数又影响哪些（信号、预览、门控）？
3. run_full_ci 里还有哪些子任务（例如 V5 检查、压力测试）？停掉发布会不会影响它们？

【拟改（我确认后实施）】
- 0a 行为提交：
  - 月度 CI 改为"只评估、只记录、不发布"：结果写入 ci_runs，状态标为待批准
  - 发布只能走人工批准接口；批准接口默认拒绝，需要环境开关加输入 run_id 二次确认才放行（参照组合页"清零"的做法）
  - 审计页 A 区显示最近一次 CI 结果和待批准条数
  - 不改任何现有参数值
- 0b 界面提交：
  - 隐藏量化回测页的"批准"按钮（页面本身第 2 轮再处理）
  - 去掉 pravatar 外链和"基金经理 Pro"文字，换成本地中性占位或直接去掉；所有页面保持一致

【验收】
- 测试证明：月度 CI 跑完后 strategy_runtime.json 不变；批准接口在开关关闭时拒绝；全站 HTML / JS 不再出现 pravatar.cc
- 5 项核对不变
```

---

## 第 1 轮 · 首页和海外页合并为「宏观背景」（即原定的首页精简轮，含 AI 模块去留）

```
本轮目标：
- 首页不再重复决策中枢的执行内容，也不再自己算综合分
- 首页的背景读数和海外策略页合并成一个只读的「宏观背景」页
- 拍板项：Q1 = <A 或 B>，Q4 = <A 或 B>
- 本会话只做审计和方案。方案确认后写入 docs/HOME_BACKGROUND_MERGE_PLAN.md，下一个会话再实施

【先读】
- docs/DECISION_HUB_SLIMMING_PLAN.md（第 3 节"同一指标多处计算"、宏观背景 C4）
- docs/DECISION_RULES.md
- docs/AIAE_GLOBAL_OPTIMIZATION_PLAN.md、docs/ERP_GLOBAL_OPTIMIZATION_PLAN.md、docs/RATES_OPTIMIZATION_PLAN.md
- config/decision_modules.json、config/job_switches.json

【已知线索（请逐条核实，在方案里标"已核实"或"不成立"）】
首页（index.html、static/js/renderers.js、script.js、erp_zone_chart.js；后端 dashboard_modules/assemble_response.py、market_temp.py、services/dashboard_builder.py）：
- 执行目标在首页出现 4 处：顶部横幅、行动条、仓位研判、执行偏离
- 4 个综合分：
  - 横幅"市场温度°"
  - 仓位研判"因子体检 / 因子一致度"
  - "五策略共振 V10.0"：assemble_response.py 约 35–39 行给 AIAE 0.30、ERP 0.25 的权重，违反 10-31 定的"宏观层不计入共振"
  - 行动条"JCS 置信"环（index.html 约 178 行，按分数着绿 / 红）
- "策略配置"和策略卡上的"×% 权重"（renderers.js 约 526–559 行；market_temp.py 约 506–544 行的 weights_5 / strategy_positions）：实际没有任何资金按这些权重分配
- AIAE 在首页约出现 5 处（横幅标签、温度计、档位背景读数卡、AIAE 管控卡、因子条）
- ERP 约出现 6 处（指标卡、全球权益脉搏、走势图、策略卡、宏观标签、因子条）
- "心态指引"出现 2 处；AI 情报流已因余额不足暂停

海外页（treasury.html、static/js/treasury.js）：
- treasury.html 约 241–270 行写死了三张"AIAE × ERP 仓位矩阵 · 交叉格 = 建议仓位"表、各档"90–95%"仓位区间，还有"最冷市场 · 超配优先"的字样
- treasury.js 约 1390 行会拼出"建议仓位 …%"，但后端已不再提供这个字段，页面可能显示 undefined%。请在 18000 打开页面确认
- 海外 ERP / AIAE / 利率都已降为背景读数

全站：
- AI 助手（static/js/ai_assistant.js）每页都加载
- 日报的 AI 叙事已改用规则模板

【方案要回答】
1. 首页逐个模块定去向：保留 / 移到宏观背景 / 改成一行状态加链接（链到决策中枢）/ 隐藏。执行目标在首页最多留一行，读决策中枢的同一来源，带时间戳
2. 综合分只留 JCS 作背景读数，其余三个只隐藏显示。逐个列出它们的后端消费者（告警、日报、事件监控、AIAE 策略权重等）：有人在用的计算保留，没人用的列为待暂停
3. 「宏观背景」页的结构：
   - A 股：AIAE 读数、ERP v4、JCS、VIX、资金、行业热力
   - 海外：US / JP / HK 的 ERP、AIAE、利率
   页面只读，不出仓位，也不出操作措辞。决策中枢现有的背景区，是只留一行摘要加链接，还是整块移过来？给出建议
4. 按 Q1 处理默认入口：切到决策中枢后，旧地址（/、/index.html、/treasury.html）是跳转还是保留；侧边栏和手机底栏怎么同步
5. 按 Q4 处理 AI 模块：AI 情报流、AI 助手、日报 AI 叙事怎么隐藏，对应的任务和接口是否一并暂停
6. 海外页残留的仓位矩阵和"超配"措辞怎么删
7. 提交拆分建议，写明每步的测试和 5 项核对。参考：
   1a 首页去重、去综合分 → 1b 海外页残留清理 → 1c 新建宏观背景页 → 1d 默认入口与旧地址 → 1e AI 模块开关

【不做】
- 不改 AIAE / ERP / JCS 的算法和阈值
- 不动决策中枢执行区、合规、跟踪止盈
- 视觉细修只记在方案的"视觉待办"一节
```

---

## 第 2 轮 · 导航重排，下线低价值页面

```
本轮目标：
- 侧边栏按决策流程重排
- 下线投入产出比低的页面（隐藏，不删代码）
- 拍板项：Q3 = <A 或 B>
- 先审计、出方案；确认后写入 docs/SITE_NAV_SLIMMING_PLAN.md 再实施

【目标导航（以第 1 轮完成后的状态为基础）】
- 今日：决策中枢（默认首页；投委会简报保留页内按钮，不再单列导航）
- 账户：投资组合
- 研究：产业追踪（第 4 轮改名"产业研究"）、策略中心（第 3 轮改名"策略与证据"）
- 背景：宏观背景
- 系统：深度审计

【下线清单（请逐条核实依据和依赖）】
1. 因子分析（factor.html、static/js/factor.js）
   - 内容是通用 A 股个股因子的 IC 检验，与 ETF 池无关
   - factor.js 约 444–445 行输出"动态止损"和"建议仓位（Half-Kelly）"，违反唯一仓位 / 唯一止损
   - 查它的后端接口和计算是否别处在用
2. 量化回测（backtest.html、static/js/backtest.js）
   - 策略版本落后（backtest.html 约 97–101 行）：AIAE 是 V5（线上已是 V6-A），ERP 是 V1.0（线上是 v4），没有 GEM
   - 回测引擎和脚本保留，只隐藏页面
3. 个股深研 7 页（smic / wus / scc / zijin / byd / eastmoney / fii 的 _audit.html，对应的 *_data.js 和 audit_core.js）
   - 数据写死在 JS 里，没有来源、没有日期，也没有更新机制；"审计中…"是模拟的加载动画
   - 名字里的"审计"与深度审计（系统可信度）同名不同义
   - 按服务器权威持仓判定哪些在仓：不在仓的直接隐藏，在仓的按 Q3 处理
4. 投委会简报的导航项：report.html 页面保留，从决策中枢的按钮进入

【实现要求】
- 新增 config/site_modules.json（格式同 decision_modules.json）。侧边栏（static/js/sidebar.js）和手机底栏都读它；注意接口要经过读取鉴权
- 直接用地址打开被隐藏的页面时：不加载内容，只显示"本页已下线 · 隐藏于 MM-DD · 观察至 MM-DD · 恢复条件 …"
- 只被这些页面用到的接口 / 定时任务一并暂停；被别处用到的保留，并在方案里写明谁在用
- 观察期证据：说明现有访问日志能否按页面统计打开次数。不能的话，加一个最小的按日、按页面计数（只记路径和日期，不记别的），供第 5 轮复查用
- 复查日：decision_modules 是 11-30，portfolio_modules 是 12-01，再加本轮的复查日，建议对齐成一个日期给我

【提交拆分建议】
2a 开关与"已下线"提示（行为）→ 2b 侧边栏 / 底栏重排（界面）→ 2c 页面访问计数（如需要）

【不做】
- 不删任何文件
- 不改策略中心和产业追踪的内容（留给第 3、4 轮）
```

---

## 第 3 轮 · 策略中心精简为「策略与证据」

```
本轮目标：
- 策略中心只回答"各策略的信号是什么、验证到了哪一步"
- 不再承担执行、风险判定、止损和仓位
- 拍板项：Q2 = <A 或 B>
- 先审计、出方案；确认后写入 docs/STRATEGY_CENTER_SLIMMING_PLAN.md 再实施

【先读】
- docs/AIAE_EXECUTION_RULES.md、docs/AIAE_MONITOR_LIMITS.md、docs/DECISION_RULES.md
- docs/ACCOUNT_EXPOSURE_AND_MR_LIMITS_PLAN.md、docs/STRATEGY_HEALTH_EVIDENCE_REFRESH_20261025.md
- config/strategy_runtime.json（各策略的 validation 字段）

【现状】
- strategy.html 约 408KB，加上 strategy.js / strategy_aiae.js / strategy_erp.js / strategy_gem.js 共约 720KB，约占全站页面代码的三分之一
- 页签：宏观（AIAE、ERP）/ 总览（执行总览）/ 策略（MR、红利、动量、GEM、MR 评分规则）/ 监控（策略健康）

【已知线索（请逐条核实）】
重复的执行展示：
- 执行总览里的"总仓位 · 执行目标 / 有效上限 / 偏离 / 账户风险"（strategy.html 约 14045 行起）
- AIAE 页的"交易执行控制台 / 执行层指令卡"（strategy_aiae.js 约 721 行，读 /aiae/deviation.execution_target；决策中枢读的是 /decision/hub）

第二套风险判定：
- AIAE 页"实盘监控与对账"自带 L1–L5 限额和 A–D 等级（docs/AIAE_MONITOR_LIMITS.md；engines/position_deviation_engine.py 的 _compute_health_score）
- 其中 L2 单票 10% / 20%；L3 主题集中度按"占权益 40% / 60%"算，与 11-02 定的合规"占账户"口径不同。该引擎 10-31 之后没有改过
- 查 health_score 还被谁读（首页、审计页、日报、告警）

与唯一止损 / 唯一仓位冲突的规则文案：
- MR 评分规则页（strategy.html 约 13050 行）："硬止损 ETF −8% / 个股 −12% 立即清仓"、"时间止损 减半仓位"
- 同页约 13887 行："Kelly-Lite 仓位公式 → 建仓 12% 总资金"、单标的上限 20%
- 动量页的"累计浮亏止损"、GEM 页的"总仓位"
- 后端也要查：engines/momentum_rotation_engine.py 引用了 strategy_params.get_position_cap / get_stop_loss，信号输出里是否带止损价和仓位比例，谁在读

内嵌的回测与参数优化：
- MR"回测验证报告"、红利"参数优化回测结果"、动量"回测控制台 + 参数优化中心（网格搜索）"

【方案要回答】
1. 每个策略页签保留什么。建议只留三样：
   - 当前信号列表
   - 验证状态（已验证 / 影子 / 被否 / 证据不足，读 strategy_runtime.json 的 validation）
   - 一个证据块：只读预注册的验证产物，不在页面上跑网格搜索
2. 执行总览和 AIAE 交易执行控制台：改成一行状态加链接到决策中枢，数字与决策中枢同源
3. 实盘监控的限额与等级：给我两个选项并说明各自影响——
   ① 删去等级和限额表，只留 L4 β 敞口观察项
   ② 改为只读合规引擎结果，不再自带阈值
4. 止损 / 仓位规则文案：删除，或改成"历史规则 · 已停用：止损以跟踪止盈为准，仓位以执行目标为准"。后端信号里的止损 / 仓位字段：没人用的列为待停，有人用的写明是谁
5. 网格搜索和参数优化入口：隐藏，与第 0 轮的 CI 批准机制保持一致
6. 红利、GEM：按 Q2 处理
7. AIAE、ERP 页签定位为"执行目标从哪来 / 规则与证据"，确认这里没有第二个仓位数字；ERP 页走势图与宏观背景页的重复，给出取舍
8. 中心开关 config/strategy_modules.json；提交拆分建议。参考：
   3a 执行重复 → 3b 第二套限额 → 3c 止损与仓位文案 → 3d 回测与参数优化隐藏、加证据块 → 3e 红利 / GEM

【不做】
- 不改 MR / 动量 / 红利 / GEM / AIAE / ERP 的算法和参数
- MR 分析台（观察与人工计划，已经过买入门控）保留
```

---

## 第 4 轮 · 产业研究（产业追踪 + 动量轮动 + 持仓研究卡）

```
本轮目标：
- 把和我的投资方式最相关的研究集中到一页「产业研究」。我的投资方式：A 股行业 ETF，集中在半导体 / AI 产业链；中长期持有为主，部分仓位做波段
- 方案 B 主线收尾后再做
- 拍板项：Q3 = <A 或 B>
- 先审计、出方案；确认后写入 docs/INDUSTRY_RESEARCH_PLAN.md 再实施

【先读】
- docs/INDUSTRY_CHALLENGER_V2_PREREGISTRATION.md
- config/industry_validation.json
- config/strategy_runtime.json（momentum 的 validation）
- docs/PROJECT_FOCUS_90_PERCENT_20261026.md（研究层与长期配置部分）

【已知线索】
- 产业追踪（industry.html、static/js/industry.js，V5.0）用 Alpha 综合分：热度 30 + 动量 25 + 价格位置 25 + 趋势 20。模型 industry-alpha-v3 不动，挑战者 v2 只作影子
- 策略中心的动量轮动（engines/momentum_rotation_engine.py）是 7 维动量分，和产业追踪是两套独立计算，都以价格动量为主；动量的验证结果是 passed=false
- 个股深研页的数据写死在 JS 里，没有来源

【方案要回答】
1. 页面结构：
   - 行业 ETF 排序：以哪套为主，另一套怎么并列展示（不合并模型、不改预注册）
   - 持仓个股研究卡
   - 行业 / ETF 研究卡（可选）
2. 研究卡的字段：来源（链接或文件）、数据日期、核心逻辑、关键指标、反证与风险、下次复核日。过期后自动灰显"需复核"；卡片上不出仓位、止损和买卖措辞
3. 研究卡数据放在哪（data_lake / config / 数据库）。持仓名单从服务器权威账户读，换仓后自动增减
4. 动量轮动页签移进来以后，策略中心是否只保留它的验证状态
5. 提交拆分与测试

【不做】
- 不改 industry-alpha-v3、挑战者 v2 和动量引擎参数
- 不接新的付费数据源（如果需要，先把选项和成本列给我）
```

---

## 第 5 轮 · 到期复查与删除（12 月上旬，按第 2 轮约定的复查日）

```
本轮目标：根据观察期证据，决定每个已隐藏模块是删除、继续观察还是恢复。只出清单，删除要我逐项确认。

【先读】
- config/decision_modules.json、portfolio_modules.json、site_modules.json、strategy_modules.json、job_switches.json
- 对应的方案文档

【对每个已隐藏模块，列成一张表】
名称 | 隐藏日 | 观察期打开次数（第 2 轮的计数或访问日志）| 观察期内是否被决定记录 / 告警 / 日报引用过 | 依赖它的接口和任务 | 建议（删除 / 继续观察 / 恢复）| 删除会动哪些文件

【删除规则（我确认后执行）】
- 每个模块一个提交：先删前端，再删只被它用到的接口和任务；被别处用到的保留
- 删除前用测试确认没有残留引用；git 历史保留
- 本机的 *.bak 旧备份（已被 .gitignore 忽略）只列清单，要不要移到仓库外归档由我决定，不要直接删

【顺带评估（只出方案）】
复盘与决定记录现在分散在三处：决策中枢复盘页、组合页、策略中心 MR 分析台。是否合并到组合页一处？
```

---

## 实施会话开头（第 1–4 轮方案确认后，每步一个会话）

```
按 docs/<方案文件>.md 实施第 <编号> 步，只做这一步。
1. 先读方案、docs/PLAN_B_IMPLEMENTATION_LOG.md 末尾，以及本步涉及的代码
2. 核对方案里的行号和描述与现状是否一致；不一致先告诉我
3. 然后按通用约束实施、测试、做 5 项核对、写日志，最后给我推送命令
```

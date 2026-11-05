# 首页并入「宏观背景」· 第 1 轮审计与方案

- 状态：**已确认**（2026-11-05 17:42 美中 = 11-06 07:42 北京）：R1–R9 按推荐，附用户修改与补充（第 10 节）。两项待用户决定：回撤读数（第 1 节，按规则已停下）、R10（第 10 节）
- 依据：`docs/SITE_SLIMMING_ROUNDS.md` 第 1 轮提示词；拍板项 Q1 = A（首页并入宏观背景，决策中枢为默认首页）、Q4 = A（AI 模块下线，开关隐藏，代码保留）
- 代码来源：本机 `tmp/qd_head.tar`（0c 会话开工时的 HEAD `2a664ef`）；之后的 `40f29c9` 只改了 `config/job_switches.json` 和测试，本轮涉及的页面、脚本、后端文件都没变。**实施会话请重新导出 tar，并按「实施会话开头」第 2 条核对行号**
- 页面实况：经 18000 查看（GET）；没有调用 `/ci/*`。读取跟踪止盈接口可能触发了一次后台补行情（写行情缓存），见第 1 节

---

## 0. 结论

1. **首页没有独有的执行信息。** 执行目标在首页出现 4 处（外加"执行建议"整段复制），全部读决策中枢同一结果；其余是背景读数、4 个综合分、策略权重和 AI 情报流。先整页下线，不先在旧首页上去重（用户已确认）。
2. **海外页「海外 AIAE 仓位」标签漏清。** 11-01 海外 AIAE 计划 P0–P3 清的是策略页，海外页 `treasury.html` 同名标签还有 3 张"交叉格 = 建议仓位"矩阵、每档仓位区间、"操作速查 · 3 天内完成清仓"、第二套止损（"风控与操作纪律手册"），页面显示 6 处"建议仓位 null%"。后端早已不提供这些数据。
3. **同一读数两个数。** 美股 AIAE：首页 58.8%（Z.1）对海外页 35.6%（市值 / M2 旧口径，未标注）。A 股 AIAE：决策中枢 24.8% 对海外页 21.9%——**决策中枢的数是对的**（第 4A 节）。
4. **做法**：`treasury.html` 改名为 `macro.html`（宏观背景），先删违规内容，再加「A 股」标签；`/`、`/index.html` 跳到决策中枢，`/treasury.html` 跳到宏观背景。旧首页文件保留，用开关恢复。
5. **5 项读数本轮都不碰**：执行目标、合规、跟踪止盈、买入门控、当前仓位的计算和显示位置（决策中枢）都不改。

---

## 1. 基线（11-06 02:13–02:2x 北京，经 18000）

| 项目 | 读数 |
|---|---|
| 执行目标 | **25.0%**（有效上限 25%，组合回撤刹车三档最严；AIAE 矩阵 60%、尾部刹车后 60%、组合波动预算 65.2%） |
| 合规 | blocked：**2 条硬阻断**（主题集中度、仓位超限检查）+ 组合波动预算警告 |
| 跟踪止盈 | RED 1 / YELLOW 0 / GREEN 14（沪电股份已触发） |
| 买入门控 / 加仓权限 | 关闭（increase = false，create_order = false） |
| 当前仓位 | **99.0%**（持仓截至 11-05 15:00 对账单 · 价格 11-05 收盘；风险状态计算于 11-05 23:34:52） |

与 11-06 02:13 第 0 轮 0c 部署后复核相同；11-06 07:43 北京再读一次，5 项不变。

**截图**：本会话无法把浏览器面板截图存成文件；改前截图在实施会话开工时拍，存 `D:\FIONA\alphacore_baselines\<日期>_round1_<步骤>\`；海外 ERP、利率两个标签的实时读数同时只读看一遍。

### 回撤读数两处不一致（补充 2，按规则已停下，待用户决定）

门槛（`services/drawdown.py` 默认策略）：进入 1 档 ≥12%（执行目标上限 75%）、2 档 ≥20%（50%）、3 档 ≥28%（25%）；退出 = 自谷底收复 50%，每次降一档。当前 3 档（最高档），谷底 −33.28%（10-30），退出线 **16.64%**。

| 读数 | 来源 | 离 28% 进入线 | 离 16.64% 退出线 |
|---|---|---|---|
| **26.36%** | 风险状态（执行目标、合规所用），11-05 23:34:52 由导入交割单触发重算 | **1.64pp（< 2pp）** | 9.72pp |
| 25.41% | 跟踪止盈面板现算（11-06 07:43） | 2.59pp | 8.77pp |

- 28% 只是"进入 3 档"的线；已在 3 档，越过它不改档位，也不改执行目标。会改档的只有 16.64% 退出线。按用户规则字面已触发（26.36% 离 28% 不到 2pp），已于 11-06 07:4x 北京告知用户，**是否提前处理由用户决定**；未决定前按原登记放到第 0 轮之后
- **变化原因**：两个数用同一个函数（`trailing_stop_service.get_report` → `drawdown.monitor`）。净值曲线只画到"所有当前持仓都有收盘价"的最后一天（`drawdown.py` 约 333–337 行 `last_common`）。23:34 有一只持仓尚无 11-05 收盘价，曲线止于 11-04（净值 0.76354 → 26.36%）；跟踪止盈 GET 接口对行情滞后 >1 个交易日的持仓会自动后台补行情（`routers/trailing.py` 74 → `ensure_prices_async`）。11-06 零点后滞后变为 2 个交易日，下一次读取触发补行情，曲线延到 11-05（0.77331 → 25.41%）。风险状态只在日终提交（约 15:50）或导入时重算，所以执行列仍是 26.4%，下一次日终会更新
- 这次补行情很可能是本会话 02:13 北京打开决策中枢时触发的（之前也可能有别的读取）。会话当时不知道这个 GET 会写行情缓存，没有事先告知；只写 `data_lake` 行情 parquet，不碰台账、止损线、日终快照。已记入实施日志。确认方式（服务器只读）：`docker logs <容器名> --since 2026-11-05T15:30:00 2>&1 | grep -E "行情同步|sync_daily|trailing-price"`

---

## 2. 提示词线索核实

| 线索 | 结论 | 说明 |
|---|---|---|
| 执行目标在首页出现 4 处：横幅、行动条、仓位研判、执行偏离 | **已核实** | `rb-advice`、`qa-pos`、仓位研判（`pos-hero` + 约束瀑布 `ps-exec`）、执行偏离 `ds-gap-target`；另有"执行建议"整段复制 |
| 综合分①横幅"市场温度°" | **已核实** | 页面 58.8°；`market_temp.py` 498–501 `total_temp` |
| 综合分②"因子体检 / 因子一致度" | **已核实** | 一致度 80；6 条因子条 |
| 综合分③"五策略共振 V10.0"，AIAE 0.30、ERP 0.25 | **已核实** | `assemble_response.py` 37–43；页面 −9.3 |
| 综合分④行动条"JCS 置信"环，按分数着色 | **部分成立** | 环是 JCS（57）；旁边标"JCS 置信"的条显示的是因子一致度（80）。首页整页下线后随之消失，不单独修 |
| "策略配置"和策略卡"×% 权重" | **已核实** | `renderers.js` 523–562；`market_temp.py` 506、538 |
| AIAE 约出现 5 处 / ERP 约 6 处 | **已核实（实际更多）** | AIAE 6–7 处，ERP 9 处 |
| "心态指引"出现 2 处 | **已核实** | `qa-mindset`、`val-mindset`；文案含"离场观望 / 战略建仓"等操作措辞 |
| AI 情报流已暂停 | **已核实** | "已暂停 · 内容截至 11-04 15:15"；旧卡片仍带"利好关注 / 利空回避" |
| `treasury.html` 241–270 三张仓位矩阵等 | **已核实** | 矩阵 235–279；"超配优先"在 119 行与 `treasury.js` 1326 |
| `treasury.js` 约 1390 行可能显示 undefined% | **已核实（显示 null%）** | 1390、1520 两处，三个地区共 6 处"建议仓位 null%" |
| 海外 ERP / AIAE / 利率都已降为背景读数 | **部分成立** | 后端都已降级；前端 ERP、利率干净；AIAE 标签前端没清 |
| AI 助手每页都加载 | **已核实** | `sidebar.js` 191 动态加载 `ai_assistant.js`，纳入本轮下线开关（补充 3） |
| 日报 AI 叙事已改用规则模板 | **已核实（有条件）** | 因 ai_services 暂停而走规则模板；`ai_config.json` 的 `enable_ai_narrative` 仍为 true，恢复 ai_services 会自动回到 AI 叙事 |

首页 VIX 卡第一次读到"--"是后台窗格里数字动画没跑完，不是缺陷。

---

## 3. 首页逐模块去向（`index.html`）

| # | 模块（行号） | 问题 | 去向 |
|---|---|---|---|
| 1 | 顶栏：系统状态 · 预警铃 · 刷新（95–132） | 预警铃与决策中枢重复 | 宏观背景页只留"数据截至 · 刷新" |
| 2 | Regime 横幅（138–151） | 综合分①；执行目标第 1 处 | 隐藏 |
| 3 | 快速行动条（153–181） | 执行目标第 2 处；心态措辞 | 隐藏；宏观背景页顶部改为一行提示（第 5 节） |
| 4 | VIX 卡（184–195） | 说明"结构性调仓" | 移到宏观背景，不显示该说明 |
| 5 | ERP 卡（196–207） | 旧择时信号"标配持有" | 不单独保留，ERP 读数由 v4 图块承担 |
| 6 | 资金卡 A+H（208–230） | "观望中性" | 移到宏观背景；标签前端改中性写法（同向流入 / 同向流出 / A/H 分歧 / 无明显方向） |
| 7 | 五策略共振 V10.0（231–243） | 综合分③ | 隐藏 |
| 8 | 全球权益脉搏（245–304） | 与海外 ERP 标签重复 | 并入海外估值标签 |
| 9 | 行业热力（306–316） | — | 移到宏观背景 |
| 10 | AI 情报流（318–345） | 已暂停 | 隐藏（AI 模块开关） |
| 11 | 宏观配置温度（355–431） | AIAE 重复；旧仪表 | 移到宏观背景，改用决策中枢 1c 的 R1–R5 档位条（`hub_core.renderAIAEHub`） |
| 12 | 仓位研判（433–506） | 执行目标第 3 处；综合分② | 隐藏 |
| 13 | 策略配置（508–575） | 权重、"建议周期" | 隐藏 |
| 14 | 辅助决策面板（579–646） | 执行目标第 4 处 | 隐藏（信号矛盾随 JCS 块出现） |
| 15 | AIAE 档位 · 背景读数（648–699） | 与 11 重复 | 隐藏 |
| 16 | ERP v4 走势图（701–711） | 买卖措辞（R7） | 移到宏观背景 |
| 17 | 策略引擎矩阵（713–800） | 权重、"发现 0 只猎物" | 隐藏 |

"隐藏"= 旧 `index.html` 整页由开关下线（文件与代码保留，第 5 轮第二批决定删除）。

---

## 4. 综合分与只被首页使用的计算（R4）

| 计算 | 位置 | 首页之外的消费者 | 外部调用 / 推送 | 结论 |
|---|---|---|---|---|
| ①市场温度 `total_temp` | `market_temp.py` 498–501 | 经 `100 − 温度` 进入 `hub_factors.macro_temp` → 决策快照与 `hub_composite`（decision_log、日报原始读数、`slippage_engine`、情景模拟） | 其输入（融资、成交、AH 溢价等）有 Tushare 拉取，但决策快照依赖 | **保留** |
| ②因子条 `hub_factors` | `market_temp.py` 552–561 | `erp_value.score` → JCS、冲突、事件、decision_log、日报；其余进决策快照 | 同上 | **保留** |
| ②因子一致度 `hub_confidence` | `market_temp.py` 569–572 | 无 | 无（纯计算） | 登记，第 5 轮删 |
| ③五策略共振 V10 | `assemble_response.py` 160–194 | 无 | 无 | 登记 |
| ④JCS | `decision/jcs.py` | 决策中枢、日报、decision_log、事件 | 低分推送已关 | **保留作背景读数** |
| 策略权重 `weights_5` 等 | `market_temp.py` 503–543；`aiae_engine.get_run_all_weights` 1096–1126 | 无（策略页另算一份，第 3 轮） | 无 | 登记 |
| 心态 | `position_engine.py` 474–480 | 无 | 无 | 登记 |
| `pos_path` | `position_engine.py` 182–228 | 无 | 无 | 登记 |
| `tomorrow_plan` | `position_engine.py` 309–467；热循环重算 | 无 | 无（内含的 `vix_alert` 只是条目类型标签，不推送） | 登记 |
| `strategy_status` / `execution_lists` | `assemble_response.py` | 无 | 无 | 登记 |

**R4 结论**：登记项都是同一次 dashboard 构建里的纯计算，没有外部调用，也没有告警推送 → 本轮不停算，第 5 轮随删除去掉。

### 4A. A 股 AIAE 24.8% 对 21.9%（补充 1）

- **24.8%**（决策中枢、旧首页）= `regime_basis_value` = `aiae_simple`（证券化率）。`V5_ENABLED = True`（`engines/aiae_params.py` 278），V6-A 扩展分位阈值（21.73 / 23.83 / 26.25 / 28.13）就用它分档 → R3。决策中枢经 `services/aiae_safety.py` 77 读它。**口径正确**
- **21.9%**（海外页四地对比）= 引擎 `current.aiae_v1` = V3 三因子融合值（0.55 × 证券化率 + 0.20 × 基金仓位归一 + 0.25 × 融资热度归一，`aiae_engine.py` 851–873）。V5 以后不再用于分档，只留作对照。海外四地对比由 `routers/aiae.py` 308 与 `warmup_pipeline.py` 300 读取，配的却是基于 24.8% 的档位 R3（21.9% 按当前阈值其实落在 R2），数与档不配套；读不到时还有写死的缺省 22.0
- 结论：两数差 2.9pp 是口径不同（单因子分档值 vs 旧三因子融合值），不是计算错误。宏观背景页的 A 股 AIAE 统一读决策中枢同一来源（`/decision/hub` 快照的 `regime_basis_value`）；海外四地对比去掉 A 股格（1c）
- 另：`routers/strategy.py` 355 `/strategy/run-all` 也读 `current.aiae_v1`（融合值），留第 3 轮核对

---

## 5. 「宏观背景」页结构（只读，不出仓位、不出操作措辞）

```
顶栏：宏观背景 · 数据截至 … · 刷新
提示行：背景读数，不作执行依据 · 仓位以执行目标为准 25%（状态计算于 …）→ 决策中枢
标签：A 股 | 海外估值 | 海外 AIAE 读数 | 利率

【A 股】
  AIAE 配置热度：读数 24.8% · R1–R5 档位条 · 融资热度 / 月斜率 / 基金仓位（决策中枢同一函数、同一来源）
  ERP v4：关键卡片 + 走势图 + 区间表（erp_zone_chart.js，与策略页共用）
  JCS 宏观读数：环 + 因子构成 + 信号新鲜度（决策中枢同一函数）
  VIX · 资金（北向 / 南向 / Z 合力）
  行业热力
  市场动态（1g 从决策中枢移来）
【海外估值】原海外 ERP 标签 + 跨市场 ERP 读数（原首页全球权益脉搏并入，美股带 Z.1 AIAE 一行）
【海外 AIAE 读数】美股 Z.1 AIAE；旧口径对照；日股代理读数；港股南向 + AH 溢价；历史走势（无档位色带）
【数据维护】（默认隐藏，见 R6）
【利率】原利率标签，不改
```

- 数据接口：`/api/v1/dashboard-data`（与旧首页同一份缓存）、`/decision/hub`、`/strategy/erp-timing`、`/strategy/erp-global`、`/aiae_global/report`、`/strategy/rates`，全部是现有 GET
- 脚本：`treasury.js` + `ui_utils.js`、`renderers.js`（热力、资金、ERP 图）+ `decision/_infra.js`、`decision/hub_core.js` + 新增 `static/js/macro.js`。已核对这些文件之间没有重名的全局函数 / 变量。`renderers.js` 的启动代码改为只在旧首页运行
- **注意**：宏观背景页不读 `/portfolio/trailing-stops`（第 1 节：这个 GET 会触发补行情）

**决策中枢背景区（R3，已确认）**：
- 明确记录：**改动 11-01 定的"JCS 模块放在决策中枢"**，JCS 完整读数移到宏观背景页；JCS 算法不动
- 决策中枢只留一行摘要 + 链接，摘要只放 **JCS 等级、AIAE 档、ERP 档和数据时间**，不放任何仓位数字，例如："JCS 一般 · AIAE R3 中性均衡 · ERP v4 4.5–5.5% 档 · 数据截至 11-05 → 宏观背景"
- ERP 档用正常化 ERP 区间表示：v4 档位数字 90 / 80 / 65 / 45 / 25 / 10 按定义就是仓位百分比（`engines/erp_allocation_v4.py` 18），摘要里不写（R10）
- 面板主体用 `config/decision_modules.json` 新开关隐藏（代码保留）；`docs/DECISION_RULES.md` 1.4 第 58 行同步改写

---

## 6. 默认入口与旧地址（R2）

| 地址 | 现状 | 改后 | 所在步 |
|---|---|---|---|
| `/treasury.html` | 海外策略 | 307 → `/macro.html#overseas`（页面改名附带的固定迁移，写在代码里，不走开关） | 1d |
| `/macro.html` | 404 | 宏观背景页（`_ALLOWED_PAGES` 加 `macro`） | 1d |
| `/` | `main.py` 805 返回 `index.html` | 307 → `/decision.html` | 1f |
| `/index.html` | 旧首页 | 307 → `/decision.html`（`config/site_modules.json` 的 `index.enabled=false`，改回 true 即恢复） | 1f |
| PWA `manifest.json` `start_url` | `/decision`，实测 404 | `/decision.html` | 1f（同一提交） |
| `static/js/sw.js` | 见下 | 同步改 | 1f（同一提交） |

**sw.js 核查**（R2）：
- 页面导航走"网络优先"：在线时先请求网络，跳转由浏览器自己跟随（导航请求的跳转响应不会被缓存），**在线时不会被缓存挡住**
- 但每次成功打开的页面都会存进缓存（`networkFirst` 的 `cache.put`），`/` 和 `/index.html` 现存的是旧首页内容，离线时会被拿出来显示
- 预缓存列表里的 `/decision` 是 404
- 同一提交：预缓存改 `/decision.html`；`CACHE_VERSION` `alphacore-v5` → `v6`（激活时删除旧缓存，清掉旧首页副本）
- 注册 SW 的页面：`index.html`、`decision.html`、`backtest.html`

其余：
- 用 307 临时跳转，不用 301（301 被浏览器永久缓存，观察期后不好恢复）；`test_api_smoke::test_root_redirect` 接受 200 / 307，不用改
- 开关读取失败按"开启"处理：最坏显示旧首页，不会断链
- `config/site_modules.json` 在 1d 新建（先放 R6 的"数据维护"模块项），1f 加 `index` 页面项；第 2 轮在同一文件扩展页面下线项
- 侧边栏最小同步："量化总览 → 宏观背景（macro.html）"，去掉"海外策略"；`getCurrentPage()` 默认值改为 `decision.html`；完整重排留第 2 轮
- 手机底栏：**决策 / 组合 / 策略 / 背景 / 简报**
- `report.html` 182 行"Back"：`./index.html` → `./decision.html`
- `sidebar.js` 全站升到 v=207（`test_round0_ui.cjs` 要求全站一致且 > 205）
- 各页静态侧栏占位里的旧链接留第 2 轮清理；`global_search.js` 无页面加载，列入第 5 轮删除清单

---

## 7. AI 模块（Q4 = A，含 AI 助手）

| 模块 | 前端 | 接口 | 定时任务 | 大模型调用 |
|---|---|---|---|---|
| AI 情报流 | 首页 318–345（`renderers.js` 1877） | GET `/intelligence/latest`、`/history`；POST `/intelligence/scan` | `nlp_scan_am` 09:35、`nlp_scan_pm` 15:15（已暂停） | `news_intelligence._call_llm_json` |
| AI 助手（每页加载） | `ai_assistant.js`，由 `sidebar.js` 191 加载 | POST `/assistant/chat`、GET `/assistant/status` | — | `routers/assistant.py` |
| 日报 AI 叙事 | 决策中枢"生成日报"、定时日报 | `/decision/daily-report` | 日报任务 | `report_generator._generate_ai_narrative` |

（决策中枢"AI 叙事分析"已在 11-02 下线，不在本轮。）

**认证现状（更正草案）**：`/intelligence/scan`、`/assistant/chat` 在 `services/auth_middleware.py` 的 `_PUBLIC_PREFIXES` 里，但读取鉴权开启时（服务器现状）这些 POST **已经要令牌**（`_needs_key`：`return read_auth`），只有 `ALPHACORE_READ_AUTH=0` 时才恢复免认证。

**R8（已确认，提前做）**：两项移出 `_PUBLIC_PREFIXES`，读取鉴权开关关闭时也要令牌。
- 前端会自动带令牌：`alphacore_utils.js` 改写了 `window.fetch`，同源 `/api/` 请求（任何方法）自动加 `X-API-Key`；所有加载 `sidebar.js` 的页面都先加载 `alphacore_utils.js`；`ai_assistant.js`（124、159）和情报扫描（`renderers.js` 1892）都用 `fetch` 和相对路径
- 浏览器里没存令牌时，非 GET 请求返回 401 但不弹令牌输入框（只有 GET 会弹），和现在其他写操作一致
- 要改的旧测试：`test_read_auth.py` 110（开关关闭时 `assistant/chat` 预期 200 → 改为 401，开关语义改用另一个仍免认证的前缀验证）

**AI 模块开关**：新建 `config/ai_modules.json`（格式同 `decision_modules.json`），三项全部关闭；AI 助手在内。
- `ai_services` 保留为"全局不调用大模型"的总闸；新开关是产品去留，两者都开才调用
- 情报流关闭：`/intelligence/scan`、`/latest`、`/history` 直接返回"已下线"，不读不写、不调用扫描；两个 NLP 任务继续暂停，`job_switches.json` 原因改为"首页精简轮决定下线"，restore_if 指向 `ai_modules.json`
- AI 助手关闭：页面不显示浮动按钮（`ai_assistant.js` 先查 status，读不到也不显示）；`/assistant/chat` 直接返回"已下线"
- 日报叙事关闭：`_is_ai_enabled()` 恒为 False
- 开关文件缺失 / 损坏：三项都按**关闭**处理

---

## 8. 海外页残留清理（`treasury.html` / `treasury.js`，当前 v=211）

**R5（已确认）：违规内容直接删除，单独一个提交。** 作为"先隐藏、不删代码"的例外写进实施日志，理由：内容违反固定规则 1 / 3 / 4（第二个仓位数字、第二套止损、操作措辞），且后端早已不提供数据（`position.matrix_position = null`、`deprecated`、`removed`）。git 留历史。

| 内容 | 位置 | 处理 | 步 |
|---|---|---|---|
| "四地对比 · 最冷市场 · 超配优先"卡 | html 116–120；js 1322–1326 | 删除 | 1a |
| 区域面板"建议仓位 null%" | js 1390 | 删除该段 | 1a |
| 每区五档竖卡（仓位区间、"全面撤退 / 系统减仓"） | html 各区 `gaiae-*-regime-cards`（137 起）；js 1393 起 | 删除 | 1a |
| 三张"AIAE × ERP 仓位矩阵"及"当前 … 建议仓位" | html 235–279；js 1509–1572、1520 | 删除 | 1a |
| "⚡ 操作速查 · 当前档位指令" | html 322–361；js 1663 | 删除 | 1a |
| "风控与操作纪律手册 · 海外版" | html 370–405 | 删除 | 1a |
| AIAE 历史走势的五档色带 | js 1734 | 删除色带，保留曲线 | 1a |
| 四地对比的标准温度、档位、"EXTREME" | html 280–320；js 1573 | 删除（读数部分 1c 改读 `display_readings`） | 1a |
| 标签 / 地区标题里的"仓位"字样 | html 89、132 起 | 改为"读数" | 1a |
| 切换标签提示"重新计算并校验 … 的策略决策" | js 519 | 改为"正在刷新数据" | 1a |
| **R9** 美股主读数 35.6%（市值 / M2，未标注） | html 102–104、js hero | 主读数改为后端已有的 `us.aiae_real`（Z.1，58.8% · 分位 · 季度 / nowcast）；35.6% 只作对照，标"**市值 / M2 · 旧口径 · 对照**"，**不叫"AIAE"**，不与 Z.1 并排成两个 AIAE；四地对比改读 `display_readings`，去掉 A 股格 | 1c（口径） |
| **R6** 日股 / 港股"数据覆盖"手动覆盖表单 | html 406–516 | 页面隐藏（`site_modules.json` 模块项，1d），4 个接口保留 | 1d |
| 海外 ERP、利率标签 | — | 已干净，不动 | — |

**1a 测试锁住字样**：新测试读 `treasury.html`（1d 后为 `macro.html`）与 `treasury.js`，断言不再出现"建议仓位""交叉格""仓位矩阵""操作速查""清仓""减仓""超配""低配""禁止买入""止损"（允许的"不作仓位依据 / 不提供仓位、ETF 配置与止盈止损规则"说明句列入白名单），且 JS 不再读取 `matrix_position`、`allocations`；另用 18000 同结构的报告夹具跑渲染，页面文字里没有 `null%` / `undefined%` / 仓位区间。

**R6 核查**（4 个接口都要令牌，调用进写操作日志）：

| 接口 | 写入的数据 | 现在的自动来源 |
|---|---|---|
| `POST /aiae_jp/update_margin` | 日股信用取引残高（买残，兆円）→ 日股 AIAE 融资热度 | JPX XLS 自动获取 |
| `POST /aiae_jp/update_foreign` | 日股外国人投资家周净买入、12 个月累计（亿円） | JPX 投资部门别统计自动获取 |
| `POST /aiae_hk/update_southbound` | 港股南向资金周 / 月 / 12 个月净买入（亿 RMB），同时写 HSI、HSTECH 两个 ERP 引擎 | Tushare 自动获取 |
| `POST /aiae_hk/update_ah_premium` | AH 溢价指数 | A+H 篮子自动计算 |

- 用户每月的 Shiller 更新：`ie_data.xls` → `_dev_tools/update_shiller_csv.py` → `data/shiller_us_monthly.csv`（`engines/us_valuation.py` 49、`us_aiae_real.py` 52 读取）
- Z.1 更新：本机生成 `data/us_aiae_z1_quarterly.csv`（`us_aiae_real.py` 51 读取）
- 两者都是文件随仓库提交，**不经这 4 个接口** → 按推荐：表单隐藏（开关可恢复），接口保留

---

## 9. 提交拆分（按用户建议的顺序）

| 步 | 内容 | 类型 | 主要文件 | 新测试（改前失败、改后通过） |
|---|---|---|---|---|
| **1a** | R5 海外页违规内容删除（第 8 节 1a 各项） | 界面 | `treasury.html`、`treasury.js`（v=212） | 第 8 节字样锁 + 渲染夹具 |
| **1b** | R8 两个 AI 接口移出免认证列表 | 行为 | `services/auth_middleware.py` | 开关关闭时无令牌 POST 两接口 → 401；`test_read_auth.py` 110 按第 7 节修改 |
| **1c** | R9 海外读数口径 | 口径 | `treasury.html`、`treasury.js`（v=213） | 美股主读数 58.78 标 Z.1；旧口径标"旧口径 · 对照"且不含"AIAE"字样；无标准温度 / 档位；无 A 股 AIAE 数 |
| **1d** | 新建宏观背景页：`treasury.html` 改名 `macro.html`，标签改名、顶部提示行、R6 表单隐藏；`/treasury.html` 固定迁移跳转；`_ALLOWED_PAGES` 加 `macro`；新建 `config/site_modules.json` + `services/site_modules.py` + `GET /api/v1/system/site-modules`（经读取鉴权） | 行为（1d-1）+ 界面（1d-2），一起部署 | `main.py`、`macro.html`、`treasury.js` | `/macro.html` 200；`/treasury.html` → 307 `/macro.html#overseas`；R6 开关关时表单不渲染、开时渲染；`test_treasury_erp_background.py` 读取路径改为 `macro.html` |
| **1e** | 「A 股」标签：AIAE、ERP v4、JCS、VIX、资金、行业热力；`renderers.js` 启动代码限旧首页 | 界面 | `macro.html`、新 `static/js/macro.js`、`renderers.js` | A 股标签含上述读数；A 股 AIAE 取 `regime_basis_value`；不含仓位研判 / 执行偏离 / 共振 / 市场温度 / 一致度 / 心态 / 权重 / 情报流；"执行目标"只出现一行且带时间；不请求 `/decision/alerts`、`/intelligence/latest`、`/portfolio/trailing-stops` |
| **1e-2** | R7 ERP v4 图措辞："升档线 / 降档线 / 高于当前档 / 低于当前档 / 当前档"，规则与数据不变（是否改档位数字见 R10） | 界面 | `erp_zone_chart.js`（策略页 ERP 标签同步变化） | 图文字不含"买入线 / 卖出线 / 加仓区 / 减仓区 / 防守区 / 持有"；完成后在 `SITE_SLIMMING_ROUNDS.md` 第 3 轮注明 |
| **1f** | 跳转与 manifest：`/`、`/index.html` → 决策中枢（`site_modules.json` 加 `index`）；`manifest.json` `start_url`；`sw.js` 预缓存与缓存版本 | 行为 | `main.py`、`services/site_modules.py`、`manifest.json`、`static/js/sw.js` | 跳转状态码与 Location；开关改 true 时 `/index.html` 返回旧页；开关文件损坏按开启；`start_url` 与预缓存路径返回 200；`CACHE_VERSION` 已升 |
| **1f-ui** | 侧边栏 / 手机底栏 / report 返回按钮 | 界面 | `sidebar.js`（v=207，全站引用同步）、`report.html` | `test_sidebar_frontend.cjs` 补断言；`test_round0_ui.cjs` 页面清单加 `macro.html` |
| **1g** | 决策中枢背景区：摘要行（JCS 等级 · AIAE 档 · ERP 档 · 数据时间，无仓位数字）+ 链接，主体用开关隐藏；`renderMarketEvents` 抽到共享文件，宏观背景页显示市场动态；`DECISION_RULES.md` 1.4 改写 | 界面 | `decision.html`、`decision.js`、新 `static/js/decision/macro_bg.js`、`config/decision_modules.json`、`docs/DECISION_RULES.md` | 摘要行不含 `%` 仓位数字和"仓位"字样；开关关时主体不渲染；宏观背景页渲染市场动态；执行区、合规、跟踪止盈 DOM 不变 |
| **1h** | AI 模块开关：`config/ai_modules.json` + 三个后端门控 + `job_switches.json` 原因改写 | 行为 | `routers/intelligence.py`、`routers/assistant.py`、`report_generator.py`、新 `services/ai_modules.py` | 临时把 ai_services 设为开启，开关关时 scan 不调用扫描、chat 不调用大模型、`_is_ai_enabled` 为 False；开关文件缺失 / 损坏按关闭 |
| **1h-ui** | AI 助手浮动按钮按开关不显示 | 界面 | `ai_assistant.js`（v=3） | status 返回已下线或请求失败时不注入按钮 |

- 可选项：无（原可选的"AI 接口认证"已按 R8 提前为 1b）
- 与草案相比：R9 口径（1c）、"数据维护"开关（1d）、AI 模块开关（1h）是用户建议顺序里没写到的三步，按依赖关系插入；`/treasury.html` 的迁移跳转必须和改名同一次部署，所以放在 1d，不等 1f

**会话分组建议**（每组末部署一次，部署前先问用户）：
A：1a + 1b ｜ B：1c + 1d ｜ C：1e + 1e-2 ｜ D：1f + 1f-ui（部署后首页即切到决策中枢）｜ E：1g + 1h + 1h-ui

**每步 5 项核对**：都不改执行目标、合规、跟踪止盈、买入门控、当前仓位的计算；1f 只改"打开 `/` 看到哪个页面"；1g 只动背景区。每组部署前后经 18000 各核一次。核对时注意第 1 节：读跟踪止盈接口可能触发补行情——每次读取前在日志里写明。

**会改到的旧测试**（实施时逐条说明）：`test_read_auth.py`（1b）、`test_treasury_erp_background.py`（1d 读取路径）、`test_round0_ui.cjs`（1f-ui 页面清单）、`test_sidebar_frontend.cjs`（1f-ui 补断言）；1g 可能涉及 `test_decision_visual_1c.cjs`、`test_jcs_frontend.cjs` 的夹具。`test_home_*.cjs`、`test_position_asof.cjs` 读旧首页文件，文件保留，预计不用改。

**观察期**：`site_modules.json`（index、数据维护）与 `ai_modules.json` 三项，`review_on` = 隐藏日 + 4 周，进第 5 轮第二批。

---

## 10. 拍板记录

**2026-11-05 17:42 美中，用户："按推荐（R1–R9），附以下修改和补充"。**

| 编号 | 问题 | 决定 | 用户修改 / 补充 | 落实位置 |
|---|---|---|---|---|
| R1 | 宏观背景页怎么建 | `treasury.html` 改名 `macro.html` + 新增「A 股」标签 | — | 1d、1e |
| R2 | `/index.html` 跳到哪 | 决策中枢 | 同一提交修正 manifest `start_url`，并检查 `sw.js` 是否缓存旧首页、有就同步改 | 1f；sw.js 核查见第 6 节（会缓存旧首页供离线用，同一提交改预缓存路径并升缓存版本） |
| R3 | 决策中枢背景区 | 只留摘要行 + 链接，主体移到宏观背景 | **明确记录改动 11-01"JCS 模块放在决策中枢"**；摘要行只放 JCS 等级、AIAE 档、ERP 档及数据时间，不放任何仓位数字；JCS 算法不动 | 1g；第 5 节 |
| R4 | 只被首页用的计算 | 本轮不改生成器，第 5 轮随删除去掉 | 列出有无外部调用或告警推送，有则本轮就停 | 第 4 节：均无 → 本轮不停 |
| R5 | 海外页违规内容 | 直接删除 | 作为"先隐藏、不删代码"的例外写进日志（内容违反固定规则，后端早已不提供数据）；单独提交；测试锁住"建议仓位、交叉格、清仓"等字样 | 1a；第 8 节 |
| R6 | 手动覆盖表单 | 页面隐藏，4 个接口保留 | 先列 4 个接口覆盖的数据，以及每月 Shiller / Z.1 更新是否经它们录入；经它们录入就改成"数据维护"折叠区、不隐藏 | 第 8 节：Shiller / Z.1 不经这 4 个接口 → 按推荐隐藏（1d） |
| R7 | ERP v4 图措辞 | 改中性写法 | 另列后端同类措辞位置，留给第 0 轮后的措辞统一提交；第 3 轮方案注明 ERP 图已改 | 1e-2；后端清单见第 12 节 |
| R8 | AI 接口免认证 | 移出免认证列表 | 排在前面；确认前端调用自动带令牌 | 1b；第 7 节（已确认会自动带） |
| R9 | 美股 AIAE 主读数 | Z.1 为主 | 代理口径标"旧口径 · 对照"，不和 Z.1 并排显示成两个"AIAE" | 1c |
| 补充 1 | A 股 AIAE 24.8% 对 21.9% | 只读查清来源 | 决策中枢的数若错立即告知；宏观背景页统一读决策中枢同一来源 | 第 4A 节：决策中枢的数正确 |
| 补充 2 | 回撤 26.4% 对 25.4% | 只读列门槛、距离、原因 | 任一数离档位边界不到 2pp 就先停下告知 | 第 1 节：26.36% 离 28% 进入线 1.64pp → **已停下告知，待用户决定** |
| 补充 3 | Q4 范围 | AI 助手纳入本轮下线开关 | — | 1h、1h-ui |
| 顺序 | 提交顺序 | 违规内容清理 → AI 接口认证 → 新建宏观背景页 → A 股标签 → 跳转与 manifest → 决策中枢背景区 → 可选项 | 改前截图在实施会话开工时拍，存 `D:\FIONA\alphacore_baselines\`；海外 ERP 和利率实时读数同时只读看一遍 | 第 9 节 |
| 确认 | "JCS 置信"实为因子一致度 | 首页整页下线后消失，不单独修 | — | 第 2 节 |
| 确认 | 先下线整页、不先去重 | 同意 | — | 第 0、9 节 |

**待定 R10（落实 R3 时发现）**：ERP v4 的档位数字 90 / 80 / 65 / 45 / 25 / 10 按定义就是仓位百分比（`erp_allocation_v4.py` 18："ERP_adj 分档 → 10/25/45/65/80/90%"）。现在旧首页和策略页 ERP 图都显示"v4 档位（背景读数）65"、区间表里写"→ 80 档"。
- 推荐：1e-2 一并改为按正常化 ERP 区间称呼（"4.5–5.5% 档"，6 档中第 3 档），图上不再显示 90…10；前向记录 CSV、规则、预注册不变
- 备选：保持数字，只靠"背景读数、不作仓位依据"说明区分

---

## 11. 视觉待办（只登记，不在本轮做）

- 海外页大量内联样式、emoji、彩色渐变卡片，颜色未走 `ac_tokens.css`
- A 股标签的 VIX / 资金 / 热力卡片沿用旧首页样式，需统一到 ac_tokens
- AIAE 历史迷你图本轮不带过去，视觉轮再定
- 海外 ERP 标签"旧五维评分 / 旧引擎估算口径走势"是否继续展示
- 行业热力"R:75"等标注缺图例
- 宏观背景页手机端布局

## 12. 本轮发现、不在本轮处理（登记）

- **读页面会写服务器**：`GET /portfolio/trailing-stops`（决策中枢、组合页都会读）对行情滞后 >1 个交易日的持仓自动后台补行情，写 `data_lake` 行情 parquet（30 分钟内不重复）。与固定规则 8"会话的只读核对"冲突：建议之后决定是改成只在日终 / 导入时补，还是在规则 8 里写明这是允许的自动行为。在此之前，会话读这个接口前先在日志写明
- 回撤读数两处不一致（第 1 节），连同已登记的"回撤近似值（台账只到 11-03）"一起
- **R7 后端同类措辞**（留给第 0 轮后的措辞统一提交）：
  - `engines/erp_timing_engine.py` 152–159 `SIGNAL_MAP`：强力买入 / 买入 / 标配持有 / 逐步减仓 / 低配防御 / 清仓观望，带仓位区间 80–100% … 0–10%。消费者：`market_temp.py` 258（旧首页 ERP 卡）、`assemble_response.py` 430、`routers/strategy.py` 320（策略页 ERP 信号）
  - `engines/erp_us_engine.py` 133–138、`erp_hk_engine.py` 148–153、`erp_jp_engine.py` 约 126–130：同一套 `label_cn` + 仓位区间
  - `engines/rates_strategy_engine.py` 824："超配TLT+Gold 30%"（利率页目前未显示）
  - `dashboard_modules/decision/scenarios.py` 54："历史级别买入机会"（情景模拟，决策页已隐藏）
  - `dashboard_modules/report_generator.py` 26、530 与 `decision/conflicts.py` 149：AIAE 档名"低配置区"
  - ERP v4 告警文案已于 11-02 去掉仓位与加减仓措辞（`services/erp_v4_forward_log.py` 144），不在清单内
- 海外四地对比的 A 股缺省值写死 22.0（`routers/aiae.py` 302、`warmup_pipeline.py` 295），属"|| 默认数字"类问题
- `slippage_engine.py` 89 把 `hub_composite` 记作 `decision_price`，语义不对
- `narrative_engine.py` 读 `heatmap_data`，实际字段名是 `sector_heatmap`（叙事模块已下线）
- `main.py` 505 读 `market_temp.confidence`，字段不存在，数据新鲜度里 market_temp 恒为 unknown
- `_PUBLIC_PREFIXES` 其余前缀（`/decision/alerts` 含确认已读的 POST、`/simulate`、`/shock`、`/param-snapshot`、`/narrative`）：读取鉴权开启时已要令牌，只在开关关闭时免认证；留到 12 月后的安全待办
- `report_generator.py` 225、516 仍读 `suggested_position`（AIAE 矩阵上限），待后端仓位措辞统一时核对

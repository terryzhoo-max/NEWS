# 跟踪止盈锚点漂移修复 · 补丁与操作步骤（2026-11-13）

方案：`docs/TRAILING_ANCHOR_FIX_PLAN.md` 第 5 节。顺序：**部署 1（T1 + T3）→ F4 → 部署 2（T2）**。
补丁基于 `3c24641`，可直接应用到当前 `d7ca67d`（其后只多了日志提交，补丁不改日志）。
`git am` 时提示 "new blank line at EOF" 是方案文档末尾空行的警告，不影响应用。

---

## 一、部署 1：T1 + T3

### 1. 本机应用补丁（PowerShell）
```powershell
cd "D:\FIONA\google AI\quant_dashboard"
git status --short          # 应为空（工作区干净）
git log -1 --format=%h      # 应为 d7ca67d
git am (Get-ChildItem "D:\FIONA\google AI\tmp\trailing_fix_patches\deploy1\*.patch" | Sort-Object Name | ForEach-Object FullName)
git log --oneline -5        # 4 个新提交: docs / T1 / T1 界面 / T3
```
若 `git am` 报冲突：`git am --abort`（回到 d7ca67d），把输出贴给会话。

### 2. 推送（一键推送会先跑本机全量 pytest 与前端测试，并提交剩下的实施日志）
```powershell
$env:ALPHACORE_COMMIT_MSG = "docs: 跟踪止盈 T1/T3 实施日志 (锚点锁定+F4恢复入口; T2 另行部署)"; & "D:\FIONA\google AI\一键推送.bat"; Remove-Item Env:ALPHACORE_COMMIT_MSG
```

### 3. 部署窗口（北京时间）
- 今晚 11-13（周五）**22:30–23:59**，或
- 周六 11-14 **09:00–19:50**（避开 06:30、08:30 两个任务，以及每天 19:55–20:10 的重启）
- 不要拖到周一 11-16：最晚 **08:20** 前或 **09:15–15:25** 之间完成（避开 08:25–08:45、15:30–17:40）

服务器执行：`cd /root/quant_dashboard/quant_dashboard && bash update.sh`

### 4. 部署 1 后只读核对（会话经 18000 做，你只需开隧道）
- GET `/portfolio/trailing-stops`：13 只止损线与部署前（见实施日志表）逐值相同；全部 GREEN；`meta.engine` 仍为 2.1，`config_hash` 仍为 `ff6283d0a8`；9 只显示"已锁定"；`anchor_hints` 为空
- GET `/portfolio/trailing-stops/restore-preview`：proposals 只有 688825 / 688008；恢复后止损线 26.04 / 128.61；`would_trigger=false`
- 状态文件此时还没有 `anchor_lock` 字段（下一次日终提交才写），这是正常的

---

## 二、F4：恢复两只（先只读预览，你逐只确认后再 POST）

### 1. 只读预览（服务器执行；令牌从 .env 读取，不出现在命令行、不回显；不改 .env）
```bash
cd /root/quant_dashboard/quant_dashboard
curl -sS "http://127.0.0.1:8000/api/v1/portfolio/trailing-stops/restore-preview" -H 'X-AC-Caller: manual-curl' \
  -H @<(printf 'X-API-Key: %s\n' "$(grep -m1 '^API_SECRET_KEY=' .env | cut -d= -f2-)") \
  | docker exec -i quant_dashboard_app python -c "import json,sys; d=json.load(sys.stdin)['data']; [print(p['ts_code'], p['name'], '| 当前', p['current_anchor'], p['current_stop'], '| 快照', p['before_change']['snapshot_date'], p['before_change']['anchor'], p['before_change']['stop'], '/', p['before_change']['close'], '比值', round(p['before_change']['ratio'], 10), '| 恢复后', p['restored_stop'], p['restored_status'], '触发' if p['would_trigger'] else '不触发') for p in d['proposals']]"
```
预期两行：
- `688825.SH 长鑫科技 | 当前 2026-07-27 -2.08 | 快照 2026-11-12 2026-11-02 26.04 / 40.97 比值 0.6355870149 | 恢复后 26.04 GREEN 不触发`
- `688008.SH 澜起科技 | 当前 2026-08-26 114.27 | 快照 2026-11-12 2026-08-27 128.61 / 162.89 比值 0.7895512309 | 恢复后 128.61 GREEN 不触发`

（"当前"一列会随最新收盘变化；快照与恢复后的数值应与上面一致。）把输出贴给会话核对后，逐只确认。

### 2. 写入（服务器执行；每只一次，理由可改，≥4 字）
```bash
cd /root/quant_dashboard/quant_dashboard
CODE='688825.SH'; REASON='11-12 导入对账单后锚点漂移, 按 11-12 日终快照恢复 (F4)'
printf '{"ts_code":"%s","snapshot_date":"2026-11-12","reason":"%s"}' "$CODE" "$REASON" > /tmp/f4_body.json
curl -sS -X POST "http://127.0.0.1:8000/api/v1/portfolio/trailing-stops/restore-anchor" \
  -H 'Content-Type: application/json' -H 'X-AC-Caller: manual-curl' \
  -H @<(printf 'X-API-Key: %s\n' "$(grep -m1 '^API_SECRET_KEY=' .env | cut -d= -f2-)") \
  --data-binary @/tmp/f4_body.json; echo; rm -f /tmp/f4_body.json
```
第二只把第 2 行改成 `CODE='688008.SH'` 再执行一遍。返回应为 `"status": "success"`，`restored_stop` 为 26.04 / 128.61。

### 3. F4 后只读核对
```bash
docker exec quant_dashboard_app python -c "import json; s=json.load(open('/app/data_lake/trailing_stop_state.json')); [print(c, s['positions'][c].get('anchor_lock'), s['positions'][c].get('published')) for c in ('688825.SH','688008.SH')]; [print(a) for a in s['audit'] if a['action']=='anchor_restore']"
docker exec quant_dashboard_app sh -c 'grep -h trailing_anchor_restore /app/data_lake/audit/write_log-*.jsonl | tail -2'
```
预期：两只 `anchor_lock` 分别为 11-02（exact）/ 08-27（inferred_cost），带 `restored_from: 2026-11-12`；`published.date` 为 2026-11-12；审计 2 条 `anchor_restore`；写操作日志 2 条（result=restored）。会话再经 18000 GET 确认页面上两只为 26.04 / 128.61。

---

## 三、部署 2：T2（F4 核对通过后）

### 1. 本机
```powershell
cd "D:\FIONA\google AI\quant_dashboard"
git status --short
git am (Get-ChildItem "D:\FIONA\google AI\tmp\trailing_fix_patches\deploy2\*.patch" | Sort-Object Name | ForEach-Object FullName)
$env:ALPHACORE_COMMIT_MSG = "跟踪止盈 T2: 止损线合理性下限 (新股ATR0剔除首日取小/50%封顶/CHECK需核对)"; & "D:\FIONA\google AI\一键推送.bat"; Remove-Item Env:ALPHACORE_COMMIT_MSG
```

### 2. 部署窗口
会话在 F4 核对后给出（同样避开禁止窗口）。服务器：`cd /root/quant_dashboard/quant_dashboard && bash update.sh`

### 3. 部署 2 后只读核对（会话经 18000）
- `meta.engine` = 2.2，`config_hash` 改变（新增 `max_r_pct`），属预期
- 深南电路 002916、生益电子 688183 止损线上调到成本的 50%（11-13 收盘口径：100.05、33.28），行下标"止损幅度已按 50% 封顶"
- 长鑫 26.04、澜起 128.61 不变；其余 9 只与部署前 GET 逐值相同；没有 RED，没有 CHECK
- 决策中枢"今日结论"止损项仍为"0 只"

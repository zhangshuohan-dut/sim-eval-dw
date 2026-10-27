# 仿真评测数据仓库（sim-eval-dw）

> 在线报告：https://sim-eval-dw.app.workbuddy.host/?sharecode=XBB4LLDA2I

把 3000 局算法仿真日志做成一套可复算的指标口径：ODS → DWD → DWS → ADS 四层建模、9 项数据质量断言、分位数与同场景配对实验。

数据来自 2026 年全国大学生数学建模竞赛 B 题（无线电干扰源定位与清除）的离线评测日志。原始日志只有一堆逐局 CSV，字段散、口径不统一、还有一列字段名与真实含义不符——这个项目就是把它整理成能支撑结论的样子。

**规模**：3000 局任务 / 39103 个干扰源 / 9 项质量断言全部通过。

---

## 1. 为什么做这件事

原始 CSV 的问题很具体：

1. 三份日志（问题三、问题四新版、问题四基线）列数不同、列名不同，同一个「定位清除总时间」在三处的字段名分别是 `t`、`t`、`t`，而「每源耗时」叫 `avg`。
2. 问题四配对表里有一列 `delta_s`，字面看是「总时间差」，实测等于「每源耗时差」。按字面用会把提升幅度算错一个量级。
3. 没有分位数，只有均值。而评测里真正该盯的是 P90/P99 的尾部。
4. 「这批数据能不能用」全靠人工扫表，没有断言。

改造目标：任何一张报表的数字，都能沿 `ADS → DWS → DWD → ODS → 源 CSV 行号` 回溯。

---

## 2. 分层架构

```
ODS  原始层（原样落地，不改列名，只补批次与行号）
  ├─ ods_q3_run_1000          问题三 1000 局
  ├─ ods_q4_run_new_1000      问题四新版 1000 局
  ├─ ods_q4_run_base_1000     问题四基线 1000 局
  └─ ods_q4_paired_1000       问题四同场景配对 1000 对
        ↓  统一粒度 + 派生指标 + 对账字段
DWD  明细层（一局一行）
  ├─ dwd_task_run             三份日志合并后的公共事实表
  ├─ dwd_task_stage_cost      阶段耗时竖表（列转行，供占比分析）
  └─ dwd_q4_paired            配对明细（重算总时间差，修正字段名歧义）
        ↓  预聚合
DWS  汇总层
  ├─ dws_problem_algo_stat    问题×算法：均值/中位/P90/P99/标准差/变异系数
  ├─ dws_src_bucket_stat      按源数分档的规模效应
  ├─ dws_stage_mix            时间构成占比
  ├─ dws_cost_model           单变量最小二乘：固定成本 + 边际单源成本
  ├─ dws_pair_by_src          配对差异按源数分层
  ├─ dws_q4_paired_stat       配对差异整体分布与胜率
  └─ dws_dir_profile          问题四定向源分布画像
        ↓  面向消费
ADS  应用层
  ├─ ads_kpi_overview         一屏指标卡
  ├─ ads_algo_lift            算法提升结论（含"没有提升"的诚实结论）
  ├─ ads_src_scaling          源数-单源耗时曲线
  ├─ ads_stage_mix            时间构成（图表数据源）
  ├─ ads_algorithm_behavior   策略分支与兜底路径触发画像
  └─ ads_resume_facts         汇报/简历口径卡
```

---

## 3. 快速开始

依赖：`python3`（只用标准库）、`sqlite3` 3.35+（需要窗口函数）。

```bash
bash etl/run_pipeline.sh
```

一次跑完：ODS 装载 → DWD → DWS → ADS → 数据质量校验，最后打印记分卡。

单步执行：

```bash
python3 etl/load_ods.py                                  # CSV → ODS
sqlite3 db/sim_dw.sqlite < sql/10_dwd.sql                # DWD
sqlite3 db/sim_dw.sqlite < sql/20_dws.sql                # DWS
sqlite3 db/sim_dw.sqlite < sql/30_ads.sql                # ADS
sqlite3 db/sim_dw.sqlite < sql/90_dq_checks.sql          # 质量断言
python3 etl/export_report_data.py                        # 导出报表数据
open report/index.html                                   # 打开分析报告
```

流水线是**幂等**的：ODS 全量覆盖、下游每个对象先 `DROP` 再建，重复执行结果一致。

---

## 4. 指标口径

| 指标 | 定义 | 备注 |
|---|---|---|
| `clear_ratio` | `cleared_cnt / src_cnt` | 分母为 0 时返回 NULL，不返回 0 |
| `is_all_cleared` | `cleared_cnt = src_cnt` | 用于统计「全清局占比」 |
| `reconcile_diff` | `total_sec - (move+measure+switch+clear)` | 对账字段，DQ-01 断言其绝对值 ≤ 0.05 秒 |
| `per_src_sec` | 直接取源字段，并与 `total_sec / src_cnt` 交叉校验 | DQ-02 |
| P50 / P90 / P99 | **最近秩法**：第 `round(n·p)` 个最小值 | 与 Excel `PERCENTILE.INC` 的线性插值略有差异，刻意选择，因为评测口径要可复现 |
| `cv_total` | `std(total_sec) / avg(total_sec)` | 标准差用 `sqrt(E[x²] − E[x]²)` 在 SQL 内计算 |
| `wall_headroom_x` | `1200 / max(wall_sec)` | 赛题程序运行上限 20 分钟，余量倍数 |

---

## 5. 结论

**1. 移动是唯一真正的瓶颈。**
问题三移动占 76.18%、测量 17.50%、切频 3.41%、定位清除 2.92%；问题四移动占 71.44%、测量升到 22.55%。优化路径的收益远大于抠测量精度。

**2. 规模效应显著，来源是固定成本摊薄。**
问题三单源耗时从 10 源 297.8 秒降到 16 源 208.8 秒（−29.9%），同期单局总耗时反而从 2977.6 秒升到 3340.8 秒。用最小二乘拆开：

```
总耗时 ≈ 2397.4 秒（截距，与源数无关） + 57.65 秒/源 × 源数
R² = 0.1992
```

R² 只有 0.20，这条线性关系**解释力有限**——剩下大部分波动来自每局源的空间分布与巡查路径长度。诚实的结论是「源数不足以单独解释耗时差异」，而不是换个说法把 R² 说圆。

**3. 均值不够，必须看尾部。**
问题三单局总耗时 P50 3141 秒、P90 3481 秒、P99 3817 秒，变异系数 8.03%（单源耗时的变异系数更高，13.91%）。波动主要来自各局源数不同，不是算法随机性——同一源数档内的离散度明显小于跨档。

**4. 配对实验推翻了一个直觉。**
1000 对同场景（种子 750000–750999）比较：新版平均多花 5.1 秒（+0.09%），只有 35.6% 的场景更快，中位差 +8.0 秒。

所以「新版更快」这句话在题设误差范围内**不成立**。它的真实收益是容错：覆盖更保守（平均覆盖点从 36.8 增至 43.3，+17.7%），代价是这 +0.09%。因为定位清除只占总时间 1.72%，覆盖变保守对整体的影响被稀释了。

能算出「没有提升」并且说清楚原因，比硬凑一个提升幅度有价值。

**5. 兜底路径的触发率是可以量化的。**
问题四 1000 局中，补测达上限转覆盖的频道 98 个（占 0.75%）；问题三的 `forced / dedup / relaxed / degenerate` 四个兜底计数全为 0——说明预设哨点在终测集上足够用，兜底逻辑未被触发。

---

## 6. 数据质量

9 项断言，任一 FAIL 即为 `BLOCKED`，阻断下游出表：

| 编号 | 断言 | 维度 |
|---|---|---|
| DQ-01 | 总时间 = 移动+测量+切频+清除（≤0.05 秒） | 完整性 |
| DQ-02 | 单源耗时 = 总时间 / 源数 | 一致性 |
| DQ-03 | 0 ≤ 清除数 ≤ 源数 | 有效性 |
| DQ-04 | run_id 唯一 | 唯一性 |
| DQ-05 | 关键字段非空 | 完整性 |
| DQ-06 | `delta_s` 实为每源差（字段名歧义核查） | 口径 |
| DQ-07 | 阶段耗时非负 | 有效性 |
| DQ-08 | 程序运行时间 ≤ 1200 秒 | 约束 |
| DQ-09 | 每局全部清除 | 业务 |

当前结果：9 PASS / 0 FAIL / 0 WARN，平均通过率 100%。

---

## 7. 已知局限

1. **定向源比例无法归因。** 本批 1000 局问题四数据里，定向源个数与源总数近似共线（定向占比固定在 60% 附近），因此不能从中分离「定向源比例」的影响。要做归因必须另跑变比例实验。`dws_dir_profile` 只做分布画像，不下因果结论。
2. **离线和官方测试不能混算。** 这些是离线仿真日志，与官方模拟器的正式测试记录场景分布不同，不能放在同一张表里比较。
3. **没有分区与增量。** 目前是全量覆盖式重建（数据量 4000 行，够用）。真实数仓应按 `dt` 分区、按批次增量写入，见 `docs/mysql_migration.md`。

---

## 8. SQL 技术点

如果被问到「这里面有什么值得说的 SQL」，答案是这四处：

1. **没有 `PERCENTILE` 也能算分位数**：`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY x)` 配 `COUNT() OVER (...)`，再用 `MAX(CASE WHEN rn = CAST(ROUND(cnt*0.9) AS INTEGER) THEN x END)` 取最近秩。
2. **列转行**：`dwd_task_stage_cost` 用四个 `UNION ALL` 把宽表拆成竖表，占比分析才写得干净。
3. **在 SQL 里做最小二乘**：`slope = cov(x,y)/var(x)`，`intercept = ȳ − slope·x̄`，`R² = cov²/(var_x·var_y)`——不导出到 Python 也能给出固定成本拆解。
4. **断言式质量校验**：每项检查是一条 `INSERT INTO dq_check_result SELECT ...`，`status` 由 `CASE WHEN failed_cnt = 0 THEN 'PASS'` 判定，最后汇总成 `READY/BLOCKED`。

---

## 9. 目录结构

```
sim-eval-dw/
├── data/raw/                    原始逐局 CSV（不改动）
├── etl/
│   ├── load_ods.py              CSV → ODS，含装载日志与幂等
│   ├── run_pipeline.sh          一键重建
│   └── export_report_data.py    导出报表数据（report/data.js）
├── sql/
│   ├── 10_dwd.sql               明细层
│   ├── 20_dws.sql               汇总层
│   ├── 30_ads.sql               应用层
│   └── 90_dq_checks.sql         数据质量断言
├── db/sim_dw.sqlite             产物（可随时重建，不入库）
├── report/
│   ├── index.html               分析报告（ECharts）
│   └── data.js                  报表数据（由脚本生成）
└── docs/
    └── mysql_migration.md       MySQL / HiveSQL 迁移要点
```

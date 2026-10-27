# 迁移到 MySQL / HiveSQL 的要点

本项目当前跑在 SQLite 上，是为了零依赖、一条命令复现。SQL 本身的写法（CTE、窗口函数、`UNION ALL`、`CASE WHEN`）在 MySQL 8 与 Hive 上都能直接用，需要改的是下面这几处。

---

## 1. 类型映射

| SQLite | MySQL | Hive | 说明 |
|---|---|---|---|
| `INTEGER` | `INT` / `BIGINT` | `BIGINT` | 主键与外键统一 `BIGINT` |
| `REAL` | `DECIMAL(18,6)` 或 `DOUBLE` | `DOUBLE` | **耗时类字段建议 `DECIMAL(18,6)`**，浮点比较会踩 `0.1+0.2≠0.3` 的坑 |
| `TEXT` | `VARCHAR(64)` | `STRING` | 编码、枚举列按实际长度给 |
| `NUMERIC`（ODS 动态类型） | 按列显式声明 | `STRING` | ODS 层 Hive 上建议全 `STRING`，DWD 再转 |

DDL 示例（`dwd_task_run` 的 Hive 版本）：

```sql
CREATE TABLE IF NOT EXISTS dwd.dwd_task_run (
    run_id              STRING      COMMENT '任务唯一键：problem_algo_seed',
    problem_cd          STRING      COMMENT 'Q3 / Q4',
    algo_cd             STRING      COMMENT 'final_v3 / new / baseline',
    seed_no             BIGINT      COMMENT '场景种子，配对实验的关联键',
    src_cnt             INT         COMMENT '本局干扰源个数',
    dir_src_cnt         INT         COMMENT '定向源个数，问题三为 NULL',
    cleared_cnt         INT         COMMENT '成功清除个数',
    total_sec           DECIMAL(18,6) COMMENT '定位清除总时间（秒）',
    per_src_sec         DECIMAL(18,6) COMMENT '单源耗时（秒）',
    move_sec            DECIMAL(18,6),
    measure_sec         DECIMAL(18,6),
    switch_sec          DECIMAL(18,6),
    clear_sec           DECIMAL(18,6),
    wall_sec            DECIMAL(18,6) COMMENT '程序运行时间，上限 1200 秒',
    clear_ratio         DECIMAL(10,6),
    is_all_cleared      TINYINT,
    stage_sum_sec       DECIMAL(18,6),
    reconcile_diff      DECIMAL(18,6) COMMENT '对账字段，DQ-01 断言 |diff| <= 0.05',
    dir_ratio           DECIMAL(10,4)
)
COMMENT '逐局任务事实表'
PARTITIONED BY (dt STRING COMMENT '数据日期，yyyy-MM-dd')
STORED AS PARQUET
TBLPROPERTIES ('parquet.compression'='snappy');
```

---

## 2. 分位数：三种写法

本项目用「最近秩法」，因为评测口径要可复现，不接受插值带来的口径漂移。

**MySQL 8 / Hive（窗口函数，等价于本项目写法）**

```sql
WITH ranked AS (
    SELECT problem_cd, algo_cd, total_sec,
           ROW_NUMBER() OVER (PARTITION BY problem_cd, algo_cd ORDER BY total_sec) AS rn,
           COUNT(*)     OVER (PARTITION BY problem_cd, algo_cd)                    AS cnt
    FROM dwd_task_run
)
SELECT problem_cd, algo_cd,
       MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.90) AS INT) THEN total_sec END) AS p90_total_sec
FROM ranked
GROUP BY problem_cd, algo_cd;
```

**Hive 原生命令（更省事，但口径是线性插值，结果会与上一种差几十毫秒）**

```sql
SELECT problem_cd, algo_cd,
       percentile(total_sec, 0.5)  AS p50,
       percentile(total_sec, 0.9)  AS p90,
       percentile_approx(total_sec, 0.99) AS p99_approx
FROM dwd_task_run
GROUP BY problem_cd, algo_cd;
```

**MySQL 8 原生**

```sql
SELECT DISTINCT
       problem_cd, algo_cd,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_sec) OVER (PARTITION BY problem_cd, algo_cd) AS p90
FROM dwd_task_run;
```

> 选哪种取决于团队口径。**同一个指标只能选一种，并写进指标字典**——两套混用就会出现「同一张报表两个 P90」。

---

## 3. 分区与增量

SQLite 版是全量 `DROP + CREATE`，4000 行没问题。上生产要改成按天分区 + 增量覆盖：

```sql
-- 每次只重写当天分区，历史分区不动
INSERT OVERWRITE TABLE dwd.dwd_task_run PARTITION (dt = '${biz_date}')
SELECT ... FROM ods.ods_q3_run_1000 WHERE dt = '${biz_date}'
UNION ALL
SELECT ... FROM ods.ods_q4_run_new_1000 WHERE dt = '${biz_date}';
```

配套要点：

1. **幂等键**：`run_id` 在分区内唯一，`INSERT OVERWRITE` 天然去重；如果改用 `INSERT INTO`，必须先按 `run_id` 去重（`ROW_NUMBER() OVER (PARTITION BY run_id ORDER BY _load_ts DESC) = 1`）。
2. **ODS 落地**：原始 CSV 建议原样进 HDFS 的 `ods/<table>/dt=YYYY-MM-DD/`，保留 `_src_file`、`_row_no`，出问题能回到具体行。
3. **小文件**：逐局日志单文件很小，落盘前按 128MB 合并，否则 Hive 上几万个 KB 级文件会把 NameNode 拖死。
4. **调度依赖**：`ODS → DWD → DWS → ADS → DQ` 串行，DQ 结果为 `BLOCKED` 时不触发 ADS 下游（在本项目里体现为 `dq_scorecard.pipeline_status`）。

---

## 4. 函数差异对照

| 用途 | SQLite | MySQL | Hive |
|---|---|---|---|
| 当前时间 | `datetime('now','localtime')` | `NOW()` | `current_timestamp()` |
| 字符串拼接 | `\|\|` | `CONCAT()` | `CONCAT()` / `\|\|` |
| 空值兜底 | `COALESCE` / `IFNULL` | `IFNULL` / `COALESCE` | `COALESCE` / `NVL` |
| 取整 | `CAST(x AS INTEGER)`（向零截断） | `CAST(x AS SIGNED)` | `CAST(x AS BIGINT)` |
| 平方根 | `SQRT()` | `SQRT()` | `SQRT()` |
| 安全除法 | `NULLIF(分母,0)` | `NULLIF` | `NULLIF` |

**注意 `CAST` 的截断行为**：SQLite 与 MySQL 对负数 `CAST(-1.5 AS INT)` 都向零截断，Hive 也是。如果分位数取的是 `(n-1)*p` 的插值位置，负数索引不可能出现，但 `ROUND` 与 `CAST` 组合时仍建议显式加 `FLOOR`。

---

## 5. 迁移后必须重跑的三件事

1. **DQ-01 ~ DQ-09 全部重跑**，确认 `pipeline_status = READY`。`DECIMAL` 与 `DOUBLE` 的精度差异会让 `reconcile_diff` 的阈值（0.05 秒）表现不同。
2. **对账分位数**：用同一批种子，比较 SQLite 与目标库的 P50/P90/P99，允许误差应小于 0.01 秒；超过说明取了不同的分位数算法。
3. **重算 ADS 口径卡**，把 `ads_resume_facts` 里的数字与 README 的结论表逐条对一遍——数字变了但结论没变，才说明只是存储引擎换了。

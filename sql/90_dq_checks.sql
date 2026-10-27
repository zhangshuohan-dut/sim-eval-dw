-- =====================================================================
-- 90_dq_checks.sql  |  数据质量校验层
-- 目标：把「这批数据能不能用」变成可执行的断言，而不是靠人工扫表。
-- 每个检查项输出：总行数、失败行数、通过率、状态。
-- 最后汇总成 dq_scorecard，并把失败项视为流水线阻断信号。
-- =====================================================================

DROP TABLE IF EXISTS dq_check_result;
CREATE TABLE dq_check_result (
    check_cd    TEXT,
    check_name  TEXT,
    dimension   TEXT,
    total_cnt   INTEGER,
    failed_cnt  INTEGER,
    pass_rate   REAL,
    status      TEXT,
    checked_at  TEXT
);

-- DQ-01 完整性：四项动作耗时之和应等于总时间（允许浮点误差 0.05 秒）
INSERT INTO dq_check_result
SELECT 'DQ-01', '总时间 = 移动+测量+切频+清除', '完整性',
       COUNT(*),
       SUM(CASE WHEN ABS(reconcile_diff) > 0.05 THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN ABS(reconcile_diff) > 0.05 THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN ABS(reconcile_diff) > 0.05 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-02 一致性：单源耗时 = 总时间 / 源数
INSERT INTO dq_check_result
SELECT 'DQ-02', '单源耗时 = 总时间 / 源数', '一致性',
       COUNT(*),
       SUM(CASE WHEN ABS(per_src_sec - total_sec / NULLIF(src_cnt, 0)) > 0.05 THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN ABS(per_src_sec - total_sec / NULLIF(src_cnt, 0)) > 0.05 THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN ABS(per_src_sec - total_sec / NULLIF(src_cnt, 0)) > 0.05 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-03 有效性：清除数不得超过源数，且不为负
INSERT INTO dq_check_result
SELECT 'DQ-03', '0 <= 清除数 <= 源数', '有效性',
       COUNT(*),
       SUM(CASE WHEN cleared_cnt < 0 OR cleared_cnt > src_cnt THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN cleared_cnt < 0 OR cleared_cnt > src_cnt THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN cleared_cnt < 0 OR cleared_cnt > src_cnt THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-04 唯一性：一局任务只应出现一行
INSERT INTO dq_check_result
SELECT 'DQ-04', 'run_id 唯一', '唯一性',
       COUNT(*),
       COUNT(*) - COUNT(DISTINCT run_id),
       ROUND(CAST(COUNT(DISTINCT run_id) AS REAL) / COUNT(*), 6),
       CASE WHEN COUNT(*) = COUNT(DISTINCT run_id) THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-05 完整性：关键维度与度量不得为空
INSERT INTO dq_check_result
SELECT 'DQ-05', '关键字段非空', '完整性',
       COUNT(*),
       SUM(CASE WHEN seed_no IS NULL OR src_cnt IS NULL OR total_sec IS NULL
                     OR per_src_sec IS NULL OR cleared_cnt IS NULL THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN seed_no IS NULL OR src_cnt IS NULL OR total_sec IS NULL
                     OR per_src_sec IS NULL OR cleared_cnt IS NULL THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN seed_no IS NULL OR src_cnt IS NULL OR total_sec IS NULL
                     OR per_src_sec IS NULL OR cleared_cnt IS NULL THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-06 口径校验：配对表原始 delta_s 字段的真实含义
--       若失败行数为 0，说明 delta_s 确实等于「每源耗时差」而不是「总时间差」——
--       这正是本次 ETL 发现并修正的字段名歧义。
INSERT INTO dq_check_result
SELECT 'DQ-06', 'delta_s 实为每源差（字段名歧义核查）', '口径',
       COUNT(*),
       SUM(CASE WHEN ABS(src_delta_sec - (new_per_src_sec - base_per_src_sec)) > 0.001 THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN ABS(src_delta_sec - (new_per_src_sec - base_per_src_sec)) > 0.001 THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN ABS(src_delta_sec - (new_per_src_sec - base_per_src_sec)) > 0.001 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_q4_paired;

-- DQ-07 有效性：任何阶段耗时不得为负
INSERT INTO dq_check_result
SELECT 'DQ-07', '阶段耗时非负', '有效性',
       COUNT(*),
       SUM(CASE WHEN move_sec < 0 OR measure_sec < 0 OR switch_sec < 0 OR clear_sec < 0 THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN move_sec < 0 OR measure_sec < 0 OR switch_sec < 0 OR clear_sec < 0 THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN move_sec < 0 OR measure_sec < 0 OR switch_sec < 0 OR clear_sec < 0 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-08 约束：程序运行时间不得超过赛题 20 分钟（1200 秒）上限
INSERT INTO dq_check_result
SELECT 'DQ-08', '程序运行时间 <= 1200 秒', '约束',
       COUNT(*),
       SUM(CASE WHEN wall_sec > 1200 THEN 1 ELSE 0 END),
       ROUND(1.0 - CAST(SUM(CASE WHEN wall_sec > 1200 THEN 1 ELSE 0 END) AS REAL) / COUNT(*), 6),
       CASE WHEN SUM(CASE WHEN wall_sec > 1200 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'FAIL' END,
       datetime('now', 'localtime')
FROM dwd_task_run;

-- DQ-09 业务：每局是否完成全部源清除（非脏数据，但必须可见）
INSERT INTO dq_check_result
SELECT 'DQ-09', '每局全部清除', '业务',
       COUNT(*),
       SUM(CASE WHEN is_all_cleared = 0 THEN 1 ELSE 0 END),
       ROUND(AVG(is_all_cleared), 6),
       CASE WHEN SUM(CASE WHEN is_all_cleared = 0 THEN 1 ELSE 0 END) = 0 THEN 'PASS' ELSE 'WARN' END,
       datetime('now', 'localtime')
FROM dwd_task_run;


-- ---------------------------------------------------------------------
-- 汇总记分卡：一行看全貌，FAIL 数 > 0 即应阻断下游
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dq_scorecard;
CREATE TABLE dq_scorecard AS
SELECT
    COUNT(*)                                        AS check_cnt,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS pass_cnt,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS fail_cnt,
    SUM(CASE WHEN status = 'WARN' THEN 1 ELSE 0 END) AS warn_cnt,
    ROUND(AVG(pass_rate), 6)                        AS avg_pass_rate,
    CASE WHEN SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) = 0
         THEN 'READY' ELSE 'BLOCKED' END            AS pipeline_status,
    MAX(checked_at)                                 AS checked_at
FROM dq_check_result;

-- =====================================================================
-- 10_dwd.sql  |  DWD 明细层
-- 目标：把 ODS 的四张原始表统一到「一局任务一行」的公共粒度，
--       完成类型转换、口径统一、派生指标与对账字段。
-- 方言：SQLite 3.35+（窗口函数）。MySQL 迁移点见 docs/mysql_migration.md
-- 幂等：每个对象先 DROP 再建，可重复执行
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. dwd_task_run：逐局任务事实表（问题三 + 问题四新旧两版合并）
--    统一列语义后，后续所有汇总都只依赖这一张表。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dwd_task_run;
CREATE TABLE dwd_task_run AS
WITH src AS (
    SELECT
        'Q3'                                        AS problem_cd,
        'final_v3'                                  AS algo_cd,
        CAST(seed      AS INTEGER)                  AS seed_no,
        CAST(n_src     AS INTEGER)                  AS src_cnt,
        CAST(NULL AS INTEGER)                       AS dir_src_cnt,
        CAST(killed    AS INTEGER)                  AS cleared_cnt,
        CAST(t         AS REAL)                     AS total_sec,
        CAST(avg       AS REAL)                     AS per_src_sec,
        CAST(n_measure AS INTEGER)                  AS measure_cnt,
        CAST(n_clear   AS INTEGER)                  AS clear_cnt,
        CAST(NULL AS INTEGER)                       AS switch_cnt,
        CAST(t_move    AS REAL)                     AS move_sec,
        CAST(t_measure AS REAL)                     AS measure_sec,
        CAST(t_switch  AS REAL)                     AS switch_sec,
        CAST(t_clear   AS REAL)                     AS clear_sec,
        CAST(NULL AS INTEGER)                       AS max_refine_rounds,
        CAST(NULL AS INTEGER)                       AS cap_ch_cnt,
        CAST(NULL AS INTEGER)                       AS cover_event_cnt,
        CAST(NULL AS INTEGER)                       AS cover_pt_cnt,
        CAST(wall      AS REAL)                     AS wall_sec,
        CAST(viol      AS INTEGER)                  AS viol_cnt,
        CAST(aborted   AS INTEGER)                  AS aborted_flag,
        CAST(NULL AS INTEGER)                       AS unresolved_cnt,
        CAST(forced     AS INTEGER)                 AS forced_cnt,
        CAST(dedup      AS INTEGER)                 AS dedup_cnt,
        CAST(relaxed    AS INTEGER)                 AS relaxed_cnt,
        CAST(degenerate AS INTEGER)                 AS degenerate_cnt,
        _src_file, _load_ts
    FROM ods_q3_run_1000

    UNION ALL

    SELECT
        'Q4', 'new',
        CAST(seed AS INTEGER), CAST(n_src AS INTEGER), CAST(n_dir AS INTEGER),
        CAST(killed AS INTEGER), CAST(t AS REAL), CAST(avg AS REAL),
        CAST(n_measure AS INTEGER), CAST(n_clear AS INTEGER), CAST(n_switch AS INTEGER),
        CAST(t_move AS REAL), CAST(t_measure AS REAL), CAST(t_switch AS REAL), CAST(t_clear AS REAL),
        CAST(max_refine_rounds AS INTEGER), CAST(n_ch_at_cap AS INTEGER),
        CAST(n_cover_events AS INTEGER), CAST(cover_pts AS INTEGER),
        CAST(wall AS REAL), CAST(viol AS INTEGER), CAST(aborted AS INTEGER), CAST(unresolved AS INTEGER),
        CAST(NULL AS INTEGER), CAST(NULL AS INTEGER), CAST(NULL AS INTEGER), CAST(NULL AS INTEGER),
        _src_file, _load_ts
    FROM ods_q4_run_new_1000

    UNION ALL

    SELECT
        'Q4', 'baseline',
        CAST(seed AS INTEGER), CAST(n_src AS INTEGER), CAST(n_dir AS INTEGER),
        CAST(killed AS INTEGER), CAST(t AS REAL), CAST(avg AS REAL),
        CAST(n_measure AS INTEGER), CAST(n_clear AS INTEGER), CAST(n_switch AS INTEGER),
        CAST(t_move AS REAL), CAST(t_measure AS REAL), CAST(t_switch AS REAL), CAST(t_clear AS REAL),
        CAST(max_refine_rounds AS INTEGER), CAST(n_ch_at_cap AS INTEGER),
        CAST(n_cover_events AS INTEGER), CAST(cover_pts AS INTEGER),
        CAST(wall AS REAL), CAST(viol AS INTEGER), CAST(aborted AS INTEGER), CAST(unresolved AS INTEGER),
        CAST(NULL AS INTEGER), CAST(NULL AS INTEGER), CAST(NULL AS INTEGER), CAST(NULL AS INTEGER),
        _src_file, _load_ts
    FROM ods_q4_run_base_1000
),
typed AS (
    SELECT
        problem_cd || '_' || algo_cd || '_' || CAST(seed_no AS TEXT) AS run_id,
        *
    FROM src
)
SELECT
    run_id,
    problem_cd,
    algo_cd,
    seed_no,
    src_cnt,
    dir_src_cnt,
    cleared_cnt,
    total_sec,
    per_src_sec,
    measure_cnt,
    clear_cnt,
    switch_cnt,
    move_sec,
    measure_sec,
    switch_sec,
    clear_sec,
    max_refine_rounds,
    cap_ch_cnt,
    cover_event_cnt,
    cover_pt_cnt,
    wall_sec,
    viol_cnt,
    aborted_flag,
    unresolved_cnt,
    forced_cnt,
    dedup_cnt,
    relaxed_cnt,
    degenerate_cnt,

    -- 派生：完成率与是否全清
    CASE WHEN src_cnt > 0 THEN ROUND(CAST(cleared_cnt AS REAL) / src_cnt, 6) END AS clear_ratio,
    CASE WHEN cleared_cnt = src_cnt THEN 1 ELSE 0 END                            AS is_all_cleared,

    -- 对账：四项动作耗时之和 应等于 定位清除总时间
    ROUND(move_sec + measure_sec + switch_sec + clear_sec, 6)                    AS stage_sum_sec,
    ROUND(total_sec - (move_sec + measure_sec + switch_sec + clear_sec), 6)      AS reconcile_diff,

    -- 派生：定向源占比（仅问题四有值）
    CASE WHEN dir_src_cnt IS NULL THEN NULL
         WHEN src_cnt > 0 THEN ROUND(CAST(dir_src_cnt AS REAL) / src_cnt, 4) END AS dir_ratio,

    -- 派生：平均每次测量/清除的代价（看动作效率，不只看总量）
    CASE WHEN measure_cnt > 0 THEN ROUND(total_sec / measure_cnt, 3) END         AS sec_per_measure,
    CASE WHEN src_cnt > 0 THEN ROUND(CAST(measure_cnt AS REAL) / src_cnt, 2) END AS measure_per_src,

    _src_file,
    _load_ts
FROM typed;

CREATE UNIQUE INDEX idx_dwd_task_run_pk ON dwd_task_run (run_id);
CREATE INDEX idx_dwd_task_run_dim ON dwd_task_run (problem_cd, algo_cd, src_cnt);


-- ---------------------------------------------------------------------
-- 2. dwd_task_stage_cost：阶段耗时竖表（列转行）
--    宽表便于对账，竖表便于算占比与画堆叠图 —— 两种形态并存是常态。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dwd_task_stage_cost;
CREATE TABLE dwd_task_stage_cost AS
SELECT run_id, problem_cd, algo_cd, src_cnt, 'MOVE'    AS stage_cd, move_sec    AS stage_sec FROM dwd_task_run
UNION ALL
SELECT run_id, problem_cd, algo_cd, src_cnt, 'MEASURE', measure_sec FROM dwd_task_run
UNION ALL
SELECT run_id, problem_cd, algo_cd, src_cnt, 'SWITCH',  switch_sec  FROM dwd_task_run
UNION ALL
SELECT run_id, problem_cd, algo_cd, src_cnt, 'CLEAR',   clear_sec   FROM dwd_task_run;

CREATE INDEX idx_dwd_stage_cost_dim ON dwd_task_stage_cost (problem_cd, algo_cd, stage_cd);


-- ---------------------------------------------------------------------
-- 3. dwd_q4_paired：问题四同场景配对明细（同一 seed 上新版 vs 基线）
--    注意：原始 CSV 的 delta_s 字段名有歧义 —— 实测它等于「每源耗时差」，
--    而不是总时间差。这里重命名为 src_delta_sec，并另算 total_delta_sec。
--    这一条是本次建模做数据治理时真实踩到的坑，见 90_dq_checks.sql 的 DQ-06。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dwd_q4_paired;
CREATE TABLE dwd_q4_paired AS
SELECT
    'Q4PAIR_' || CAST(seed AS INTEGER)                       AS pair_id,
    CAST(seed AS INTEGER)                                    AS seed_no,
    CAST(n_src AS INTEGER)                                   AS src_cnt,
    CAST(n_dir AS INTEGER)                                   AS dir_src_cnt,
    ROUND(CAST(n_dir AS REAL) / NULLIF(CAST(n_src AS REAL), 0), 4) AS dir_ratio,
    CAST(new_killed  AS INTEGER)                             AS new_cleared_cnt,
    CAST(base_killed AS INTEGER)                             AS base_cleared_cnt,
    CAST(new_total_s AS REAL)                                AS new_total_sec,
    CAST(base_total_s AS REAL)                               AS base_total_sec,
    ROUND(CAST(new_total_s AS REAL) - CAST(base_total_s AS REAL), 6) AS total_delta_sec,
    ROUND((CAST(new_total_s AS REAL) - CAST(base_total_s AS REAL))
          / NULLIF(CAST(base_total_s AS REAL), 0), 6)         AS total_delta_pct,
    CAST(new_per_source_s AS REAL)                           AS new_per_src_sec,
    CAST(base_per_source_s AS REAL)                          AS base_per_src_sec,
    CAST(delta_s AS REAL)                                    AS src_delta_sec,   -- 原字段，实为每源差
    CASE WHEN CAST(new_total_s AS REAL) < CAST(base_total_s AS REAL) THEN 1 ELSE 0 END AS new_faster_flag,
    CAST(new_max_refine_rounds AS INTEGER)                   AS new_max_refine_rounds,
    CAST(new_n_ch_at_cap AS INTEGER)                         AS new_cap_ch_cnt,
    CAST(new_cover_pts AS INTEGER)                           AS new_cover_pt_cnt,
    CAST(new_wall AS REAL)                                   AS new_wall_sec,
    CAST(base_wall AS REAL)                                  AS base_wall_sec,
    CAST(new_viol AS INTEGER)                                AS new_viol_cnt,
    CAST(base_viol AS INTEGER)                               AS base_viol_cnt,
    CAST(new_aborted AS INTEGER)                             AS new_aborted_flag,
    CAST(base_aborted AS INTEGER)                            AS base_aborted_flag
FROM ods_q4_paired_1000;

CREATE UNIQUE INDEX idx_dwd_q4_paired_pk ON dwd_q4_paired (pair_id);
CREATE INDEX idx_dwd_q4_paired_src ON dwd_q4_paired (src_cnt, dir_ratio);

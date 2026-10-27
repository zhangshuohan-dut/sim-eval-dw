-- =====================================================================
-- 30_ads.sql  |  ADS 应用层
-- 目标：直接面向消费方的成品表 —— 一屏指标卡、算法提升结论、
--       图表数据源、以及给简历/汇报用的口径化数字。
-- 依赖：20_dws.sql、90_dq_checks.sql（画像表由 90 生成）
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. ads_kpi_overview：单行总览指标卡
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_kpi_overview;
CREATE TABLE ads_kpi_overview AS
SELECT
    (SELECT COUNT(*) FROM dwd_task_run)                                        AS total_run_cnt,
    (SELECT SUM(src_cnt) FROM dwd_task_run)                                    AS total_src_cnt,
    (SELECT SUM(cleared_cnt) FROM dwd_task_run)                                AS total_cleared_cnt,
    (SELECT ROUND(CAST(SUM(cleared_cnt) AS REAL) / NULLIF(SUM(src_cnt), 0), 6)
       FROM dwd_task_run)                                                      AS overall_clear_ratio,
    (SELECT ROUND(AVG(is_all_cleared), 4) FROM dwd_task_run)                   AS all_cleared_run_ratio,

    -- 主力方案（问题三 final_v3）的核心效率指标
    (SELECT avg_per_src_sec FROM dws_problem_algo_stat
      WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3')                        AS q3_avg_per_src_sec,
    (SELECT p90_per_src_sec FROM dws_problem_algo_stat
      WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3')                        AS q3_p90_per_src_sec,
    (SELECT avg_total_sec FROM dws_problem_algo_stat
      WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3')                        AS q3_avg_total_sec,

    -- 问题四主力方案
    (SELECT avg_per_src_sec FROM dws_problem_algo_stat
      WHERE problem_cd = 'Q4' AND algo_cd = 'new')                             AS q4_avg_per_src_sec,
    (SELECT p90_per_src_sec FROM dws_problem_algo_stat
      WHERE problem_cd = 'Q4' AND algo_cd = 'new')                             AS q4_p90_per_src_sec,

    -- 程序运行时间约束：赛题上限 1200 秒（20 分钟）
    (SELECT ROUND(MAX(wall_sec), 3) FROM dwd_task_run)                         AS max_wall_sec,
    1200                                                                       AS wall_limit_sec,
    (SELECT ROUND(1200.0 / NULLIF(MAX(wall_sec), 0), 1) FROM dwd_task_run)     AS wall_headroom_x,

    -- 稳定性：不变量违例、异常中止、未决频道
    (SELECT COALESCE(SUM(viol_cnt), 0) FROM dwd_task_run)                                   AS total_viol_cnt,
    (SELECT COALESCE(SUM(aborted_flag), 0) FROM dwd_task_run)                               AS total_aborted_cnt,
    (SELECT COALESCE(SUM(unresolved_cnt), 0) FROM dwd_task_run)                             AS total_unresolved_cnt,

    -- 固定成本模型（问题三）
    (SELECT intercept_sec FROM dws_cost_model WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3') AS q3_fixed_cost_sec,
    (SELECT slope_sec_per_src FROM dws_cost_model WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3') AS q3_marginal_sec_per_src,
    (SELECT r_squared FROM dws_cost_model WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3')      AS q3_cost_model_r2;


-- ---------------------------------------------------------------------
-- 2. ads_algo_lift：问题四新旧方案同场景配对对比（对外结论表）
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_algo_lift;
CREATE TABLE ads_algo_lift AS
SELECT
    'Q4 19m 矩形覆盖 vs 20m 六角点阵'                     AS comparison,
    pair_cnt,
    avg_new_total_sec,
    avg_base_total_sec,
    avg_total_delta_sec,
    ROUND(lift_total_pct * 100, 2)                      AS lift_total_pct,
    new_faster_cnt,
    ROUND(new_faster_rate * 100, 2)                     AS new_faster_rate_pct,
    -- 每源口径：论文正文报告的就是这一套（均值差、相对变化、中位差）
    avg_new_per_src_sec,
    avg_base_per_src_sec,
    avg_src_delta_sec,
    ROUND(per_src_lift_pct * 100, 3)                    AS per_src_lift_pct,
    p50_src_delta_sec,
    p10_total_delta_sec,
    p50_total_delta_sec,
    p90_total_delta_sec,
    -- 定性说明：这是覆盖策略的代价对照，不是算法版本优劣；
    -- 两者设计半径不同（19 m vs 名义 20 m），差值是买 1 m 清除余量的钱。
    printf('%d 对同场景中，19m 矩形单元覆盖相对 20m 六角点阵每源多耗 %.3f s（+%.3f%%），换取 1m 清除余量；'
           || '两种策略均全部清除，属数值稳健性加固，不是算法退化',
           pair_cnt, avg_src_delta_sec, per_src_lift_pct * 100) AS conclusion
FROM dws_q4_paired_stat;


-- ---------------------------------------------------------------------
-- 3. ads_src_scaling：源数-单源耗时曲线（折线图数据源）
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_src_scaling;
CREATE TABLE ads_src_scaling AS
SELECT
    problem_cd,
    algo_cd,
    algo_cd AS series_name,
    src_cnt,
    run_cnt,
    avg_per_src_sec,
    avg_total_sec
FROM dws_src_bucket_stat
WHERE (problem_cd = 'Q3' AND algo_cd = 'final_v3')
   OR (problem_cd = 'Q4' AND algo_cd IN ('new', 'baseline'))
ORDER BY problem_cd, algo_cd, src_cnt;


-- ---------------------------------------------------------------------
-- 4. ads_stage_mix：时间构成（堆叠柱/饼图数据源）
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_stage_mix;
CREATE TABLE ads_stage_mix AS
SELECT
    problem_cd,
    algo_cd,
    stage_cd,
    CASE stage_cd
        WHEN 'MOVE'    THEN '移动'
        WHEN 'MEASURE' THEN '测量'
        WHEN 'SWITCH'  THEN '切频'
        WHEN 'CLEAR'   THEN '定位清除'
    END AS stage_name,
    stage_sec,
    ROUND(stage_ratio * 100, 2) AS stage_ratio_pct
FROM dws_stage_mix
WHERE (problem_cd = 'Q3' AND algo_cd = 'final_v3')
   OR (problem_cd = 'Q4' AND algo_cd = 'new')
ORDER BY problem_cd, stage_ratio DESC;


-- ---------------------------------------------------------------------
-- 5. ads_algorithm_behavior：策略分支与兜底路径触发画像
--    回答「算法有没有走到异常/兜底分支」，比只看总耗时更能解释稳定性。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_algorithm_behavior;
CREATE TABLE ads_algorithm_behavior AS
SELECT
    problem_cd,
    algo_cd,
    COUNT(*)                                  AS run_cnt,
    ROUND(AVG(max_refine_rounds), 2)          AS avg_max_refine_rounds,
    MAX(max_refine_rounds)                    AS max_refine_rounds,
    COALESCE(SUM(cap_ch_cnt), 0)              AS cap_ch_sum,
    ROUND(COALESCE(SUM(cap_ch_cnt), 0) * 1.0 / SUM(src_cnt), 4) AS cap_ch_rate,
    COALESCE(SUM(cover_event_cnt), 0)         AS cover_event_sum,
    ROUND(AVG(cover_pt_cnt), 1)               AS avg_cover_pt_cnt,
    COALESCE(SUM(forced_cnt), 0)              AS forced_sum,
    COALESCE(SUM(dedup_cnt), 0)               AS dedup_sum,
    COALESCE(SUM(relaxed_cnt), 0)             AS relaxed_sum,
    COALESCE(SUM(degenerate_cnt), 0)          AS degenerate_sum
FROM dwd_task_run
GROUP BY problem_cd, algo_cd;


-- ---------------------------------------------------------------------
-- 5. ads_resume_facts：简历/汇报口径卡（一句话数字，直接用）
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS ads_resume_facts;
CREATE TABLE ads_resume_facts AS
SELECT '样本规模'   AS fact_name, CAST(total_run_cnt AS TEXT) || ' 局 / ' || CAST(total_src_cnt AS TEXT) || ' 个源' AS fact_value FROM ads_kpi_overview
UNION ALL
SELECT '清除完成率', CAST(ROUND(overall_clear_ratio * 100, 2) AS TEXT) || '%' FROM ads_kpi_overview
UNION ALL
SELECT '问题三平均单源耗时', CAST(q3_avg_per_src_sec AS TEXT) || ' 秒/源' FROM ads_kpi_overview
UNION ALL
SELECT '问题三 P90 单源耗时', CAST(q3_p90_per_src_sec AS TEXT) || ' 秒/源' FROM ads_kpi_overview
UNION ALL
SELECT '固定成本项', CAST(q3_fixed_cost_sec AS TEXT) || ' 秒（与源数无关）' FROM ads_kpi_overview
UNION ALL
SELECT '边际单源成本', CAST(q3_marginal_sec_per_src AS TEXT) || ' 秒/源' FROM ads_kpi_overview
UNION ALL
SELECT '线性模型拟合优度', 'R² = ' || CAST(q3_cost_model_r2 AS TEXT) FROM ads_kpi_overview
UNION ALL
SELECT '程序运行峰值', CAST(max_wall_sec AS TEXT) || ' 秒（上限 1200 秒，余量 ' || CAST(wall_headroom_x AS TEXT) || ' 倍）' FROM ads_kpi_overview
UNION ALL
SELECT '稳定性', CAST(total_viol_cnt AS TEXT) || ' 次不变量违例 / ' || CAST(total_aborted_cnt AS TEXT) || ' 次异常中止' FROM ads_kpi_overview
UNION ALL
SELECT '覆盖策略代价', CAST(pair_cnt AS TEXT) || ' 对同场景：19m 矩形覆盖较 20m 六角点阵每源 +'
       || printf('%.3f', avg_src_delta_sec) || ' 秒（+' || printf('%.3f', per_src_lift_pct * 100)
       || '%），换取 1m 清除余量' FROM dws_q4_paired_stat;

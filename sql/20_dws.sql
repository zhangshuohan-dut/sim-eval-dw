-- =====================================================================
-- 20_dws.sql  |  DWS 汇总层
-- 目标：按「问题 × 算法」「源数档」「定向源占比档」等分析维度预聚合，
--       并把分位数、变异系数、阶段占比一次性算好，供 ADS 与图表直接消费。
-- 分位数口径：最近秩法 nearest-rank（P90 = 第 ceil(0.9n) 个最小值）。
--             与 Excel PERCENTILE.INC 的线性插值略有差异，故在文档中显式声明。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. dws_problem_algo_stat：问题 × 算法的整体表现
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_problem_algo_stat;
CREATE TABLE dws_problem_algo_stat AS
WITH agg AS (
    SELECT
        problem_cd,
        algo_cd,
        COUNT(*)                        AS run_cnt,
        SUM(src_cnt)                    AS src_sum,
        SUM(cleared_cnt)                AS cleared_sum,
        SUM(aborted_flag)               AS aborted_cnt,
        SUM(viol_cnt)                   AS viol_sum,
        SUM(unresolved_cnt)             AS unresolved_sum,
        ROUND(AVG(total_sec), 3)        AS avg_total_sec,
        ROUND(AVG(per_src_sec), 3)      AS avg_per_src_sec,
        ROUND(MIN(total_sec), 3)        AS min_total_sec,
        ROUND(MAX(total_sec), 3)        AS max_total_sec,
        ROUND(AVG(wall_sec), 3)         AS avg_wall_sec,
        ROUND(MAX(wall_sec), 3)         AS max_wall_sec,
        ROUND(SQRT(AVG(total_sec * total_sec) - AVG(total_sec) * AVG(total_sec)), 3)   AS std_total_sec,
        ROUND(SQRT(AVG(per_src_sec * per_src_sec) - AVG(per_src_sec) * AVG(per_src_sec)), 3) AS std_per_src_sec,
        ROUND(AVG(measure_cnt), 1)      AS avg_measure_cnt,
        ROUND(AVG(clear_cnt), 1)        AS avg_clear_cnt
    FROM dwd_task_run
    GROUP BY problem_cd, algo_cd
),
ranked_total AS (
    SELECT problem_cd, algo_cd, total_sec AS v,
           ROW_NUMBER() OVER (PARTITION BY problem_cd, algo_cd ORDER BY total_sec) AS rn,
           COUNT(*)     OVER (PARTITION BY problem_cd, algo_cd)                    AS cnt
    FROM dwd_task_run
),
pct_total AS (
    SELECT problem_cd, algo_cd,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.50) AS INTEGER) THEN v END), 3) AS p50_total_sec,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.90) AS INTEGER) THEN v END), 3) AS p90_total_sec,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.99) AS INTEGER) THEN v END), 3) AS p99_total_sec
    FROM ranked_total
    GROUP BY problem_cd, algo_cd
),
ranked_per AS (
    SELECT problem_cd, algo_cd, per_src_sec AS v,
           ROW_NUMBER() OVER (PARTITION BY problem_cd, algo_cd ORDER BY per_src_sec) AS rn,
           COUNT(*)     OVER (PARTITION BY problem_cd, algo_cd)                      AS cnt
    FROM dwd_task_run
),
pct_per AS (
    SELECT problem_cd, algo_cd,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.50) AS INTEGER) THEN v END), 3) AS p50_per_src_sec,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.90) AS INTEGER) THEN v END), 3) AS p90_per_src_sec,
           ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.99) AS INTEGER) THEN v END), 3) AS p99_per_src_sec
    FROM ranked_per
    GROUP BY problem_cd, algo_cd
)
SELECT
    a.problem_cd,
    a.algo_cd,
    a.run_cnt,
    a.src_sum,
    a.cleared_sum,
    ROUND(CAST(a.cleared_sum AS REAL) / NULLIF(a.src_sum, 0), 6) AS clear_ratio,
    a.avg_total_sec,
    p.p50_total_sec,
    p.p90_total_sec,
    p.p99_total_sec,
    a.min_total_sec,
    a.max_total_sec,
    a.std_total_sec,
    ROUND(a.std_total_sec / NULLIF(a.avg_total_sec, 0), 4)       AS cv_total,
    a.avg_per_src_sec,
    q.p50_per_src_sec,
    q.p90_per_src_sec,
    q.p99_per_src_sec,
    a.std_per_src_sec,
    ROUND(a.std_per_src_sec / NULLIF(a.avg_per_src_sec, 0), 4)   AS cv_per_src,
    a.avg_measure_cnt,
    a.avg_clear_cnt,
    a.avg_wall_sec,
    a.max_wall_sec,
    a.aborted_cnt,
    a.viol_sum,
    a.unresolved_sum
FROM agg a
JOIN pct_total p ON p.problem_cd = a.problem_cd AND p.algo_cd = a.algo_cd
JOIN pct_per   q ON q.problem_cd = a.problem_cd AND q.algo_cd = a.algo_cd;


-- ---------------------------------------------------------------------
-- 2. dws_src_bucket_stat：按源数分档看规模效应
--    目的是回答「源变多，单源成本是升还是降」
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_src_bucket_stat;
CREATE TABLE dws_src_bucket_stat AS
SELECT
    problem_cd,
    algo_cd,
    src_cnt,
    COUNT(*)                                                    AS run_cnt,
    SUM(cleared_cnt)                                            AS cleared_sum,
    ROUND(AVG(total_sec), 3)                                    AS avg_total_sec,
    ROUND(AVG(per_src_sec), 3)                                  AS avg_per_src_sec,
    ROUND(MIN(per_src_sec), 3)                                  AS min_per_src_sec,
    ROUND(MAX(per_src_sec), 3)                                  AS max_per_src_sec
FROM dwd_task_run
GROUP BY problem_cd, algo_cd, src_cnt
ORDER BY problem_cd, algo_cd, src_cnt;


-- ---------------------------------------------------------------------
-- 3. dws_stage_mix：时间构成（移动/测量/切频/清除）
--    用自连接算占比，避免依赖窗口聚合的方言差异
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_stage_mix;
CREATE TABLE dws_stage_mix AS
WITH s AS (
    SELECT problem_cd, algo_cd, stage_cd,
           ROUND(SUM(stage_sec), 3) AS stage_sec
    FROM dwd_task_stage_cost
    GROUP BY problem_cd, algo_cd, stage_cd
),
t AS (
    SELECT problem_cd, algo_cd, SUM(stage_sec) AS total_sec
    FROM s
    GROUP BY problem_cd, algo_cd
)
SELECT
    s.problem_cd,
    s.algo_cd,
    s.stage_cd,
    s.stage_sec,
    t.total_sec,
    ROUND(s.stage_sec / NULLIF(t.total_sec, 0), 4) AS stage_ratio
FROM s
JOIN t ON t.problem_cd = s.problem_cd AND t.algo_cd = s.algo_cd;


-- ---------------------------------------------------------------------
-- 4. dws_cost_model：用单变量最小二乘拆「固定成本 + 每源边际成本」
--    这是本题最有业务含义的一条结论：
--    总耗时 ≈ intercept（与源数无关的巡查/判空开销）+ slope × 源数
--    R² 用来判断这条线性关系站不站得住。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_cost_model;
CREATE TABLE dws_cost_model AS
WITH stat AS (
    SELECT
        problem_cd,
        algo_cd,
        COUNT(*)                                        AS run_cnt,
        AVG(CAST(src_cnt AS REAL))                      AS mean_x,
        AVG(total_sec)                                  AS mean_y,
        AVG(CAST(src_cnt AS REAL) * src_cnt) - AVG(CAST(src_cnt AS REAL)) * AVG(CAST(src_cnt AS REAL)) AS var_x,
        AVG(CAST(src_cnt AS REAL) * total_sec) - AVG(CAST(src_cnt AS REAL)) * AVG(total_sec)          AS cov_xy,
        AVG(total_sec * total_sec) - AVG(total_sec) * AVG(total_sec)                                  AS var_y
    FROM dwd_task_run
    GROUP BY problem_cd, algo_cd
)
SELECT
    problem_cd,
    algo_cd,
    run_cnt,
    ROUND(cov_xy / NULLIF(var_x, 0), 3)                                  AS slope_sec_per_src,
    ROUND(mean_y - (cov_xy / NULLIF(var_x, 0)) * mean_x, 3)              AS intercept_sec,
    ROUND((cov_xy * cov_xy) / NULLIF(var_x * var_y, 0), 4)               AS r_squared,
    ROUND(mean_x, 3)                                                     AS mean_src_cnt,
    ROUND(mean_y, 3)                                                     AS mean_total_sec
FROM stat;


-- ---------------------------------------------------------------------
-- 5. dws_q4_paired_stat：同场景配对差异（新版 vs 基线）
--    配对实验的价值：消除「每局源数不同」带来的方差，比较的是同一批种子。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_q4_paired_stat;
CREATE TABLE dws_q4_paired_stat AS
WITH agg AS (
    SELECT
        COUNT(*)                                AS pair_cnt,
        SUM(new_faster_flag)                    AS new_faster_cnt,
        ROUND(AVG(new_faster_flag), 4)          AS new_faster_rate,
        ROUND(AVG(new_total_sec), 3)            AS avg_new_total_sec,
        ROUND(AVG(base_total_sec), 3)           AS avg_base_total_sec,
        ROUND(AVG(total_delta_sec), 3)          AS avg_total_delta_sec,
        ROUND(AVG(total_delta_pct), 6)          AS avg_total_delta_pct,
        ROUND(AVG(new_per_src_sec), 3)          AS avg_new_per_src_sec,
        ROUND(AVG(base_per_src_sec), 3)         AS avg_base_per_src_sec,
        ROUND(AVG(src_delta_sec), 3)            AS avg_src_delta_sec,
        ROUND(SUM(new_viol_cnt), 0)             AS new_viol_sum,
        ROUND(SUM(base_viol_cnt), 0)            AS base_viol_sum
    FROM dwd_q4_paired
),
ranked AS (
    SELECT total_delta_sec AS v,
           ROW_NUMBER() OVER (ORDER BY total_delta_sec) AS rn,
           COUNT(*)     OVER ()                         AS cnt
    FROM dwd_q4_paired
),
-- 每源口径的分位数：论文正文报告的是每源配对差（均值 0.392 s、中位 0.651 s），
-- 整局口径会被源数放大，两者不能混用，所以两套都算出来。
ranked_src AS (
    SELECT src_delta_sec AS v,
           ROW_NUMBER() OVER (ORDER BY src_delta_sec) AS rn,
           COUNT(*)     OVER ()                       AS cnt
    FROM dwd_q4_paired
),
pct AS (
    SELECT
        ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.10) AS INTEGER) THEN v END), 3) AS p10_total_delta_sec,
        ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.50) AS INTEGER) THEN v END), 3) AS p50_total_delta_sec,
        ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.90) AS INTEGER) THEN v END), 3) AS p90_total_delta_sec
    FROM ranked
),
pct_src AS (
    SELECT
        ROUND(MAX(CASE WHEN rn = CAST(ROUND(cnt * 0.50) AS INTEGER) THEN v END), 3) AS p50_src_delta_sec
    FROM ranked_src
)
SELECT
    a.*,
    p.p10_total_delta_sec,
    p.p50_total_delta_sec,
    p.p90_total_delta_sec,
    ps.p50_src_delta_sec,
    ROUND((a.avg_new_total_sec - a.avg_base_total_sec) / NULLIF(a.avg_base_total_sec, 0), 6) AS lift_total_pct,
    ROUND(a.avg_src_delta_sec * 1.0 / NULLIF(a.avg_base_per_src_sec, 0), 6)                  AS per_src_lift_pct
FROM agg a
CROSS JOIN pct p
CROSS JOIN pct_src ps;


-- ---------------------------------------------------------------------
-- 6. dws_dir_profile：问题四定向源画像
--    数据事实：本批 1000 局的定向源个数与源总数近似共线（定向占比固定在 60% 附近），
--    因此这里只做分布画像，不据此下「定向源越多越慢」的因果结论。
--    要分离该效应，需要另做变比例实验（论文附录的定向占比敏感性实验即为此设计）。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_dir_profile;
CREATE TABLE dws_dir_profile AS
SELECT
    dir_src_cnt,
    COUNT(*)                                                  AS run_cnt,
    ROUND(AVG(CAST(src_cnt AS REAL)), 2)                      AS avg_src_cnt,
    ROUND(AVG(CAST(dir_src_cnt AS REAL) / src_cnt), 4)        AS avg_dir_ratio,
    ROUND(AVG(total_sec), 3)                                  AS avg_total_sec,
    ROUND(AVG(per_src_sec), 3)                                AS avg_per_src_sec,
    ROUND(AVG(sec_per_measure), 3)                            AS avg_sec_per_measure
FROM dwd_task_run
WHERE problem_cd = 'Q4' AND algo_cd = 'new'
GROUP BY dir_src_cnt
ORDER BY dir_src_cnt;


-- ---------------------------------------------------------------------
-- 7. dws_pair_by_src：配对差异按源数分层
--    目的是检查「新版更快」是否只在某类规模上成立，而不是全局结论。
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dws_pair_by_src;
CREATE TABLE dws_pair_by_src AS
SELECT
    src_cnt,
    COUNT(*)                              AS pair_cnt,
    ROUND(AVG(new_total_sec), 3)          AS avg_new_total_sec,
    ROUND(AVG(base_total_sec), 3)         AS avg_base_total_sec,
    ROUND(AVG(total_delta_sec), 3)        AS avg_delta_sec,
    ROUND(AVG(new_faster_flag), 4)        AS new_faster_rate,
    ROUND(AVG(new_wall_sec), 3)           AS avg_new_wall_sec,
    ROUND(AVG(base_wall_sec), 3)          AS avg_base_wall_sec
FROM dwd_q4_paired
GROUP BY src_cnt
ORDER BY src_cnt;

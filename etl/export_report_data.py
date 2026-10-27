#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
报表数据导出
------------------------------------------------------------------
从 ADS / DWS 层取数，生成 report/data.js（window.DW_DATA = {...}）。
用 JS 全局变量而不是 fetch，是为了让 index.html 双击直接用 file:// 打开也能渲染。

用法
  python3 etl/export_report_data.py
"""

from __future__ import annotations

import json
import os
import sqlite3
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "db", "sim_dw.sqlite")
OUT_PATH = os.path.join(BASE_DIR, "report", "data.js")


def rows(conn: sqlite3.Connection, sql: str) -> list[dict]:
    cur = conn.execute(sql)
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def one(conn: sqlite3.Connection, sql: str) -> dict:
    data = rows(conn, sql)
    return data[0] if data else {}


def main() -> None:
    conn = sqlite3.connect(DB_PATH)
    try:
        payload = {
            "generated_at": datetime.now().strftime("%Y-%m-%d %H:%M"),
            "kpi": one(conn, "SELECT * FROM ads_kpi_overview"),
            "facts": rows(conn, "SELECT fact_name, fact_value FROM ads_resume_facts"),
            "scorecard": one(conn, "SELECT * FROM dq_scorecard"),
            "dq": rows(
                conn,
                "SELECT check_cd, check_name, dimension, total_cnt, failed_cnt,"
                " ROUND(pass_rate * 100, 2) AS pass_rate_pct, status"
                " FROM dq_check_result ORDER BY check_cd",
            ),
            "scaling": rows(
                conn,
                "SELECT problem_cd, algo_cd, src_cnt, run_cnt, avg_per_src_sec, avg_total_sec"
                " FROM ads_src_scaling ORDER BY problem_cd, algo_cd, src_cnt",
            ),
            "stage": rows(
                conn,
                "SELECT problem_cd, algo_cd, stage_name, stage_sec, stage_ratio_pct"
                " FROM ads_stage_mix ORDER BY problem_cd, stage_ratio_pct DESC",
            ),
            "q3_hist": rows(
                conn,
                "SELECT CAST(total_sec / 200 AS INTEGER) * 200 AS bin_start,"
                " COUNT(*) AS cnt"
                " FROM dwd_task_run WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3'"
                " GROUP BY bin_start ORDER BY bin_start",
            ),
            "pair_hist": rows(
                conn,
                "SELECT CAST((total_delta_sec + 100) / 20 AS INTEGER) * 20 - 100 AS bin_start,"
                " COUNT(*) AS cnt"
                " FROM dwd_q4_paired"
                " WHERE total_delta_sec BETWEEN -100 AND 100"
                " GROUP BY bin_start ORDER BY bin_start",
            ),
            "pair_by_src": rows(
                conn,
                "SELECT src_cnt, pair_cnt, ROUND(avg_delta_sec, 2) AS avg_delta_sec,"
                " ROUND(new_faster_rate * 100, 1) AS new_faster_pct"
                " FROM dws_pair_by_src ORDER BY src_cnt",
            ),
            "behavior": rows(
                conn,
                "SELECT problem_cd, algo_cd, avg_max_refine_rounds, max_refine_rounds,"
                " cap_ch_sum, cap_ch_rate, cover_event_sum, avg_cover_pt_cnt"
                " FROM ads_algorithm_behavior ORDER BY problem_cd, algo_cd",
            ),
            "q3_stat": one(
                conn,
                "SELECT * FROM dws_problem_algo_stat WHERE problem_cd = 'Q3' AND algo_cd = 'final_v3'",
            ),
            "q4_stat": one(
                conn,
                "SELECT * FROM dws_problem_algo_stat WHERE problem_cd = 'Q4' AND algo_cd = 'new'",
            ),
            "lift": one(conn, "SELECT * FROM ads_algo_lift"),
            "cost_model": rows(
                conn,
                "SELECT problem_cd, algo_cd, intercept_sec, slope_sec_per_src, r_squared"
                " FROM dws_cost_model ORDER BY problem_cd, algo_cd",
            ),
        }
    finally:
        conn.close()

    os.makedirs(os.path.dirname(OUT_PATH), exist_ok=True)
    with open(OUT_PATH, "w", encoding="utf-8") as fh:
        fh.write("window.DW_DATA = ")
        json.dump(payload, fh, ensure_ascii=False, indent=2)
        fh.write(";\n")
    print(f"[EXPORT] {OUT_PATH}  ({os.path.getsize(OUT_PATH)} bytes)")


if __name__ == "__main__":
    main()

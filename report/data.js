window.DW_DATA = {
  "generated_at": "2026-10-27 21:30",
  "kpi": {
    "total_run_cnt": 3000,
    "total_src_cnt": 39103,
    "total_cleared_cnt": 39103,
    "overall_clear_ratio": 1.0,
    "all_cleared_run_ratio": 1.0,
    "q3_avg_per_src_sec": 245.099,
    "q3_p90_per_src_sec": 293.231,
    "q3_avg_total_sec": 3152.184,
    "q4_avg_per_src_sec": 459.824,
    "q4_p90_per_src_sec": 581.229,
    "max_wall_sec": 4.296,
    "wall_limit_sec": 1200,
    "wall_headroom_x": 279.3,
    "total_viol_cnt": 0,
    "total_aborted_cnt": 0,
    "total_unresolved_cnt": 0,
    "q3_fixed_cost_sec": 2397.379,
    "q3_marginal_sec_per_src": 57.65,
    "q3_cost_model_r2": 0.1992
  },
  "facts": [
    {
      "fact_name": "样本规模",
      "fact_value": "3000 局 / 39103 个源"
    },
    {
      "fact_name": "清除完成率",
      "fact_value": "100.0%"
    },
    {
      "fact_name": "问题三平均单源耗时",
      "fact_value": "245.099 秒/源"
    },
    {
      "fact_name": "问题三 P90 单源耗时",
      "fact_value": "293.231 秒/源"
    },
    {
      "fact_name": "固定成本项",
      "fact_value": "2397.379 秒（与源数无关）"
    },
    {
      "fact_name": "边际单源成本",
      "fact_value": "57.65 秒/源"
    },
    {
      "fact_name": "线性模型拟合优度",
      "fact_value": "R² = 0.1992"
    },
    {
      "fact_name": "程序运行峰值",
      "fact_value": "4.296 秒（上限 1200 秒，余量 279.3 倍）"
    },
    {
      "fact_name": "稳定性",
      "fact_value": "0 次不变量违例 / 0 次异常中止"
    },
    {
      "fact_name": "覆盖策略代价",
      "fact_value": "1000 对同场景：19m 矩形覆盖较 20m 六角点阵每源 +0.392 秒（+0.085%），换取 1m 清除余量"
    }
  ],
  "scorecard": {
    "check_cnt": 9,
    "pass_cnt": 9,
    "fail_cnt": 0,
    "warn_cnt": 0,
    "avg_pass_rate": 1.0,
    "pipeline_status": "READY",
    "checked_at": "2026-10-27 21:30:55"
  },
  "dq": [
    {
      "check_cd": "DQ-01",
      "check_name": "总时间 = 移动+测量+切频+清除",
      "dimension": "完整性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-02",
      "check_name": "单源耗时 = 总时间 / 源数",
      "dimension": "一致性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-03",
      "check_name": "0 <= 清除数 <= 源数",
      "dimension": "有效性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-04",
      "check_name": "run_id 唯一",
      "dimension": "唯一性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-05",
      "check_name": "关键字段非空",
      "dimension": "完整性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-06",
      "check_name": "delta_s 实为每源差（字段名歧义核查）",
      "dimension": "口径",
      "total_cnt": 1000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-07",
      "check_name": "阶段耗时非负",
      "dimension": "有效性",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-08",
      "check_name": "程序运行时间 <= 1200 秒",
      "dimension": "约束",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    },
    {
      "check_cd": "DQ-09",
      "check_name": "每局全部清除",
      "dimension": "业务",
      "total_cnt": 3000,
      "failed_cnt": 0,
      "pass_rate_pct": 100.0,
      "status": "PASS"
    }
  ],
  "scaling": [
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 10,
      "run_cnt": 129,
      "avg_per_src_sec": 297.755,
      "avg_total_sec": 2977.555
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 11,
      "run_cnt": 129,
      "avg_per_src_sec": 275.425,
      "avg_total_sec": 3029.671
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 12,
      "run_cnt": 155,
      "avg_per_src_sec": 258.098,
      "avg_total_sec": 3097.175
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 13,
      "run_cnt": 123,
      "avg_per_src_sec": 243.425,
      "avg_total_sec": 3164.523
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 14,
      "run_cnt": 169,
      "avg_per_src_sec": 226.068,
      "avg_total_sec": 3164.956
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 15,
      "run_cnt": 161,
      "avg_per_src_sec": 217.562,
      "avg_total_sec": 3263.425
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "src_cnt": 16,
      "run_cnt": 134,
      "avg_per_src_sec": 208.799,
      "avg_total_sec": 3340.779
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 10,
      "run_cnt": 150,
      "avg_per_src_sec": 588.501,
      "avg_total_sec": 5885.01
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 11,
      "run_cnt": 126,
      "avg_per_src_sec": 540.324,
      "avg_total_sec": 5943.569
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 12,
      "run_cnt": 159,
      "avg_per_src_sec": 491.285,
      "avg_total_sec": 5895.417
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 13,
      "run_cnt": 131,
      "avg_per_src_sec": 454.728,
      "avg_total_sec": 5911.465
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 14,
      "run_cnt": 140,
      "avg_per_src_sec": 417.797,
      "avg_total_sec": 5849.161
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 15,
      "run_cnt": 156,
      "avg_per_src_sec": 391.231,
      "avg_total_sec": 5868.462
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "src_cnt": 16,
      "run_cnt": 138,
      "avg_per_src_sec": 332.382,
      "avg_total_sec": 5318.104
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 10,
      "run_cnt": 150,
      "avg_per_src_sec": 589.033,
      "avg_total_sec": 5890.328
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 11,
      "run_cnt": 126,
      "avg_per_src_sec": 540.283,
      "avg_total_sec": 5943.108
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 12,
      "run_cnt": 159,
      "avg_per_src_sec": 492.009,
      "avg_total_sec": 5904.104
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 13,
      "run_cnt": 131,
      "avg_per_src_sec": 454.577,
      "avg_total_sec": 5909.504
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 14,
      "run_cnt": 140,
      "avg_per_src_sec": 418.347,
      "avg_total_sec": 5856.857
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 15,
      "run_cnt": 156,
      "avg_per_src_sec": 392.145,
      "avg_total_sec": 5882.179
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "src_cnt": 16,
      "run_cnt": 138,
      "avg_per_src_sec": 332.397,
      "avg_total_sec": 5318.351
    }
  ],
  "stage": [
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "stage_name": "移动",
      "stage_sec": 2401228.026,
      "stage_ratio_pct": 76.18
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "stage_name": "测量",
      "stage_sec": 551480.0,
      "stage_ratio_pct": 17.5
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "stage_name": "切频",
      "stage_sec": 107500.0,
      "stage_ratio_pct": 3.41
    },
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "stage_name": "定位清除",
      "stage_sec": 91976.0,
      "stage_ratio_pct": 2.92
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "stage_name": "移动",
      "stage_sec": 4155347.888,
      "stage_ratio_pct": 71.44
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "stage_name": "测量",
      "stage_sec": 1311715.0,
      "stage_ratio_pct": 22.55
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "stage_name": "切频",
      "stage_sec": 249849.0,
      "stage_ratio_pct": 4.3
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "stage_name": "定位清除",
      "stage_sec": 99879.0,
      "stage_ratio_pct": 1.72
    }
  ],
  "q3_hist": [
    {
      "bin_start": 2400,
      "cnt": 8
    },
    {
      "bin_start": 2600,
      "cnt": 61
    },
    {
      "bin_start": 2800,
      "cnt": 214
    },
    {
      "bin_start": 3000,
      "cnt": 326
    },
    {
      "bin_start": 3200,
      "cnt": 237
    },
    {
      "bin_start": 3400,
      "cnt": 104
    },
    {
      "bin_start": 3600,
      "cnt": 37
    },
    {
      "bin_start": 3800,
      "cnt": 11
    },
    {
      "bin_start": 4000,
      "cnt": 2
    }
  ],
  "pair_hist": [
    {
      "bin_start": -100,
      "cnt": 7
    },
    {
      "bin_start": -80,
      "cnt": 16
    },
    {
      "bin_start": -60,
      "cnt": 21
    },
    {
      "bin_start": -40,
      "cnt": 69
    },
    {
      "bin_start": -20,
      "cnt": 197
    },
    {
      "bin_start": 0,
      "cnt": 348
    },
    {
      "bin_start": 20,
      "cnt": 153
    },
    {
      "bin_start": 40,
      "cnt": 52
    },
    {
      "bin_start": 60,
      "cnt": 29
    },
    {
      "bin_start": 80,
      "cnt": 8
    }
  ],
  "pair_by_src": [
    {
      "src_cnt": 10,
      "pair_cnt": 150,
      "avg_delta_sec": 5.32,
      "new_faster_pct": 30.0
    },
    {
      "src_cnt": 11,
      "pair_cnt": 126,
      "avg_delta_sec": -0.46,
      "new_faster_pct": 36.5
    },
    {
      "src_cnt": 12,
      "pair_cnt": 159,
      "avg_delta_sec": 8.69,
      "new_faster_pct": 34.6
    },
    {
      "src_cnt": 13,
      "pair_cnt": 131,
      "avg_delta_sec": -1.96,
      "new_faster_pct": 38.2
    },
    {
      "src_cnt": 14,
      "pair_cnt": 140,
      "avg_delta_sec": 7.7,
      "new_faster_pct": 37.1
    },
    {
      "src_cnt": 15,
      "pair_cnt": 156,
      "avg_delta_sec": 13.72,
      "new_faster_pct": 40.4
    },
    {
      "src_cnt": 16,
      "pair_cnt": 138,
      "avg_delta_sec": 0.25,
      "new_faster_pct": 32.6
    }
  ],
  "behavior": [
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "avg_max_refine_rounds": null,
      "max_refine_rounds": null,
      "cap_ch_sum": 0,
      "cap_ch_rate": 0.0,
      "cover_event_sum": 0,
      "avg_cover_pt_cnt": null
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "avg_max_refine_rounds": 1.67,
      "max_refine_rounds": 4,
      "cap_ch_sum": 109,
      "cap_ch_rate": 0.0084,
      "cover_event_sum": 13004,
      "avg_cover_pt_cnt": 36.8
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "avg_max_refine_rounds": 1.63,
      "max_refine_rounds": 4,
      "cap_ch_sum": 98,
      "cap_ch_rate": 0.0075,
      "cover_event_sum": 13003,
      "avg_cover_pt_cnt": 43.3
    }
  ],
  "q3_stat": {
    "problem_cd": "Q3",
    "algo_cd": "final_v3",
    "run_cnt": 1000,
    "src_sum": 13093,
    "cleared_sum": 13093,
    "clear_ratio": 1.0,
    "avg_total_sec": 3152.184,
    "p50_total_sec": 3141.027,
    "p90_total_sec": 3481.215,
    "p99_total_sec": 3817.309,
    "min_total_sec": 2402.952,
    "max_total_sec": 4091.642,
    "std_total_sec": 253.18,
    "cv_total": 0.0803,
    "avg_per_src_sec": 245.099,
    "p50_per_src_sec": 241.195,
    "p90_per_src_sec": 293.231,
    "p99_per_src_sec": 325.538,
    "std_per_src_sec": 34.087,
    "cv_per_src": 0.1391,
    "avg_measure_cnt": 110.3,
    "avg_clear_cnt": 21.9,
    "avg_wall_sec": 0.202,
    "max_wall_sec": 0.436,
    "aborted_cnt": null,
    "viol_sum": 0,
    "unresolved_sum": null
  },
  "q4_stat": {
    "problem_cd": "Q4",
    "algo_cd": "new",
    "run_cnt": 1000,
    "src_sum": 13005,
    "cleared_sum": 13005,
    "clear_ratio": 1.0,
    "avg_total_sec": 5816.791,
    "p50_total_sec": 5860.942,
    "p90_total_sec": 6143.755,
    "p99_total_sec": 6440.567,
    "min_total_sec": 3640.789,
    "max_total_sec": 6817.848,
    "std_total_sec": 332.849,
    "cv_total": 0.0572,
    "avg_per_src_sec": 459.824,
    "p50_per_src_sec": 455.495,
    "p90_per_src_sec": 581.229,
    "p99_per_src_sec": 618.472,
    "std_per_src_sec": 83.966,
    "cv_per_src": 0.1826,
    "avg_measure_cnt": 262.3,
    "avg_clear_cnt": 24.6,
    "avg_wall_sec": 1.681,
    "max_wall_sec": 4.249,
    "aborted_cnt": null,
    "viol_sum": 0,
    "unresolved_sum": 0
  },
  "lift": {
    "comparison": "Q4 19m 矩形覆盖 vs 20m 六角点阵",
    "pair_cnt": 1000,
    "avg_new_total_sec": 5816.791,
    "avg_base_total_sec": 5811.675,
    "avg_total_delta_sec": 5.115,
    "lift_total_pct": 0.09,
    "new_faster_cnt": 356,
    "new_faster_rate_pct": 35.6,
    "avg_new_per_src_sec": 459.824,
    "avg_base_per_src_sec": 459.432,
    "avg_src_delta_sec": 0.392,
    "per_src_lift_pct": 0.085,
    "p50_src_delta_sec": 0.651,
    "p10_total_delta_sec": -38.086,
    "p50_total_delta_sec": 8.01,
    "p90_total_delta_sec": 56.538,
    "conclusion": "1000 对同场景中，19m 矩形单元覆盖相对 20m 六角点阵每源多耗 0.392 s（+0.085%），换取 1m 清除余量；两种策略均全部清除，属数值稳健性加固，不是算法退化"
  },
  "cost_model": [
    {
      "problem_cd": "Q3",
      "algo_cd": "final_v3",
      "intercept_sec": 2397.379,
      "slope_sec_per_src": 57.65,
      "r_squared": 0.1992
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "baseline",
      "intercept_sec": 6656.005,
      "slope_sec_per_src": -64.923,
      "r_squared": 0.1543
    },
    {
      "problem_cd": "Q4",
      "algo_cd": "new",
      "intercept_sec": 6655.375,
      "slope_sec_per_src": -64.482,
      "r_squared": 0.1508
    }
  ]
};

#!/usr/bin/env bash
# ---------------------------------------------------------------------
# 一键重建数仓：ODS 装载 → DWD → DWS → ADS → 数据质量校验
# 用法： bash etl/run_pipeline.sh
# 依赖：python3（仅标准库）、sqlite3（3.35+，需窗口函数）
# ---------------------------------------------------------------------
set -euo pipefail
cd "$(dirname "$0")/.."

SQLITE_BIN="${SQLITE_BIN:-sqlite3}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

echo "==> [1/5] ODS 装载"
"$PYTHON_BIN" etl/load_ods.py

for pair in "10_dwd.sql:DWD" "20_dws.sql:DWS" "30_ads.sql:ADS" "90_dq_checks.sql:DQ"; do
  file="${pair%%:*}"; layer="${pair##*:}"
  echo "==> $layer  $file"
  "$SQLITE_BIN" db/sim_dw.sqlite < "sql/$file"
done

echo "==> 结果概览"
"$SQLITE_BIN" -header -column db/sim_dw.sqlite "SELECT * FROM dq_scorecard;"
"$SQLITE_BIN" -header -column db/sim_dw.sqlite "SELECT fact_name, fact_value FROM ads_resume_facts;"
echo "==> 完成，库文件 db/sim_dw.sqlite"

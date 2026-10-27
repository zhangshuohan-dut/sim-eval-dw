#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ODS 层装载脚本
------------------------------------------------------------------
把原始逐局评测 CSV 全量写入 SQLite 的 ODS 层。

设计约定
  1. ODS 只做"原样落地"：不改列名、不做类型强转（除 NULL 归一），
     便于与上游 CSV 逐列对账。
  2. 每张表附三个装载元数据列：_src_file / _row_no / _load_ts，
     任何一行都能回溯到源文件与行号。
  3. 全量覆盖式装载（DROP + CREATE），可重复执行，天然幂等。
  4. 每次装载写一行 etl_load_log，便于排查"某天数据为什么少了"。

用法
  python3 etl/load_ods.py
"""

from __future__ import annotations

import csv
import os
import sqlite3
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(BASE_DIR, "db", "sim_dw.sqlite")
RAW_DIR = os.path.join(BASE_DIR, "data", "raw")

# ODS 表名 -> 源文件。表名保持"问题 + 算法"语义，避免直接沿用中文文件名。
SOURCES = [
    ("ods_q3_run_1000", "q3_run_1000.csv"),
    ("ods_q4_run_new_1000", "q4_run_new_1000.csv"),
    ("ods_q4_run_base_1000", "q4_run_base_1000.csv"),
    ("ods_q4_paired_1000", "q4_paired_1000.csv"),
]

NULL_TOKENS = {"", "nan", "NaN", "None", "NULL", "null"}


def quote_ident(name: str) -> str:
    """SQLite 标识符转义，防止列名里出现空格或关键字。"""
    return '"' + name.replace('"', '""') + '"'


def load_table(conn: sqlite3.Connection, table: str, filename: str, load_ts: str) -> int:
    path = os.path.join(RAW_DIR, filename)
    with open(path, newline="", encoding="utf-8-sig") as fh:
        reader = csv.reader(fh)
        header = next(reader)
        rows = [r for r in reader if any(cell.strip() for cell in r)]

    conn.execute(f"DROP TABLE IF EXISTS {quote_ident(table)}")
    cols_ddl = ", ".join(f"{quote_ident(c)} NUMERIC" for c in header)
    conn.execute(
        f"CREATE TABLE {quote_ident(table)} ("
        f"{cols_ddl}, _src_file TEXT, _row_no INTEGER, _load_ts TEXT)"
    )

    placeholders = ",".join("?" * (len(header) + 3))
    insert_sql = f"INSERT INTO {quote_ident(table)} VALUES ({placeholders})"

    payload = []
    for idx, row in enumerate(rows, start=1):
        row = row + [""] * (len(header) - len(row))  # 容忍短行
        values = [None if v.strip() in NULL_TOKENS else v.strip() for v in row]
        payload.append(values + [filename, idx, load_ts])

    conn.executemany(insert_sql, payload)
    conn.commit()
    return len(payload)


def main() -> None:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    try:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute(
            "CREATE TABLE IF NOT EXISTS etl_load_log ("
            " layer TEXT, table_name TEXT, src_file TEXT, row_cnt INTEGER,"
            " load_ts TEXT, status TEXT)"
        )
        load_ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        for table, filename in SOURCES:
            n = load_table(conn, table, filename, load_ts)
            conn.execute(
                "INSERT INTO etl_load_log VALUES (?,?,?,?,?,?)",
                ("ODS", table, filename, n, load_ts, "SUCCESS"),
            )
            conn.commit()
            print(f"[ODS] {table:<24} <- {filename:<24} {n:>5} 行")

        batch_total = conn.execute(
            "SELECT SUM(row_cnt) FROM etl_load_log WHERE load_ts = ?", (load_ts,)
        ).fetchone()[0]
        print(f"[ODS] 装载完成，本次合计 {batch_total} 行，库文件 {DB_PATH}")
    finally:
        conn.close()


if __name__ == "__main__":
    main()

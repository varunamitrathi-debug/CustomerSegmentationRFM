"""
Step 1: load the UCI Online Retail II workbook (both yearly sheets) into SQLite.
Run once:  python load.py      (needs pandas and openpyxl; takes about a minute)
"""
import sqlite3
import pandas as pd
from pathlib import Path

ROOT = Path(__file__).parent
sheets = pd.read_excel(ROOT / "data" / "online retail.xlsx", sheet_name=None)
df = pd.concat(sheets.values(), ignore_index=True)
df.columns = ["invoice", "stockcode", "description", "quantity", "invoicedate", "price", "customer", "country"]
df["invoice"] = df["invoice"].astype(str)
df["stockcode"] = df["stockcode"].astype(str)
df["invoicedate"] = pd.to_datetime(df["invoicedate"]).dt.strftime("%Y-%m-%d %H:%M:%S")

con = sqlite3.connect(ROOT / "retail.db")
df.to_sql("transactions", con, if_exists="replace", index=False)
con.execute("CREATE INDEX IF NOT EXISTS i1 ON transactions(customer)")
con.execute("CREATE INDEX IF NOT EXISTS i2 ON transactions(invoice)")
con.commit()
print(f"Loaded {len(df):,} rows into retail.db")

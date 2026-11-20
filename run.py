"""
Step 2: run every query in analysis.sql, save results to output/, size the
recommendations and draw the chart.
Run after load.py:  python run.py     (needs pandas and matplotlib)
"""
import re
import sqlite3
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

ROOT = Path(__file__).parent
OUT, CH = ROOT / "output", ROOT / "charts"
OUT.mkdir(exist_ok=True)
CH.mkdir(exist_ok=True)

sql = (ROOT / "analysis.sql").read_text()
blocks = re.split(r"^-- name: (.+)$", sql, flags=re.M)[1:]
con = sqlite3.connect(ROOT / "retail.db")
pd.set_option("display.width", 220)
pd.set_option("display.max_columns", 20)

results = {}
for name, query in zip(blocks[0::2], blocks[1::2]):
    name = name.strip()
    df = pd.read_sql_query(query, con)
    results[name] = df
    df.to_csv(OUT / f"{name}.csv", index=False)
    if name != "03 customer rfm":
        print(f"\n=== {name} ===")
        print(df.to_string(index=False))
con.close()

# Step 3: size the recommendations. Inputs come from the queries above.
# The win back and retention rates are ASSUMPTIONS, set here so you can change them.
assumeWinBack = 0.15        # share of At risk customers brought back to their year one spend
assumeChurnAvoided = 0.05   # share of Champions kept who would otherwise lapse

seg = results["09 at risk detail"].set_index("segment")
risk = seg.loc["4 At risk"]
champ = seg.loc["1 Champions"]
winBack = risk["customers"] * assumeWinBack * risk["avg spend year one gbp"]
champValue = champ["spend dec 2010 to dec 2011 gbp"] / champ["customers"]
keepChampions = champ["customers"] * assumeChurnAvoided * champValue

sizing = pd.DataFrame({
    "recommendation": ["1 win back At risk customers (15 pct return to year one spend, assumption)",
                       "2 protect Champions (5 pct fewer lapse, assumption)"],
    "customers in scope": [int(risk["customers"]), int(champ["customers"])],
    "annual revenue impact gbp": [round(winBack), round(keepChampions)],
})
sizing.to_csv(OUT / "10 recommendation impact.csv", index=False)
print("\n=== 10 recommendation impact ===")
print(sizing.to_string(index=False))

# Chart: share of customers versus share of revenue by segment
s = results["04 segments"].copy()
s["label"] = s["segment"].str[2:]
fig, ax = plt.subplots(figsize=(8, 4))
x = range(len(s))
ax.bar([i - 0.2 for i in x], s["share of customers pct"], width=0.4, color="#999999", label="Share of customers")
ax.bar([i + 0.2 for i in x], s["share of revenue pct"], width=0.4, color="#333333", label="Share of revenue")
ax.set_xticks(list(x)); ax.set_xticklabels(s["label"], rotation=15)
ax.set_ylabel("Percent"); ax.legend(frameon=False)
ax.spines["top"].set_visible(False); ax.spines["right"].set_visible(False)
ax.set_title("Champions are a quarter of customers and over two thirds of revenue")
plt.tight_layout(); plt.savefig(CH / "segments.png", dpi=110); plt.close()
print("\nSaved output and charts")

# Build guide: RFM customer segmentation in SQL

One or two evenings.

## 1. Get the data and load it

* Download Online Retail II from the [UCI page](https://archive.ics.uci.edu/dataset/502/online+retail+ii), unzip, and save the workbook in `data/` as `online retail.xlsx`. It has two sheets, one per year; `load.py` reads both.
* Run `pip install pandas openpyxl matplotlib`, then `python load.py`. You should see 1,067,371 rows loaded into `retail.db`.
* Column names are simplified on load: invoice, stockcode, description, quantity, invoicedate, price, customer, country.

## 2. Clean before you count

Open `analysis.sql`. Query 01 shows why cleaning matters: invoices starting with C are cancellations, some lines have zero or negative quantity, and about 243,000 lines have no customer id. Every later query starts from the same `clean` CTE that removes them, so the rule is written once and applied the same way everywhere.

## 3. Build RFM step by step

* **Recency**: days between a customer's last order and 10 December 2011, the day after the data ends.
* **Frequency**: number of distinct invoices.
* **Monetary**: total spend (quantity x price).
* `NTILE(5) OVER (ORDER BY recency DESC)` splits customers into five equal groups; ordering recency descending gives the most recent buyers a 5. Frequency and monetary are ordered ascending so the biggest buyers score 5.

Run query 03 to see one row per customer with all three scores.

## 4. Turn scores into segments

Query 04 uses a CASE rule on the R and F scores:

* Champions: R 4 or 5 and F 4 or 5
* Loyal: R and F at least 3
* New or promising: recent (R 4 or 5) but few orders (F 1 or 2)
* At risk: R 1 or 2 but F 3 or more, so they used to buy often
* Hibernating: R and F both 1 or 2
* Needs attention: everyone else

The numeric prefix (1 to 6) keeps the segments in a sensible order in every output.

## 5. Find the leak and size it

Query 09 splits each segment's spend into the first year (December 2009 to November 2010) and the second. `run.py` then sizes two actions with two clearly marked assumptions:

```
assumeWinBack = 0.15
assumeChurnAvoided = 0.05
```

Change them and rerun to see the effect. When you present, say these two numbers are assumptions; everything else is measured.

## 6. Publish

Commit everything except `data/`, `retail.db` and the customer level file (listed in `.gitignore`).

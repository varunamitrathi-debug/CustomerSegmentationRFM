# Customer segmentation (RFM) for an online retailer

**Question.** Which customers drive the revenue of a UK online gift wholesaler, which ones are slipping away, and what is it worth to act?

**Answer in one line.** A quarter of customers (the Champions) bring 69% of revenue, and a group of 824 once valuable customers is drifting away: they spent £1.33 million in the first year and only £0.31 million in the second. Winning back 15% of them (an assumption) is worth about £199,000 a year.

## Approach

* Loaded 1,067,371 transaction lines (December 2009 to December 2011) from the UCI Online Retail II dataset into SQLite.
* Cleaned in SQL: removed cancellations, zero or negative lines and lines with no customer (24.5% of rows).
* Scored every customer 1 to 5 on Recency, Frequency and Monetary value with the NTILE window function, then grouped them into six segments with a CASE rule.
* Compared each segment's spend in year one and year two to find who is fading, and sized two actions.

## Key findings

| Segment | Customers | Share of customers | Revenue (£) | Share of revenue | Avg orders | Avg spend (£) |
|---|---|---|---|---|---|---|
| Champions | 1,473 | 25.1% | 12,254,731 | 69.1% | 15.7 | 8,320 |
| Loyal | 1,229 | 20.9% | 2,586,345 | 14.6% | 5.5 | 2,104 |
| New or promising | 440 | 7.5% | 394,038 | 2.2% | 1.5 | 896 |
| At risk | 824 | 14.0% | 1,634,077 | 9.2% | 4.9 | 1,983 |
| Needs attention | 384 | 6.5% | 204,693 | 1.2% | 1.4 | 533 |
| Hibernating | 1,528 | 26.0% | 669,546 | 3.8% | 1.3 | 438 |

* **Revenue is concentrated.** The top 10% of customers bring 63.9% of revenue and the top 1% bring 31.8%. 72.4% of customers have ordered more than once, so this is a repeat business.
* **The At risk group is a leak.** These 824 customers ordered 4.9 times on average but have not bought for about a year (369 days on average). Their spend fell from £1,326,233 in the first year to £307,843 in the second.
* **Sales are seasonal and UK heavy.** Revenue peaks every September to November (over £1.1 million in November in both years), and the UK brings 83.0% of revenue. 6.2% of gross sales value was later cancelled.

![Share of customers and revenue by segment](charts/segments.png)

## Recommendations

| # | Action | Sizing | Annual revenue impact |
|---|---|---|---|
| 1 | **Win back At risk customers** with a personal account call and a reorder offer timed before the autumn peak | 824 customers x 15% return to their year one spend of £1,610 (**assumption**) | about £199,000 |
| 2 | **Protect Champions** with a named account manager and early access to the autumn range | 1,473 customers x 5% fewer lapses (**assumption**) x £4,294 average spend in the last year | about £316,000 |

Both uplift rates are assumptions kept in one place in `run.py`; every other input comes from the queries.

## Files

```
CustomerSegmentationRFM/
  README.md          this summary
  Build Guide.md     step by step instructions
  load.py            loads the workbook into retail.db
  analysis.sql       all queries, commented
  run.py             runs the queries, sizes the actions, draws the chart
  output/            one CSV per query (the customer level RFM table is created when you run it)
  charts/            chart used above
  data/              put the UCI workbook here (not committed)
```

## Tools

SQL (SQLite: CTEs, NTILE, ROW NUMBER and SUM OVER window functions, CASE segmentation), Python (pandas, matplotlib) to load, run and chart.

## How to run

1. Download the dataset from the [UCI Machine Learning Repository: Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii), unzip it and save the workbook in `data/` as `online retail.xlsx`.
2. Run:

```
pip install pandas openpyxl matplotlib
python load.py
python run.py
```

Data: Chen, D. (2012). Online Retail II. UCI Machine Learning Repository. CC BY 4.0.

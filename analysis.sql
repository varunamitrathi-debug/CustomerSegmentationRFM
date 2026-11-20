-- Customer segmentation (RFM) for a UK online gift retailer, SQLite.
-- Data: UCI Online Retail II, December 2009 to December 2011.
-- Each block starting with "-- name:" is one query; run.py runs them all
-- and saves each result to output/<name>.csv.
--
-- Clean sales = not a cancellation (invoice starting with C), positive
-- quantity and price, and a known customer. Revenue is quantity x price in GBP.


-- name: 01 data quality
SELECT COUNT(*) AS "rows",
       SUM(invoice LIKE 'C%') AS "cancellation rows",
       SUM(customer IS NULL) AS "rows without customer",
       SUM(quantity <= 0 OR price <= 0) AS "rows with zero or negative values",
       ROUND(100.0 * SUM(invoice LIKE 'C%' OR customer IS NULL OR quantity <= 0 OR price <= 0) / COUNT(*), 1) AS "pct excluded"
FROM transactions;


-- name: 02 yearly overview
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
)
SELECT SUBSTR(invoicedate, 1, 4) AS "year",
       COUNT(DISTINCT invoice) AS "orders",
       COUNT(DISTINCT customer) AS "customers",
       ROUND(SUM(quantity * price), 0) AS "revenue gbp",
       ROUND(SUM(quantity * price) / COUNT(DISTINCT invoice), 2) AS "avg order value gbp"
FROM clean GROUP BY 1 ORDER BY 1;


-- name: 03 customer rfm
-- Recency = days from last order to 10 Dec 2011 (day after the data ends).
-- Frequency = number of orders. Monetary = total spend.
-- Each is scored 1 to 5 with NTILE, 5 being best.
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
),
base AS (
  SELECT customer,
         CAST(JULIANDAY('2011-12-10') - JULIANDAY(MAX(invoicedate)) AS INT) AS recency,
         COUNT(DISTINCT invoice) AS frequency,
         SUM(quantity * price) AS monetary
  FROM clean GROUP BY customer
)
SELECT CAST(customer AS INT) AS "customer",
       recency AS "recency days", frequency AS "orders", ROUND(monetary, 2) AS "spend gbp",
       NTILE(5) OVER (ORDER BY recency DESC) AS "r score",
       NTILE(5) OVER (ORDER BY frequency) AS "f score",
       NTILE(5) OVER (ORDER BY monetary) AS "m score"
FROM base;


-- name: 04 segments
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
),
base AS (
  SELECT customer,
         JULIANDAY('2011-12-10') - JULIANDAY(MAX(invoicedate)) AS recency,
         COUNT(DISTINCT invoice) AS frequency,
         SUM(quantity * price) AS monetary
  FROM clean GROUP BY customer
),
scored AS (
  SELECT *, NTILE(5) OVER (ORDER BY recency DESC) AS r, NTILE(5) OVER (ORDER BY frequency) AS f
  FROM base
),
seg AS (
  SELECT *,
    CASE
      WHEN r >= 4 AND f >= 4 THEN '1 Champions'
      WHEN r >= 3 AND f >= 3 THEN '2 Loyal'
      WHEN r >= 4 AND f <= 2 THEN '3 New or promising'
      WHEN r <= 2 AND f >= 3 THEN '4 At risk'
      WHEN r <= 2 AND f <= 2 THEN '6 Hibernating'
      ELSE '5 Needs attention' END AS segment
  FROM scored
)
SELECT segment AS "segment",
       COUNT(*) AS "customers",
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS "share of customers pct",
       ROUND(SUM(monetary), 0) AS "revenue gbp",
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS "share of revenue pct",
       ROUND(AVG(recency), 0) AS "avg recency days",
       ROUND(AVG(frequency), 1) AS "avg orders",
       ROUND(AVG(monetary), 0) AS "avg spend gbp"
FROM seg GROUP BY segment ORDER BY segment;


-- name: 05 repeat and concentration
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
),
c AS (SELECT customer, COUNT(DISTINCT invoice) AS n, SUM(quantity * price) AS spend FROM clean GROUP BY customer),
ranked AS (SELECT *, ROW_NUMBER() OVER (ORDER BY spend DESC) AS rk, COUNT(*) OVER () AS total, SUM(spend) OVER () AS rev FROM c)
SELECT COUNT(*) AS "customers",
       ROUND(100.0 * AVG(n >= 2), 1) AS "repeat customer pct",
       ROUND(100.0 * SUM(CASE WHEN rk <= total * 0.10 THEN spend END) / MAX(rev), 1) AS "top 10 pct of customers share of revenue",
       ROUND(100.0 * SUM(CASE WHEN rk <= total * 0.01 THEN spend END) / MAX(rev), 1) AS "top 1 pct of customers share of revenue"
FROM ranked;


-- name: 06 top countries
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
)
SELECT country AS "country",
       COUNT(DISTINCT customer) AS "customers",
       ROUND(SUM(quantity * price), 0) AS "revenue gbp",
       ROUND(100.0 * SUM(quantity * price) / (SELECT SUM(quantity * price) FROM clean), 1) AS "share of revenue pct"
FROM clean GROUP BY country ORDER BY 3 DESC LIMIT 10;


-- name: 07 monthly revenue
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
)
SELECT SUBSTR(invoicedate, 1, 7) AS "month",
       ROUND(SUM(quantity * price), 0) AS "revenue gbp",
       COUNT(DISTINCT customer) AS "active customers"
FROM clean GROUP BY 1 ORDER BY 1;


-- name: 08 cancellations
SELECT ROUND(SUM(CASE WHEN invoice NOT LIKE 'C%' AND quantity > 0 THEN quantity * price END), 0) AS "gross sales gbp",
       ROUND(-SUM(CASE WHEN invoice LIKE 'C%' THEN quantity * price END), 0) AS "cancelled value gbp",
       ROUND(100.0 * -SUM(CASE WHEN invoice LIKE 'C%' THEN quantity * price END)
             / SUM(CASE WHEN invoice NOT LIKE 'C%' AND quantity > 0 THEN quantity * price END), 1) AS "cancelled pct of gross"
FROM transactions
WHERE customer IS NOT NULL AND price > 0;


-- name: 09 at risk detail
-- Spend in the last 12 months versus the 12 months before, for each segment.
-- Feeds the recommendation sizing in run.py.
WITH clean AS (
  SELECT * FROM transactions
  WHERE invoice NOT LIKE 'C%' AND customer IS NOT NULL AND quantity > 0 AND price > 0
),
base AS (
  SELECT customer,
         JULIANDAY('2011-12-10') - JULIANDAY(MAX(invoicedate)) AS recency,
         COUNT(DISTINCT invoice) AS frequency,
         SUM(CASE WHEN invoicedate <  '2010-12-10' THEN quantity * price ELSE 0 END) AS spendYearOne,
         SUM(CASE WHEN invoicedate >= '2010-12-10' THEN quantity * price ELSE 0 END) AS spendYearTwo
  FROM clean GROUP BY customer
),
scored AS (SELECT *, NTILE(5) OVER (ORDER BY recency DESC) AS r, NTILE(5) OVER (ORDER BY frequency) AS f FROM base),
seg AS (
  SELECT *,
    CASE
      WHEN r >= 4 AND f >= 4 THEN '1 Champions'
      WHEN r >= 3 AND f >= 3 THEN '2 Loyal'
      WHEN r >= 4 AND f <= 2 THEN '3 New or promising'
      WHEN r <= 2 AND f >= 3 THEN '4 At risk'
      WHEN r <= 2 AND f <= 2 THEN '6 Hibernating'
      ELSE '5 Needs attention' END AS segment
  FROM scored
)
SELECT segment AS "segment", COUNT(*) AS "customers",
       ROUND(SUM(spendYearOne), 0) AS "spend dec 2009 to nov 2010 gbp",
       ROUND(SUM(spendYearTwo), 0) AS "spend dec 2010 to dec 2011 gbp",
       ROUND(AVG(spendYearOne), 0) AS "avg spend year one gbp"
FROM seg GROUP BY segment ORDER BY segment;

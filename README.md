# Olist E-Commerce Analysis

Business analysis of the Olist Brazilian e-commerce dataset (100K+ orders, 2016-2018). All data cleaning and analysis done in PostgreSQL, dashboard built in Power BI.

Olist is a marketplace that connects small sellers to customers across Brazil. I wanted to understand what drives its revenue, where it loses money, and whether its customers come back. The analysis covers five questions:

1. How is revenue trending and where is growth stalling?
2. Which product categories drive revenue, and where is shipping pricing a problem?
3. Where do deliveries fail and what does that cost in customer satisfaction?
4. Do customers purchase again?
5. How much revenue is lost to cancellations?

## Dataset

Source: [Brazilian E-Commerce Public Dataset by Olist on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

9 relational tables, 99,441 orders, Sep 2016 to Oct 2018. Main tables: orders, order_items, customers, payments, reviews, products, sellers, geolocation, and a category translation table.

Raw CSVs are not included in this repo. Download them from the Kaggle link above.

## Tools

- PostgreSQL (pgAdmin) for import, cleaning and analysis. Joins, CTEs, window functions (ROW_NUMBER, LAG, NTILE), views.
- Power BI for the dashboard. Power Query transformations, one DAX calculated column, conditional formatting, map visual.
- GitHub for documentation.

## Data cleaning

Profiling the raw data surfaced several issues. Each cleaning decision is in sql/02_data_cleaning.sql:

| Issue | Decision |
|---|---|
| 814 duplicate review IDs, 547 orders with multiple reviews | Kept only the latest review per order using ROW_NUMBER() |
| 8 orders marked delivered but missing the delivery date | Flagged as corrupt and excluded from delivery metrics |
| 610 products with no category | Labeled "unknown" instead of dropping them, so their revenue stays in category analysis |
| Partial months at both ends of the dataset | Analysis window limited to complete months: Jan 2017 to Aug 2018 |
| 1,234 canceled/unavailable orders | Kept as a separate funnel-loss segment |

## Key findings

**Revenue hit R$15.68M but growth flattened.** Monthly revenue grew from R$137K in Jan 2017 to R$1.17M in Nov 2017 (Black Friday, +53% month over month). After that it stayed around R$1.0-1.15M through mid 2018. The platform kept adding customers but revenue stopped growing with them.

**Late delivery is the biggest satisfaction killer.** On-time orders average 4.29 stars. Late orders average 2.57. More than half of late orders (54.1%) get a 1 or 2 star review, compared to 9.2% for on-time orders.

**Delivery quality depends heavily on where the customer lives.** In Alagoas, 24% of orders arrive late and average delivery takes 24.5 days. In São Paulo it's 5.9% and 8.7 days. The northern and northeastern states consistently miss the delivery dates the platform itself promises.

**Only 3% of customers ever come back.** Out of 96,096 unique customers, 2,888 made a second purchase. Growth is almost entirely paid for by acquisition. The RFM segmentation shows 11,663 "at-risk high spenders" who hold R$4.6M in historical revenue, which makes them the obvious retention target.

**Freight pricing is broken for furniture and home categories.** furniture_decor and housewares carry freight at 23%+ of item price. For watches_gifts it's 8.4%.

**Cancellations cost about R$102K over the window.** July 2018 alone lost R$18.9K, a spike that would be worth an operational investigation.

## Dashboard

Four pages in Power BI (file: dashboard/olist_analysis.pbix, PDF export included).

**Page 1: Executive Overview** — revenue, orders, AOV and repeat rate KPIs, monthly revenue trend, month-over-month growth.

![Executive Overview](dashboard/screenshots/page1_executive_overview.png)

**Page 2: Category Performance** — top 10 categories by revenue, revenue share treemap, freight-to-price table with the problem categories flagged in red.

![Category Performance](dashboard/screenshots/page2_category_performance.png)

**Page 3: Delivery & Reviews** — Brazil map shaded by late delivery rate, delivery days by state, review score comparison for late vs on-time orders.

![Delivery & Reviews](dashboard/screenshots/page3_delivery_reviews.png)

**Page 4: Customers & Funnel** — RFM segments, repeat rate, monthly cancellations with lost revenue.

![Customers & Funnel](dashboard/screenshots/page4_customers_funnel.png)

## Recommendations

1. Fix delivery reliability in the Northeast first. Either recalibrate the promised delivery dates for states like AL, MA and PI, or invest in regional carriers. Moving orders from late to on-time takes most of them out of the 1-2 star zone.
2. Run a win-back campaign for the at-risk high spender segment. 11,663 customers with R$4.6M of past spend beat any equivalent acquisition spend when the baseline repeat rate is 3%.
3. Rework freight pricing for furniture and housewares. Options: freight subsidies, regional warehousing, or minimum basket sizes.
4. Investigate the July 2018 cancellation spike for a root cause.

## Repository structure

```
olist-ecommerce-analysis/
├── sql/
│   ├── 01_create_tables.sql       Schema for all 9 tables
│   ├── 02_data_cleaning.sql       Cleaning views
│   └── 03_analysis_queries.sql    6 analysis queries
├── results/                       Query outputs as CSV
├── dashboard/
│   ├── olist_analysis.pbix
│   ├── olist_analysis.pdf
│   └── screenshots/
└── README.md
```

## How to reproduce

1. Download the dataset from Kaggle.
2. Create a PostgreSQL database and run sql/01_create_tables.sql.
3. Import each CSV into its table (pgAdmin Import/Export, format CSV, encoding UTF8, header on).
4. Run sql/02_data_cleaning.sql to create the views.
5. Run the queries in sql/03_analysis_queries.sql and export the results.
6. Open dashboard/olist_analysis.pbix in Power BI Desktop.

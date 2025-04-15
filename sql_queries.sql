-- real_estate_analysis_queries.sql

-- Query 1: High-Value Listings or Sales
SELECT ADDRESS, TOWN, ASSESSED_VALUE AS AMOUNT, 'Listed_Value' AS SOURCE
FROM property
WHERE ASSESSED_VALUE > 1000000

UNION

SELECT ADDRESS, TOWN, SALE_AMOUNT AS AMOUNT, 'Sale_Amount' AS SOURCE
FROM property
WHERE SALE_AMOUNT > 1000000;


-- Query 2: Exact Matches in Assessed and Sold Values
SELECT ADDRESS, TOWN, ASSESSED_VALUE
FROM property
WHERE ASSESSED_VALUE IS NOT NULL

INTERSECT

SELECT ADDRESS, TOWN, SALE_AMOUNT
FROM property
WHERE SALE_AMOUNT IS NOT NULL;


-- Query 3: Assessed but Not Sold
SELECT ADDRESS, TOWN, ASSESSED_VALUE
FROM property
WHERE ASSESSED_VALUE IS NOT NULL

EXCEPT

SELECT ADDRESS, TOWN, SALE_AMOUNT
FROM property
WHERE SALE_AMOUNT IS NOT NULL;


-- Query 4: Properties in Clinton but not in Lebanon
SELECT ADDRESS, ASSESSED_VALUE
FROM property
WHERE TOWN = 'Clinton'

EXCEPT

SELECT ADDRESS, ASSESSED_VALUE
FROM property
WHERE TOWN = 'Lebanon';


-- Query 5: Shared Property Types and Values Between Ansonia and Avon
SELECT PROPERTY_TYPE, ASSESSED_VALUE
FROM property
WHERE TOWN = 'Ansonia'

INTERSECT

SELECT PROPERTY_TYPE, ASSESSED_VALUE
FROM property
WHERE TOWN = 'Avon';


-- Query 6: Recent Listings That Haven't Sold (Last 5 Years)
WITH recent_listings AS (
    SELECT ADDRESS, TOWN, LIST_YEAR, ASSESSED_VALUE
    FROM property
    WHERE LIST_YEAR >= DATE_PART('year', CURRENT_DATE) - 5
),
recent_sales AS (
    SELECT ADDRESS, TOWN, LIST_YEAR, SALE_AMOUNT
    FROM property
    WHERE LIST_YEAR >= DATE_PART('year', CURRENT_DATE) - 5
      AND SALE_AMOUNT IS NOT NULL
)
SELECT *
FROM recent_listings
EXCEPT
SELECT ADDRESS, TOWN, LIST_YEAR, SALE_AMOUNT
FROM recent_sales;



-- Query 7:Rank properties by Sale Amount within each town
WITH RankedSales AS (
    SELECT 
        Town,
        Address,
        "Sale Amount",
        RANK() OVER (PARTITION BY Town ORDER BY "Sale Amount" DESC) AS rank_within_town
    FROM real_estate
    WHERE "Sale Amount" IS NOT NULL
)
SELECT *
FROM RankedSales
WHERE rank_within_town <= 5;
--Shows top 5 most expensive properties in each town





-- Query 8:Track how average sale amounts changed from 2020 to 2021 by town
WITH AvgSalesByYear AS (
    SELECT 
        Town, 
        "List Year", 
        AVG("Sale Amount") AS avg_price
    FROM real_estate
    WHERE "Sale Amount" IS NOT NULL
    GROUP BY Town, "List Year"
),
PriceDiff AS (
    SELECT 
        a.Town,
        MAX(CASE WHEN a."List Year" = 2021 THEN a.avg_price END) AS avg_2021,
        MAX(CASE WHEN a."List Year" = 2020 THEN a.avg_price END) AS avg_2020
    FROM AvgSalesByYear a
    GROUP BY a.Town
)
SELECT *,
       (avg_2021 - avg_2020) AS price_change,
       ROUND((avg_2021 - avg_2020)/avg_2020 * 100, 2) AS percent_change
FROM PriceDiff
WHERE avg_2021 IS NOT NULL AND avg_2020 IS NOT NULL
ORDER BY percent_change DESC;
--Identifies towns with the highest % price increase or decrease



-- Query 9:Find the most common property type in each town
WITH TypeCount AS (
    SELECT 
        Town,
        "Property Type",
        COUNT(*) AS property_count,
        RANK() OVER (PARTITION BY Town ORDER BY COUNT(*) DESC) AS rnk
    FROM real_estate
    GROUP BY Town, "Property Type"
)
SELECT Town, "Property Type", property_count
FROM TypeCount
WHERE rnk = 1;
--Helps identify town-level housing market trends (e.g., mostly residential or commercial)





-- Query 10:Bucket properties into price ranges and count how many fall into each bucket
WITH Bucketed AS (
    SELECT 
        CASE 
            WHEN "Sale Amount" < 100000 THEN 'Under 100K'
            WHEN "Sale Amount" BETWEEN 100000 AND 200000 THEN '100K-200K'
            WHEN "Sale Amount" BETWEEN 200001 AND 400000 THEN '200K-400K'
            WHEN "Sale Amount" BETWEEN 400001 AND 600000 THEN '400K-600K'
            ELSE 'Over 600K'
        END AS price_bucket
    FROM real_estate
    WHERE "Sale Amount" IS NOT NULL
)
SELECT price_bucket, COUNT(*) AS count
FROM Bucketed
GROUP BY price_bucket
ORDER BY count DESC;
--For visualizing market segmentation



-- Query 11:Find properties with an unusually high sales ratio in a town (more than 2 std deviations above the mean)
WITH TownStats AS (
    SELECT 
        Town,
        AVG("Sales Ratio") AS avg_ratio,
        STDDEV("Sales Ratio") AS stddev_ratio
    FROM real_estate
    WHERE "Sales Ratio" IS NOT NULL
    GROUP BY Town
),
Anomalies AS (
    SELECT r.*
    FROM real_estate r
    JOIN TownStats t ON r.Town = t.Town
    WHERE r."Sales Ratio" > t.avg_ratio + 2 * t.stddev_ratio
)
SELECT Town, Address, "Sales Ratio"
FROM Anomalies
ORDER BY "Sales Ratio" DESC;
--Useful for fraud detection or market inefficiencies


-- Query 12: Top 10 Towns by Year-Over-Year Appreciation Rate
WITH avg_2020 AS (
    SELECT "TOWN", AVG("SALE_AMOUNT") AS avg_2020
    FROM property
    WHERE "SALE_AMOUNT" IS NOT NULL AND "LIST_YEAR" = 2020
    GROUP BY "TOWN"
),
avg_2021 AS (
    SELECT "TOWN", AVG("SALE_AMOUNT") AS avg_2021
    FROM property
    WHERE "SALE_AMOUNT" IS NOT NULL AND "LIST_YEAR" = 2021
    GROUP BY "TOWN"
)
SELECT
    a."TOWN",
    a.avg_2020,
    b.avg_2021,
    ROUND((b.avg_2021 - a.avg_2020) / a.avg_2020 * 100, 2) AS appreciation_rate
FROM avg_2020 a
JOIN avg_2021 b ON a."TOWN" = b."TOWN"
ORDER BY appreciation_rate DESC
LIMIT 10;

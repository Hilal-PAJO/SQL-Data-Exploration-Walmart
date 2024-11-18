/* 

## SQL Data Exploration for Global Superstore Dataset

### Skills Demonstrated
- Data selection and ordering
- Aggregations for sales and profit analysis
- Advanced window functions for ranking and cumulative analysis
- Creation and usage of views for reusable queries
- Use of CTEs for managing complex queries
- Temporary tables for staging intermediate results
- Conditional aggregation with `HAVING` for targeted filtering
- Time-based grouping to analyze seasonality

*/

--1.Checking the Table Structure
-- Viewing the entire data table to understand its structure and fields
SELECT * 
FROM WALMART..['Global_Superstore']
ORDER BY 3,2

--2.Sales and Profit Analysis
--**Purpose: Provide a high-level summary of the company’s overall performance.
--**Insight: Knowing the total sales and profit helps in determining the store's overall financial success.

--Calculating the total sales across all records
SELECT  SUM(SALES) AS TOTAL_SALES
FROM WALMART..['Global_Superstore']

--Calculating the total profit across all records
SELECT  SUM(Profit) AS TOTAL_PROFIT
FROM WALMART..['Global_Superstore']

--3.Profit per Sale by Country
--**Purpose: Shows profitability efficiency for each country by calculating profit per sale.
--**Insight: This can highlight which countries are most profitable on a per-sale basis, useful for targeted business strategies.

--Aggregating sales and profit by country to calculate profitability per sale
SELECT COUNTRY, SUM(SALES) AS TOTAL_SALES, SUM(Profit) AS TOTAL_PROFIT, SUM(Profit)/SUM(SALES) AS PROFIT_PER_SALES
FROM WALMART..['Global_Superstore']
GROUP BY Country 
ORDER BY 4 DESC

--Profit changes over years
SELECT YEAR_, SUM(Profit) AS SUM_PROFIT
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_
ORDER BY 1 DESC

--Most profitable products over years
SELECT Year_, CATEGORY, Product_Name, SUM(Profit)as SUM_PROFIT
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_, CATEGORY, PRODUCT_NAME
ORDER BY 1,4 DESC

--Sales by category
SELECT YEAR_, CATEGORY, SUM(SALES) AS SUM_SALES
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_, CATEGORY
ORDER BY 1,3

--4.Creating a View for Category Sales Analysis
--**Purpose: Store commonly-used category sales data in a view to avoid recalculating it in future queries.
--**Insight: Simplifies queries for category analysis, making code cleaner and more modular.

--Defining a view to make category sales data reusable and easier to query
CREATE VIEW CATEGORY_SALES AS
SELECT YEAR_, CATEGORY, SUM(SALES) AS SUM_SALES
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_, CATEGORY

--5.Identifying the Most Profitable Products in Top 10 Countries
--**Purpose: This query ranks products within each country and selects the most profitable product for each of the top 10 countries by sales.
--**Insight: Shows which products are top performers in different regions, useful for localized product strategies.

--Using a CTE and window functions to find the top product by profit in each of the top 10 countries by sales
WITH COUNTRY_PRODUCT_PROFIT AS
(
	SELECT 
		COUNTRY, Product_Name, SUM(Profit) AS TOTAL_PROFIT,
		ROW_NUMBER() OVER (PARTITION BY COUNTRY ORDER BY SUM(Profit) DESC) AS RANK_
	FROM WALMART..['Global_Superstore']
	WHERE COUNTRY IN 
		(
			SELECT TOP 10 Country 
			FROM WALMART..['Global_Superstore'] 
			GROUP BY Country 
			ORDER BY SUM(SALES) DESC
		)
	GROUP BY Country,Product_Name
)
SELECT COUNTRY, PRODUCT_NAME, TOTAL_PROFIT
FROM COUNTRY_PRODUCT_PROFIT
WHERE RANK_=1
ORDER BY TOTAL_PROFIT DESC

--City sales in lead country
SELECT COUNTRY, City, SUM(SALES) AS SALES
FROM WALMART..['Global_Superstore']
WHERE COUNTRY = 'United States'
GROUP BY COUNTRY, City
ORDER BY 3 DESC

--Which segments are more popular in Top 1 city in Top 1 country
SELECT COUNTRY, City,Segment, SUM(SALES) AS SALES
FROM WALMART..['Global_Superstore']
WHERE  City ='New York City' 
GROUP BY COUNTRY, City ,Segment
ORDER BY 3,2 DESC

--What is the most popular segment among customers in New York City 
WITH 
CUSTOMER_SALES_NY AS
(
	SELECT City, SEGMENT, CUSTOMER_NAME, SUM(SALES) AS CUSTOMER_SALES
	FROM WALMART..['Global_Superstore']
	WHERE City ='New York City' 
	GROUP BY City, SEGMENT, CUSTOMER_NAME
),
TOTAL_SALES_NY AS 
(
	SELECT City, SUM(SALES) AS TOTAL_SALES
	FROM WALMART..['Global_Superstore']
	WHERE City ='New York City'
	GROUP BY City
),
CUMULATIVE_RATE_TABLE AS 
(
SELECT CS.City, CS.SEGMENT, CS.CUSTOMER_NAME, CS.CUSTOMER_SALES, TS.TOTAL_SALES, 
		(CAST(CS.CUSTOMER_SALES AS DECIMAL) / TS.TOTAL_SALES) * 100 AS SALES_RATE,
        SUM((CAST(CS.CUSTOMER_SALES AS DECIMAL) / TS.TOTAL_SALES) * 100) OVER 
		(PARTITION BY CS.SEGMENT ORDER BY CS.CUSTOMER_SALES DESC) AS CUMULATIVE_RATE
		FROM CUSTOMER_SALES_NY AS CS 
		INNER JOIN TOTAL_SALES_NY AS TS ON CS.City = TS.City
		WHERE CS.City = 'New York City'
)
SELECT City, SEGMENT, SUM( CUSTOMER_SALES) AS TOTAL_CUSTOMER_SALES, MAX(CUMULATIVE_RATE) AS SEGMENT_CUMULATIVE_RATE
FROM CUMULATIVE_RATE_TABLE
GROUP BY City, SEGMENT
ORDER BY SEGMENT, TOTAL_CUSTOMER_SALES DESC 

--6.Using a Temp Table to Stage Data for Analysis
--**Purpose: Sets up a temporary table to hold intermediate results, helping to manage complex calculations and reuse data efficiently in subsequent queries.
--**Insight: Using temp tables is beneficial for breaking down large queries into manageable parts, especially useful for complex transformations.

--Dropping the temp table if it already exists, then creating it to stage customer sales data for analysis
DROP TABLE IF EXISTS #TEMP_CUSTOMER_SALES
CREATE TABLE #TEMP_CUSTOMER_SALES
(
SEGMENT NVARCHAR(50),
CITY NVARCHAR(50),
CUSTOMER_NAME NVARCHAR(100),
CUSTOMER_SALES INT,
TOTAL_SALES INT,
SALES_RATE DECIMAL(18,2),
CUMULATIVE_RATE DECIMAL(18,2)
)

WITH 
CUSTOMER_SALES_NY AS
(
	SELECT City, CUSTOMER_NAME, SUM(SALES) AS CUSTOMER_SALES
	FROM WALMART..['Global_Superstore']
	WHERE City ='New York City' 
	GROUP BY City, CUSTOMER_NAME
),
TOTAL_SALES_NY AS 
(
	SELECT City, SUM(SALES) AS TOTAL_SALES
	FROM WALMART..['Global_Superstore']
	WHERE City ='New York City'
	GROUP BY City
),
CUMULATIVE_RATE_TABLE AS 
(
SELECT CS.City, CS.CUSTOMER_NAME, CS.CUSTOMER_SALES, TS.TOTAL_SALES, (CAST(CS.CUSTOMER_SALES AS DECIMAL) / TS.TOTAL_SALES) * 100 AS SALES_RATE,
        SUM((CAST(CS.CUSTOMER_SALES AS DECIMAL) / TS.TOTAL_SALES) * 100) OVER (ORDER BY CS.CUSTOMER_SALES DESC) AS CUMULATIVE_RATE
		FROM CUSTOMER_SALES_NY AS CS 
		INNER JOIN TOTAL_SALES_NY AS TS ON CS.City = TS.City
		WHERE CS.City = 'New York City'
)
INSERT INTO #TEMP_CUSTOMER_SALES
SELECT DISTINCT GS.Segment, CRT.City, CRT.CUSTOMER_NAME, CRT.CUSTOMER_SALES, CRT.TOTAL_SALES, CRT.SALES_RATE, CRT.CUMULATIVE_RATE
FROM CUMULATIVE_RATE_TABLE AS CRT
INNER JOIN WALMART..['Global_Superstore'] AS GS ON CRT.Customer_Name = GS.Customer_Name 
GROUP BY GS.Segment, CRT.City, CRT.CUSTOMER_NAME,CRT.CUSTOMER_SALES, CRT.TOTAL_SALES, CRT.SALES_RATE, CRT.CUMULATIVE_RATE
ORDER BY CRT.CUMULATIVE_RATE ASC

--7.Applying Pareto Analysis to Identify Top 80% Customers in New York City
--**Purpose: Implements the Pareto principle (80/20 rule) to identify the subset of customers responsible for the majority of sales.
--**Insight: Reveals high-value customers, which can guide targeted retention or loyalty strategies.

--Who are the customers who by %80 of the products in NYC (PARETO 80-20 RULE) (USING TEMP TABLE)
SELECT * 
FROM #TEMP_CUSTOMER_SALES
WHERE CUMULATIVE_RATE <= 80
ORDER BY 7

--8.Seasonality in Monthly Sales (United States)
--**Purpose: Examines seasonal patterns in U.S. sales.
--**Insight: Identifies peak sales periods, which can inform inventory and marketing strategies for seasonal demand.

--Aggregating monthly sales in the U.S. to identify seasonal trends
SELECT YEAR_, MONTH(ORDER_DATE) AS MONTH, SUM(SALES) AS TOTAL_SALES
FROM WALMART..['Global_Superstore']
WHERE Country='United States'
GROUP BY YEAR_,MONTH(Order_Date)
ORDER BY 1,2

--September, October, November and December are peak months. 
--Finding products with high sales in peak months (Sept-Dec) for 2011 to 2014 in the United States
SELECT YEAR_, MONTH(ORDER_DATE) AS MONTH, PRODUCT_NAME, SUM(SALES) AS TOTAL_SALES
FROM WALMART..['Global_Superstore']
WHERE Country='United States' AND MONTH(Order_Date) >=9
GROUP BY YEAR_,MONTH(Order_Date), PRODUCT_NAME
HAVING SUM(SALES)>=3000
ORDER BY 4 DESC

--Which sub category is more popular in each year?
SELECT DISTINCT YEAR_, SUB_CATEGORY, SUM(SALES) AS TOTAL_SALES
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_, SUB_CATEGORY
ORDER BY 1,3 DESC

--9.Shipping Mode Cost Analysis
--**Purpose: Examines the cost distribution across different shipping modes.
--**Insight: This analysis helps in assessing the cost-effectiveness of each shipping method, crucial for logistics optimization.

--Summing up shipping costs by mode to see which modes are most used and their associated costs
SELECT DISTINCT YEAR_,Ship_Mode, SUM(Shipping_Cost) AS TOTAL_SHIPPING_COST
FROM WALMART..['Global_Superstore']
GROUP BY YEAR_,Ship_Mode
ORDER BY 1,3 DESC


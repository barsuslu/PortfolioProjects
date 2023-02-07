--DISCOVERY ANALYTICS
--Inspecting our data
SELECT * FROM PortfolioDB.dbo.sales_data_sample

--Checking Unique Values
SELECT DISTINCT STATUS FROM PortfolioDB.dbo.sales_data_sample --nice one to plot
SELECT DISTINCT YEAR_ID FROM PortfolioDB.dbo.sales_data_sample
SELECT DISTINCT PRODUCTLINE FROM PortfolioDB.dbo.sales_data_sample --nice one to plot
SELECT DISTINCT COUNTRY FROM PortfolioDB.dbo.sales_data_sample --nice one to plot
SELECT DISTINCT DEALSIZE FROM PortfolioDB.dbo.sales_data_sample --nice one to plot
SELECT DISTINCT TERRITORY FROM PortfolioDB.dbo.sales_data_sample --nice one to plot

--See if the data includes all 2005?
SELECT DISTINCT MONTH_ID
FROM PortfolioDB.dbo.sales_data_sample
WHERE YEAR_ID = 2005
--The data just includes first 5 months for 2005 so it won't be a good idea to compare yearly sales with each other

--ANALYSIS

--grouping SALES by PRODUCTLINE
SELECT
PRODUCTLINE, SUM(SALES) AS REVENUE
FROM PortfolioDB.dbo.sales_data_sample
GROUP BY PRODUCTLINE
ORDER BY 2 DESC

--grouping SALES by DEALSIZE
SELECT
DEALSIZE, SUM(SALES) AS REVENUE
FROM PortfolioDB.dbo.sales_data_sample
GROUP BY DEALSIZE
ORDER BY 2 DESC

--what is the best month in terms of sales in a specific year
SELECT
MONTH_ID, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS NOOFORDERS
FROM PortfolioDB.dbo.sales_data_sample
WHERE YEAR_ID = 2004 --change year to see for other years
GROUP BY MONTH_ID
ORDER BY 2 DESC

--November seems to be the best month for both 2004 & 2005. Which product line did they sell most in November?
SELECT
PRODUCTLINE, SUM(SALES) AS REVENUE, COUNT(ORDERNUMBER) AS NOOFORDERS
FROM PortfolioDB.dbo.sales_data_sample
WHERE YEAR_ID = 2004 AND MONTH_ID = 11 --change year to see for other years
GROUP BY PRODUCTLINE
ORDER BY 2 DESC


--RFM ANALYSIS
--Who is our best customer? (This can be answered best by RFM Analysis) (using percentiles in Window Functions and CTEs)
WITH rfm AS(
	SELECT
		CUSTOMERNAME,
		SUM(SALES) AS TOTALSALES,
		AVG(SALES) AS AVGSALES,
		COUNT(ORDERNUMBER) AS FREQUENCY,
		MAX(ORDERDATE) AS LASTORDERDATE,
		(SELECT MAX(ORDERDATE) FROM PortfolioDB.dbo.sales_data_sample) AS GENERALLASTDATE, --to see the last date that the orders are taken
		DATEDIFF(DD, MAX(ORDERDATE), (SELECT MAX(ORDERDATE) FROM PortfolioDB.dbo.sales_data_sample)) AS RECENCY --how many days passed since last order
	FROM PortfolioDB.dbo.sales_data_sample
	GROUP BY CUSTOMERNAME
),
rfm_calc AS(
	SELECT 
		r.*,
		NTILE(4) OVER (ORDER BY RECENCY DESC) AS RFM_RECENCY, --it has DESC beacuse less days the recency is the customer should belong to a higher quartile
		NTILE(4) OVER (ORDER BY FREQUENCY) AS RFM_FREQUENCY,
		NTILE(4) OVER (ORDER BY AVGSALES) AS RFM_MONETARY
	FROM rfm r
)
SELECT 
	c.*,
	RFM_RECENCY + RFM_FREQUENCY + RFM_MONETARY AS RFM_VALUE,
	CAST(RFM_RECENCY AS varchar) + CAST(RFM_FREQUENCY AS varchar) + CAST(RFM_MONETARY AS varchar) AS RFM_STR
into #rfm --Create a table to store RFM values for ease of use in further anaysis
FROM rfm_calc c

WITH segments AS (
	SELECT
		CUSTOMERNAME,
		RFM_RECENCY,
		RFM_FREQUENCY,
		RFM_MONETARY,
		CASE
			when RFM_STR IN (111, 112, 113, 121, 122, 123, 131, 132, 211, 212, 221, 231, 114, 141, 142) then 'Lost Customer' --Customers who didn't made a purchase for a long time
			when RFM_STR IN (133, 134, 143, 224, 234, 241, 242, 244, 334, 343, 344) then 'Customer Slipping Away' --Big spenders who haven't purchased lately
			when RFM_STR IN (311, 312, 411, 331) then 'New Customers'
			when RFM_STR IN (214, 222, 223, 233, 322) then 'Potential Churn Customers'
			when RFM_STR IN (314, 323, 333, 321, 421, 422, 332, 341, 342, 432, 441, 442) then 'Active Customers' --Customers who bought recently and frequently (but at low price points)
			when RFM_STR IN (414, 424, 433, 434, 443, 444) then 'Loyal Customers'
		end rfm_segment
	FROM #rfm
)

SELECT 
	s.rfm_segment, 
	COUNT(*) AS no_of_customers
FROM segments s
GROUP BY s.rfm_segment
ORDER BY 2 DESC
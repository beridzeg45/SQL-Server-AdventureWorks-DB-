-- 1.Identify the top 10 products by sales revenue in the last quarter of the year.

DECLARE @LAST_DATE DATE = (SELECT MAX(ORDERDATE) FROM FactInternetSales)
DECLARE @StartDateOfLastQuarter DATE = DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @LAST_DATE) - 1, 0)
DECLARE @EndDateOfLastQuarter DATE = DATEADD(DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, @LAST_DATE), 0));

SELECT TOP 10 FIS.ProductKey,EnglishProductName, FORMAT(SUM(SalesAmount),'C2') AS REVENUE,
FORMAT(CAST(SUM(SalesAmount) AS FLOAT)/(SELECT SUM(SalesAmount) FROM FactInternetSales),'P2') AS [PERCENT OF TOTAL REVENUE]
FROM FactInternetSales AS FIS
JOIN DimProduct DM ON FIS.ProductKey=DM.ProductKey
WHERE OrderDate BETWEEN @StartDateOfLastQuarter AND @EndDateOfLastQuarter
GROUP BY FIS.ProductKey,EnglishProductName
ORDER BY SUM(SalesAmount) DESC ;

-- 2.Determine REVENUE BY DIFFERENT AGE SEGMENTS WITH DIFFERENCE OF 3 YEARS
WITH T1 AS
(
SELECT FLOOR(DATEDIFF(DAY, BirthDate, DateFirstPurchase) / 365.25 / 3) * 3 AS AgeGroup, SUM(SalesAmount) AS [REVENUE]
FROM DimCustomer DC
JOIN FactInternetSales FIS ON DC.CustomerKey=FIS.CustomerKey
GROUP BY FLOOR(DATEDIFF(DAY, BirthDate, DateFirstPurchase) / 365.25 / 3)*3
)
SELECT CONCAT(AGEGROUP,'-',LEAD(AgeGroup) OVER(ORDER BY AGEGROUP)) AS [AGE GROUP], FORMAT(REVENUE,'C2') AS [REVENUE]
FROM T1;

DECLARE @BIN INT=3;

WITH T1 AS 
(
SELECT CONCAT(FLOOR(DATEDIFF(DAY, BirthDate, DateFirstPurchase) / 365.25 / @BIN) * @BIN,'-',FLOOR(DATEDIFF(DAY, BirthDate, DateFirstPurchase) / 365.25 / @BIN) * @BIN+@BIN) AS [AgeGroup], SUM(SalesAmount) AS [REVENUE]
FROM DimCustomer DC
JOIN FactInternetSales FIS ON DC.CustomerKey=FIS.CustomerKey
GROUP BY FLOOR(DATEDIFF(DAY, BirthDate, DateFirstPurchase) / 365.25 / @BIN)*@BIN
)
SELECT AgeGroup, FORMAT(REVENUE,'C2') AS [REVENUE]
FROM T1
ORDER BY CAST(LEFT(AgeGroup,CHARINDEX('-',AGEGROUP)-1) AS INT);

-- 3.Find the month with the highest sales volume.

SELECT TOP 1 FORMAT(OrderDate,'yyyy-MM') AS [MONTH],FORMAT(SUM(SalesAmount),'C2') AS [SALES]
FROM FactInternetSales FIS
GROUP BY FORMAT(OrderDate,'yyyy-MM')
ORDER BY SUM(SalesAmount) DESC;

-- 4.Calculate the total sales amount for each sales territory.

SELECT SalesTerritoryCountry,FORMAT(SUM(SalesAmount),'C2') AS[SALES], FORMAT(CAST(SUM(SalesAmount) AS FLOAT)/(SELECT SUM(SalesAmount) FROM FactInternetSales),'P2') AS[PERCENT OF TOTAL SALES]
FROM DimSalesTerritory DST
JOIN FactInternetSales FIS ON DST.SalesTerritoryKey=FIS.SalesTerritoryKey
GROUP BY SalesTerritoryCountry
ORDER BY SUM(SalesAmount) DESC;


-- 5.Identify the top 5 customers by the number of orders placed.
WITH T1 AS
(
SELECT DC.CustomerKey, IIF(MiddleName IS NULL,CONCAT(FirstName,' ',LastName),CONCAT(FirstName,' ',MiddleName,'. ',LastName)) AS [FULL NAME]
FROM DimCustomer DC
)
SELECT TOP 5 T1.CustomerKey, [FULL NAME], COUNT(OrderDate) AS [ORDERS PLACED]
FROM T1 JOIN FactInternetSales FIS ON T1.CustomerKey=FIS.CustomerKey
GROUP BY T1.CustomerKey, [FULL NAME]
ORDER BY [ORDERS PLACED] DESC;


-- 6.Analyze the seasonality of sales for specific product categories.
SELECT FORMAT(OrderDate,'yyyy-MM') AS [MONTH],EnglishProductCategoryName, SUM(FIS.OrderQuantity) AS [QUANTITY ORDERED]
FROM FactInternetSales FIS
JOIN DimProduct DP ON FIS.ProductKey=DP.ProductKey
JOIN DimProductSubcategory DPSC ON DP.ProductSubcategoryKey=DPSC.ProductSubcategoryKey
JOIN DimProductCategory DPC ON DPSC.ProductCategoryKey=DPC.ProductCategoryKey
GROUP BY FORMAT(OrderDate,'yyyy-MM'),EnglishProductCategoryName
ORDER BY EnglishProductCategoryName, [MONTH];

-- 7.Determine the average number of days between order date and ship date BY SHIPPING COUNTRY.
SELECT SalesTerritoryCountry, AVG(DATEDIFF(DAY,OrderDate,ShipDate)) AS [AVERAGE DAYS]
FROM FactInternetSales FIS
JOIN DimSalesTerritory DST ON FIS.SalesTerritoryKey=DST.SalesTerritoryKey
GROUP BY SalesTerritoryCountry;


-- 8.Calculate the year-over-year growth rate in sales revenue.

WITH T1 AS
(
SELECT FORMAT(OrderDate,'yyyy-MM') AS [PERIOD],SUM(SalesAmount) AS [SALES]
FROM FactInternetSales FIS
GROUP BY FORMAT(OrderDate,'yyyy-MM')
)
,T2 AS
(
SELECT T1.[PERIOD],T1.SALES, LAG(SALES) OVER(ORDER BY T1.[PERIOD]) AS [PREVIOUS]
FROM T1
)
SELECT [PERIOD],FORMAT(SALES,'C0') AS [SALES], FORMAT(SALES/PREVIOUS-1,'P2') AS [CHANGE]
FROM T2
ORDER BY PERIOD OFFSET 2 ROWS; 


-- 9.Identify the most profitable product categories based on gross margin. COMPARE WITH GENERATED REVENUE

SELECT EnglishProductSubcategoryName, FORMAT(AVG((SalesAmount-TotalProductCost)/SalesAmount),'P2') AS [AVG GROSS MARGIN], 
FORMAT(CAST(SUM(SalesAmount) AS FLOAT)/(SELECT SUM(SalesAmount) FROM FactInternetSales),'P2') AS [PERCENT OF TOTAL REVENUE]
FROM FactInternetSales FIS
JOIN DimProduct DP ON FIS.ProductKey=DP.ProductKey
JOIN DimProductSubcategory DPSC ON DP.ProductSubcategoryKey=DPSC.ProductSubcategoryKey
GROUP BY EnglishProductSubcategoryName
ORDER BY AVG((SalesAmount-TotalProductCost)/SalesAmount) DESC;

-- 10.Determine the correlation between promotional offers and sales volume.
SELECT PromotionKey,FORMAT(OrderDate,'yyyy-MM') AS [PERIOD], SUM(SalesAmount) AS [REVENUE]
FROM FactInternetSales FIS
GROUP BY PromotionKey,FORMAT(OrderDate,'yyyy-MM')
ORDER BY PERIOD, PromotionKey;


-- 14.Determine SALES AMOUNT AND PERCENTAGE OF TOTAL REVENUE OVER WEEKENDS
    SET DATEFIRST 1;
    WITH T1 AS
    (
    SELECT DATEPART(WEEKDAY,OrderDate) AS [INDEX],DATENAME(WEEKDAY,OrderDate) AS [WEEKDAY], SUM(SalesAmount) AS [SALES]
    FROM FactInternetSales FIS
    GROUP BY DATEPART(WEEKDAY,OrderDate),DATENAME(WEEKDAY,OrderDate)
    )
    SELECT WEEKDAY,FORMAT(SALES,'C0') AS [SALES], FORMAT(SALES/(SELECT SUM(SalesAmount) FROM FactInternetSales),'P2') AS [PERCENTAGE]
    FROM T1
    ORDER BY [INDEX];


-- 17.Calculate the customer retention rate.
SELECT
FORMAT(
(SELECT COUNT(*) FROM(SELECT CustomerKey, COUNT(OrderDate) AS [TOTAL ORDERS] FROM FactInternetSales FIS GROUP BY CustomerKey HAVING COUNT(OrderDate)=1) AS T1)/
CAST((SELECT COUNT(DISTINCT CustomerKey) FROM DimCustomer) AS FLOAT)
,'P2')
AS [PERCENT OF CUSTOMERS WITH ONE PURCHASE];

--18.FIND CUSTOMERS WHO MADE LAST PURCHASE OVER 1 YEAR AGO
DECLARE @TODAY DATE = DATEADD(DAY,1,(SELECT MAX(OrderDate) FROM FactInternetSales));

WITH T1 AS
(
SELECT CustomerKey, MIN(OrderDate) AS [FIRST DATE]
FROM FactInternetSales FIS
GROUP BY CustomerKey
)
,T2 AS
(
SELECT CustomerKey, MAX(OrderDate) AS [LAST DATE]
FROM FactInternetSales FIS
GROUP BY CustomerKey
)
,T3 AS
(
SELECT CustomerKey, COUNT(OrderDate) AS [TOTAL ORDERS]
FROM FactInternetSales FIS
GROUP BY CustomerKey
)
,T4 AS
(
SELECT T1.CustomerKey AS [CUSTOMERKEY],[TOTAL ORDERS], [FIRST DATE],[LAST DATE], DATEDIFF(DAY,[FIRST DATE],[LAST DATE]) AS [DIFFERENCE]
FROM T1
JOIN T2 ON T1.CustomerKey=T2.CustomerKey
JOIN T3 ON T2.CustomerKey=T3.CustomerKey
)
SELECT T4.CUSTOMERKEY,CONCAT(FirstName,' ',LastName) AS [FULL NAME],Gender,Phone,EmailAddress, [TOTAL ORDERS], [LAST DATE], DATEDIFF(DAY,[LAST DATE],@TODAY) AS [DAYS PASSED SINCE LAST PURCHASE]
FROM T4
JOIN DimCustomer DC ON T4.CUSTOMERKEY=DC.CustomerKey
WHERE DATEDIFF(DAY,[LAST DATE],@TODAY)>=365
ORDER BY [DAYS PASSED SINCE LAST PURCHASE] ASC;
 
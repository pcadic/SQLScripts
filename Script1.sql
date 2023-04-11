USE [SQLBook]
GO


/* Population of Males and Females per state**/
SELECT [Stab],
	   SUM([Males])   AS [Number of Males],
       SUM([Females]) AS [Number of Females]
  FROM [dbo].[ZipCensus]
GROUP BY [Stab]
ORDER BY [Stab];
GO


/* Number of European born per state and per county, from the most populated county to the least */
SELECT [Stab], 
	   [County],
	   SUM([FBEurope])   AS [Number of European born]
  FROM [dbo].[ZipCensus]
GROUP BY [Stab], 
		 [County]
ORDER BY SUM([FBEurope]) DESC;
GO


/* Average product price per GroupName above $25 */
SELECT [GroupName],
       AVG([FullPrice]) AS [Average Price]
  FROM [dbo].[Products]
  GROUP BY [GroupName]
  HAVING AVG([FullPrice]) > 25;
GO


/* Minimum, maximum and average full price of products per groupname, with roll up into Total */
SELECT IIF(GROUPING([GroupName]) = 1, 'Total', [GroupName]) AS [GroupName],
		MIN([FullPrice])									AS [Minimum Full Price],
		MAX([FullPrice])									AS [Maximum Full Price],
		AVG([FullPrice])									AS [Average Full Price]
FROM [dbo].[Products]
WHERE [GroupName] <> '#N/A'
GROUP BY ROLLUP ([GroupName]);
GO


/* Display of the average full price along each product and its full price */
SELECT p.[ProductID],
       p.[FullPrice],
       pcj.[Average Full Price]
 FROM [dbo].[Products] p
 CROSS JOIN 
   (
	SELECT AVG([FullPrice]) AS [Average Full Price] 
	  FROM [dbo].[Products]
	) pcj
ORDER BY p.[ProductID];
GO


/* Display of Customer information (Id, HouseholdId, FirtsName) along with their respective order (OrderId, OrderDate) */
SELECT	c.[CustomerId], 
		c.[HouseholdId],
		c.[FirstName],
		o.[OrderId],
		o.[OrderDate]
FROM [dbo].[Customers] c
INNER JOIN [SQLBook].[dbo].[Orders] o ON c.[CustomerId] = o.[CustomerId]
ORDER BY c.[CustomerId];
GO


/* Display of all orders (OrderId, OrderDate) along with the Customer information (Id, HouseholdId, FirtsName) if known */
SELECT	c.[CustomerId], 
		c.[HouseholdId],
		c.[FirstName],
		o.[OrderId],
		o.[OrderDate]
FROM [dbo].[Customers] c
RIGHT OUTER JOIN [dbo].[Orders] o ON c.[CustomerId] = o.[CustomerId]
ORDER BY c.[CustomerId];
GO


/* Display the Zipcode delivery of each order, and the sate abbreviation if known */
SELECT o.[OrderId],
	   o.[ZipCode],
	   z.[Stab]
FROM [dbo].[Orders] o
LEFT OUTER JOIN [dbo].[ZipCensus] z ON o.[ZipCode] = z.[zcta5]
ORDER BY o.[OrderId];
GO


/* Display all orders in the Wyoming state along all web campaigns */
SELECT o.[OrderId], 
       o.[CustomerId], 
	   o.[City], 
	   c.[Discount]
FROM
(
SELECT *
FROM [dbo].[Orders]
WHERE [State] = 'WY'
) o 
FULL OUTER JOIN 
(SELECT [CampaignId], 
	    [Discount]
FROM [dbo].[Campaigns]
WHERE [Channel] = 'WEB') c ON c.[CampaignId] = o.[CampaignId];
GO


/* Display the amount of product in stock per group name */
WITH ProductInStock
AS
(
  SELECT [GroupName], 
		 [FullPrice]
  FROM [dbo].[Products]
  WHERE [GroupName] <> '#N/A'
  AND [IsInStock] = 'Y'
)
SELECT [GroupName], 
	   SUM(FullPrice) AS [Total Full Price]
FROM [ProductInStock]
GROUP BY [GroupName]
ORDER BY [Total Full Price];
GO


/* Average number of orders per zip code */
WITH OrderZip (Zip, num)
AS
(
	SELECT [ZipCode], 
		   COUNT(*) 
	FROM [dbo].[Orders] 
	GROUP BY [ZipCode]
)
SELECT AVG(num)  AS [Average Zip code Order]
FROM OrderZip;
GO


/*Display of Average State Population */
WITH Pop_ByState
AS
(
	SELECT [Stab], 
		   SUM([TotPop]) AS [Total State Population]
	FROM [dbo].[ZipCensus]
	GROUP BY [Stab]
)
SELECT AVG([Total State Population]) AS [Average State Population]
FROM Pop_ByState;
GO


/* Display of the maximum price order for each customer */
WITH CTE_TotalPriceOrder
AS
(
  SELECT [OrderId], 
		 SUM([TotalPrice]) AS [TotalPriceOrder]
  FROM [dbo].[OrderLines]
  GROUP BY [OrderId]
)
SELECT o.[CustomerID], 
	  MAX(cte.TotalPriceOrder) AS [TotalPriceCustomer]
FROM CTE_TotalPriceOrder cte
INNER JOIN [dbo].[Orders] o ON o.[OrderId] = cte.[OrderId]
GROUP BY o.[CustomerID]
HAVING o.[CustomerID] <> 0
ORDER BY [TotalPriceCustomer] DESC;
GO


/* Number of order per month in an descending order */
WITH CTE_MonthOrder (OrderId, Month)
AS
(
	SELECT o.[OrderId], 
		  cal.[MonthAbbr]
	FROM [dbo].[Orders] o
	INNER JOIN [dbo].[Calendar] cal ON o.[OrderDate] = cal.[Date]
)
SELECT Month, 
	   COUNT(*) as [Number of Order]
FROM CTE_MonthOrder
GROUP BY Month
ORDER BY  [Number of Order] DESC;
GO

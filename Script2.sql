USE [SQLBook]
GO


/* 1: Add auxiliary data : IsGenreFemale, IsGenreMale and IsGenreUnknown*/ 
SELECT	c.[CustomerId], 
		IIF(c.[Gender] = 'F', 100, 0) AS [IsGenreFemale],
		IIF(c.[Gender] = 'M', 100, 0) AS [IsGenreMale],
		IIF(LEN(c.[Gender]) <> 1 , 100, 0) AS [IsGenreUnknown]
FROM [dbo].[Customers] c
ORDER BY c.[CustomerId];
GO


/* 2: IIF : Computation of Genre percentage */
WITH CTE_Male
AS
(
	SELECT FORMAT(AVG(IIF(c.[Gender] = 'M', 100.0, 0)), 'N2') AS [Average Genre Male]
	FROM [dbo].[Customers] c
),
CTE_Female
AS
(
	SELECT FORMAT(AVG(IIF(c.[Gender] = 'F', 100.0, 0)), 'N2')  AS [Average Genre Female]
	FROM [dbo].[Customers] c
),
CTE_Unknown
AS
(
	SELECT FORMAT(AVG(IIF(LEN(c.[Gender]) <> 1 , 100.0, 0)), 'N2') AS [Average Genre Unknown]
	FROM [dbo].[Customers] c
)
SELECT	[Average Genre Male],
		[Average Genre Female],	
		[Average Genre Unknown]
FROM CTE_Male, CTE_Female, CTE_Unknown;
GO


/* 3:CASE:  Sum of Full Total Price per Payment Type : American Express, Debit, Mstercard, Visa and Other*/
WITH CTE_PricePerType
AS
(
	SELECT [OrderId],
			CASE [PaymentType]
				WHEN 'AE' THEN 'American Express'
				WHEN 'DB' THEN 'Debit'
				WHEN 'MC' THEN 'Mastercard'
				WHEN 'VI' THEN 'Visa'
				ELSE 'Other' 
			END AS [Payment Type],
			[TotalPrice]
	FROM [dbo].[Orders]
)
SELECT [Payment Type],
		SUM([TotalPrice]) AS [Sum Total Price]
FROM CTE_PricePerType
GROUP BY [Payment Type]
ORDER BY [Payment Type];
GO

/*4: ISNULL:  Number of orders per state (for more than 5,000 orders)*/
WITH CTE_OrderAndState (OrderId, ZipCode, Stab)
AS
(
	SELECT o.[OrderId],
		   o.[ZipCode],
		   ISNULL(z.[Stab],'Undefined ZipCode')
	FROM [dbo].[Orders] o
	LEFT OUTER JOIN [dbo].[ZipCensus] z ON o.[ZipCode] = z.[zcta5]
)
SELECT Stab,
	   COUNT(*) AS [Number of orders]
FROM CTE_OrderAndState
GROUP BY Stab
HAVING COUNT(*) >= 5000
ORDER BY Stab;
GO



/* 5: COALESCE : First Shipment volume for products sold between 2009 and 2011*/
WITH CTE_ProductShipYear (ProductID, y2009, y2010, y2011)
AS
(
	SELECT ol.[ProductID],   
			SUM(IIF(YEAR(ol.[ShipDate]) = 2009, 1,NULL)),
			SUM(IIF(YEAR(ol.[ShipDate]) = 2010, 1,NULL)),
			SUM(IIF(YEAR(ol.[ShipDate]) = 2011, 1,NULL))
	FROM [dbo].[OrderLines] ol
	WHERE YEAR(ol.[ShipDate]) IN (2009, 2010, 2011)
	GROUP BY ol.[ProductId]
)
SELECT ProductID, COALESCE(y2009, y2010, y2011) AS [First Shipment Volume]
FROM CTE_ProductShipYear
ORDER BY ProductID;
GO


/* 6 : PIVOT : Number of Orders associated with the campaign channel WEB, AD, MAIL and REFERRAL*/
SELECT 'Count' AS [Campaign Channel], pvt.[WEB], pvt.[AD], pvt.[MAIL], pvt.[REFERRAL]
FROM 
(
	SELECT o.[OrderId],
		   c.[Channel]
	FROM [dbo].[Orders] o
	JOIN [dbo].[Campaigns] c ON o.[CampaignId] = c.[CampaignId]
) AS sdata
PIVOT
(
	COUNT(OrderId)
	FOR [Channel]
	IN ([WEB], [AD], [MAIL], [REFERRAL])
) AS pvt;
GO



/* 7: Add Additional Data : order week end Percent */
SELECT o.[OrderId],
		IIF(c.[DOW] = 'Sat' OR c.[DOW] = 'Sun',100.0,0) AS [Weekend Order]
FROM [dbo].[Orders] o
JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date];
GO


/* 8  IIF : Weekend Orders by US State */
WITH CTE_WeekendOrder (OrderId, State, [Weekend Order])
AS
(
	SELECT  o.[OrderId],
			o.[State],
			IIF(c.[DOW] = 'Sat' OR c.[DOW] = 'Sun',100.0,0)
	FROM [dbo].[Orders] o
	JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date]
	WHERE o.[State] IN (
						SELECT DISTINCT [Stab] 
						FROM [dbo].[ZipCensus]
						)
)
SELECT State, 
	   FORMAT(AVG([Weekend Order]), 'N2') AS [Avg. Num. of Weekend Order]
FROM CTE_WeekendOrder
GROUP BY State
ORDER BY [Avg. Num. of Weekend Order] DESC;
GO


/* 9:CASE: Number of Orders per Price Range */
WITH CTE_OrderPriceCategory
As
(
	SELECT o.[OrderId],
		CASE
			WHEN [TotalPrice] = 0                            THEN 'Free Orders'
			WHEN [TotalPrice] > 0    AND TotalPrice <= 10    THEN 'Under $10'
			WHEN [TotalPrice] > 10   AND TotalPrice <= 100   THEN 'Under $100'
			WHEN [TotalPrice] > 100  AND TotalPrice <= 1000  THEN 'Under $1000'
			WHEN [TotalPrice] > 1000 AND TotalPrice <= 10000 THEN 'Under $10000'
		END AS [Price Category]
	FROM [dbo].[Orders] o
)
SELECT [Price Category],
		COUNT(OrderId) AS [Number of Orders]
FROM CTE_OrderPriceCategory
GROUP BY [Price Category]
ORDER BY [Price Category];
GO


/* 10:ISNULL : Subscriber loyalty in number of years (for SubscriberID inferior to 1000)*/
WITH CTE_SubscriverPerLoyalty
AS
(
  SELECT [SubscriberID],
		DATEDIFF (YEAR, [StartDate], ISNULL([StopDate],getDate())) AS [Year Loyalty] 
  From [dbo].[Subscribers]
  WHERE [SubscriberID] < 10000
 )
 SELECT [Year Loyalty]		AS [Loyalty Year],
		COUNT(SubscriberID) AS [Number of Subscribers]
 FROM CTE_SubscriverPerLoyalty
 GROUP BY [Year Loyalty]
 ORDER BY [Year Loyalty];
 GO

/* 11 COALESCE : Average total price of orders during the first year of a Campaign introduction */
WITH CTE_ChannelEffect
AS 
(
  SELECT c.[Channel], 
		AVG(IIF(YEAR(o.[OrderDate]) = 2013, o.[TotalPrice], NULL)) AS [y2013],
		AVG(IIF(YEAR(o.[OrderDate]) = 2014, o.[TotalPrice], NULL)) AS [y2014],
		AVG(IIF(YEAR(o.[OrderDate]) = 2015, o.[TotalPrice], NULL)) AS [y2015],
		AVG(IIF(YEAR(o.[OrderDate]) = 2016, o.[TotalPrice], NULL)) AS [y2016]		
  FROM [dbo].[Campaigns] c
  JOIN [dbo].[Orders] o ON c.[CampaignId] = o.[CampaignId]
  GROUP BY c.[Channel]
)
SELECT Channel, 
	   COALESCE([y2013],[y2014],[y2015],[y2016]) AS [First Performance]
FROM CTE_ChannelEffect;
GO


/* 11 PIVOT: Average amount used per Payment Type and State */
SELECT pvt.Stab, pvt.[AE], pvt.[VI], pvt.[DB], pvt.[MC], pvt.[OC]
FROM 
(
	SELECT z.[Stab], 
		   IIF(o.[PaymentType] = '??', 'OC', o.[PaymentType]) AS [PaymentType],
		   o.[TotalPrice]
	FROM [dbo].[Orders] o
	JOIN [dbo].[ZipCensus] z ON o.[ZipCode] = z.[zcta5]
) AS sdata
PIVOT
(
	AVG(TotalPrice)
	FOR [PaymentType]
	IN ([AE], [VI], [DB], [MC], [OC])
) AS pvt
ORDER BY pvt.Stab



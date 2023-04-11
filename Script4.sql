USE [SQLBook]
GO


/*3.1:ROW_NUMBER(): Population Rank per State */
SELECT  zc.[Stab]											AS [State],
		SUM(zc.[TotPop])									AS [State Total Pop.],
		ROW_NUMBER () OVER (ORDER BY SUM(zc.[TotPop]))		AS [Population Rank]
FROM [dbo].[ZipCensus] zc
GROUP BY zc.[Stab]
ORDER BY zc.[Stab];
GO


/*3.2: RANK & DENSE_RANK : European born people ranked per AL counties Rank and Dense Rank*/
SELECT [County],
	   SUM([FBEurope])									AS [Number of European born],
	   ROW_NUMBER ()	OVER (ORDER BY SUM([FBEurope]))	AS [Sequence],
	   RANK()			OVER (ORDER BY SUM([FBEurope]))	AS [Rank],
	   DENSE_RANK()		OVER (ORDER BY SUM([FBEurope]))	AS [No Gap Rank]
  FROM [dbo].[ZipCensus]
  WHERE [Stab] = 'AL'
GROUP BY [Stab], 
		 [County]
HAVING SUM([FBEurope]) > 0
ORDER BY SUM([FBEurope]) ASC;
GO


/*3.3:NTILE(n) : Display price of Game product per quartile */
SELECT	[ProductId], 
		[FullPrice],  
		NTILE (4) OVER (ORDER BY [FullPrice] DESC) AS [Quartile]  
FROM [dbo].[Products] 
WHERE [GroupName] ='GAME' 
  AND [IsInStock] = 'Y';
GO


/*3.4:NTILE(n): Display the first group out of 10 of customers who pays the most per year 2015 and 1016 in Alabama*/
WITH CTE_PricePerYear (YearOrder, Customer,TotalPrice)
AS
(
	SELECT  YEAR(OrderDate)  ,
			CustomerId,  
			SUM(TotalPrice) 
	FROM [dbo].[Orders] o 
	WHERE [State] = 'AL' 
	  AND [CustomerId] != 0 
	  AND YEAR([OrderDate]) IN (2015, 2016)
	GROUP BY YEAR([OrderDate]), 
			 [CustomerId]
),
CTE_Ntile10 (YearOrder, Customer, TotalPrice, Group10)
AS
(
 SELECT YearOrder, 
		Customer, 
		TotalPrice, 
	    NTILE (10) OVER (PARTITION BY YearOrder ORDER BY TotalPrice DESC)
 FROM CTE_PricePerYear
)
SELECT YearOrder, 
	   Customer, 
	   TotalPrice
FROM CTE_Ntile10
WHERE Group10 = 1
ORDER BY YearOrder,
		 Customer;
GO


/*3.5:MIN, MAX, AVG, SUM, COUNT, COUNT_BIG: Summary of Total price of orders per year */
SELECT  DISTINCT YEAR([OrderDate]) AS YearOrder,
		MIN([TotalPrice])			OVER (PARTITION BY YEAR([OrderDate]))		AS MinTotalPrice,
		MAX([TotalPrice])			OVER (PARTITION BY YEAR([OrderDate]))		AS MaxTotalPrice,
		FORMAT(AVG([TotalPrice])	OVER (PARTITION BY YEAR([OrderDate])),'N')	AS AvgrTotalPrice,
		FORMAT(SUM([TotalPrice])	OVER (PARTITION BY YEAR([OrderDate])),'N')  AS SumTotalPrice,
		COUNT([OrderId])			OVER (PARTITION BY YEAR([OrderDate]))		AS CountOrder,
		COUNT_BIG([OrderId])		OVER (PARTITION BY YEAR([OrderDate]))		AS CountBOrder
FROM [dbo].[Orders]
WHERE [TotalPrice] != 0
ORDER BY YEAR([OrderDate]);
GO


/* 3.6:, AVG, VAR, VARP, STDEV  , STDEVP : Summary of Monthly fees for the Subscribers (SubscriberID < 1000) */
SELECT DISTINCT [RatePlan],
		FORMAT(AVG([MonthlyFee])    OVER (PARTITION BY [RatePlan]),'N') AS AvgrMonthlyFee,
		FORMAT(VAR([MonthlyFee])    OVER (PARTITION BY [RatePlan]),'N')	AS VarMonthlyFee,
		FORMAT(VARP([MonthlyFee])   OVER (PARTITION BY [RatePlan]),'N')	AS VarPMonthlyFee,
		FORMAT(STDEV([MonthlyFee])  OVER (PARTITION BY [RatePlan]),'N')	AS StdevMonthlyFee,
		FORMAT(STDEVP([MonthlyFee]) OVER (PARTITION BY [RatePlan]),'N') AS StdevPMonthlyFee
FROM [dbo].[Subscribers]
WHERE [SubscriberId] < 10000;
GO


/* 3.7: FIRST_VALUE: Comparaison of the Total Price of the orders per month compared to the first year*/
WITH CTE_SumPerMonth (OrderYear, OrderMonth, OrderMonthAbbr, OrderSumTotalPice)
AS
(
	SELECT  c.[Year],
			c.[Month],
			c.[MonthAbbr],
			SUM(o.TotalPrice)  
	FROM [dbo].[Orders] o 
	INNER JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date]
	WHERE c.[Year] IN (2013, 2014, 2015)
	GROUP BY    c.[Year], 
				c.[Month],
				c.[MonthAbbr]
)
SELECT	OrderYear,
		OrderMonthAbbr,
		OrderSumTotalPice,
		FIRST_VALUE(OrderSumTotalPice) OVER(PARTITION BY OrderMonth ORDER BY OrderYear) AS FirstValue,
		OrderSumTotalPice - FIRST_VALUE(OrderSumTotalPice) OVER(PARTITION BY OrderMonth ORDER BY OrderYear) AS GapWithFirstValue
FROM CTE_SumPerMonth
ORDER BY OrderMonth, 
		 OrderYear;
GO


/* 3.8: Comparaison of the numbers of new subscribers in 2006 compared to previous years (2003-2005)*/
WITH CTE_NbSubsPerYEar (SubsYear, SubsRatePlan, SubsNum)
AS
(
  SELECT c.[Year], 
		 s.[RatePlan], 
		 count(s.[SubscriberId]) 
  FROM [dbo].[Subscribers] s 
  INNER JOIN [dbo].[Calendar] c on s.[StartDate] = c.[Date]
  WHERE c.[Year] IN (2003, 2004, 2005, 2006)
  GROUP BY	c.[Year],  
			s.[RatePlan]
)
SELECT	SubsYear, 
		SubsRatePlan, 
		SubsNum,
		LAST_VALUE(SubsNum) OVER (PARTITION BY SubsYear ORDER BY SubsRatePlan RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING) AS LastValue,
		LAST_VALUE(SubsNum) OVER (PARTITION BY SubsYear ORDER BY SubsRatePlan RANGE BETWEEN CURRENT ROW AND UNBOUNDED FOLLOWING)-SubsNum AS GapWithLastValue
FROM CTE_NbSubsPerYEar
ORDER BY SubsYear,
		 SubsRatePlan;
GO


/* 3.9:LAG and LEAD:  Display the Sum Total Price of the top 10 best seller products in each group and the amount of the previous and the next products*/
WITH CTE_BestPdt (GroupName, ProductId, SumTotalPrice, RankN)
AS
(
	SELECT	p.[GroupName], 
			o.[ProductId], 
			SUM(o.[TotalPrice]), 
			ROW_NUMBER() OVER (PARTITION BY p.[GroupName] ORDER BY SUM(o.[TotalPrice]) DESC)
	FROM [dbo].[OrderLines] o 
	INNER JOIN [dbo].[Products] p on p.[ProductId] = o.[ProductId]
	WHERE p.[GroupName] NOT IN ('#N/A', 'FREEBIE')
	GROUP BY p.[GroupName], o.[ProductId]
)
SELECT	GroupName, 
		ProductId, 
		SumTotalPrice, 
		LAG(SumTotalPrice) OVER(PARTITION BY GroupName ORDER BY  SumTotalPrice DESC) as PrevSumTotalPrice,
		LEAD(SumTotalPrice) OVER(PARTITION BY GroupName ORDER BY SumTotalPrice DESC) as NextSumTotalPrice
FROM CTE_BestPdt 
WHERE RankN <= 10
ORDER BY GroupName, 
		 SumTotalPrice desc;
GO


/* 3:10: Display of Percent relative rank and the cumulative distributuion of the county population of states NV and WY*/
SELECT [Stab], 
	   [County], 
	   SUM([TotPop]) AS SumPop,
	   FORMAT(PERCENT_RANK() OVER ( PARTITION BY [Stab] ORDER BY  SUM([TotPop]) ),'N') AS PercentRelativeRank,
	   FORMAT(CUME_DIST()    OVER ( PARTITION BY [Stab] ORDER BY  SUM([TotPop]) ),'N') AS CumulDistib
FROM [dbo].[ZipCensus]
WHERE [Stab] IN ('NV','WY') 
  AND [County] IS NOT NULL
GROUP BY [Stab], 
		 [County];
GO


 /*3.11: Display Pecentile 0.5 (Continuous and discrete) for every orders per year and per month  */
SELECT DISTINCT c.[Year], 
	   c.[Month],
	   c.[MonthAbbr],
	   PERCENTILE_CONT (0.5) WITHIN GROUP ( ORDER BY o.[TotalPrice] ) OVER ( PARTITION BY c.[Year], c.[Month] ) as PercentileCont,
	   PERCENTILE_DISC (0.5) WITHIN GROUP ( ORDER BY o.[TotalPrice] ) OVER ( PARTITION BY c.[Year], c.[Month] ) as PercentileDisc
FROM [dbo].[Orders] o
INNER JOIN [dbo].[Calendar] c on c.[Date] = o.[OrderDate]
ORDER BY c.[Year], 
		 c.[Month];
GO





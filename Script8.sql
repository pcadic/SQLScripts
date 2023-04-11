USE [SQLBook]
GO

/* 1 SAMPLING TESTS */

/* 1.1 Random Sampling from a small table with NEWID()				*/
/* Select top 10% of Campaigns rows randomly ordered with NEWID()	*/
SELECT  TOP 10 PERCENT
		NEWID() AS [GUID],
		* 
FROM [dbo].[Campaigns]
ORDER BY [GUID];
GO


/* 1.2 Random sampling from a large table with BINARY_CHECKSUM			*/
/* Select randomly around 10% of subscribers using BINARY_CHECKSUM()	*/
SELECT * 
FROM [dbo].[Subscribers]
WHERE (ABS(CAST((BINARY_CHECKSUM(*) * RAND()) as int)) % 100) < 10;
GO

/* 1.3 Repeated Random Sample													*/
/* Select 10% or products row using a repeated random sample with ROW_NUMBER()	*/
WITH CTE_RN_Products
AS
(
	SELECT  ROW_NUMBER() OVER (ORDER BY [ProductId]) AS [RowNumber],
			*
	FROM [dbo].[Products]
)
SELECT *
FROM CTE_RN_Products
WHERE (([RowNumber] * 79 + 19) % 100) < 10;
GO

/* 1.4 Proportional Stratified Sample						*/
/* See Excel tab 1.4 Stratified sampling					*/
/* Pre-analysis : Percentage of Products per GroupName		*/
SELECT  a.*, b.*, 
		FORMAT(a.[TotalGroupProducts]*1.0/b.[TotalProducts],'N2') AS [PtGroupName]
FROM
(
	SELECT  [GroupName], 
			COUNT(*) AS [TotalGroupProducts] 
	FROM [dbo].[Products]
	GROUP BY [GroupName]
) a
CROSS JOIN
(
	SELECT COUNT(*) AS [TotalProducts] 
	FROM [dbo].[Products]
)b
ORDER BY [PtGroupName];

/* Pick 1 product from every group of 100 products, ordered by GroupName */
--I could have written [RowNumber] % 100 = 3 but I wanted to avoid
--the selection of the GroupName #N/A 
WITH CTE_OrderedProduct
AS
(
	SELECT  ROW_NUMBER() OVER (ORDER BY [GroupName]) as [RowNumber], 
			*
	FROM [dbo].[Products]
)
SELECT * 
FROM CTE_OrderedProduct
WHERE [RowNumber] % 100 = 3
ORDER BY [GroupName];
GO


/* 1.5 Balanced Sample																	*/
/* See Excel tab 1.5 Balanced sampling Data												*/ 
/* Pre-analysis : Orders placed in 2015 for more than $1000 during weekdens or weekdays */
--It seems that the orders with the highest Total Price have been placed during the Weekend
--Are they just 3 outliers? 
--Do the highest orders are mainly placed during weekdays ?
SELECT 	[OrderId], [OrderDate], [TotalPrice],
		IIF(c.[DOWint] = 1 OR c.[DOWint] = 7,  [TotalPrice], NULL) AS [Weekend],
		IIF(c.[DOWint] = 1 OR c.[DOWint] = 7,  NULL, [TotalPrice]) AS [NotWeekend]
FROM [dbo].[Orders] o
JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date]
AND YEAR([OrderDate]) = '2015'
AND [TotalPrice] > 1000
ORDER BY [TotalPrice] DESC;

--158 orders placed during weekdays versus 61 during the weekend. Cutoff at 50.
--The random balanced sample still shows that the orders with the highest Total Price have been placed during the Weekend
WITH CTE_IsWeekend
AS
(
	SELECT ROW_NUMBER() OVER (PARTITION BY [IsWeekend] ORDER BY NEWID()) AS [RN_IsWeekend],
			*
	FROM
		(
			SELECT 	[OrderId], [OrderDate], [TotalPrice],
					IIF(c.[DOWint] = 1 OR c.[DOWint] = 7,  1, 0) AS [IsWeekend]
			FROM [dbo].[Orders] o
			JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date]
			AND YEAR([OrderDate]) = '2015'
			AND [TotalPrice] > 1000
		) a
) 
SELECT [OrderId], [OrderDate], [TotalPrice],
		IIF([IsWeekend] = 1, [TotalPrice], NULL) AS [Weekend],
		IIF([IsWeekend] = 0, [TotalPrice], NULL) AS [NotWeekend]
FROM CTE_IsWeekend
WHERE [RN_IsWeekend] <= 50;
GO


/* 1 SAMPLING and DATA MODEL	*/

/* Analyse the Total Price of orders placed by women in 2014 compared to 2015 */
/* Model with no dimensions		*/
/* Model set is year 2014		*/
/* Score set is year 2015		*/
SELECT	YEAR(o.[OrderDate]) AS [Year], 
		AVG(o.[TotalPrice]) AS [Average Total Price F]
FROM [dbo].[Orders] o 
JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
 AND c.[Gender] = 'F'
GROUP BY YEAR(o.[OrderDate]);
GO

/* Dimension : State */
--State has no incidence on the sales
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT * 
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT [State], AVG([TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2014'
	GROUP BY [State]
)
SELECT AVG(ctscore.[TotalPrice]) AS [Avg Score TotalPrice], 
	   AVG(COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg)) AS [Avg Model TotalPrice]
FROM CTE_ScoreSet ctscore
LEFT JOIN CTE_ModelSet ctmodel ON ctscore.[State] = ctmodel.[State];
GO


/* Dimension : ZipCode */
--Better but not close
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT * 
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT [ZipCode], AVG([TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2014'
	GROUP BY [ZipCode]
)
SELECT AVG(ctscore.[TotalPrice]) AS [Avg Score TotalPrice], 
	   AVG(COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg)) AS [Avg Model TotalPrice]
FROM CTE_ScoreSet ctscore
LEFT JOIN CTE_ModelSet ctmodel ON ctscore.[ZipCode] = ctmodel.[ZipCode];
GO


/* Dimension : Payment Type */
--Better but not close
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT * 
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT [PaymentType], AVG([TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data
	WHERE YEAR([OrderDate]) = '2014'
	GROUP BY [PaymentType]
)
SELECT AVG(ctscore.[TotalPrice]) AS [Avg Score TotalPrice], 
	   AVG(COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg)) AS [Avg Model TotalPrice]
FROM CTE_ScoreSet ctscore
LEFT JOIN CTE_ModelSet ctmodel ON ctscore.[PaymentType] = ctmodel.[PaymentType];
GO


/* Dimension : Campaign Channel */
--Better but not close
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT d.*, c.[Channel] 
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT c.[Channel], AVG(d.[TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR(d.[OrderDate]) = '2014'
	GROUP BY c.[Channel]
)
SELECT AVG(ctscore.[TotalPrice]) AS [Avg Score TotalPrice], 
	   AVG(COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg)) AS [Avg Model TotalPrice]
FROM CTE_ScoreSet ctscore
LEFT JOIN CTE_ModelSet ctmodel ON ctscore.[Channel] = ctmodel.[Channel];
GO


/* Dimension : Campaign Channel and Payment Type */
-- Based on the Lesson 
-- Best Dimensions so far
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT d.*, c.[Channel] 
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT c.[Channel], d.[PaymentType], AVG(d.[TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR(d.[OrderDate]) = '2014'
	GROUP BY c.[Channel], d.[PaymentType]
)
SELECT AVG(ctscore.[TotalPrice]) AS [Avg Score TotalPrice], 
	   AVG(COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg)) AS [Avg Model TotalPrice]
FROM CTE_ScoreSet ctscore
LEFT JOIN CTE_ModelSet ctmodel 
	ON (ctscore.[Channel] = ctmodel.[Channel] AND
		ctscore.[PaymentType] = ctmodel.[PaymentType]);
GO


/* Assessing Broader context */
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE c.[Gender] = 'F'
)
SELECT
   YEAR([OrderDate]) AS [Year], 
   AVG([TotalPrice]) AS [Average Total Price]
FROM CTE_Data
GROUP BY YEAR([OrderDate])
ORDER BY [Year];
GO


/* Evaluating the Model Using a Value Chart (for Dimensions Campaign Channel and Payment Type) */
DECLARE @FallBack2014Avg FLOAT = (SELECT AVG([TotalPrice]) 
									FROM [Orders] o
									JOIN [Customers] c ON o.[CustomerId] = c.[CustomerId] 
									WHERE YEAR([OrderDate]) = 2014
										AND c.[Gender] = 'F');
WITH CTE_Data
AS
(
	SELECT o.*
	FROM [dbo].[Orders] o 
	JOIN [dbo].[Customers] c ON o.[CustomerId] = c.[CustomerId]
	WHERE YEAR(o.[OrderDate]) IN ('2014','2015')
	 AND c.[Gender] = 'F'
),
CTE_ScoreSet
AS
(
	SELECT d.*, c.[Channel] 
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR([OrderDate]) = '2015'
),
CTE_ModelSet
AS
(
	SELECT c.[Channel], d.[PaymentType], AVG(d.[TotalPrice]) AS [Average TotalPrice 2014 F]
	FROM CTE_Data d
	JOIN [dbo].[Campaigns] c ON c.[CampaignId] = d.[CampaignId]
	WHERE YEAR(d.[OrderDate]) = '2014'
	GROUP BY c.[Channel], d.[PaymentType]
)
SELECT b.[Decile],
		AVG(b.[Model TotalPrice]) AS [Average Model TotalPrice],
		AVG(b.[Score TotalPrice]) AS [Average Score TotalPrice]
		FROM 
			(
				SELECT a.*, NTILE(10) OVER (ORDER BY a.[Model TotalPrice] DESC) AS [Decile]
				FROM (
						SELECT ctscore.[TotalPrice] AS [Score TotalPrice], 
							   COALESCE(ctmodel.[Average TotalPrice 2014 F], @FallBack2014Avg) AS [Model TotalPrice]
						FROM CTE_ScoreSet ctscore
						LEFT JOIN CTE_ModelSet ctmodel 
							ON (ctscore.[Channel] = ctmodel.[Channel] AND
								ctscore.[PaymentType] = ctmodel.[PaymentType])
					) a
			) b 
GROUP BY b.[Decile]
ORDER BY b.[Decile];
GO
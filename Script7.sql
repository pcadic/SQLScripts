USE [SQLBook]
GO


/* 6.1																							*/
/* Probability and Odds for clients to use an Overseas Card (OC) as PaymentType (Orders table)	*/
/* '??' taken into account as other payment, but unknown										*/
/* No Graph																						*/
WITH CTE_TotalOrders 
AS
(
	SELECT COUNT([OrderId]) AS [Total Orders]
	FROM [dbo].[Orders] 
),
CTE_OrdersPaidByOC
AS
(
	SELECT COUNT([OrderId]) AS [OC Orders]
	FROM [dbo].[Orders]
	WHERE [PaymentType] = 'OC'
),
CTE_Proba
AS
(
	SELECT c2.[OC Orders]*1.0/c1.[Total Orders] AS [POC]
	FROM CTE_TotalOrders  c1, CTE_OrdersPaidByOC c2
)
SELECT FORMAT([POC],'N2') AS [Probability of OC Payment],
	   FORMAT([POC]/(1-[POC]),'N2') AS [Odds of OC Payment]
FROM CTE_Proba; 
GO


/* 6.2																							*/
/* Probability and Odds for clients to use an Overseas Card or Master Card						*/
/* '??' taken into account as other payment, but unknown										*/
/* No Graph																						*/
WITH CTE_TotalOrders 
AS
(
	SELECT COUNT([OrderId]) AS [Total Orders]
	FROM [dbo].[Orders] 
),
CTE_OrdersPaidByOCMC
AS
(
	SELECT COUNT([OrderId]) AS [OCMC Orders]
	FROM [dbo].[Orders]
	WHERE [PaymentType] IN ('OC','MC')
),
CTE_Proba
AS
(
	SELECT c2.[OCMC Orders]*1.0/c1.[Total Orders] AS [POCMC]
	FROM CTE_TotalOrders  c1, CTE_OrdersPaidByOCMC c2
)
SELECT FORMAT([POCMC],'N2') AS [Probability of OC or MC Payment],
	   FORMAT([POCMC]/(1-[POCMC]),'N2') AS [Odds of OC or MC Payment]
FROM CTE_Proba; 
GO

 
/* 6.3																							 */
/* Probability and Odds for clients to use a Debit card as opposed to a credit card (MC, VI, AE) */						
/* No Graph																						 */
WITH CTE_TotalOrders 
AS
(
	SELECT COUNT([OrderId]) AS [Total Orders]
	FROM [dbo].[Orders] 
	WHERE [PaymentType] in ('DB', 'MC', 'VI', 'AE')
),
CTE_OrdersPaidByDB
AS
(
	SELECT COUNT([OrderId]) AS [DB Orders]
	FROM [dbo].[Orders]
	WHERE [PaymentType] = 'DB'
),
CTE_Proba
AS
(
	SELECT c2.[DB Orders]*1.0/c1.[Total Orders] AS [PDB]
	FROM CTE_TotalOrders  c1, CTE_OrdersPaidByDB c2
)
SELECT FORMAT([PDB],'N2') AS [Probability of OC or MC Payment],
	   FORMAT([PDB]/(1-[PDB]),'N2') AS [Odds of OC or MC Payment]
FROM CTE_Proba; 
GO


/* 6.4																							 */
/* Probability for clients to use any payment cards												 */
WITH CTE_TotalOrders 
AS
(
	SELECT COUNT([OrderId]) AS [Total Orders]
	FROM [dbo].[Orders]
)
SELECT  a.*, cte.*, 
		FORMAT(a.[NbPaymentType]*1.0/cte.[Total Orders],'N4') AS [Probability Card]
FROM 
	(
		SELECT [PaymentType], COUNT([OrderId]) AS [NbPaymentType]
		FROM [dbo].[Orders] 
		GROUP BY [PaymentType]
	) a
CROSS JOIN CTE_TotalOrders cte;
GO


/* 6.5 :												*/
/* Probability for Gender of Customers					*/
/* Population is all customers whose gender is known	*/
SELECT gt.*, t.*, 
	  FORMAT(gt.[Total Gender]*1.0/t.[Total],'N2') AS [Probability per Gender]
FROM
(
	  SELECT [Gender], 
			 COUNT(*) AS [Total Gender]
	  FROM [dbo].[Customers]
	  WHERE [Gender] in ('M','F')
	  GROUP BY [Gender]
  ) gt
CROSS JOIN
  (
  	  SELECT COUNT(*) AS [Total]
	  FROM [dbo].[Customers]
	  WHERE [Gender] in ('M','F')
  ) t;
GO


/* 6.6								*/
/* Probability of Day of the orders */
WITH CTE_OrderDay
AS
  (
	  SELECT o.[OrderId], 
			 c.[DOW], c.[DOWint]
	  FROM [dbo].[Orders] o
	  JOIN [dbo].[Calendar] c ON o.[OrderDate] = c.[Date]
  )
SELECT a.*, b.*, 
	   FORMAT(a.[Total Order per Day]*1.0/b.[Total Order],'N2') AS [Probability Order Day]
FROM 
	(
	 SELECT cte.[DOW], cte.[DOWint], 
			COUNT(*) AS [Total Order per Day]
	 FROM CTE_OrderDay cte
	 GROUP BY cte.[DOW], cte.[DOWint]
	) a
CROSS JOIN
	(
		SELECT COUNT(*) AS [Total Order] FROM CTE_OrderDay
	) b
ORDER BY a.[DOWint];
GO


 /* 6.7														*/
 /* Probability of Campaign channels that trigger an order	*/
WITH CTE_CampaignOrder
AS
 (
	SELECT o.[OrderId], c.[Channel]
	FROM [dbo].[Orders] o
	INNER JOIN [dbo].[Campaigns] c ON o.[CampaignId] = c.[CampaignId]
 )
SELECT a.*, b.*, 
	  FORMAT(a.[Total Channel Order]*1.0/b.[Total Order],'N3')  AS [Probability Campaign Channel ]
FROM
	(
		SELECT cte.[Channel], 
			   COUNT(*) AS [Total Channel Order]
		FROM CTE_CampaignOrder cte
		GROUP BY cte.[Channel]
	) a
 CROSS JOIN
	(
		SELECT COUNT(*) AS [Total Order] FROM CTE_CampaignOrder 
	) b;
GO


/* 6.8																	*/
/* Probability that book products are sold according to customer gender */
SELECT 	a.[ProductId],
		a.[GroupName],
		SUM(a.[Female])									AS [Total Female], 
		SUM(a.[Male])									AS [Total Male], 
		SUM([MF])										AS [Total MF],
		FORMAT(SUM(a.[Female])*1.0/ SUM([MF]),'N2')		AS [Proba Female],
		FORMAT(SUM(a.Male)*1.0/ SUM([MF]),'N2')			AS [Proba Male]
FROM
(
	SELECT c.[Gender], 
		IIF(c.[Gender] = 'F',1,0)						AS [Female],
		IIF(c.[Gender] = 'M',1,0)						AS [Male],
		IIF(c.[Gender] = 'M' OR c.[Gender] = 'F',1,0)	AS [MF],
		p.[ProductId],
		p.[GroupName]
	FROM [dbo].[Products] p
	JOIN [dbo].[OrderLines] ol ON ol.[ProductId] = P.[ProductId]
	JOIN [dbo].[Orders] o ON o.[OrderId]=ol.[OrderId]
	JOIN [dbo].[Customers] c on c.CustomerId = o.CustomerId
) a
WHERE [MF] != 0 
GROUP BY [ProductId],
		 [GroupName]
HAVING [GroupName] = 'BOOK'
ORDER BY [Proba Male] DESC;
GO


/* 6.9									*/
/* Probability of poplution per State	*/
SELECT  st.*, ct.*, 
		FORMAT(st.[Total State Population]*1.0/ct.[Total Country Population],'N3') AS [Proba State Population]
FROM
  (
	 SELECT [Stab], 
			SUM([TotPop]) AS [Total State Population]
	 FROM [dbo].[ZipCensus]
	 GROUP BY [Stab]
  ) st
CROSS JOIN
  (
  	 SELECT SUM([TotPop]) AS [Total Country Population]
	 FROM [dbo].[ZipCensus]
  ) ct;
GO


/* 6.10																							*/
/* Probability of commuting people for Workers 16 years and over (Pacific Ocean States scope)	*/
WITH CTE_WestCommunting
AS
(
	SELECT  [Stab]				AS [State], 
			SUM([Worker16])		AS [TWorker16], 
			SUM([DriveAlone])	AS [TDriveAlone], 
			SUM([Carpool])		AS [TCarpool], 
			SUM([PublicTrans])	AS [TPublicTrans], 
			SUM([WalkToWork])	AS [TWalkToWork], 
			SUM([OtherCommute])	AS [TOtherCommute], 
			SUM([WorkAtHome])	AS [TWorkAtHome]
	FROM [dbo].[ZipCensus]
	WHERE [Stab] IN ('WA','OR','CA','AK')
	GROUP BY [Stab]
)
SELECT	[State],
		FORMAT([TDriveAlone]*1.0/[TWorker16],'N2')		AS [Prob. DriveAlone],
		FORMAT([TCarpool]*1.0/[TWorker16],'N2')			AS [Prob. Carpool], 
		FORMAT([TPublicTrans]*1.0/[TWorker16],'N2')		AS [Prob. PublicTrans], 
		FORMAT([TWalkToWork]*1.0/[TWorker16],'N2')		AS [Prob. WalkToWork], 
		FORMAT([TOtherCommute]*1.0/[TWorker16],'N2')	AS [Prob. OtherCommute], 
		FORMAT([TWorkAtHome]*1.0/[TWorker16],'N2')		AS [Prob. WorkAtHome]
FROM CTE_WestCommunting;
GO


/* 6.11														*/
/* Probability of orders according to range of Total Price	*/
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
SELECT cte.*, a.*,
	   FORMAT(cte.[Number of Orders]*1.0/a.[Total Order],'N3') AS [Prob. Price Range]
FROM
(
	SELECT [Price Category],
			COUNT(OrderId) AS [Number of Orders]
	FROM CTE_OrderPriceCategory
	GROUP BY [Price Category]
) cte
CROSS JOIN
(
	SELECT COUNT([OrderId]) AS [Total Order] FROM [dbo].[Orders]
) a
ORDER BY cte.[Price Category]
GO


/* 6.12																*/
/* Probablity of Foreign Born people in 3 counties of Connecticut	*/
SELECT [Stab], [ZipName], [County], 
	   [FBMinusSea], [TotPop],
	   FORMAT([FBMinusSea]*1.0/[TotPop],'N2') AS [Prob. Foreign Born]
FROM [dbo].[ZipCensus]
WHERE [zcta5] IN ('06902', '06118', '06762')
ORDER BY [Prob. Foreign Born];
GO


/* 6.13																*/
/* Probablity of the Age repartition : before 20, 20 to 64, over 65	*/
WITH CTE_DEAge
AS
(
	SELECT [Stab], SUM([TotPop]) AS [DE TotPop],
		   SUM([Under18]+([Over18]-[Over21]))	AS [0-20], 
		   SUM([Over21]-[Over65])				AS [21-64], 
		   SUM([Over65])						AS [65-] 
	FROM [dbo].[ZipCensus]
	WHERE [TotPop] != 0 AND Stab = 'DE'
	GROUP BY [Stab]
)
SELECT cte.*,
	   FORMAT(cte.[0-20]*1.0/[DE TotPop],'N2')	AS [Proba 0-20],
	   FORMAT(cte.[21-64]*1.0/[DE TotPop],'N2')	AS [Proba 21-64],
	   FORMAT(cte.[65-]*1.0/[DE TotPop],'N2')	AS [Proba 65-]
FROM CTE_DEAge cte
GO
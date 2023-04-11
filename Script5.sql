USE [SQLBook]
GO

/* 4.1a : Scatter Plot : Showing the location */
/* Display the coordinates of counties where 50% of Owner-occupied units is worth more than 1 million */
SELECT	[Stab] AS State, 
	[zcta5], 
	[ZIPName], 
	[County], 
	[Longitude], 
	[Latitude]
FROM	[dbo].[ZipCensus]
WHERE	[Latitude] BETWEEN 24 AND 50 AND
	[Longitude] BETWEEN -125 AND -65
  AND	([HvalOverMillion]*1.0/[OwnerOcc]*100) >= 50 AND [OwnerOcc] !=0;
GO


/* 4.1b : Scatter Plot : Showing the location */
/* Display the  coordinates of counties where we can find the customers */
SELECT	[Stab] AS State, 
	[zcta5], 
	[zipname], 
	[County], 
	[Longitude], 
	[Latitude]
FROM	[dbo].[ZipCensus]
WHERE	[zcta5] IN ( SELECT DISTINCT [ZipCode]
		     FROM [dbo].[Orders]
		   )
AND	[Latitude] BETWEEN 24 AND 50 AND
	[Longitude] BETWEEN -125 AND -65;
GO


/*4.2a : Scatter Plot : Showing the location  */
/* Plot counties whose more than 10% of the population is born outside US */ 
SELECT  [Totpop], 
	[BornOutsideUS], 
	[Longitude],
	IIF ([BornOutsideUS]*1.0/[Totpop] * 100 >= 10 ,[Latitude],0) AS [Born Outside], 
	IIF ([BornOutsideUS]*1.0/[Totpop] * 100 <  10 ,[Latitude],0) AS [Born Inside] 
FROM	[dbo].[ZipCensus]
WHERE	[Latitude] BETWEEN 24 AND 50 AND
	[Longitude] BETWEEN -125 AND -65
	AND [Totpop] != 0
GO


/*4.2b : Scatter Plot : Showing the location  */
/* Plot counties depending on the most used payment type*/
SELECT zc.[Longitude],
       IIF (pt.[PaymentType] = 'VI' ,zc.[Latitude],0) AS [Visa], 
       IIF (pt.[PaymentType] = 'AE' ,zc.[Latitude],0) AS [AmEx],		
       IIF (pt.[PaymentType] = 'MC' ,zc.[Latitude],0) AS [MasterCard], 
       IIF (pt.[PaymentType] = 'DB' ,zc.[Latitude],0) AS [Debit] 
FROM (
	SELECT o.[Zipcode], 
	       o.[PaymentType],
	       COUNT(o.[OrderId]) AS [NbPaymentType],
	       RANK () OVER (PARTITION BY o.[Zipcode] ORDER BY count(o.[OrderId]) DESC) AS [Seq]
	FROM [dbo].[Orders] o
	GROUP BY o.[Zipcode],
		 o.[PaymentType]
	) pt
JOIN [dbo].[ZipCensus] zc ON zc.[zcta5] = pt.[ZipCode]
WHERE pt.[Seq] = 1
  AND pt.[PaymentType] in ('VI','AE','MC','DB');
GO


/*4.3a : Bubble Plot : Show Data by Location & Enabling Data Drill-Down Using 3D Maps */
/* Display the number of distinct customers per location */
WITH CTE_NbCustomer (ZipCode, NbCust)
AS
(
	SELECT  [ZipCode], 
		COUNT(DISTINCT [CustomerId]) 
	FROM [dbo].[Orders] o
	Group BY [ZipCode]
)
SELECT	zc.[Longitude], 
	zc.[Latitude], 
	cte.NbCust
FROM [dbo].[ZipCensus] zc
JOIN CTE_NbCustomer cte ON cte.ZipCode = zc.[zcta5]
WHERE zc.[Latitude] BETWEEN 24 AND 50 AND
      zc.[Longitude] BETWEEN -125 AND -65;
GO


/*4.3b : No Bubble plot : Enabling Data Drill-Down Using 3D Maps */
/* Display the percentage of people that work at home per location*/
SELECT  [Longitude], 
	[Latitude], 
	FORMAT([WorkAtHome]*1.0/[Worker16]*100,'N2') AS [WorkAtHomePct]
FROM [dbo].[ZipCensus]
WHERE [Latitude] BETWEEN 24 AND 50 AND
      [Longitude] BETWEEN -125 AND -65
  AND [Worker16] != 0 AND [WorkAtHome] != 0
ORDER BY [WorkAtHomePct];
GO



/*4.4a : Fine Tune analysis */
/* Display the Maximum total price for an order in 1 county of a state */
WITH CTE_BigOrder
AS
(
	SELECT  [ZipCode], 
		[State], 
		SUM([TotalPrice]) As [SumTotalPrice], 
		ROW_NUMBER () OVER (PARTITION BY [State] ORDER BY SUM([TotalPrice]) DESC) AS [Seq]
	FROM [dbo].[Orders]
	WHERE [State] != ''
	GROUP BY [ZipCode], [State]
)
SELECT	zc.[Longitude], 
	zc.[Latitude], 
	cte.SumTotalPrice,
	CONCAT (zc.[Stab], ': ', FORMAT(cte.SumTotalPrice, 'N')) AS [Info]
FROM [dbo].[ZipCensus] zc 
JOIN CTE_BigOrder cte ON cte.ZipCode = zc.[zcta5]
WHERE [Latitude] BETWEEN 24 AND 50 AND
      [Longitude] BETWEEN -125 AND -65
  AND cte.Seq = 1;
GO


/*4.4b : Fine Tune analysis */
/* Display the Maximum number of Customers in 1 county of a state */
WITH CTE_NbCustomer (ZipCode, State, NbCust, Seq)
AS
(
	SELECT  [ZipCode], 
		[State],
		COUNT(DISTINCT [CustomerId]),
		ROW_NUMBER () OVER (PARTITION BY [State] ORDER BY COUNT(DISTINCT [CustomerId]) DESC)
	FROM [dbo].[Orders]
	WHERE [State] != ''
	GROUP BY [ZipCode],
		 [State]
)
SELECT	zc.[Longitude], 
	zc.[Latitude], 
	cte.[NbCust],
	CONCAT(cte.[State],': ',cte.[NbCust]) AS [Info]
FROM [dbo].[ZipCensus] zc
JOIN CTE_NbCustomer cte ON cte.ZipCode = zc.[zcta5]
WHERE zc.[Latitude] BETWEEN 24 AND 50 AND
      zc.[Longitude] BETWEEN -125 AND -65
AND cte.Seq = 1
AND cte.[State] IN (SELECT DISTINCT [Stab] from [dbo].[ZipCensus])
ORDER BY cte.[State]
GO


/* 4.5a : Georgaphy, Location and XML */
/* Location of county where the Household income less than $10,000 represents more the 50% of Total households */
SELECT	[Stab], [zcta5], [zipname], [County], 
	[Longitude], 
	[Latitude],
	FORMAT([HHInc0]*1.0/[TotHHs]*100, 'N2') AS [PctHHInc0],
	CONCAT(
		'<Placemark><name>', [ZIPName], ' (', [zcta5], ')</name>',
		'<description>HHInc0: ', FORMAT(HHInc0*1.0/TotHHs*100, 'N2'), '</description>',
		'<styleUrl>#icon-1899-0288D1</styleUrl>',
		'<Point><coordinates>', [Longitude], ',', [Latitude], ',', 0,
		'</coordinates></Point></Placemark>') AS [Paste into KML file]
FROM	[dbo].[ZipCensus]
WHERE	[Latitude] < 50.0 AND [Longitude] > -125.0
AND	([HHInc0]*1.0/[TotHHs]*100) > 50 AND TotHHs !=0;
GO


/* 4.5b : Georgaphy, Location and XML */
/* Top 10% of number of customers in a county */
WITH CTE_NbCustomer (ZipCode, NbCust, PercentRank)
AS
(
	SELECT  [ZipCode], 
		COUNT(DISTINCT [CustomerId]),
		PERCENT_RANK () OVER (ORDER BY COUNT(DISTINCT [CustomerId]))
	FROM [dbo].[Orders] o
	GROUP BY [ZipCode]
)
SELECT	zc.[Longitude], zc.[Latitude], 
	cte.[NbCust],
	CONCAT(
		'<Placemark><name>', zc.[ZIPName], ' (', zc.[zcta5], ')</name>',
		'<description>Number of Customers: ', cte.[NbCust], '</description>',
		'<styleUrl>#icon-1899-0288D1</styleUrl>',
		'<Point><coordinates>', zc.[Longitude], ',', zc.[Latitude], ',', 0,
		'</coordinates></Point></Placemark>') AS [Paste into KML file]
FROM [dbo].[ZipCensus] zc
JOIN CTE_NbCustomer cte ON cte.ZipCode = zc.[zcta5]
WHERE [Latitude] BETWEEN 24 AND 50 AND
      [Longitude] BETWEEN -125 AND -65
AND cte.PercentRank >= 0.9;
GO


/* 4.6a : Distance between 2 points on a sphere : angle method : No graph*/
/* Distance of each county from the county in the same state where more European born citizen can be found */
DECLARE @EARTH_RADIUS FLOAT = 3957.773;
WITH CTE_MaxEuropeanByCounty
AS
(
	SELECT  z2.[zcta5], z2.[ZipName], z2.[County], z2.[Stab], 
		z2.[Latitude]  * PI() / 180 AS [Latitude Eur Radians], 
		z2.[Longitude] * PI() / 180 AS [Longitude Eur Radians]
	FROM [dbo].[ZipCensus] z2
	JOIN 
	(
		SELECT  [Stab],
			MAX(FBEurope) AS [MaxEuropean]
		FROM [dbo].[ZipCensus]
		GROUP BY [Stab]
	) AS z1 ON z1.Stab = z2.[Stab] AND z2.[FBEurope] = z1.[MaxEuropean]
)
SELECT  z.[Stab], z.[zcta5], z.[County], z.[ZIPName],
	z.[latitude]  * PI() / 180   AS [Latitude], 
	z.[longitude] * PI() / 180   AS [Longitude],
	cte.zcta5, cte.County, cte.ZIPName,
	cte.[Latitude Eur Radians], 
	cte.[Longitude Eur Radians], 
	ACOS(
		SIN(z.[latitude]  * PI() / 180) * 
		SIN([Latitude Eur Radians])
		+
		COS(z.[latitude]  * PI() / 180) * 
		COS([Latitude Eur Radians]) * 
		COS(z.[longitude] * PI() / 180 - [Longitude Eur Radians])
	) * @EARTH_RADIUS AS [Distance]
	FROM [dbo].[ZipCensus] z
	LEFT OUTER JOIN CTE_MaxEuropeanByCounty cte on cte.Stab = z.[Stab]
ORDER BY z.[Stab], [Distance] ASC;
GO



/* 4.6b : Distance between 2 points on a sphere : spadial data type method : No graph*/
/* Distance of each county from the county in the same state where more European born citizen can be found */
DECLARE @SRID_FOOT   INT =   4748;
WITH CTE_MaxEuropeanByCounty
AS
(
	SELECT z2.[zcta5], z2.[ZipName], z2.[County], z2.[Stab],
	geography::Point(z2.[Latitude], z2.[Longitude], @SRID_FOOT) AS [PointRef]
	FROM [dbo].[ZipCensus] z2
	JOIN 
	(
		SELECT  [Stab], 
			MAX(FBEurope) AS [MaxEuropean]
		FROM [dbo].[ZipCensus]
		GROUP BY [Stab]
	) AS z1 ON z1.[Stab] = z2.[Stab] AND z2.[FBEurope] = z1.[MaxEuropean]
)
SELECT	z.[Stab],
	z.[zcta5],
	z.[County],
	z.[ZIPName],
	z.[Latitude], z.[Longitude],
	cte.Stab, cte.zcta5, cte.County, cte.ZIPName,
	cte.PointRef, 
	cte.PointRef.STDistance(geography::Point(z.[Latitude], z.[Longitude], @SRID_FOOT)) / 5280  as [Distance]
FROM [dbo].[ZipCensus] z
LEFT OUTER JOIN CTE_MaxEuropeanByCounty cte on cte.Stab = z.[Stab]
ORDER BY z.[Stab], [Distance] ASC;
GO


/* 4.6c : Finding all objects within a distance : angle method : No graph*/
/* Displaying counties that are less than 100 miles away from the most populated county */
DECLARE @EARTH_RADIUS FLOAT = 3957.773;
DECLARE @DISTANCE_SOUGHT FLOAT = 100.0;
WITH CTE_GeoRadius
AS
(
	SELECT  zc.*, 
		zc.[Latitude]  * PI()/180 as [Latitude Radians],
		zc.[Longitude] * PI()/180 as [Longitude Radians]
	FROM [dbo].[ZipCensus] zc
)
SELECT a.state, a.zcta5, a.ZipName, a.County, a.Stab, a.Longitude, a.latitude, FORMAT(a.Distance,'N2') AS Distance
FROM 
(
	SELECT	c.*,
		ACOS(
			SIN(c.[Latitude Radians]) * 
			SIN(mt.[Latitude Radians])
			+
			COS(c.[Latitude Radians]) * 
			COS(mt.[Latitude Radians]) * 
			COS(c.[Longitude Radians] - mt.[Longitude Radians])
                    ) * @EARTH_RADIUS AS [Distance]
	FROM CTE_GeoRadius c
	CROSS JOIN (SELECT *
		    FROM CTE_GeoRadius 
		    WHERE TotPop = (SELECT MAX([TotPop]) from [dbo].[ZipCensus])
		   ) mt
) a
WHERE [Distance] < @DISTANCE_SOUGHT
ORDER BY [Distance]; 
GO


/* 4.6d : Finding all objects within a distance : angle method : No graph*/
/* Displaying counties that are less than 100 miles away from the most populated county */
DECLARE @SRID_FOOT   INT =   4748;
DECLARE @DISTANCE_SOUGHT FLOAT = 100.0;
WITH CTE_GeoDT
AS
(
	SELECT  zc.*,
		geography::Point(zc.[Latitude], zc.[Longitude], @SRID_FOOT) AS [Point]
	FROM [dbo].[ZipCensus] zc
)
SELECT a.state, a.zcta5, a.ZipName, a.County, a.Stab, a.Longitude, a.latitude, FORMAT(a.Distance,'N2') AS Distance
FROM 
(
	SELECT	c.*,
		c.[Point].STDistance(mt.[Point]) / 5280  as [Distance]
	FROM CTE_GeoDT c
	CROSS JOIN (SELECT *
		    FROM CTE_GeoDT 
		    WHERE TotPop = (SELECT MAX([TotPop]) from [dbo].[ZipCensus])
	  	   ) mt
) a
WHERE [Distance] < @DISTANCE_SOUGHT
ORDER BY [Distance];
GO

USE [SQLBook]
GO


/*5.1 : Function A01087932_GetOrdersWithDayDelays(nbDayDealy int)*/
/* Description : Display the orders whose delay between the date order and the ship date of the last product sent is superior to nbDayDealy (between 0.0 and 1.0)  */
/* Parameters  : nbDayDealy (int) :  Delay in number of days */
/* Call        : SELECT * FROM A01087932_GetOrdersWithDayDelays(10); */
IF object_id(N'A01087932_GetOrdersWithDayDelays', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetOrdersWithDayDelays;
GO

CREATE FUNCTION A01087932_GetOrdersWithDayDelays
(   
    @nbDayDealy int
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT a.[OrderId], 
		   o.[OrderDate],  
		   a.[MaxDate], 
		   DATEDIFF(DAY,o.[OrderDate], a.[MaxDate]) as [Delay]
	FROM 
		(
			SELECT [OrderId], 
				   MAX([ShipDate])  as [MaxDate]
			FROM [dbo].[OrderLines]
			GROUP BY [OrderId]
		) a
	JOIN [dbo].[Orders] o ON o.[OrderId] = a.[OrderId]
	WHERE DATEDIFF(DAY,o.[OrderDate], a.[MaxDate]) >= @nbDayDealy
);
GO

SELECT * FROM dbo.A01087932_GetOrdersWithDayDelays(10) ORDER BY [Delay] DESC;
SELECT * FROM dbo.A01087932_GetOrdersWithDayDelays(100) ORDER BY [Delay] DESC;
GO


/*5.1b : Function A01087932_GetNbOrdersWithDayDelays(nbDayDealy int)*/
/* Description : Display the number of orders whose delay between the date order and the ship date of the last product sent is superior to nbDayDealy (between 0.0 and 1.0)  */
/* Parameters  : nbDayDealy (int) :  Delay in number of days */
/* Call        : SELECT * FROM A01087932_GetNbOrdersWithDayDelays(10); */
IF object_id(N'A01087932_GetNbOrdersWithDayDelays', N'FN') IS NOT NULL
    DROP FUNCTION A01087932_GetNbOrdersWithDayDelays;
GO

CREATE FUNCTION A01087932_GetNbOrdersWithDayDelays
(   
    @nbDayDealy int
)
RETURNS int
AS
BEGIN
	DECLARE @NbOrderWithDayDelays int = 0;
	WITH CTE
	AS
	(
	SELECT a.[OrderId], 
		   DATEDIFF(DAY,a.[OrderDate], a.[MaxDate]) as [Delay]
	FROM 
		(
			SELECT o.[OrderId], 
				   o.[OrderDate], 
				   MAX(ol.[ShipDate])  as [MaxDate]
			FROM [dbo].[Orders] o
			JOIN [dbo].[OrderLines] ol on o.[OrderId] = ol.[OrderId]
			GROUP BY o.[OrderId], o.[OrderDate]
		) a
	)
	SELECT @NbOrderWithDayDelays = COUNT(*)
	FROM CTE
	WHERE [Delay] >= @nbDayDealy;
	RETURN @NbOrderWithDayDelays;
END;
GO

SELECT dbo.A01087932_GetNbOrdersWithDayDelays(10) AS [Number of orders with exceded delay];
SELECT dbo.A01087932_GetNbOrdersWithDayDelays(100) AS [Number of orders with exceded delay];
GO


/*5.2 : Function A01087932_GetTopProducts(nbTop int)*/
/* Description : Display the nbTop best Products */
/* Parameters  : nbTop (int) :  number of top best seller products */
/* Call        : SELECT * FROM A01087932_GetTopProducts(10); */
IF object_id(N'A01087932_GetTopProducts', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetTopProducts;
GO

CREATE FUNCTION A01087932_GetTopProducts
(   
    @nbTop int
)
RETURNS TABLE 
AS
RETURN 
(
SELECT ol.[ProductId], 
	   ol.[TotalNumUnitSold]
FROM
(
	SELECT  [ProductId], 
		    SUM([NumUnits]) AS [TotalNumUnitSold],
			ROW_NUMBER() OVER (ORDER BY SUM([NumUnits]) DESC) AS [TopRank]
	FROM [dbo].[OrderLines]
	GROUP BY [ProductId]
) ol
WHERE ol.[TopRank] <= @nbTop
);
GO

SELECT * FROM dbo.A01087932_GetTopProducts(10);
SELECT * FROM dbo.A01087932_GetTopProducts(15);
GO


/*5.3 : Function A01087932_GetCountiesNoENSPLanguage(nbLimit float)*/
/* Description : Display the counties whose number of people that do not speak both English and Spanish is higher than the given parameter */
/* Parameters  : nbLimit (float) :  Limit for the proportion of non EN-SP speakers */
/* Call        : SELECT * FROM A01087932_GetCountiesNoENSPLanguage(2.0/3); */
IF object_id(N'A01087932_GetCountiesNoENSPLanguage', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCountiesNoENSPLanguage;
GO

CREATE FUNCTION A01087932_GetCountiesNoENSPLanguage
(   
    @nbLimit float
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT [Stab] , 
		   [County], 
		   [TotPop], 
		   [Over5], 
		   ([OthLang]-[Spanish])*1.0/[Over5] AS [NonENSP]
	FROM [dbo].[ZipCensus]
	WHERE [Over5] != 0
	  AND ([OthLang]-[Spanish])*1.0/[Over5] >= @nbLimit
);
GO

SELECT * FROM dbo.A01087932_GetCountiesNoENSPLanguage(0.66) ORDER BY NonENSP DESC ;
SELECT * FROM dbo.A01087932_GetCountiesNoENSPLanguage(2.0/3) ORDER BY NonENSP DESC ;
GO


/*5.4 : Function A01087932_GetCountiesCloseLandArea(Area float, nbCounties int)*/
/* Description : Returns a predifined number of Counties that have an area closed to the area given in the parameter */
/* Parameters  : Area (float) :  Area in square per mile */
/*             : nbCounties (int) :  Maximum number of Counties to return*/
/* Call        : SELECT * FROM A01087932_GetCountiesCLoseLandArea(34.02);*/
IF object_id(N'A01087932_GetCountiesCloseLandArea', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCountiesCloseLandArea;
GO

CREATE FUNCTION A01087932_GetCountiesCloseLandArea
(   
    @Area float = 0.0,
	@nbCounties int = 10
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT a.[Stab], 
		   a.[County], 
		   a.[AreaSQMI]
	FROM
		(
		SELECT [Stab],
			   [County], 
			   [AreaSQMI], 
			   ABS([AreaSQMI]-@Area) AS [DiffArea],
			   ROW_NUMBER()  OVER ( ORDER BY ABS([AreaSQMI]-@Area) ASC) AS [Seq]
		FROM [dbo].[ZipCensus]
		) a
	WHERE a.[Seq] <= @nbCounties
);
GO

SELECT * FROM A01087932_GetCountiesCloseLandArea(34.02, 10) ORDER BY [AreaSQMI];
SELECT * FROM A01087932_GetCountiesCloseLandArea(154.54, 20) ORDER BY [AreaSQMI];
GO


/*5.5 : Function A01087932_GetCustomerMinMaxPurchase(MinPurchase money, MaxPurchase money)*/
/* Description : Returns the list of Customers that have placed an order whose amount is between MinPurchase and MaxPurchase */
/* Parameters  : MinPurchase (money) :  Lowest purchase */
/*			   : MaxPurchase (money) :  Highest purchase */
/* Call        : SELECT * FROM A01087932_GetCustomerMinMaxPurchase(19.63, 39.95);*/
IF object_id(N'A01087932_GetCustomerMinMaxPurchase', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCustomerMinMaxPurchase;
GO

CREATE FUNCTION A01087932_GetCustomerMinMaxPurchase
(   
    @MinPurchase money,
	@MaxPurchase money
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT o.[CustomerId], 
		   o.[OrderId],  
		   o.[TotalPrice], 
		   o.[OrderDate]
	FROM [dbo].[Orders] o
	WHERE o.[TotalPrice] BETWEEN @MinPurchase AND @MaxPurchase
	AND o.[CustomerId] != 0
);
GO

SELECT * FROM dbo.A01087932_GetCustomerMinMaxPurchase(19.63, 39.95) ORDER BY [CustomerId], [OrderDate];
SELECT * FROM dbo.A01087932_GetCustomerMinMaxPurchase(5678.99, 9876.54) ORDER BY [CustomerId], [OrderDate];
GO


/*5.6 : Function A01087932_GetCountiesNamedLike(NameCounty varchar)*/
/* Description : Returns the list of Counties whose name contains the given parameter */
/* Parameters  : NameCounty (varchar) : Text contained in the County name */
/* Call        : SELECT * FROM A01087932_GetCountiesNamedLike('South');*/
IF object_id(N'A01087932_GetCountiesNamedLike', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCountiesNamedLike;
GO

CREATE FUNCTION A01087932_GetCountiesNamedLike
(   
    @NameCounty varchar(255)
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT [state], 
		   [zcta5], 
		   [ZIPName], 
		   [County], 
		   [Stab], [TotPop]
	FROM [dbo].[ZipCensus]
	WHERE UPPER([County]) LIKE UPPER('%'+@NameCounty+'%')
);
GO

SELECT * FROM dbo. A01087932_GetCountiesNamedLike('South') ORDER BY [County];
SELECT * FROM dbo. A01087932_GetCountiesNamedLike('New') ORDER BY [County];
GO


/*5.7 : Function A01087932_GetActiveSubscribersAtCutoffDate(cutoffDate Date)*/
/* Description : Returns the list of active subscribers at a cutoff date */
/* Parameters  : cutoffDate (date) : Cutoff date */
/* Call        : SELECT * FROM A01087932_GetActiveSubscribersAtCutofDate('2015-10-12');*/
IF object_id(N'A01087932_GetActiveSubscribersAtCutofDate', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetActiveSubscribersAtCutoffDate;
GO

CREATE FUNCTION A01087932_GetActiveSubscribersAtCutoffDate
(   
    @cutoffDate date
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT *
	FROM [dbo].[Subscribers]
	WHERE ([StopDate] is NULL AND [StartDate] <= @cutoffDate) OR
		  ([StopDate] IS NOT NULL AND [StopDate] >= @cutoffDate AND [StartDate] <= @cutoffDate)
);
GO

SELECT * FROM A01087932_GetActiveSubscribersAtCutoffDate('1999-10-12') ORDER BY [StartDate];
SELECT * FROM A01087932_GetActiveSubscribersAtCutoffDate('2005-10-12') ORDER BY [StartDate];
GO


/*5.8 : Function A01087932_GetCountiesAroundAPoint(Latitude float, Longitude float, Radius int)*/
/* Description : Returns the Counties that are around a certain distance (radius) from a Point(Latitude,Longitude) */
/* Parameters  : Latitude (float)  : Latitude*/
/*			   : Longitude (float) : Longitude*/
/*			   : Radius (int) : Radius - distance from the point*/
/* Call        : SELECT * FROM A01087932_GetCountiesAroundAPoint(39.8, -98.6, 10);*/
IF object_id(N'A01087932_GetCountiesAroundAPoint', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCountiesAroundAPoint;
GO

CREATE FUNCTION A01087932_GetCountiesAroundAPoint
(   
    @LatitudeP  float,
	@LongitudeP float, 
	@Radius		int 
)
RETURNS @retFindResultSet TABLE   
(  
    [Stab] varchar(255),  
    [zcta5] varchar(255),  
    [ZipName] varchar(255),  
    [County] varchar(255), 
    [Longitude] float,  
	[Latitude] float,
	[Distance] numeric 
)  
AS
BEGIN
	DECLARE @SRID_FOOT   INT =   4748;
	DECLARE @CENTER_POINT_F geography = geography::Point(@LatitudeP, @LongitudeP, @SRID_FOOT);
	
	WITH CTE_GeoDT
	AS
	(
	SELECT 
		zc.*,
		geography::Point(zc.[Latitude], zc.[Longitude], @SRID_FOOT) AS [Point]
	FROM [dbo].[ZipCensus] zc
	)
	
	INSERT @retFindResultSet  
	SELECT a.[Stab], 
		   a.[zcta5], 
		   a.[ZipName], 
		   a.[County], 
		   a.[Longitude], 
		   a.[Latitude], 
		   FORMAT(a.[Distance],'N2') AS [Distance]
	FROM 
	(
		SELECT	c.*,
				c.[Point].STDistance(@CENTER_POINT_F) / 5280  as [Distance]
		FROM CTE_GeoDT c
	) a
	WHERE a.[Distance] < @Radius;
   RETURN  
END;
GO

SELECT * FROM A01087932_GetCountiesAroundAPoint(37.25,-92.51,25) ORDER BY [Distance];
SELECT * FROM A01087932_GetCountiesAroundAPoint(37.25,-92.51,100) ORDER BY [Distance];
GO


/*5.9 : Function A01087932_GetStateInfo(StabP varchar )*/
/* Description : Returns some demographic information about a State */
/* Parameters  : StabP (varchar) : State abbreviation */
/* Call        : SELECT * FROM A01087932_GetStateInfo('NY');*/
IF object_id(N'A01087932_GetStateInfo', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetStateInfo;
GO

CREATE FUNCTION A01087932_GetStateInfo
(   
    @StabP varchar(255)
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT FORMAT(SUM([TotPop]),'N0')    AS [Total State Population],
		   FORMAT(AVG([TotPop]),'N0')    AS [Average County Population],
		   FORMAT(MIN([TotPop]),'N0')    AS [Smallest County],
		   FORMAT(MAX([TotPop]),'N0')    AS [Biggest County],
		   FORMAT(COUNT([zcta5]),'N0')   AS [Number of County],
		   FORMAT(VARP([TotPop]),'N2')   AS [Population Variance],
		   FORMAT(STDEVP([TotPop]),'N2') AS [Population Standard Deviation]
	FROM [dbo].[ZipCensus]
	WHERE [Stab] = @StabP

);
GO

SELECT * FROM A01087932_GetStateInfo('NY');
SELECT * FROM A01087932_GetStateInfo('CA');
GO


/*5.10 : Function A01087932_GetCustomerPerMonthOfFocuseYear(FocusYear int)*/
/* Description : Returns the number of Customers who placed an order on the focused year (displayed per month) */
/* Parameters  : FocusYear (int) : Year of the study */
/* Call        : SELECT * FROM A01087932_GetActiveSubscribersAtCutofDate('2015-10-12');*/
IF object_id(N'A01087932_GetCustomerPerMonthOfFocuseYear', N'IF') IS NOT NULL
    DROP FUNCTION A01087932_GetCustomerPerMonthOfFocuseYear;
GO

CREATE FUNCTION A01087932_GetCustomerPerMonthOfFocuseYear
(   
    @FocusYear int
)
RETURNS TABLE 
AS
RETURN 
(
	SELECT MONTH([OrderDate])           AS [MonthOrder], 
		   COUNT(DISTINCT [CustomerId]) AS [Number Of Customers]
	FROM [dbo].[Orders]
	WHERE YEAR([OrderDate]) = @FocusYear
	GROUP BY MONTH([OrderDate])
);
GO

SELECT * FROM A01087932_GetCustomerPerMonthOfFocuseYear(2013) ORDER BY [MonthOrder];
SELECT * FROM A01087932_GetCustomerPerMonthOfFocuseYear(2014) ORDER BY [MonthOrder];
GO
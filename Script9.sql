USE SQLBook;


/**********Naive Bayes Model**********/
-- Dimension Channel : Conditional probability of having an order higher than $100 by Channel
DECLARE @YearOfStudy INT = 2014;
DECLARE @AverageOrderTotalPrice FLOAT = 100.0;

SELECT	c.[Channel], 
        AVG(IIF(o.[TotalPrice] > @AverageOrderTotalPrice, 1.0, 0))	AS HighOrderProbability, 
        SUM(IIF(o.[TotalPrice] > @AverageOrderTotalPrice, 1, 0))	AS NumHighOrder, 
        SUM(IIF(o.[TotalPrice] > @AverageOrderTotalPrice, 0, 1))	AS NumNotHighOrder
FROM [dbo].[Orders] o
JOIN [dbo].[Campaigns] c ON c.[CampaignId] = o.[CampaignId]
WHERE YEAR(o.[OrderDate]) = @YearOfStudy
GROUP BY [Channel]
ORDER BY [Channel];
GO

-- Dimensions Channel & PaymentType : Conditional Predicted and Actual probabilities of having an order higher than $100 by Channel and Payment Type
DECLARE @YearOfStudy INT = 2014;
DECLARE @AverageOrderTotalPrice FLOAT = 100.0;
WITH
cteData
AS (
	SELECT	o.[OrderId], 
                o.[TotalPrice], 
                IIF(o.[PaymentType] = '??' OR o.[PaymentType] = 'OC','Other',o.[PaymentType]) AS [PaymentType], 
                c.[Channel]
	FROM [dbo].[Orders] o
	JOIN [dbo].[Campaigns] c on c.[CampaignId] = o.[CampaignId]
	WHERE YEAR(o.[OrderDate]) = @YearOfStudy
),
dimChannel 
AS (
	SELECT [Channel], 
               AVG(IIF([TotalPrice] > @AverageOrderTotalPrice, 1.0, 0)) AS p
	FROM cteData
	GROUP BY [Channel]
),
dimPayment 
AS (
	SELECT [PaymentType], 
               AVG(IIF([TotalPrice] > @AverageOrderTotalPrice, 1.0, 0)) AS p
	FROM cteData
	GROUP BY [PaymentType]
),
overall 
AS (
	SELECT AVG(IIF([TotalPrice] > @AverageOrderTotalPrice, 1.0, 0)) AS p
	FROM cteData
),
actual AS (
	SELECT [Channel], [PaymentType], 
               AVG(IIF([TotalPrice] > @AverageOrderTotalPrice, 1.0, 0)) AS p
	FROM cteData
	GROUP BY [Channel], [PaymentType]
)
SELECT
	[Channel], [Predicted Probability per Channel],
	[PaymentType], [Predicted Probability per Payment Type],
	[Overall Probability],
	[Predicted Probability],
	[Actual Probability]
FROM (
	SELECT
		dimC.[Channel],		dimC.p	        AS [Predicted Probability per Channel], 
		dimP.[PaymentType],	dimP.p		AS [Predicted Probability per Payment Type],
		o.p					AS [Overall Probability],
		POWER(o.p, -1) * dimC.p * dimP.p	AS [Predicted Probability],
		a.p					AS [Actual Probability]
	FROM dimChannel dimC
	CROSS JOIN dimPayment dimP
	CROSS JOIN overall o
	JOIN actual a
	ON dimC.[Channel] = a.[Channel]
	AND dimP.[PaymentType] = a.[PaymentType]
) t
ORDER BY [Channel], [PaymentType];
GO


/**********Lookup Model for Classification**********/
/* Model to determine any particular behavior to order a product during each days of the week [Model 1 :Check day by day] */
--Look at Excel file, tab Product vs Day-Weekend
--Uncomment for displaying Pivot function or for displaying corresponding days
--1 = Sunday
--2 = Monday
--...
--7 = Saturday
DECLARE @YEAR VARCHAR(4) = '2015';
WITH
[lookup] 
AS (
    SELECT	[ProductId], 
                [DOWint]
    FROM (
        SELECT
            ol.[ProductId], 
            c.[DOWint],
            COUNT(*) as cnt,
            ROW_NUMBER() OVER (PARTITION BY ol.[ProductId] ORDER BY COUNT(*) DESC) as seq
			FROM [dbo].[Orders] o
			JOIN [dbo].[Calendar] c ON c.Date = o.[OrderDate]
			JOIN [dbo].[OrderLines] ol ON o.[OrderId] = ol.[OrderId]
        WHERE [OrderDate] < @YEAR + '-01-01'
        GROUP BY  ol.[ProductId], c.[DOWint]
    ) zg 
    WHERE seq = 1
),
[actuals] 
AS (
    SELECT   [ProductId],  
             [DOWint]
    FROM (
        SELECT
            ol.[ProductId], 
            c.[DOWint], 
            COUNT(*) as cnt,
            ROW_NUMBER() OVER (PARTITION BY ol.[ProductId] ORDER BY COUNT(*) DESC) as seq
			FROM [dbo].[Orders] o
			JOIN [dbo].[Calendar] c ON c.Date = o.[OrderDate]
			JOIN [dbo].[OrderLines] ol ON o.[OrderId] = ol.[OrderId]
        WHERE [OrderDate] >= @YEAR + '-01-01'
        GROUP BY  ol.[ProductId], c.[DOWint]
    ) zg 
    WHERE seq = 1
),
[result] AS (
SELECT
    l.[DOWint] as [Predicted DOW],
    a.[DOWint] as [Actual DOW], 
    COUNT(*) as [Number of Products]
FROM [lookup] l
JOIN [actuals] a ON l.[ProductId] = a.[ProductId]
--WHERE l.[DOWint] = a.[DOWint]
GROUP BY l.[DOWint], a.[DOWint]
)
SELECT * FROM [result]
PIVOT
(
   MAX([Number of Products])
   FOR [Actual DOW] IN ([1],[2],[3],[4],[5],[6],[7])
) pivot1
ORDER BY [Predicted DOW];
GO
--Model not conclusive : 18.84%

/* Model to determine any particular behavior to order a product during the weekend or during weekdays [Model 2 :Check weekdays vs weekend] */
DECLARE @YEAR VARCHAR(4) = '2015';
WITH
CTEorder
AS (
	SELECT	o.[OrderDate], o.[OrderId], 
                IIF(c.[DOWint] = 1 OR c.[DOWint] = 7, 'Weekend', 'Weekday') as [Week] 
	FROM [dbo].[Orders] o
	JOIN [dbo].[Calendar] c ON c.Date = o.[OrderDate]
),
[lookup] 
AS (
    SELECT   [ProductId], 
             [Week]
    FROM (
        SELECT
            ol.[ProductId], 
            cte.[Week],
            COUNT(*) as cnt,
            ROW_NUMBER() OVER (PARTITION BY ol.[ProductId] ORDER BY COUNT(*) DESC) as seq
			FROM CTEOrder cte
			JOIN [dbo].[OrderLines] ol ON cte.[OrderId] = ol.[OrderId]
        WHERE cte.[OrderDate] < @YEAR + '-01-01'
        GROUP BY  ol.[ProductId], cte.[Week]
    ) zg 
    WHERE seq = 1
),
[actuals] 
AS (
    SELECT   [ProductId], 
             [Week]
    FROM (
        SELECT
            ol.[ProductId], 
            cte.[Week], 
            COUNT(*) as cnt,
            ROW_NUMBER() OVER (PARTITION BY ol.[ProductId] ORDER BY COUNT(*) DESC) as seq
			FROM CTEOrder cte
			JOIN [dbo].[OrderLines] ol ON cte.[OrderId] = ol.[OrderId]
        WHERE cte.[OrderDate] >= @YEAR + '-01-01'
        GROUP BY  ol.[ProductId], cte.[Week]
    ) zg 
    WHERE seq = 1
),
[result] AS (
SELECT
    l.[Week] as [Predicted Week],
    a.[Week] as [Actual Week], 
    COUNT(*) as [Number of Products]
FROM [lookup] l
JOIN [actuals] a ON l.[ProductId] = a.[ProductId]
--WHERE l.[Week] = a.[Week]
GROUP BY l.[Week], a.[Week]
)
SELECT * FROM [result]
PIVOT
(
   MAX([Number of Products])
   FOR [Actual Week] IN ([Weekday],[Weekend])
) pivot1
ORDER BY [Predicted Week];
GO
--Better Model than comparison for each days. However, it is not conclusive for the weekends. 


/* Model to determine any particular behavior for Payment Type used per ZipCode  */
--Look at Excel file, tab Payment Type
DECLARE @YEAR VARCHAR(4) = '2015';
WITH
[lookup] 
AS (
    SELECT   [ZipCode], 
             [PaymentType]
    FROM (
        SELECT	[ZipCode],
		[PaymentType],				
		COUNT(*) AS cnt,
		ROW_NUMBER() OVER (PARTITION BY [ZipCode] ORDER BY COUNT(*) DESC) AS seq
	FROM [dbo].[Orders]
        WHERE [OrderDate] < @YEAR + '-01-01'
	AND [PaymentType] NOT IN ('OC','??')
        GROUP BY  [ZipCode], [PaymentType]
    ) t 
    WHERE seq = 1
),
[actuals] 
AS (
    SELECT   [ZipCode], 
             [PaymentType]
    FROM (
        SELECT	[ZipCode],
		[PaymentType],				
		COUNT(*) AS cnt,
		ROW_NUMBER() OVER (PARTITION BY [ZipCode] ORDER BY COUNT(*) DESC) AS seq
	FROM [dbo].[Orders]
        WHERE [OrderDate] >= @YEAR + '-01-01'
	AND [PaymentType] NOT IN ('OC','??')
        GROUP BY  [ZipCode], [PaymentType]
    ) t 
    WHERE seq = 1
),
[result] AS (
SELECT
    l.[PaymentType] AS [Predicted PaymentType],
    a.[PaymentType] AS [Actual PaymentType], 
    COUNT(*)		AS [Number of ZipCode]
FROM [lookup] l
JOIN [actuals] a ON l.[ZipCode] = a.[ZipCode]
--WHERE l.[DOWint] = a.[DOWint]
GROUP BY l.[PaymentType], a.[PaymentType]
)
SELECT * FROM [result]
PIVOT
(
   MAX([Number of ZipCode])
   FOR [Actual PaymentType] IN ([AE],[DB],[MC],[VI])
) pivot1
ORDER BY [Predicted PaymentType];
GO
--The model is correct for 46.85%



/**********Customer Signatures**********/
/*			State Signature				*/ 
--Per State, display of State Abbreviation, Total number of orders placed, Total price order, Average Price order, 
--Number of Household who bought, Most used Payment Type, Most sold Product group name
--at cutoff date
DROP FUNCTION IF EXISTS A01087932_StateTopUsedPayment;
GO
CREATE FUNCTION A01087932_StateTopUsedPayment(@cutoffdate DATE)
RETURNS TABLE
AS
RETURN
(
	SELECT  [State], [PaymentType]
	FROM	(
			SELECT	[State], [PaymentType], 
                                COUNT(*) AS ctn, 
                                ROW_NUMBER () OVER (PARTITION BY [State] ORDER BY COUNT(*) DESC) AS seq
			FROM [dbo].[Orders]
			WHERE [OrderDate] < @cutoffdate
			GROUP BY [State], [PaymentType]
		) spt
	WHERE seq = 1
);
GO
--SELECT * FROM A01087932_StateTopUsedPayment('2016-01-01');
--GO


DROP FUNCTION IF EXISTS A01087932_StateTopProduct;
GO
CREATE FUNCTION A01087932_StateTopProduct(@cutoffdate DATE)
RETURNS TABLE
AS
RETURN
(
	SELECT  [State], [GroupName]
	FROM	(
				SELECT	[State], [GroupName], 
                                        COUNT(*) AS ctn, 
                                        ROW_NUMBER () OVER (PARTITION BY [State] ORDER BY COUNT(*) DESC) AS seq
				FROM [dbo].[Orders] o
				JOIN [dbo].[OrderLines] ol	ON ol.[OrderId] = o.[OrderId]
				JOIN Products p			ON p.[ProductId] = ol.[ProductId]
				WHERE [OrderDate] < @cutoffdate
				GROUP BY [State], [GroupName]
			) spt
	WHERE seq = 1
);
GO
--SELECT * FROM A01087932_StateTopProduct('2016-01-01');
--GO



DROP FUNCTION IF EXISTS A01087932_StateOrders;
GO
CREATE FUNCTION A01087932_StateOrders(@cutoffdate DATE)
RETURNS TABLE
AS
RETURN
(
	SELECT  o.[State], 
                COUNT(o.[OrderId])	AS [Number of Orders],
		SUM(o.[TotalPrice])	AS [Total Price Order],
		AVG(o.[TotalPrice])	AS [Average Price Order],
		COUNT(c.HouseholdId)	AS [Nb HouseholdId]
	FROM [dbo].[Orders] o
	JOIN [Customers] c ON c.[CustomerId] = o.[CustomerId]
	WHERE [OrderDate] < @cutoffdate
	GROUP BY [State]
);
GO
--SELECT * FROM A01087932_StateOrders('2016-01-01');
--GO


DROP FUNCTION IF EXISTS A01087932_StateSignature;
GO
CREATE FUNCTION A01087932_StateSignature(@cutoffdate DATE)
RETURNS TABLE
AS
RETURN
(
SELECT	A.[State], A.[Number of Orders], A.[Total Price Order], A.[Average Price Order], A.[Nb HouseholdId], 
        B.[PaymentType] AS [TopUsedPayment], D.[GroupName] AS [Top Product],
	@cutoffdate AS [Cutoff Date]
FROM A01087932_StateOrders(@cutoffdate) A
JOIN A01087932_StateTopUsedPayment(@cutoffdate) B ON A.[State] = B.[State]
JOIN A01087932_StateTopProduct(@cutoffdate) D ON D.[State] = A.[State]
WHERE A.[State] != ''
);
GO
SELECT * FROM A01087932_StateSignature('2016-01-01') ORDER BY [State]



/**********Customer Signatures**********/
/*			State Signature				*/ 
--Per State, display of Total Price Order the last three years from the cutoff date 
DROP PROCEDURE IF EXISTS A01087932_P_ThreeYearsOfSales;
GO
CREATE PROCEDURE A01087932_P_ThreeYearsOfSales(@CutoffDate DATE)
AS
BEGIN
	DROP FUNCTION IF EXISTS A01087932_F_ThreeYearsOfSales;
	DECLARE @year INT = YEAR(@CutoffDate);
	DECLARE @years VARCHAR(MAX) = CONCAT('[', @year-2, '],[', @year-1, '],[', @year, ']');
	DECLARE @sql VARCHAR(MAX) = 'CREATE FUNCTION A01087932_F_ThreeYearsOfSales()
	RETURNS TABLE 
	AS
	RETURN 
	(
		SELECT 
			[State],' + @years + '
		FROM (

			SELECT 
				[State],
				[TotalPrice],
				YEAR([OrderDate]) AS [Year] 
			FROM [dbo].[Orders]

		) AS soh 
		PIVOT 
		(
			SUM([TotalPrice]) 
			FOR [Year] 
			IN (' + @years + ')
		) AS pvt
	)';
	EXEC(@sql);
END
GO
EXEC A01087932_P_ThreeYearsOfSales '2014-01-01';
SELECT * FROM A01087932_F_ThreeYearsOfSales() ORDER BY [State];
GO

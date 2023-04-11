/* Authorization for use admin sa on the database SQLBook */
ALTER AUTHORIZATION 
ON DATABASE::SQLBook
TO sa;


USE [SQLBook]
GO

/* Relation ZipCensus ZipCounty */
/* Problem : Orders are linked to a CustomerId = 0 */
/* Solution: Addition of dummy CustomerId = 0 */

SELECT zce.zcta5, zco.ZipCode
FROM ZipCensus zce
FULL OUTER JOIN ZipCounty zco ON zce.zcta5 = zco.ZipCode
WHERE zce.zcta5 IS NULL OR zco.ZipCode IS NULL
ORDER BY zce.zcta5, zco.ZipCode;

/* 1st step : Suppression of orphan ZipCounty rows */
SELECT zce.zcta5, zco.ZipCode
FROM ZipCensus zce
FULL OUTER JOIN ZipCounty zco ON zce.zcta5 = zco.ZipCode
WHERE zce.zcta5 IS NULL
ORDER BY zce.zcta5, zco.ZipCode;

DELETE FROM zco
FROM ZipCensus zce
FULL OUTER JOIN ZipCounty zco ON zce.zcta5 = zco.ZipCode
WHERE zce.zcta5 IS NULL;

/* 2nd step : Suppression of orphan ZipCensus rows */
SELECT zce.zcta5, zco.ZipCode
FROM ZipCensus zce
FULL OUTER JOIN ZipCounty zco ON zce.zcta5 = zco.ZipCode
WHERE zco.ZipCode IS NULL
ORDER BY zce.zcta5, zco.ZipCode;

DELETE FROM zce
FROM ZipCensus zce
FULL OUTER JOIN ZipCounty zco ON zce.zcta5 = zco.ZipCode
WHERE zco.ZipCode IS NULL;



/* Relation Orders - ZipCensus */
/* Problem : ZipCode of some orders do not reference a valid pk in ZipCensus.zcta5 */
/* Solution: Removal of the orphan records */

SELECT o.*
   FROM [dbo].[Orders] o
   LEFT JOIN [dbo].[ZipCensus] z
   ON z.zcta5 = o.ZipCode
   WHERE z.zcta5 IS NULL
   ORDER BY o.ZipCode;

DELETE FROM o
FROM [dbo].[Orders] o
LEFT JOIN [dbo].[ZipCensus] z
ON z.zcta5 = o.ZipCode
WHERE z.zcta5 IS NULL;




/* Relation Orders - OrderLines */
/* Problem : Some Orders have been removed and not the linked OrderLines */
/* Solution: Removal of the orphan records */

SELECT ol.*
   FROM [dbo].[Orders] od
   RIGHT JOIN [dbo].[OrderLines] ol
   ON od.OrderId = ol.OrderId
   WHERE od.OrderId IS NULL
   ORDER BY ol.OrderId, ol.OrderLineId;

DELETE FROM ol
   FROM [dbo].[Orders] od
   RIGHT JOIN [dbo].[OrderLines] ol
   ON od.OrderId = ol.OrderId
   WHERE od.OrderId IS NULL;



   	 

/* Relation Customer - Orders */
/* Problem : Orders are linked to a CustomerId = 0 */
/* Solution: Addition of dummy CustomerId = 0 */

SELECT o.[CustomerId]
FROM [dbo].[Orders] o
WHERE o.[CustomerId] NOT IN (
							SELECT c.[CustomerId]
							FROM [dbo].[Customers] c
							);

INSERT INTO [dbo].[Customers] (CustomerId, HouseholdId, Gender, FirstName)
VALUES (0,0,' ',' ');  


/*

SELECT 
	o.[State],
	YEAR(o.OrderDate),
	COUNT(*),
	ROW_NUMBER() OVER (PARTITION BY o.[State] ORDER BY COUNT(*) DESC)
FROM Orders o
GROUP BY o.[State], YEAR(o.OrderDate);

 */  
USE MusicStreamDW

DROP PROCEDURE IF EXISTS usp_measure05
DROP PROCEDURE IF EXISTS usp_measure06
DROP PROCEDURE IF EXISTS usp_measure07
DROP PROCEDURE IF EXISTS usp_measure08
DROP PROCEDURE IF EXISTS usp_measure09
DROP PROCEDURE IF EXISTS usp_measure10
DROP PROCEDURE IF EXISTS usp_measure11
DROP PROCEDURE IF EXISTS usp_measure12
DROP PROCEDURE IF EXISTS usp_measure13
DROP PROCEDURE IF EXISTS usp_measure17

SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-5-Top 3 listeners who played most songs from top 5 most popular artists
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure05 
AS

SET NOCOUNT ON;

WITH TopArtists AS (
    SELECT TOP 5 SON.SourceArtistID
    FROM FactPlayHistory HIS
         JOIN DimSong SON
				ON HIS.SongKey = SON.SongKey
    GROUP BY SON.SourceArtistID
    ORDER BY COUNT(*) DESC, SON.SourceArtistID)
,LatestListenerNames AS (
	SELECT SourceListenerID, ListenerName
	FROM DimListener
	WHERE ToDT = '2079-01-01')
SELECT TOP 3 
	 ListenerID = LIS.SourceListenerID 
	,LN.ListenerName
	,PlayCount  = COUNT(*) 
FROM FactPlayHistory HIS
     JOIN DimSong SON
			ON HIS.SongKey = SON.SongKey
	 JOIN DimListener LIS
			ON HIS.ListenerKey = LIS.ListenerKey
	 JOIN LatestListenerNames LN
			ON LIS.SourceListenerID = LN.SourceListenerID
WHERE SON.SourceArtistID IN (SELECT SourceArtistID 
                             FROM TopArtists)
GROUP BY LIS.SourceListenerID, LN.ListenerName
ORDER BY PlayCount DESC, LIS.SourceListenerID
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-6-Top 5 songs with highest play count in the last month
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure06 
AS

SET NOCOUNT ON;

SELECT TOP 5 
     DS.SongName
	,DS.ArtistName
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey	 
WHERE D.FullDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
GROUP BY DS.SongName, DS.ArtistName
ORDER BY PlayCount DESC, DS.SongName, DS.ArtistName;
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-7-Top 3 genres with highest play count over the past quarter
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure07 
AS

SET NOCOUNT ON;

SELECT TOP 3 
     S.GenreName
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
	 JOIN DimSong S 
			ON F.SongKey = S.SongKey
WHERE D.FullDate >= DATEADD(QUARTER, -1, CONVERT(date, GETDATE()))
GROUP BY S.GenreName
ORDER BY PlayCount DESC, S.GenreName; 
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-8-Genres not played in the last month but were played in the previous 6 months
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure08 
AS

SET NOCOUNT ON;

SELECT DISTINCT S.GenreName
FROM FactPlayHistory F 
	 JOIN DimSong S
			ON S.SongKey = F.SongKey
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
WHERE D.FullDate BETWEEN DATEADD(MONTH, -7, CONVERT(date, GETDATE())) AND DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
  AND S.GenreName NOT IN (SELECT DISTINCT S2.GenreName
					      FROM FactPlayHistory F2 
						       JOIN DimSong S2
									ON S2.SongKey = F2.SongKey
							   JOIN DimDate D2 
									ON F2.PlayDateKey = D2.DateKey
					      WHERE D2.FullDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE())))
ORDER BY 1; 
GO


-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-9 - Monthly timeline of total songs listened
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure09 
AS

SET NOCOUNT ON;

SELECT Month     = FORMAT(D.FullDate, 'yyyy-MM')
      ,PlayCount = COUNT(*)
FROM FactPlayHistory F
     JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
GROUP BY FORMAT(D.FullDate, 'yyyy-MM') 
ORDER BY FORMAT(D.FullDate, 'yyyy-MM') 
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-10 - Monthly timeline of top 5 songs
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure10 
AS
SET NOCOUNT ON;

--10-Monthly timeline of top 5 songs
SELECT SON.SongName
	  ,SON.ArtistName
	  ,Month     = FORMAT(D.FullDate, 'yyyy-MM')
	  ,PlayCount = COUNT(*)
FROM FactPlayHistory F
     JOIN DimSong SON 
			ON F.SongKey = SON.SongKey
     JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
WHERE F.SongKey IN (SELECT TOP 5 F2.SongKey
 				    FROM FactPlayHistory F2
				    GROUP BY F2.SongKey
				    ORDER BY COUNT(*) DESC, F2.SongKey) --<--SongID included to ensure predictibility because WITH TIES is not used  
GROUP BY SON.SongName, SON.ArtistName, FORMAT(D.FullDate, 'yyyy-MM') 
ORDER BY SON.SongName, SON.ArtistName, FORMAT(D.FullDate, 'yyyy-MM') 
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
----Metric-11 - Monthly timeline of top 5 genres
----2025-05-28 : TAG - Temel A. Gullen - Created
-------------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure11 
AS
SET NOCOUNT ON;

--11-Monthly timeline of top 5 genres
SELECT S.GenreName
      ,Month     = FORMAT(D.FullDate, 'yyyy-MM')
	  ,PlayCount = COUNT(*)
FROM FactPlayHistory F
	 JOIN DimSong S
			ON F.SongKey = S.SongKey
     JOIN DimDate D
			ON F.PlayDateKey = D.DateKey
WHERE S.GenreName IN (SELECT TOP 5 S2.GenreName
 				      FROM FactPlayHistory F2
				           JOIN DimSong S2
							  ON F2.SongKey = S2.SongKey
				      GROUP BY S2.GenreName
				      ORDER BY COUNT(*) DESC, S2.GenreName) --<--Genre included to ensure predictibility because WITH TIES is not used  
GROUP BY S.GenreName, FORMAT(D.FullDate, 'yyyy-MM') 
ORDER BY S.GenreName, FORMAT(D.FullDate, 'yyyy-MM') 
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-12 - Top 3 listeners that had the highest month-to-month increase in listening songs last month
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure12 
AS
SET NOCOUNT ON;

;WITH MonthlyPlaysLastMonth2 AS (
	SELECT L.SourceListenerID, Count = COUNT(*) 
	FROM FactPlayHistory F
	     JOIN DimDate D
				ON F.PlayDateKey = D.DateKey
		 JOIN DimListener L
				ON F.ListenerKey = L.ListenerKey
	WHERE FORMAT(D.FullDate, 'yyyy-MM') = FORMAT(DATEADD(month, -2, CONVERT(date, GETDATE())), 'yyyy-MM') 
	GROUP BY L.SourceListenerID, FORMAT(D.FullDate, 'yyyy-MM'))
,MonthlyPlaysLastMonth1 AS (
	SELECT L.SourceListenerID, ListenerName = (SELECT D.ListenerName FROM DimListener D WHERE D.SourceListenerID = L.SourceListenerID AND D.ToDT = '2079-01-01'), Count = COUNT(*) 
	FROM FactPlayHistory F
	     JOIN DimDate D
				ON F.PlayDateKey = D.DateKey
		 JOIN DimListener L
				ON F.ListenerKey = L.ListenerKey
	WHERE FORMAT(D.FullDate, 'yyyy-MM') = FORMAT(DATEADD(month, -1, CONVERT(date, GETDATE())), 'yyyy-MM') 
	GROUP BY L.SourceListenerID, FORMAT(D.FullDate, 'yyyy-MM'))
SELECT TOP 3 
	 ListenerID = M1.SourceListenerID
	,M1.ListenerName
	,Count2 = ISNULL(M2.Count, 0)
	,Count1 = M1.Count
	,Increase = M1.Count - ISNULL(M2.Count, 0)
FROM MonthlyPlaysLastMonth1 M1
     LEFT JOIN MonthlyPlaysLastMonth2 M2
			ON M1.SourceListenerID = M2.SourceListenerID
ORDER BY M1.Count - ISNULL(M2.Count, 0) DESC, M1.ListenerName
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-13 - Top 3 songs with highest "number of times played" / "included in number of playlists" ratio
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure13 
AS
SET NOCOUNT ON;

;WITH NofPlayLists AS (
	SELECT A.ArtistName
		  ,S.SourceSongID
	      ,S.SongName
		  ,Count = COUNT(*)
    FROM FactPlayListSong F
		 JOIN DimSong S
				ON F.SongKey = S.SongKey
         JOIN DimArtist A
				ON S.SourceArtistID = A.SourceArtistID
    GROUP BY A.ArtistName, S.SourceSongID, S.SongName)
,NofTimesPlayed AS (
	SELECT S.SourceSongID, Count = COUNT(*)
    FROM FactPlayHistory F
		 JOIN DimSong S
				ON F.SongKey = S.SongKey
    GROUP BY S.SourceSongID)
SELECT TOP 3
	 PL.ArtistName
	,PL.SongName
	,PlayListCount = PL.Count
	,PlayCount     = HI.Count
	,Ratio         = 1.0 * HI.Count / PL.Count
FROM NofPlayLists PL
     JOIN NofTimesPlayed HI
			ON PL.SourceSongID = HI.SourceSongID
GROUP BY PL.ArtistName, PL.SongName, PL.Count, HI.Count
ORDER BY 1.0 * HI.Count / PL.Count DESC, PL.SongName, PL.ArtistName
GO

-----------------------------------------------------------------------------------------------------------------------------------------------------
--Metric-17 - Most frequent LinstenerName change 
--2025-05-28 : TAG - Temel A. Gullen - Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE usp_measure17 
AS
SET NOCOUNT ON;
SELECT TOP 3
	 SourceListenerID
	,ListenerName = (SELECT D2.ListenerName FROM DimListener D2 WHERE D2.SourceListenerID = D1.SourceListenerID AND D2.ToDT = '2079-01-01')
	,ChangeCound  = COUNT(*)
FROM DimListener D1
WHERE ListenerKey > 0
GROUP BY SourceListenerID
ORDER BY COUNT(*) DESC, 2
GO

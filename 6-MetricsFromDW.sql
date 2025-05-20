
----------------------------------------------------------------------------------------------------------------------------
--MusicStreamDW Data Statistics

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------

SET XACT_ABORT ON

USE MusicStreamDW

--1-Average number of songs played per listener per month
SELECT AVG(CAST(MonthlyPlays AS FLOAT)) AS AvgSongsPerListenerPerMonth
FROM (
	  SELECT DIMLI.SourceListenerID
			,D.Year
			,D.Month
			,COUNT(*) AS MonthlyPlays
      FROM FactPlayHistory F
	       JOIN DimListener DIMLI
				ON F.ListenerKey = DIMLI.ListenerKey
		   JOIN DimDate D 
				ON F.PlayDateKey = D.DateKey
      GROUP BY DIMLI.SourceListenerID, D.Year, D.Month
	 ) AS ListenerMonthlyCounts;


--2-Top 5 songs with highest play count across all listeners
SELECT TOP 5 WITH TIES
	 DS.SourceSongID AS SongID
    ,DS.SongName
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
GROUP BY DS.SourceSongID, DS.SongName
ORDER BY PlayCount DESC, DS.SongName;


--3-Total number of songs played by listeners who joined in the last year
SELECT COUNT(*) AS TotalSongsPlayed
FROM FactPlayHistory F
	 JOIN DimListener DL 
			ON F.ListenerKey = DL.ListenerKey
WHERE DL.CreatedDate >= DATEADD(YEAR, -1, GETDATE());


--4-Top 3 genres with highest play count across all listeners
SELECT TOP 3
     DS.Genre
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
GROUP BY DS.Genre
ORDER BY PlayCount DESC;


--5-Top 3 listeners who played most songs from top 5 most popular artists
WITH TopArtists AS (
    SELECT TOP 5 SON.SourceArtistID
    FROM FactPlayHistory HIS
         JOIN DimSong SON
				ON HIS.SongKey = SON.SongKey
    GROUP BY SON.SourceArtistID
    ORDER BY COUNT(*) DESC
)
SELECT TOP 3 WITH TIES
	 LIS.SourceListenerID AS ListenerID
	,LIS.ListenerName
	,COUNT(*) AS PlayCount
FROM FactPlayHistory HIS
     JOIN DimSong SON
			ON HIS.SongKey = SON.SongKey
	 JOIN DimListener LIS
			ON HIS.ListenerKey = LIS.ListenerKey
WHERE SON.SourceArtistID IN (SELECT SourceArtistID 
                             FROM TopArtists)
GROUP BY LIS.SourceListenerID, LIS.ListenerName
ORDER BY PlayCount DESC, LIS.SourceListenerID;


--6-Top 5 songs with highest play count in the last month
SELECT TOP 5 WITH TIES
     DS.SongName
	,DS.ArtistName
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey	 
WHERE D.FullDate >= DATEADD(MONTH, -1, GETDATE())
GROUP BY DS.SongName, DS.ArtistName
ORDER BY PlayCount DESC, DS.SongName, DS.ArtistName;


--7-Top 3 genres with highest play count over the past quarter
SELECT TOP 3 WITH TIES
     DS.Genre
	,COUNT(*) AS PlayCount
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
WHERE D.FullDate >= DATEADD(QUARTER, -1, GETDATE())
GROUP BY DS.Genre
ORDER BY PlayCount DESC, DS.Genre;


--8-Genres not played in the last month but were played in the previous 6 months
SELECT DISTINCT DS.Genre
FROM DimSong DS
	 JOIN FactPlayHistory F 
			ON DS.SongKey = F.SongKey
	 JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
WHERE D.FullDate BETWEEN DATEADD(MONTH, -7, GETDATE()) AND DATEADD(MONTH, -1, GETDATE())
  AND DS.Genre NOT IN (SELECT DISTINCT DS2.Genre
					   FROM DimSong DS2
							JOIN FactPlayHistory F2 
									ON DS2.SongKey = F2.SongKey
							JOIN DimDate D2 
									ON F2.PlayDateKey = D2.DateKey
					   WHERE D2.FullDate >= DATEADD(MONTH, -1, GETDATE()));

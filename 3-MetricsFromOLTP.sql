
----------------------------------------------------------------------------------------------------------------------------
--MusicStream Data Statistics

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------

SET XACT_ABORT ON

USE MusicStream

--1-Average number of songs played per listener per month
SELECT
    AVG(CAST(MonthlyPlays AS FLOAT)) AS AvgSongsPerListenerPerMonth
FROM (
	  SELECT ListenerID
			,DATEPART(YEAR, PlayDate) AS PlayYear
			,DATEPART(MONTH, PlayDate) AS PlayMonth
			,COUNT(*) AS MonthlyPlays
      FROM PlayHistory
      GROUP BY ListenerID, DATEPART(YEAR, PlayDate), DATEPART(MONTH, PlayDate)
	 ) AS PlaysPerListenerMonth;


--2-Top 5 songs with highest play count across all listeners
SELECT TOP 5 WITH TIES
     S.SongID
	,S.SongName
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
GROUP BY S.SongID, S.SongName
ORDER BY PlayCount DESC, S.SongName;


--3-Total songs played by listeners who joined in the last year
SELECT COUNT(*) AS TotalSongsPlayed
FROM PlayHistory PH
     JOIN Listener L 
			ON PH.ListenerID = L.ListenerID
WHERE L.CreatedDate >= DATEADD(YEAR, -1, GETDATE());


--4-Top 3 genres with highest play count across all listeners
SELECT TOP 3
     S.Genre
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
JOIN Song S ON PH.SongID = S.SongID
GROUP BY S.Genre
ORDER BY PlayCount DESC;


--5-Top 3 listeners who played most songs from top 5 most popular artists
WITH TopArtists AS (
    SELECT TOP 5 SON.ArtistID
    FROM PlayHistory HIS
	     JOIN Song SON
			ON HIS.SongID = SON.SongID
    GROUP BY SON.ArtistID
    ORDER BY COUNT(*) DESC
)
SELECT TOP 3 WITH TIES
     HIS.ListenerID
	,LIS.ListenerName
	,COUNT(*) AS PlayCount
FROM PlayHistory HIS
     JOIN Song SON 
			ON HIS.SongID = SON.SongID
	 JOIN Listener LIS
			ON HIS.ListenerID = LIS.ListenerID
WHERE SON.ArtistID IN (SELECT ArtistID 
                       FROM TopArtists)
GROUP BY HIS.ListenerID, LIS.ListenerName
ORDER BY PlayCount DESC, HIS.ListenerID;


--6-Top 5 songs with highest play count in the last month
SELECT TOP 5 WITH TIES	 
	 S.SongName
	,AR.ArtistName
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
	 JOIN Artist AR
			ON S.ArtistID = AR.ArtistID
WHERE PH.PlayDate >= DATEADD(MONTH, -1, GETDATE())
GROUP BY S.SongName, AR.ArtistName
ORDER BY PlayCount DESC, S.SongName, AR.ArtistName;


--7-Top 3 genres with highest play count over the past quarter
SELECT TOP 3 WITH TIES
     S.Genre
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
WHERE PH.PlayDate >= DATEADD(QUARTER, -1, GETDATE())
GROUP BY S.Genre
ORDER BY PlayCount DESC, S.Genre;


--8-Genres not played in the last month but were played in the previous 6 months
SELECT DISTINCT S.Genre
FROM Song S
	 JOIN PlayHistory PH 
			ON S.SongID = PH.SongID
WHERE PH.PlayDate BETWEEN DATEADD(MONTH, -7, GETDATE()) AND DATEADD(MONTH, -1, GETDATE())
  AND S.Genre NOT IN (SELECT DISTINCT S2.Genre
					  FROM Song S2
						   JOIN PlayHistory PH2 
								ON S2.SongID = PH2.SongID
					  WHERE PH2.PlayDate >= DATEADD(MONTH, -1, GETDATE())
					  );


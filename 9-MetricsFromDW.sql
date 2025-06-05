
----------------------------------------------------------------------------------------------------------------------------
--MusicStreamDW Data Statistics

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------
 
SET XACT_ABORT ON

USE MusicStreamDW

--1-Average number of songs played per listener per month
SELECT AvgSongsPerListenerPerMonth = AVG(CAST(MonthlyPlays AS FLOAT)) 
FROM (SELECT DIMLI.SourceListenerID
			,D.Year
			,D.Month
			,COUNT(*) AS MonthlyPlays
      FROM FactPlayHistory F
	       JOIN DimListener DIMLI
				ON F.ListenerKey = DIMLI.ListenerKey
		   JOIN DimDate D 
				ON F.PlayDateKey = D.DateKey
      GROUP BY DIMLI.SourceListenerID, D.Year, D.Month) AS T;


--2-Top 5 songs with highest play count across all listeners
SELECT TOP 5
	 DS.ArtistName
    ,DS.SongName
	,PlayCount = COUNT(*) 
FROM FactPlayHistory F
	 JOIN DimSong DS 
			ON F.SongKey = DS.SongKey
GROUP BY DS.ArtistName, DS.SongName
ORDER BY PlayCount DESC, DS.SongName, DS.ArtistName;


--3-Total number of songs played by listeners who joined in the last year
SELECT TotalSongsPlayed = COUNT(*)
FROM FactPlayHistory F
	 JOIN DimListener DL 
			ON F.ListenerKey = DL.ListenerKey
WHERE DL.CreatedDate >= DATEADD(YEAR, -1, CONVERT(date, GETDATE()));


--4-Top 3 genres with highest play count across all listeners
SELECT TOP 3
     S.GenreName
	,PlayCount = COUNT(*) 
FROM FactPlayHistory F
	 JOIN DimSong S 
			ON F.SongKey = S.SongKey
GROUP BY S.GenreName
ORDER BY PlayCount DESC, S.GenreName;


--5-Top 3 listeners who played most songs from top 5 most popular artists
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


--6-Top 5 songs with highest play count in the last month
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


--7-Top 3 genres with highest play count over the past quarter
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


--8-Genres not played in the last month but were played in the previous 6 months
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


--TIMELINE
--9-Monthly timeline total songs listened
SELECT Month     = FORMAT(D.FullDate, 'yyyy-MM')
      ,PlayCount = COUNT(*)
FROM FactPlayHistory F
     JOIN DimDate D 
			ON F.PlayDateKey = D.DateKey
GROUP BY FORMAT(D.FullDate, 'yyyy-MM') 
ORDER BY FORMAT(D.FullDate, 'yyyy-MM') 


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


--INCREASE
--12-Top 3 listeners that had the highest month-to-month increase in listening songs last month
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


--INTENTION vs REALITY
--13-Top 3 songs with highest "number of times played" / "included in number of playlists" ratio
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


--INCOMPLETE DETAILS
--14-Listeners with no email or name
SELECT ListenerKey
      ,ListenerID = SourceListenerID
	  ,ListenerName
	  ,Email
	  ,FromDT
FROM DimListener
WHERE ListenerKey > 0 
  AND ToDT = '2079-01-01'
  AND (ListenerName = 'Unknown' OR Email = 'Unknown')
ORDER BY SourceListenerID, FromDT


--15-Playlists with no listener or name
SELECT PlayListID = SourcePlayListID
	  ,PlayListName
	  ,ListenerID = SourceListenerID
	  ,ListenerName = ListenerName
FROM DimPlayList
WHERE PlayListKey > 0 
  AND (PlayListName = 'Unknown' OR ListenerName = 'Unknown')
ORDER BY SourcePlayListID


--16-Songs with no name, artist or genre
SELECT SongID   = SourceSongID
	  ,SongName
	  ,ArtistName
	  ,GenreName
FROM DimSong
WHERE SongKey > 0
  AND (SongName = 'Unknown' OR ArtistName = 'Unknown' OR GenreName = 'Unknown')
ORDER BY SourceSongID


--MOST FREQUENT UPDATE
--17-Most frequent LinstenerName change 
SELECT TOP 3
	 SourceListenerID
	,ListenerName = (SELECT D2.ListenerName FROM DimListener D2 WHERE D2.SourceListenerID = D1.SourceListenerID AND D2.ToDT = '2079-01-01')
	,ChangeCound  = COUNT(*)
FROM DimListener D1
WHERE ListenerKey > 0
GROUP BY SourceListenerID
ORDER BY COUNT(*) DESC, 2

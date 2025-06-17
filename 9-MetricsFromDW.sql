
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
EXEC usp_metric05


--6-Top 5 songs with highest play count in the last month
EXEC usp_metric06

--7-Top 3 genres with highest play count over the past quarter
EXEC usp_metric07


--8-Genres not played in the last month but were played in the previous 6 months
EXEC usp_metric08


--TIMELINE
--9-Monthly timeline total songs listened
EXEC usp_metric09


--10-Monthly timeline of top 5 songs
EXEC usp_metric10


--11-Monthly timeline of top 5 genres
EXEC usp_metric11


--INCREASE
--12-Top 3 listeners that had the highest month-to-month increase in listening songs last month
EXEC usp_metric12


--INTENTION vs REALITY
--13-Top 3 songs with highest "number of times played" / "included in number of playlists" ratio
EXEC usp_metric13


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
EXEC usp_metric17
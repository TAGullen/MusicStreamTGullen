
----------------------------------------------------------------------------------------------------------------------------
--MusicStream Data Statistics

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------
 
SET XACT_ABORT ON

USE MusicStream

--1-Average number of songs played per listener per month
SELECT AvgSongsPerListenerPerMonth = AVG(CAST(MonthlyPlays AS FLOAT)) 
FROM (SELECT ListenerID
			,DATEPART(YEAR, PlayDate) AS PlayYear
			,DATEPART(MONTH, PlayDate) AS PlayMonth
			,COUNT(*) AS MonthlyPlays
      FROM PlayHistory
      GROUP BY ListenerID, DATEPART(YEAR, PlayDate), DATEPART(MONTH, PlayDate)) AS T;


--2-Top 5 songs with highest play count across all listeners
SELECT TOP 5
     A.ArtistName
	,S.SongName
	,PlayCount = COUNT(*)  
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
	 JOIN Artist A
			ON S.ArtistID = A.ArtistID
GROUP BY A.ArtistName, S.SongName
ORDER BY PlayCount DESC, S.SongName, A.ArtistName;


--3-Total songs played by listeners who joined in the last year
SELECT TotalSongsPlayed = COUNT(*) 
FROM PlayHistory PH
     JOIN Listener L 
			ON PH.ListenerID = L.ListenerID
WHERE L.CreatedDate >= DATEADD(YEAR, -1, CONVERT(date, GETDATE()));


--4-Top 3 genres with highest play count across all listeners
SELECT TOP 3
     G.GenreName
	,PlayCount = COUNT(*) 
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
	 JOIN Genre G 
			ON S.GenreID = G.GenreID
GROUP BY G.GenreName
ORDER BY PlayCount DESC, G.GenreName;


--5-Top 3 listeners who played most songs from top 5 most popular artists
WITH TopArtists AS (
    SELECT TOP 5 SON.ArtistID
    FROM PlayHistory HIS
	     JOIN Song SON
			ON HIS.SongID = SON.SongID
    GROUP BY SON.ArtistID
    ORDER BY COUNT(*) DESC, SON.ArtistID)
SELECT TOP 3 
     HIS.ListenerID
	,LIS.ListenerName
	,PlayCount = COUNT(*) 
FROM PlayHistory HIS
     JOIN Song SON 
			ON HIS.SongID = SON.SongID
	 JOIN Listener LIS
			ON HIS.ListenerID = LIS.ListenerID
WHERE SON.ArtistID IN (SELECT ArtistID 
                       FROM TopArtists)
GROUP BY HIS.ListenerID, LIS.ListenerName
ORDER BY PlayCount DESC, LIS.ListenerName;


--6-Top 5 songs with highest play count in the last month
SELECT TOP 5 	 
	 S.SongName
	,AR.ArtistName
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
	 JOIN Artist AR
			ON S.ArtistID = AR.ArtistID
WHERE PH.PlayDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
GROUP BY S.SongName, AR.ArtistName
ORDER BY PlayCount DESC, S.SongName, AR.ArtistName;


--7-Top 3 genres with highest play count over the past quarter
SELECT TOP 3 
     G.GenreName
	,COUNT(*) AS PlayCount
FROM PlayHistory PH
     JOIN Song S 
			ON PH.SongID = S.SongID
     JOIN Genre G 
			ON S.GenreID = G.GenreID
WHERE PH.PlayDate >= DATEADD(QUARTER, -1, CONVERT(date, GETDATE()))
GROUP BY G.GenreName
ORDER BY PlayCount DESC, G.GenreName;


--8-Genres not played in the last month but were played in the previous 6 months
SELECT DISTINCT G.GenreName
FROM PlayHistory PH 
	 JOIN Song S
			ON S.SongID = PH.SongID
     JOIN Genre G 
			ON S.GenreID = G.GenreID
WHERE PH.PlayDate BETWEEN DATEADD(MONTH, -7, CONVERT(date, GETDATE())) AND DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
  AND G.GenreID NOT IN (SELECT DISTINCT S2.GenreID
					    FROM PlayHistory PH2 
						     JOIN Song S2
									ON S2.SongID = PH2.SongID
					    WHERE PH2.PlayDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE())))
ORDER BY 1;


--TIMELINE
--9-Monthly timeline total songs listened
SELECT Month     = FORMAT(PlayDate, 'yyyy-MM')
      ,PlayCount = COUNT(*)
FROM PlayHistory 
GROUP BY FORMAT(PlayDate, 'yyyy-MM') 
ORDER BY FORMAT(PlayDate, 'yyyy-MM') 


--10-Monthly timeline of top 5 songs
SELECT SON.SongName
	  ,ART.ArtistName
	  ,Month     = FORMAT(HIS.PlayDate, 'yyyy-MM')
	  ,PlayCount = COUNT(*)
FROM PlayHistory HIS
     JOIN Song SON
			ON HIS.SongID = SON.SongID
	 JOIN Artist ART
			ON SON.ArtistID = ART.ArtistID
WHERE SON.SongID IN (SELECT TOP 5 P.SongID 
 				     FROM PlayHistory P
				     GROUP BY P.SongID
				     ORDER BY COUNT(*) DESC, P.SongID) --<--SongID included to ensure predictibility because WITH TIES is not used  
GROUP BY SON.SongName, ART.ArtistName, FORMAT(HIS.PlayDate, 'yyyy-MM')
ORDER BY SON.SongName, ART.ArtistName, FORMAT(HIS.PlayDate, 'yyyy-MM')


--11-Monthly timeline of top 5 genres
SELECT G.GenreName
      ,Month     = FORMAT(PlayDate, 'yyyy-MM')
	  ,PlayCount = COUNT(*)
FROM PlayHistory PHIS
	 JOIN Song S
			ON PHIS.SongID = S.SongID
     JOIN Genre G 
			ON S.GenreID = G.GenreID
WHERE S.GenreID IN (SELECT TOP 5 S2.GenreID
 				    FROM PlayHistory PHIS2
				         JOIN Song S2
							     ON PHIS2.SongID = S2.SongID
				    GROUP BY S2.GenreID
				    ORDER BY COUNT(*) DESC, S2.GenreID) --<--Genre included to ensure predictibility because WITH TIES is not used  
GROUP BY G.GenreName, FORMAT(PlayDate, 'yyyy-MM') 
ORDER BY G.GenreName, FORMAT(PlayDate, 'yyyy-MM') 


--INCREASE
--12-Top 3 listeners that had the highest month-to-month increase in listening songs last month
;WITH MonthlyPlaysLastMonth2 AS (
	SELECT ListenerID, Count = COUNT(*) 
	FROM PlayHistory 
	WHERE FORMAT(PlayDate, 'yyyy-MM') = FORMAT(DATEADD(month, -2, CONVERT(date, GETDATE())), 'yyyy-MM') 
	GROUP BY ListenerID, FORMAT(PlayDate, 'yyyy-MM'))
,MonthlyPlaysLastMonth1 AS (
	SELECT L.ListenerID, L.ListenerName, Count = COUNT(*) 
	FROM PlayHistory P
	     JOIN Listener L
				ON P.ListenerID = L.ListenerID
	WHERE FORMAT(PlayDate, 'yyyy-MM') = FORMAT(DATEADD(month, -1, CONVERT(date, GETDATE())), 'yyyy-MM') 
	GROUP BY L.ListenerID, L.ListenerName, FORMAT(PlayDate, 'yyyy-MM'))
SELECT TOP 3 
	 M1.ListenerID
	,M1.ListenerName
	,Count2   = ISNULL(M2.Count, 0)
	,Count1   = M1.Count
	,Increase = M1.Count - ISNULL(M2.Count, 0)
FROM MonthlyPlaysLastMonth1 M1
     LEFT JOIN MonthlyPlaysLastMonth2 M2
			ON M1.ListenerID = M2.ListenerID
ORDER BY M1.Count - ISNULL(M2.Count, 0) DESC, M1.ListenerName


--INTENTION vs REALITY
--13-Top 3 songs with highest "number of times played" / "included in number of playlists" ratio
;WITH NofPlayLists AS (
	SELECT A.ArtistName
	      ,S.SongID
		  ,S.SongName
		  ,Count = COUNT(*)
    FROM PlayListSong PL
	     JOIN Song S
				ON PL.SongID = S.SongID
         JOIN Artist A
				ON S.ArtistID = A.ArtistID
    GROUP BY A.ArtistName, S.SongID, S.SongName)
,NofTimesPlayed AS (
	SELECT SongID
	      ,Count = COUNT(*)
    FROM PlayHistory
    GROUP BY SongID)
SELECT TOP 3 
	 PL.ArtistName
	,PL.SongName
	,PlayListCount = PL.Count
	,PlayCount     = HI.Count
	,Ratio         = 1.0 * HI.Count / ISNULL(PL.Count, 0.5) --<--Avoid division by zero
FROM NofPlayLists PL
     LEFT JOIN NofTimesPlayed HI
			ON PL.SongID = HI.SongID
GROUP BY PL.ArtistName, PL.SongName, PL.Count, HI.Count
ORDER BY 1.0 * HI.Count / ISNULL(PL.Count, 0.5) DESC, PL.SongName, PL.ArtistName


--INCOMPLETE DETAILS
--14-Listeners with no email or name
SELECT *
FROM Listener
WHERE ListenerName IS NULL OR Email IS NULL
ORDER BY ListenerID


--15-Playlists with no listener or name
SELECT PL.PlayListID
      ,PL.PlayListName
	  ,PL.ListenerID
	  ,LI.ListenerName
FROM PlayList PL
     LEFT JOIN Listener LI
			ON PL.ListenerID = LI.ListenerID
WHERE PlayListName IS NULL OR ListenerName IS NULL
ORDER BY PlayListID


--16-Songs with no name, artist or genre
SELECT S.SongID
	  ,S.SongName
	  ,A.ArtistName
	  ,G.GenreName
FROM Song S
     LEFT JOIN Artist A
			ON S.ArtistID = A.ArtistID
	 LEFT JOIN Genre G
			ON S.GenreID = G.GenreID
WHERE S.SongName IS NULL 
   OR S.ArtistID IS NULL
   OR S.GenreID IS NULL
ORDER BY SongID


--MOST FREQUENT UPDATE
--17-Most frequent LinstenerName change 
--THIS CAN ONLY BE REPORTED FROM DW

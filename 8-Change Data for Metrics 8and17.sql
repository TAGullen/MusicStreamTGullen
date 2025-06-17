

--For Metric-08 we need to delete some data --------------------------------------------------------------------------------
DELETE PH
FROM MusicStream.dbo.PlayHistory PH
     JOIN MusicStream.dbo.Song SO 
			ON PH.SongID = SO.SongID
WHERE PH.PlayDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
  AND SO.GenreID IN (10, 15)

DELETE PH
FROM MusicStreamDW.dbo.FactPlayHistory PH
     JOIN MusicStreamDW.dbo.DimSong SO 
			ON PH.SongKey = SO.SongKey
	 JOIN MusicStreamDW.dbo.DimDate DA
			ON PH.PlayDateKey = DA.DateKey
WHERE DA.FullDate >= DATEADD(MONTH, -1, CONVERT(date, GETDATE()))
  AND SO.SourceGenreID IN (10, 15)
--END - For Metric-08 we need to delete some data --------------------------------------------------------------------------


--For Metric-17 we need to change listener names and run ETL repeatedly ----------------------------------------------------
DECLARE @I int = 1

WHILE @I <= 3
BEGIN 
	WAITFOR DELAY '00:00:02'; 

	UPDATE MusicStream.dbo.Listener 
	SET ListenerName = CASE 
						  WHEN ListenerID = 3 THEN 'LIstenerName1'
						  WHEN ListenerID = 5 AND ListenerName IN ('LIstenerName1', 'LIstenerName2') THEN 'LIstenerName2'
						  WHEN ListenerID = 5 THEN 'LIstenerName1'
						  WHEN ListenerID = 7 AND ListenerName IN ('LIstenerName2', 'LIstenerName3') THEN 'LIstenerName3'
						  WHEN ListenerID = 7 AND ListenerName = 'LIstenerName1' THEN 'LIstenerName2'
						  WHEN ListenerID = 7 THEN 'LIstenerName1'
					   END	
	WHERE ListenerID IN (3, 5, 7)

	WAITFOR DELAY '00:00:02'; 

	EXEC MusicStreamDW.dbo.usp_ETL

	SET @I += 1
END
--END - For Metric-17 we need to change listener names and run ETL repeatedly ----------------------------------------------
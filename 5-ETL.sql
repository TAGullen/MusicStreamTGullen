
-----------------------------------------------------------------------------------------------------------------------------------------------------
--Basic ETL for MusicStreamDW from MusicStream

--For initial load and incremental updates
--Assumes DW and OLTP are on the same server

--Version History
--2025-05-16 TAG : Created
-----------------------------------------------------------------------------------------------------------------------------------------------------

USE MusicStreamDW;

SET XACT_ABORT ON;

--DimArtist (Type 1) -------------------------------------------------------------------------------------------------------
MERGE DimArtist AS target
USING (
	SELECT ArtistID AS SourceArtistID
	      ,ArtistName
    FROM MusicStream.dbo.Artist
	) AS source
 ON target.SourceArtistID = source.SourceArtistID
WHEN MATCHED AND target.ArtistName <> source.ArtistName THEN UPDATE SET ArtistName = source.ArtistName
                                                                       ,UpdatedDT  = GETDATE()
WHEN NOT MATCHED THEN INSERT (SourceArtistID
                             ,ArtistName
							 ,UpdatedDT
							 )
                      VALUES (source.SourceArtistID
					         ,source.ArtistName
							 ,GETDATE());
--END - DimArtist (Type 1) -------------------------------------------------------------------------------------------------


--DimListener (Type 2) -----------------------------------------------------------------------------------------------------
DECLARE @UpdatedListeners TABLE (
     SourceListenerID int PRIMARY KEY
	,ToDT			  smalldatetime
	);

UPDATE target
SET target.ToDT = DATEADD(minute, -1, GETDATE())
OUTPUT inserted.SourceListenerID
      ,inserted.ToDT
INTO @UpdatedListeners
FROM DimListener target
     JOIN MusicStream.dbo.Listener source
		ON target.SourceListenerID = source.ListenerID
WHERE target.ToDT >= '2079-01-01'
  AND (   target.ListenerName <> ISNULL(source.ListenerName, 'Unknown')
       OR target.Email <> ISNULL(source.Email, 'Unknown'))	

INSERT INTO DimListener (
	 SourceListenerID
    ,ListenerName
	,Email
	,CreatedDate
	,FromDT
	,ToDT
	,UpdatedDT
	)
SELECT
     SOR.ListenerID
    ,ISNULL(SOR.ListenerName, 'Unknown')
    ,ISNULL(SOR.Email, 'Unknown')
	,SOR.CreatedDate
    ,CASE 
		WHEN UPD.SourceListenerID IS NULL THEN '2000-01-01'
		ELSE DATEADD(minute, 1, UPD.ToDT)
	 END
    ,'2079-01-01'
    ,GETDATE()
FROM MusicStream.dbo.Listener SOR
     LEFT JOIN @UpdatedListeners UPD
			ON SOR.ListenerID = UPD.SourceListenerID
WHERE NOT EXISTS (SELECT *
                  FROM DimListener TAR
                  WHERE TAR.SourceListenerID = SOR.ListenerID 
				    AND TAR.ToDT >= '2079-01-01');
--END - DimListener (Type 2) -----------------------------------------------------------------------------------------------


--DimSong (Type 1) ---------------------------------------------------------------------------------------------------------
MERGE DimSong AS target
USING (
    SELECT SON.SongID AS SourceSongID, ISNULL(SON.SongName, 'Unknown') AS SongName, DIMART.SourceArtistID, DIMART.ArtistName, SON.Genre
    FROM MusicStream.dbo.Song SON
         LEFT JOIN MusicStreamDW.dbo.DimArtist DIMART 
		     ON ISNULL(SON.ArtistID, 0) = DIMART.SourceArtistID
) AS source
ON target.SourceSongID = source.SourceSongID
WHEN MATCHED AND (   target.SongName <> source.SongName 
                  OR target.SourceArtistID <> source.SourceArtistID
				  OR target.ArtistName <> source.ArtistName
				  OR target.Genre <> source.Genre)					THEN UPDATE SET  SongName       = ISNULL(source.SongName, 'Unknown')
																			        ,SourceArtistID = source.SourceArtistID
																					,ArtistName     = source.ArtistName
																					,Genre			= source.Genre
																					,UpdatedDT      = GETDATE()
WHEN NOT MATCHED THEN INSERT (
						 SourceSongID
						,SongName
						,SourceArtistID
						,ArtistName
						,Genre
						,UpdatedDT
						)
					  VALUES (
						 source.SourceSongID
						,ISNULL(source.SongName, 'Unknown')
						,source.SourceArtistID
						,source.ArtistName
						,source.Genre
						,GETDATE()
						);
--END - DimSong (Type 1) ---------------------------------------------------------------------------------------------------


--DimPlayList (Type 1) -----------------------------------------------------------------------------------------------------
MERGE DimPlayList AS target
USING (
    SELECT PLI.PlayListID AS SourcePlayListID, ISNULL(PLI.PlayListName, 'Unknown') AS PlayListName, DIMLIS.SourceListenerID, DIMLIS.ListenerName
    FROM MusicStream.dbo.PlayList PLI
         LEFT JOIN MusicStreamDW.dbo.DimListener DIMLIS 
			ON ISNULL(PLI.ListenerID, 0) = DIMLIS.SourceListenerID
           AND DIMLIS.ToDT >= '2079-01-01'
    
) AS source
ON target.SourcePlayListID = source.SourcePlayListID
WHEN MATCHED AND (   target.PlayListName <> source.PlayListName 
                  OR target.SourceListenerID <> source.SourceListenerID
				  OR target.ListenerName <> source.ListenerName)		THEN UPDATE SET PlayListName	 = ISNULL(source.PlayListName, 'Unknown')
																					   ,SourceListenerID = source.SourceListenerID
																					   ,ListenerName	 = source.ListenerName
																					   ,UpdatedDT		 = GETDATE()
WHEN NOT MATCHED THEN INSERT (
						 SourcePlayListID
						,PlayListName
						,SourceListenerID
						,ListenerName
						,UpdatedDT
						)
					  VALUES (
						 source.SourcePlayListID
						,ISNULL(source.PlayListName, 'Unknown')
						,source.SourceListenerID
						,source.ListenerName
						,GETDATE()
						);
--END - DimPlayList (Type 1) -----------------------------------------------------------------------------------------------


--FactPlayListSong (Factless Fact) -----------------------------------------------------------------------------------------
INSERT INTO FactPlayListSong (
	 PlayListKey
	,SongKey
	,UpdatedDT
	)
SELECT
    DP.PlayListKey,
    DS.SongKey,
    GETDATE()
FROM MusicStream.dbo.PlayListSong PS
     JOIN DimPlayList DP 
			ON PS.PlayListID = DP.SourcePlayListID
     JOIN DimSong DS 
			ON PS.SongID = DS.SourceSongID
     LEFT JOIN FactPlayListSong F 
			ON F.PlayListKey = DP.PlayListKey 
		   AND F.SongKey = DS.SongKey
WHERE F.PlayListSongKey IS NULL;

DELETE FactPlayListSong
FROM FactPlayListSong FAC
     INNER JOIN DimPlayList DIMPL
			ON FAC.PlayListKey = DIMPL.PlayListKey
     INNER JOIN DimSong DIMSO
			ON FAC.SongKey = DIMSO.SongKey
     LEFT JOIN MusicStream.dbo.PlayListSong PS
		ON DIMPL.SourcePlayListID = PS.PlayListID
       AND DIMSO.SourceSongID = PS.SongID
WHERE PS.PlayListID IS NULL;
--END - FactPlayListSong (Factless Fact) -----------------------------------------------------------------------------------


--FactPlayHistory ----------------------------------------------------------------------------------------------------------
INSERT INTO FactPlayHistory (
	 ListenerKey
	,SongKey
	,PlayDateKey
	,UpdatedDT
	)
SELECT
     DL.ListenerKey
	,DS.SongKey
    ,CONVERT(INT, FORMAT(PH.PlayDate, 'yyyyMMdd')) AS PlayDateKey
    ,GETDATE()
FROM MusicStream.dbo.PlayHistory PH     
     JOIN DimListener DL 
			ON PH.ListenerID = DL.SourceListenerID 
		   AND PH.PlayDate BETWEEN DL.FromDT AND DL.ToDT
     JOIN DimSong DS 
			ON PH.SongID = DS.SourceSongID
     LEFT JOIN FactPlayHistory F 
			ON F.ListenerKey = DL.ListenerKey 
		   AND F.SongKey = DS.SongKey 
		   AND F.PlayDateKey = CONVERT(INT, FORMAT(PH.PlayDate, 'yyyyMMdd'))
WHERE F.PlayHistoryKey IS NULL;
--END - FactPlayHistory ----------------------------------------------------------------------------------------------------


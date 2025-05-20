
----------------------------------------------------------------------------------------------------------------------------
--MusicStream DB, Populate Tables

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------

SET XACT_ABORT ON
SET NOEXEC OFF

USE MusicStream

--Create Temp SP #GenerateName =============================================================================================
SET ANSI_NULLS ON
SET QUOTED_IDENTIFIER ON

DROP PROCEDURE IF EXISTS #GenerateName
GO
IF @@ERROR <> 0 SET NOEXEC ON
GO
CREATE PROCEDURE #GenerateName(
	 @Prefix varchar(2) = ''
	,@Length tinyint
	,@GeneratedName varchar(300) OUTPUT 
	)
AS

--This temporary SP creates random alphabetical squences 
SET NOCOUNT ON;

DECLARE @RetVal varchar(300)
DECLARE @I int = 1

SET @GeneratedName = @Prefix 
WHILE @I <= @Length 
BEGIN
	SET @GeneratedName += CHAR(97 + FLOOR(RAND() * 26))
	SET @I += 1
END 
GO
--END - Create Temp SP #GenerateName =======================================================================================


--Empty Tables =============================================================================================================
--DO NOT DELETE THIS SECTION -----------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM Artist) INSERT INTO Artist (ArtistName) VALUES ('X');			--<--Do NOT delete. It affects RESEEDING
IF NOT EXISTS (SELECT * FROM Song) INSERT INTO Song (SongName) VALUES ('X');				--<--Do NOT delete. It affects RESEEDING
IF NOT EXISTS (SELECT * FROM PlayList) INSERT INTO PlayList (PlayListName) VALUES ('X');	--<--Do NOT delete. It affects RESEEDING
IF NOT EXISTS (SELECT * FROM Listener) INSERT INTO Listener (ListenerName, CreatedDate) VALUES ('X', GETDATE());  --<--Do NOT delete. It affects RESEEDING
--END - DO NOT DELETE THIS SECTION -----------------------------------------------------------------------------------------

DELETE PlaylistSong
DELETE PlayHistory
DELETE PlayList
DELETE Song
DELETE Artist
DELETE Listener

DBCC CHECKIDENT ('Artist', RESEED, 0);
DBCC CHECKIDENT ('Song', RESEED, 0);
DBCC CHECKIDENT ('Listener', RESEED, 0);
DBCC CHECKIDENT ('PlayList', RESEED, 0);

--IMPORTANT!
--WE MUST ALSO EMPTY DW DATABASE AS WELL
--BECAUSE ALL TEXTS GENERATED HERE ARE RANDOM YET IDS REMAIN THE SAME!
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'MusicStreamDW')
BEGIN 
	DELETE MusicStreamDW.dbo.DimArtist WHERE SourceArtistID > 0
	DELETE MusicStreamDW.dbo.DimListener WHERE SourceListenerID > 0
	DELETE MusicStreamDW.dbo.DimSong WHERE SourceSongID > 0
	DELETE MusicStreamDW.dbo.DimPlayList WHERE SourcePlayListID > 0
	TRUNCATE TABLE MusicStreamDW.dbo.FactPlayListSong
	TRUNCATE TABLE MusicStreamDW.dbo.FactPlayHistory
END
--END - For DETERMINISTIC IDs uncomment this section -------------------
--END - Empty Tables =======================================================================================================


--Populate Tables ==========================================================================================================
IF @@ERROR <> 0 SET NOEXEC ON
DECLARE @Name		 varchar(100)
DECLARE @I			 int
DECLARE @NoOfRecords int
DECLARE @ArtistID	 int
DECLARE @ListenerID	 int
DECLARE @PlayListID	 int


--Artist ------------------------------------------------------------------------------------------
--Methodology ----
--Generate random texts with length = 10, prefixed by AR
SET @NoOfRecords = 100 --<== Number of records 
SET @I = 1
WHILE @I <= @NoOfRecords
BEGIN
    EXEC #GenerateName 'AR', 10, @Name OUTPUT

    IF NOT EXISTS (SELECT * FROM Artist WHERE ArtistName = @Name)
    BEGIN
        INSERT INTO Artist (ArtistName) VALUES (@Name);
        SET @I += 1;
    END
END
--END - Artist ------------------------------------------------------------------------------------


--Listener ----------------------------------------------------------------------------------------
--Methodology ----
--1-Generate random texts with length = 10, prefixed by LI 
--2-Use first 5 charactes of the name generated (excluding LI) as the email. All emails will have @abcd.com
--3-Make sure records with NULL values in ListenerName and Email exist (as it is allowed)
--4-Make sure duplicated ListenerNames and Emails exist (as this may be a real life scenario)
DROP TABLE IF EXISTS #tmpListeners
CREATE TABLE #tmpListeners (
	 RowNum int IDENTITY(1, 1) PRIMARY KEY
	,ListenerID int
	,ListenerName varchar(100)
	,Email varchar(100)
	)

--Populate
SET @NoOfRecords = 200 --<== Number of records
SET @I = 1
WHILE @I <= @NoOfRecords
BEGIN
    EXEC #GenerateName 'LI', 10, @Name OUTPUT

    IF NOT EXISTS (SELECT * FROM Listener WHERE ListenerName = @Name)
    BEGIN
        INSERT INTO Listener (ListenerName, Email, CreatedDate) 
		VALUES (@Name, RIGHT(LEFT(LOWER(@Name), 7), 5) + '@abcd.com', DATEADD(day, @I, '2024-07-01'));
        SET @I += 1;
    END
END

--Create NULL ListenerName, Email ---------------
INSERT INTO #tmpListeners (ListenerID, ListenerName, Email)
SELECT TOP 21 ListenerID, ListenerName, Email
FROM Listener
ORDER BY ListenerID

UPDATE Listener
SET ListenerName = NULL
   ,Email        = NULL 
WHERE ListenerID IN (SELECT ListenerID
                     FROM #tmpListeners
					 WHERE RowNum BETWEEN 1 AND 5)

UPDATE Listener
SET ListenerName = NULL
WHERE ListenerID IN (SELECT ListenerID
                     FROM #tmpListeners
					 WHERE RowNum BETWEEN 6 AND 10)

UPDATE Listener
SET Email = NULL
WHERE ListenerID IN (SELECT ListenerID
                     FROM #tmpListeners
					 WHERE RowNum BETWEEN 11 AND 15)
--END - Create NULL ListenerName, Email ---------

--Create some duplicate Emails ------------------
UPDATE Listener
SET Email = (SELECT Email FROM #tmpListeners WHERE RowNum = 6)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum = 7)

UPDATE Listener
SET Email = (SELECT Email FROM #tmpListeners WHERE RowNum = 16)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum BETWEEN 9 AND 10)

UPDATE Listener
SET Email = (SELECT Email FROM #tmpListeners WHERE RowNum = 18)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum = 17)
--END - Create some duplicate Emails ------------

--Create some duplicate ListenerNames -----------
UPDATE Listener
SET ListenerName = (SELECT ListenerName FROM #tmpListeners WHERE RowNum = 11)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum = 12)

UPDATE Listener
SET ListenerName = (SELECT ListenerName FROM #tmpListeners WHERE RowNum = 19)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum BETWEEN 14 AND 15)

UPDATE Listener
SET ListenerName = (SELECT ListenerName FROM #tmpListeners WHERE RowNum = 21)
WHERE ListenerID IN (SELECT ListenerID FROM #tmpListeners WHERE RowNum = 20)
--END - Create some duplicate ListenerNames -----
--END - Listener ----------------------------------------------------------------------------------


--Song --------------------------------------------------------------------------------------------
--Methodology ----
--1-For song names generate a name is a random texts with length=10, prefixed by SO 
--2-Loop through Atrists, for first ArtistID generate 1 song, for next Artist 2 songs and next one 3 songs 
--3 SKIP every 11th Artist to make sure some artist entries have no corresponding songs (as it is allowed)
--4-Make sure records with NULL values in SongName and ArtistID exist (as it is allowed)
--5-Make sure duplicated SongName and ArtistIDs exist (as this may be a real life scenario)

DROP TABLE IF EXISTS #tmpSongs
CREATE TABLE #tmpSongs (
	 RowNum int IDENTITY(1, 1) PRIMARY KEY
	,SongID int
	,SongName varchar(100)
	,ArtistID int
	)

DECLARE @Genre varchar(100)

--Populate
SET @ArtistID = (SELECT MIN(ArtistID) FROM Artist) 
WHILE @ArtistID <= (SELECT MAX(ArtistID) FROM Artist) 
BEGIN
	IF @ArtistID % 11 > 0 --<== Skip 11th of the artists intentionally
	BEGIN
		--Insert 1 song for a 3rd of artists, 2 songs for another 3rd, and 3 songs for the rest based on ArtistID
		SET @I = 1
		WHILE @I <= 3
		BEGIN 
			EXEC #GenerateName 'SO', 10, @Name OUTPUT	
	        EXEC #GenerateName 'GE', 1, @Genre OUTPUT	

			IF NOT EXISTS (SELECT * FROM Song WHERE SongName = @Name AND ArtistID = @ArtistID)
			INSERT INTO Song (SongName, ArtistID, Genre) VALUES (@Name, @ArtistID, @Genre);
	
			--Decide if enough songs entered
			IF (@ArtistID % 3) + 1 = @I
				BREAK
			ELSE
				SET @I += 1
		END
	END

	SET @ArtistID = (SELECT MIN(ArtistID) FROM Artist WHERE ArtistID > @ArtistID) 
END 

--Create NULL SongName, ArtistID ----------------
INSERT INTO #tmpSongs (SongID, SongName, ArtistID)
SELECT TOP 23 SongID, SongName, ArtistID
FROM Song
ORDER BY SongID

UPDATE Song
SET SongName = NULL
   ,ArtistID = NULL 
WHERE SongID IN (SELECT SongID
                     FROM #tmpSongs
					 WHERE RowNum = 1)

UPDATE Song
SET SongName = NULL
WHERE SongID IN (SELECT SongID
                     FROM #tmpSongs
					 WHERE RowNum = 2)

UPDATE Song
SET ArtistID = NULL
WHERE SongID IN (SELECT SongID
                     FROM #tmpSongs
					 WHERE RowNum = 3)
--END - Create NULL SongName, ArtistID ----------

--Create some duplicate ArtistIDs ---------------
UPDATE Song
SET ArtistID = (SELECT ArtistID FROM #tmpSongs WHERE RowNum = 6)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum = 7)

UPDATE Song
SET ArtistID = (SELECT ArtistID FROM #tmpSongs WHERE RowNum = 16)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum BETWEEN 9 AND 10)

UPDATE Song
SET ArtistID = (SELECT ArtistID FROM #tmpSongs WHERE RowNum = 18)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum = 17)
--END - Create some duplicate ArtistIDs ---------

--Create some duplicate SongNames ---------------
UPDATE Song
SET SongName = (SELECT SongName FROM #tmpSongs WHERE RowNum = 11)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum = 12)

UPDATE Song
SET SongName = (SELECT SongName FROM #tmpSongs WHERE RowNum = 19)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum BETWEEN 14 AND 15)

UPDATE Song
SET SongName = (SELECT SongName FROM #tmpSongs WHERE RowNum = 23)
WHERE SongID IN (SELECT SongID FROM #tmpSongs WHERE RowNum = 20)
--END - Create some duplicate SongNames ---------
----END - Song ------------------------------------------------------------------------------------


--PlayList ----------------------------------------------------------------------------------------
--Methodology ----
--1-For playlist names generate a name is a random texts with length=10, prefixed by PL
--2-Loop through listeners, for first ListenerID generate 1 playlist, for next listener 2 playlists and next one 3 playlists
--3 SKIP every 10th listener to make sure some listeners have no corresponding playlists (as it is allowed)
--4-Make sure records with NULL values in PlaylistName and ListenerID exist (as it is allowed)
--5-Make sure duplicated PlaylistName and ListenerIDs exist (as this may be a real life scenario)

DROP TABLE IF EXISTS #tmpPlayLists
CREATE TABLE #tmpPlayLists (
	 RowNum int IDENTITY(1, 1) PRIMARY KEY
	,PlayListID int
	,PlayListName varchar(100)
	,ListenerID int
	)

--Populate
SET @ListenerID = (SELECT MIN(ListenerID) FROM Listener) 
WHILE @ListenerID <= (SELECT MAX(ListenerID) FROM Listener) 
BEGIN
	IF @ListenerID % 10 > 0 --<== Skip 10th of the Listeners intentionally
	BEGIN
		--Insert 1 playlist for a 3rd of Listeners, 2 playlists for another 3rd, and 3 playlists for the rest based on ListenerID
		SET @I = 1
		WHILE @I <= 3
		BEGIN 
			EXEC #GenerateName 'PL', 10, @Name OUTPUT	
	    
			IF NOT EXISTS (SELECT * FROM Playlist WHERE PlaylistName = @Name AND ListenerID = @ListenerID)
			INSERT INTO Playlist (PlaylistName, ListenerID) VALUES (@Name, @ListenerID);
	
			--Decide if enough Playlists entered
			IF (@ListenerID % 3) + 1 = @I
				BREAK
			ELSE
				SET @I += 1
		END
	END

	SET @ListenerID = (SELECT MIN(ListenerID) FROM Listener WHERE ListenerID > @ListenerID) 
END 

--Create NULL PlaylistName, ListenerID ----------------
INSERT INTO #tmpPlaylists (PlaylistID, PlaylistName, ListenerID)
SELECT TOP 23 PlaylistID, PlaylistName, ListenerID
FROM Playlist
ORDER BY PlaylistID

UPDATE Playlist
SET PlaylistName = NULL
   ,ListenerID = NULL 
WHERE PlaylistID IN (SELECT PlaylistID
                     FROM #tmpPlaylists
					 WHERE RowNum BETWEEN 1 AND 5)

UPDATE Playlist
SET PlaylistName = NULL
WHERE PlaylistID IN (SELECT PlaylistID
                     FROM #tmpPlaylists
					 WHERE RowNum BETWEEN 6 AND 10)

UPDATE Playlist
SET ListenerID = NULL
WHERE PlaylistID IN (SELECT PlaylistID
                     FROM #tmpPlaylists
					 WHERE RowNum BETWEEN 11 AND 15)
--END - Create NULL PlaylistName, ListenerID ----------

--Create some duplicate ListenerIDs ---------------
UPDATE Playlist
SET ListenerID = (SELECT ListenerID FROM #tmpPlaylists WHERE RowNum = 6)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum = 7)

UPDATE Playlist
SET ListenerID = (SELECT ListenerID FROM #tmpPlaylists WHERE RowNum = 16)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum BETWEEN 9 AND 10)

UPDATE Playlist
SET ListenerID = (SELECT ListenerID FROM #tmpPlaylists WHERE RowNum = 18)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum = 17)
--END - Create some duplicate ListenerIDs ---------

--Create some duplicate PlaylistNames ---------------
UPDATE Playlist
SET PlaylistName = (SELECT PlaylistName FROM #tmpPlaylists WHERE RowNum = 11)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum = 12)

UPDATE Playlist
SET PlaylistName = (SELECT PlaylistName FROM #tmpPlaylists WHERE RowNum = 19)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum BETWEEN 14 AND 15)

UPDATE Playlist
SET PlaylistName = (SELECT PlaylistName FROM #tmpPlaylists WHERE RowNum = 23)
WHERE PlaylistID IN (SELECT PlaylistID FROM #tmpPlaylists WHERE RowNum = 20)
--END - Create some duplicate PlaylistNames ---------
--END - PlayList ----------------------------------------------------------------------------------


--PlayListSong ------------------------------------------------------------------------------------
--Methodology ----
--1-Loop through playlists
--2-Insert 0 song for the first PlayList, 1 song for the next, 2, 3, ... 9 songs for the next PlayLists then start with 0 song again
--3-Remember which song was entered last and continue with the next song next time.
--4-When the songs list exhausted, start again from the first song ensuring same song is included in multiple playlists (many-to-many matching)

DECLARE @tblSongIDs TABLE (SongID int NOT NULL PRIMARY KEY)
DECLARE @LastSongID       int
DECLARE @NumOfSongsWanted int
DECLARE @NumOfSongsPicked int 

--Populate
SET @NumOfSongsWanted = -1                                     --<==Start with -1 as it will be incremented
SET @LastSongID       = -1                                     --<==Start with less than min SongID
SET @PlayListID       = (SELECT MIN(PlayListID) FROM PlayList) --<==Start with the min PlayListID

WHILE @PlayListID IS NOT NULL
BEGIN
	--Insert 0 song for the first PlayList, 1 song for the next, 2, 3, ... 9 songs for the next PlayLists then start from 0 again based on CIRCULAR @NumOfSongsWanted	
	SET @NumOfSongsWanted = (@NumOfSongsWanted + 1) % 10

	DELETE FROM @tblSongIDs
	INSERT INTO @tblSongIDs
	SELECT TOP(@NumOfSongsWanted) SongID --<==Insert no of records based on @NumOfSongsWanted 
	FROM Song
	WHERE SongID > @LastSongID
	ORDER BY SongID
		
	SET @NumOfSongsPicked = (SELECT COUNT(*) FROM @tblSongIDs)

	--Insert the picked Songs
	INSERT INTO PlayListSong (PlayListID, SongID)
	SELECT @PlayListID, SongID
	FROM @tblSongIDs

	--If not enough songs picked it means we've reached the end of Songs table. So, start from the beginnig again.
	IF @NumOfSongsPicked < @NumOfSongsWanted 
	BEGIN
		--Go back to the beginning of Song table
		SET @LastSongID = -1

		DELETE FROM @tblSongIDs
		INSERT INTO @tblSongIDs
		SELECT TOP(@NumOfSongsWanted - @NumOfSongsPicked) SongID --<==Insert the missing IDs
		FROM Song
		WHERE SongID > @LastSongID
		ORDER BY SongID

		--Insert the picked Songs
		INSERT INTO PlayListSong (PlayListID, SongID)
		SELECT @PlayListID, SongID
		FROM @tblSongIDs
	END

	--Remember the last SongID
	SET @LastSongID = ISNULL((SELECT MAX(SongID) FROM @tblSongIDs), @LastSongID)

	--Set the next PlayListID
	SET @PlayListID = (SELECT MIN(PlayListID) FROM PlayList WHERE PlayListID > @PlayListID) 
END 
--END - PlayListSong ------------------------------------------------------------------------------


--PlayHistory -------------------------------------------------------------------------------------
DECLARE @PlayDateFirst date
DECLARE @PlayDateLast  date
DECLARE @PlayDate      date
DECLARE @ListenerIDs  TABLE (ListenerID int PRIMARY KEY)

--Methodology --------
--1-Assign a listening frequency (F) for each listener from 0 to 16. Listeners with F=0 never listen anything. Others listen songs once every F days.
--2-Step through days from @PlayDateFirst to @PlayDateLast
--3-On each day, determine the listeners who will listen songs on that day based on frequency (F) explained above
--4-Loop through the listeners of the day and assign songs from 1 to 13 to each of them (another prime number to avoid pattern repetition)
--5-Remember the last song entered and continue with the next song next time.
--4-When the songs list exhausted, start again from the first song and continue
--6-When all listeners of the day looped through, move onto the next day and prepare a new listeners list for the next day and continue until the last day.
--7-This ensures for ech day, there are a sunbset of listeners listen varying number of songs and some listeners never listen anything (a likely real life scenario).

--Populate
SET @PlayDateFirst    = '2024-07-01'
SET @PlayDateLast     = '2025-05-20'
SET @PlayDate         = @PlayDateFirst
SET @NumOfSongsWanted = 0                                        --<==Start with 0 but first value USED will be 1. Will repeat from 1 to 19
SET @LastSongID       = -1                                       --<==Start with less than min SongID

WHILE @PlayDate <= @PlayDateLast --DATE LOOP --------------------------
BEGIN
    --Determine all listeners on the day
	DELETE @ListenerIDs
	INSERT INTO @ListenerIDs
	SELECT ListenerID
	FROM Listener 
	WHERE (ListenerID % 17) > 0 
	  AND (DATEDIFF(day, @PlayDateFirst, @PlayDate) + 1) % (ListenerID % 17) = 0
		
	SET @ListenerID = (SELECT MIN(ListenerID) FROM @ListenerIDs) --<==Start with the min ListenerID of the day

	WHILE @ListenerID IS NOT NULL --LISTENER LOOP -------------------
	BEGIN
	    --SELECT @ListenerID

		--Insert 1 song for the first listener, 2, 3, ... 19 songs for the next listeners then start from 1 again based on CIRCULAR @NumOfSongsWanted	
		SET @NumOfSongsWanted = @NumOfSongsWanted % 19 + 1

		DELETE FROM @tblSongIDs
		INSERT INTO @tblSongIDs
		SELECT TOP(@NumOfSongsWanted) SongID --<==Insert no of records based on @NumOfSongsWanted 
		FROM Song
		WHERE SongID > @LastSongID
		ORDER BY SongID
		
		SET @NumOfSongsPicked = (SELECT COUNT(*) FROM @tblSongIDs)

		--Insert the picked Songs
		INSERT INTO PlayHistory (ListenerID, SongID, PlayDate)
		SELECT @ListenerID, SongID, @PlayDate
		FROM @tblSongIDs

		--If not enough songs picked it means we've reached the end of Songs table. So, start from the beginnig again.
		IF @NumOfSongsPicked < @NumOfSongsWanted 
		BEGIN
			--Go back to the beginning of Song table
			SET @LastSongID = -1

			DELETE FROM @tblSongIDs
			INSERT INTO @tblSongIDs
			SELECT TOP(@NumOfSongsWanted - @NumOfSongsPicked) SongID --<==Insert the missing IDs
			FROM Song
			WHERE SongID > @LastSongID
			ORDER BY SongID

			--Insert the picked Songs
			INSERT INTO PlayHistory (ListenerID, SongID, PlayDate)
			SELECT @ListenerID, SongID, @PlayDate
			FROM @tblSongIDs
		END

		--Remember the last SongID
		SET @LastSongID = (SELECT MAX(SongID) FROM @tblSongIDs)

		--Set the next ListenerID
		SET @ListenerID = (SELECT MIN(ListenerID) FROM @ListenerIDs WHERE ListenerID > @ListenerID)
	END 

	SET @PlayDate = DATEADD(day, 1, @PlayDate)
END

--Delete records before Listener.CreatedDate
DELETE PlayHistory
FROM Listener LST
     INNER JOIN PlayHistory HIS
			ON LST.ListenerID = HIS.ListenerID
WHERE LST.CreatedDate > HIS.PlayDate
--END - PlayHistory -------------------------------------------------------------------------------
--END - Populate Tables ====================================================================================================
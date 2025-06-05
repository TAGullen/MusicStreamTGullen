
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
IF @@ERROR <> 0 SET NOEXEC ON

--DO NOT DELETE THIS SECTION -----------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM Genre) INSERT INTO Genre (GenreName) VALUES ('X');			    --<--Do NOT delete. It affects RESEEDING
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
DELETE Genre
DELETE Listener

DBCC CHECKIDENT ('Genre', RESEED, 0);
DBCC CHECKIDENT ('Artist', RESEED, 0);
DBCC CHECKIDENT ('Song', RESEED, 0);
DBCC CHECKIDENT ('Listener', RESEED, 0);
DBCC CHECKIDENT ('PlayList', RESEED, 0);

--DO NOT DELETE THIS SECTION --------------------------------------------------------------------------------
--WE MUST EMPTY DW DATABASE AS WELL BECAUSE ALL TEXTS GENERATED ARE RANDOM YET IDS WILL REMAIN THE SAME!
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'MusicStreamDW')
BEGIN 
	IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[DimGenre]') AND type in ('U'))
		DELETE MusicStreamDW.dbo.DimGenre WHERE SourceGenreID > 0
	DELETE MusicStreamDW.dbo.DimArtist WHERE SourceArtistID > 0
	DELETE MusicStreamDW.dbo.DimListener WHERE SourceListenerID > 0
	DELETE MusicStreamDW.dbo.DimSong WHERE SourceSongID > 0
	DELETE MusicStreamDW.dbo.DimPlayList WHERE SourcePlayListID > 0
	DELETE MusicStreamDW.dbo.FactPlayListSong
	DELETE MusicStreamDW.dbo.FactPlayHistory
END
--DO NOT DELETE THIS SECTION --------------------------------------------------------------------------------
--END - Empty Tables =======================================================================================================


--Populate Tables ==========================================================================================================
DECLARE @Name		 varchar(100)
DECLARE @I			 int
DECLARE @NoOfRecords int
DECLARE @ArtistID	 int
DECLARE @GenreID	 int
DECLARE @ListenerID	 int
DECLARE @PlayListID	 int


--Genre -------------------------------------------------------------------------------------------
--Methodology ----
--Generate random texts with length = 2, prefixed by GEN
SET @NoOfRecords = 25 --<== Number of records 
SET @I = 1
WHILE @I <= @NoOfRecords
BEGIN
    EXEC #GenerateName 'GEN', 2, @Name OUTPUT

    IF NOT EXISTS (SELECT * FROM Genre WHERE GenreName = @Name)
    BEGIN
        INSERT INTO Genre (GenreName) VALUES (@Name);
        SET @I += 1;
    END
END
--END - Genre -------------------------------------------------------------------------------------


--Artist ------------------------------------------------------------------------------------------
--Methodology ----
--Generate random texts with length = 6, prefixed by ART
SET @NoOfRecords = 100 --<== Number of records 
SET @I = 1
WHILE @I <= @NoOfRecords
BEGIN
    EXEC #GenerateName 'ART', 6, @Name OUTPUT

    IF NOT EXISTS (SELECT * FROM Artist WHERE ArtistName = @Name)
    BEGIN
        INSERT INTO Artist (ArtistName) VALUES (@Name);
        SET @I += 1;
    END
END
--END - Artist ------------------------------------------------------------------------------------


--Listener ----------------------------------------------------------------------------------------
--Methodology ----
--1-Generate random texts with length = 6, prefixed by LIS 
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
SET @NoOfRecords = 300 --<== Number of records
SET @I = 1
WHILE @I <= @NoOfRecords
BEGIN
    EXEC #GenerateName 'LIS', 6, @Name OUTPUT

    IF NOT EXISTS (SELECT * FROM Listener WHERE ListenerName = @Name)
    BEGIN
        INSERT INTO Listener (ListenerName, Email, CreatedDate) 
		VALUES (@Name, RIGHT(LEFT(LOWER(@Name), 7), 5) + '@abcd.com', DATEADD(day, @I, '2024-01-01'));
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
--1-For song names generate a name with a random text with length=6, prefixed by SON 
--2-Loop through Atrists, generate x number of songs, x being a random integer between 0 and 20 (0 included intentionally)
--3-Pick up a random GenreID for the song
--4-Make sure records with NULL values in SongName and ArtistID exist (as it is allowed)
--5-Make sure duplicated SongName and ArtistIDs exist (but NOT both, as this may be a real life scenario)

DROP TABLE IF EXISTS #tmpSongs
CREATE TABLE #tmpSongs (
	 RowNum int IDENTITY(1, 1) PRIMARY KEY
	,SongID int
	,SongName varchar(100)
	,ArtistID int
	)

--Populate
SET @ArtistID = (SELECT MIN(ArtistID) FROM Artist) 
WHILE @ArtistID IS NOT NULL 
BEGIN
	--Insert a random number of songs for the artist
	SET @NoOfRecords = CONVERT(int, ROUND(RAND() * 20, 0)) 
		
	SET @I = 1
	WHILE @I <= @NoOfRecords
	BEGIN 
		EXEC #GenerateName 'SON', 6, @Name OUTPUT	

	    SELECT TOP 1 @GenreID = GenreID
		FROM Genre
		ORDER BY NEWID()

		IF NOT EXISTS (SELECT * FROM Song WHERE SongName = @Name AND ArtistID = @ArtistID)
		BEGIN 
			INSERT INTO Song (SongName, ArtistID, GenreID) VALUES (@Name, @ArtistID, @GenreID);
			SET @I += 1
		END								
	END

	--Increment ArtistID
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
----END - Song ------------------------------------------------------------------------------------


--PlayList ----------------------------------------------------------------------------------------
--Methodology ----
--1-For playlist names generate a name with a random text with length=6, prefixed by PLA
--2-Loop through listeners, generate x number of playLists, x being a random integer between 0 and 15 (0 included intentionally)
--3-Make sure records with NULL values in PlaylistName and ListenerID exist (as it is allowed)
--4-Make sure duplicated PlaylistName and ListenerIDs exist (as this may be a real life scenario)

DROP TABLE IF EXISTS #tmpPlayLists
CREATE TABLE #tmpPlayLists (
	 RowNum int IDENTITY(1, 1) PRIMARY KEY
	,PlayListID int
	,PlayListName varchar(100)
	,ListenerID int
	)

--Populate
SET @ListenerID = (SELECT MIN(ListenerID) FROM Listener) 
WHILE @ListenerID IS NOT NULL 
BEGIN
	--Insert a random number of playlists for the song
	SET @NoOfRecords = CONVERT(int, ROUND(RAND() * 15, 0)) 
	
	SET @I = 1
	WHILE @I <= @NoOfRecords
	BEGIN 
		EXEC #GenerateName 'PLA', 6, @Name OUTPUT	
	    
		IF NOT EXISTS (SELECT * FROM Playlist WHERE PlaylistName = @Name AND ListenerID = @ListenerID)
		BEGIN 
			INSERT INTO Playlist (PlaylistName, ListenerID) VALUES (@Name, @ListenerID);	
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
--END - PlayList ----------------------------------------------------------------------------------


--PlayListSong ------------------------------------------------------------------------------------
--Methodology ----
--Loop through playlists, randomly pick up x number of songs, x itself being a random integer between 0 and 30 (0 included intentionally)

--Populate
SET @PlayListID = (SELECT MIN(PlayListID) FROM PlayList) --<==Start with the min PlayListID

WHILE @PlayListID IS NOT NULL
BEGIN
	SET @NoOfRecords = CONVERT(int, ROUND(RAND() * 30, 0))

	--Insert the picked Songs
	INSERT INTO PlayListSong (PlayListID, SongID)
	SELECT TOP(@NoOfRecords) @PlayListID, SongID 
	FROM Song
	ORDER BY NEWID()
	
	--Set the next PlayListID
	SET @PlayListID = (SELECT MIN(PlayListID) FROM PlayList WHERE PlayListID > @PlayListID) 
END 
--END - PlayListSong ------------------------------------------------------------------------------


--PlayHistory -------------------------------------------------------------------------------------
DECLARE @PlayDateFirst			date
DECLARE @PlayDateLast			date
DECLARE @PlayDate				date
DECLARE @NoOfDaysSelected		int
DECLARE @tblPlayDatesSelected	TABLE (theDate date PRIMARY KEY)
DECLARE @tblPlayDatesAll		TABLE (theDate date PRIMARY KEY)
DECLARE @CreatedDate			date

--Methodology --------
--1-Loop through the listeners and decide the days each listener listened songs. 
--2-Loop through each day and randomly enter some songs into PlayHistory table for this user and day.

--Populate
SET @PlayDateFirst    = '2024-01-01'
SET @PlayDateLast     = GETDATE()
SET @PlayDate         = @PlayDateFirst

--Build the 'all dates' table
WHILE @PlayDate <= @PlayDateLast
BEGIN
	INSERT INTO @tblPlayDatesAll 
	VALUES (@PlayDate)

	SET @PlayDate = DATEADD(day, 1, @PlayDate)
END

SET @ListenerID = (SELECT MIN(ListenerID) FROM Listener) 
WHILE @ListenerID IS NOT NULL 
BEGIN
	SET @CreatedDate = (SELECT CreatedDate FROM Listener WHERE ListenerID = @ListenerID)
	SET @NoOfDaysSelected = CONVERT(int, ROUND(RAND() * DATEDIFF(day, @CreatedDate, @PlayDateLast), 0)) 

	DELETE @tblPlayDatesSelected 
	INSERT INTO @tblPlayDatesSelected 
	SELECT TOP (@NoOfDaysSelected) TheDate
	FROM @tblPlayDatesAll
	WHERE TheDate >= @CreatedDate
	ORDER BY NEWID()

	SET @PlayDate = (SELECT MIN(theDate) FROM @tblPlayDatesSelected) 
	WHILE @PlayDate IS NOT NULL
	BEGIN 
		--Insert a random number of songs
		SET @NoOfRecords = CONVERT(int, ROUND(RAND() * 50, 0)) 	
	    
		INSERT INTO PlayHistory (ListenerID, SongID, PlayDate) 
		SELECT TOP(@NoOfRecords) @ListenerID, SongID, @PlayDate
		FROM Song
		ORDER BY NEWID()

		SET @PlayDate = (SELECT MIN(theDate) FROM @tblPlayDatesSelected WHERE theDate > @PlayDate)  
	END

	SET @ListenerID = (SELECT MIN(ListenerID) FROM Listener WHERE ListenerID > @ListenerID) 
END 
--END - Populate Tables ====================================================================================================
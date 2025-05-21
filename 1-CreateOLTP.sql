
----------------------------------------------------------------------------------------------------------------------------
--MusicStream DB Create Database and Structure

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------

USE master

SET XACT_ABORT ON
SET NOEXEC OFF

--Create MusicStream ------------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MusicStream')
CREATE DATABASE MusicStream
GO
--END-Create MusicStream --------------------------------------------------------------------------


--Drop Tables -------------------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON
USE MusicStream

DROP TABLE IF EXISTS PlaylistSong
DROP TABLE IF EXISTS PlayHistory
DROP TABLE IF EXISTS PlayList
DROP TABLE IF EXISTS Song
DROP TABLE IF EXISTS Artist
DROP TABLE IF EXISTS Listener
GO
--END - Drop Tables -------------------------------------------------------------------------------


--Create Tables -----------------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON

--Artist
CREATE TABLE Artist (
	 ArtistID	int			 NOT NULL IDENTITY(1,1) 
	,ArtistName	varchar(100) NOT NULL
	,CONSTRAINT PK_Artist PRIMARY KEY (ArtistID)
	,CONSTRAINT UQ_ArtistName UNIQUE (ArtistName)
	,CONSTRAINT CK_ArtistName CHECK (TRIM(ArtistName)<>'')        --<== Blanks disallowed
	)

--Song
CREATE TABLE Song (
	 SongID		int	NOT NULL IDENTITY(1,1)
	,SongName	varchar(100) 
	,ArtistID	int			 
	,Genre      varchar(100)
	,CONSTRAINT PK_Song PRIMARY KEY (SongID)
	,CONSTRAINT CK_SongName CHECK (TRIM(SongName)<>'')            --<== Blanks disallowed
	,CONSTRAINT CK_Genre CHECK (TRIM(Genre)<>'')				  --<== Blanks disallowed
	,CONSTRAINT FK_Song_Artist FOREIGN KEY (ArtistID) REFERENCES Artist (ArtistID)
	)
CREATE UNIQUE INDEX IXUF_SongName_ArtistID ON Song(SongName, ArtistID)
WHERE SongName IS NOT NULL
  AND ArtistID IS NOT NULL;

--Listener
CREATE TABLE Listener (
	 ListenerID		int	NOT NULL IDENTITY(1,1)
	,ListenerName	varchar(100) 
	,Email			varchar(100) 
	,CreatedDate	date NOT NULL
	,CONSTRAINT PK_Listener PRIMARY KEY (ListenerID)
	,CONSTRAINT CK_ListenerName CHECK (TRIM(ListenerName)<>'') --<== Blanks disallowed
	,CONSTRAINT CK_Email CHECK (TRIM(Email)<>'')               --<== Blanks disallowed
	)
CREATE UNIQUE INDEX IXUF_Listener_Email ON Listener(ListenerName, Email)
WHERE ListenerName IS NOT NULL
  AND Email		   IS NOT NULL;

--PlayList
CREATE TABLE PlayList (
	 PlayListID		int NOT NULL IDENTITY(1,1)
	,PlayListName	varchar(100) 
	,ListenerID		int			 
	,CONSTRAINT PK_PlayList PRIMARY KEY (PlayListID)
	,CONSTRAINT CK_PlayListName CHECK (TRIM(PlayListName)<>'')    --<== Blanks disallowed
	,CONSTRAINT FK_PlayList_Listener FOREIGN KEY (ListenerID) REFERENCES Listener (ListenerID)	
	)
CREATE UNIQUE INDEX IXUF_PlayListName_ListenerID ON PlayList(PlayListName, ListenerID)
WHERE PlayListName IS NOT NULL
  AND ListenerID   IS NOT NULL;

--PlayHistory
CREATE TABLE PlayHistory (
	 ListenerID int		NOT NULL
	,SongID		int		NOT NULL
	,PlayDate	date	NOT NULL
	,CONSTRAINT PK_PlayHistory PRIMARY KEY (ListenerID, SongID, PlayDate)
	,CONSTRAINT FK_PlayHistory_Song FOREIGN KEY (SongID) REFERENCES Song (SongID)
	,CONSTRAINT FK_PlayHistory_Listener FOREIGN KEY (ListenerID) REFERENCES Listener (ListenerID)	
	)

--PlayListSong
CREATE TABLE PlayListSong (
	 PlayListID	int NOT NULL
	,SongID		int NOT NULL			 
	,CONSTRAINT PK_PlayListSong PRIMARY KEY (PlayListID, SongID)
	,CONSTRAINT FK_PlayListSong_Song FOREIGN KEY (SongID) REFERENCES Song (SongID)	
	,CONSTRAINT FK_PlayListSong_PlayList FOREIGN KEY (PlayListID) REFERENCES PlayList (PlayListID)	
	)
GO
--END - Create Tables -----------------------------------------------------------------------------

SET NOEXEC OFF


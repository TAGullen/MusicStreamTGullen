
----------------------------------------------------------------------------------------------------------------------------
--MusicStreamDW Create Data warehouse

--Version History
--2025-05-16 TAG : Created
----------------------------------------------------------------------------------------------------------------------------

USE master

SET XACT_ABORT ON
SET NOEXEC OFF

--Create MusicStreamDW ----------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'MusicStreamDW')
CREATE DATABASE MusicStreamDW;
GO
--END-Create MusicStreamDQ ------------------------------------------------------------------------


--Drop Tables -------------------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON
USE MusicStreamDW;

DROP TABLE IF EXISTS DimGenre;
DROP TABLE IF EXISTS DimArtist;
DROP TABLE IF EXISTS DimListener;
DROP TABLE IF EXISTS DimSong;
DROP TABLE IF EXISTS DimPlayList;
DROP TABLE IF EXISTS DimDate;
DROP TABLE IF EXISTS FactPlayListSong;
DROP TABLE IF EXISTS FactPlayHistory;
GO
--END - Drop Tables -------------------------------------------------------------------------------


--Create Tables -----------------------------------------------------------------------------------
IF @@ERROR <> 0 SET NOEXEC ON

--STAR SCHEMA 

--DimGenre - Slowly Changing Dimension Type1 - Overwrite ------------------------------------------------------------------
CREATE TABLE DimGenre (
	 GenreKey		int			  NOT NULL IDENTITY(1,1)			--Surrogate key
	,SourceGenreID	int			  NOT NULL							--OLTP business key
	,GenreName		varchar(100)  NOT NULL
	,UpdatedDT		smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_DimGenre PRIMARY KEY (GenreKey)
	,CONSTRAINT UQ_SourceGenreID UNIQUE (SourceGenreID)				--Because SCD Type1 for now 	
	,CONSTRAINT UQ_GenreName UNIQUE (GenreName)						--Because SCD Type1 for now 	
	);

--For NULL and N/A entries
SET IDENTITY_INSERT DimGenre ON;
INSERT INTO DimGenre (GenreKey, SourceGenreID, GenreName)
VALUES (0, 0, 'Unknown')
      ,(-1, -1, 'N/A');
SET IDENTITY_INSERT DimGenre OFF;
--END - DimGenre - Slowly Changing Dimension Type1 - Overwrite ------------------------------------------------------------


--DimArtist - Slowly Changing Dimension Type1 - Overwrite ------------------------------------------------------------------
CREATE TABLE DimArtist (
	 ArtistKey		int			  NOT NULL IDENTITY(1,1)			--Surrogate key
	,SourceArtistID	int			  NOT NULL							--OLTP business key
	,ArtistName		varchar(100)  NOT NULL
	,UpdatedDT		smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_DimArtist PRIMARY KEY (ArtistKey)
	,CONSTRAINT UQ_SourceArtistID UNIQUE (SourceArtistID)			--Because SCD Type1 for now 	
	,CONSTRAINT UQ_ArtistName UNIQUE (ArtistName)					--Because SCD Type1 for now 	
	);

--For NULL and N/A entries
SET IDENTITY_INSERT DimArtist ON;
INSERT INTO DimArtist (ArtistKey, SourceArtistID, ArtistName)
VALUES (0, 0, 'Unknown')
      ,(-1, -1, 'N/A');
SET IDENTITY_INSERT DimArtist OFF;
--END - DimArtist - Slowly Changing Dimension Type1 - Overwrite ------------------------------------------------------------


--DimListener - Slowly Changing Dimension Type2 - Add a new row ------------------------------------------------------------
CREATE TABLE DimListener (
	 ListenerKey		int		      NOT NULL IDENTITY(1,1)		--Surrogate key
	,SourceListenerID	int			  NOT NULL						--OLTP business key
	,ListenerName		varchar(100)  NOT NULL
	,Email				varchar(100)  NOT NULL
	,CreatedDate		date		  NOT NULL
	,FromDT				smalldatetime NOT NULL DEFAULT GETDATE()	--SCD Type 2 - Effective from date-time
	,ToDT				smalldatetime NOT NULL DEFAULT '2079-01-01'	--SCD Type 2 - Effective to date-time
	,UpdatedDT			smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_DimListener PRIMARY KEY (ListenerKey)
	);

--For NULL and N/A entries
SET IDENTITY_INSERT DimListener ON;
INSERT INTO DimListener (ListenerKey, SourceListenerID, ListenerName, Email, CreatedDate, FromDT)
VALUES (0, 0, 'Unknown', 'Unknown', '2000-01-01', '2000-01-01')
      ,(-1, -1, 'N/A', 'N/A', '2000-01-01', '2000-01-01');
SET IDENTITY_INSERT DimListener OFF;
--END - DimListener - Slowly Changing Dimension Type2 - Add a new row ------------------------------------------------------


--DimSong - Slowly Changing Dimension Type1 - Overwrite --------------------------------------------------------------------
CREATE TABLE DimSong (
	 SongKey		int				NOT NULL IDENTITY(1,1) 			--Surrogate key
	,SourceSongID	int				NOT NULL						--OLTP business key
	,SongName		varchar(100)    NOT NULL 
	,SourceArtistID	int				NOT NULL						--Included for traceability
	,ArtistName		varchar(100)    NOT NULL 
	,SourceGenreID	int				NOT NULL						--Included for traceability
	,GenreName      varchar(100)    NOT NULL
	,UpdatedDT		smalldatetime   NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_DimSong PRIMARY KEY (SongKey)
	);

--For NULL and N/A entries
SET IDENTITY_INSERT DimSong ON;
INSERT INTO DimSong (SongKey, SourceSongID, SongName, SourceArtistID, ArtistName, SourceGenreID, GenreName)
VALUES (0, -1, 'Unknown', -1, 'Unknown', -1, 'Unknown')
      ,(-1, -1, 'N/A', -1, 'N/A', -1, 'N/A');
SET IDENTITY_INSERT DimSong OFF;
--END - DimSong - Slowly Changing Dimension Type1 - Overwrite --------------------------------------------------------------


--DimPlayList - Slowly Changing Dimension Type1 - Overwrite ----------------------------------------------------------------
CREATE TABLE DimPlayList (
	 PlayListKey		int			  NOT NULL IDENTITY(1,1)		--Surrogate key 
	,SourcePlayListID	int			  NOT NULL						--OLTP business key
	,PlayListName		varchar(100)  NOT NULL 
	,SourceListenerID	int			  NOT NULL						--Included for traceability
	,ListenerName		varchar(100)  NOT NULL	
	,UpdatedDT			smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_DimPlayList PRIMARY KEY (PlayListKey)
	);

--For NULL and N/A entries
SET IDENTITY_INSERT DimPlayList ON;
INSERT INTO DimPlayList (PlayListKey, SourcePlayListID, PlayListName, SourceListenerID, ListenerName)
VALUES (0, -1, 'Unknown', -1, 'Unknown')
      ,(-1, -1, 'N/A', -1, 'N/A');
SET IDENTITY_INSERT DimPlayList OFF;
--END - DimPlayList - Slowly Changing Dimension Type1 - Overwrite ----------------------------------------------------------


--DimDate - Date Dimension -------------------------------------------------------------------------------------------------
CREATE TABLE DimDate (
	 DateKey             int		 NOT NULL PRIMARY KEY			-- YYYYMMDD format
	,FullDate            date		 NOT NULL						-- Date value
	,Day                 tinyint	 NOT NULL						-- Day of month 
	,DayOfWeek           tinyint	 NOT NULL						-- 1=Monday, 7=Sunday (ISO)
	,DayOfWeekName       varchar(10) NOT NULL				
	,IsWeekend           bit		 NOT NULL               
	,WeekOfYear          tinyint	 NOT NULL						-- ISO week number (1–53)
	,Month               tinyint	 NOT NULL				
	,MonthName           varchar(10) NOT NULL				
	,Quarter             tinyint	 NOT NULL				
	,Year                int		 NOT NULL               
	);

--For NULL and N/A entries
INSERT INTO DimDate (DateKey, FullDate, Day, DayOfWeek, DayOfWeekName, IsWeekend, WeekOfYear, Month, monthName, Quarter, Year)
VALUES (0, '1900-01-01', 0, 0, 'Unknown', 0, 0, 0, 'Unknown', 0, 0)
      ,(-1, '1900-01-02', 255, 255, 'N/A', 0, 255, 255, 'N/A', 255, -1);


-- Load data
DECLARE @StartDate   date = '2000-01-01';
DECLARE @EndDate     date = '2050-12-31';
DECLARE @CurrentDate date = @StartDate;

SET DATEFIRST 1

WHILE @CurrentDate <= @EndDate
BEGIN
    INSERT INTO DimDate (
		 DateKey
		,FullDate        
		,Day             
		,DayOfWeek       
		,DayOfWeekName   
		,IsWeekend       
		,WeekOfYear      
		,Month           
		,MonthName       
		,Quarter         
		,Year            
		)
    VALUES (
		 FORMAT(@CurrentDate, 'yyyyMMdd')
		,@CurrentDate
		,DATEPART(DAY, @CurrentDate)
		,DATEPART(WEEKDAY, @CurrentDate)  --Depends on DATEFIRST
		,DATENAME(WEEKDAY, @CurrentDate)
		,CASE WHEN DATENAME(WEEKDAY, @CurrentDate) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
		,DATEPART(ISO_WEEK, @CurrentDate)
		,DATEPART(MONTH, @CurrentDate)
		,DATENAME(MONTH, @CurrentDate)
		,DATEPART(QUARTER, @CurrentDate)
		,DATEPART(YEAR, @CurrentDate)		
    );

	SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
END
--END - DimDate - Date Dimension -------------------------------------------------------------------------------------------


--FactPlayListSong - Factless Fact -----------------------------------------------------------------------------------------
CREATE TABLE FactPlayListSong (
	 PlayListSongKey	int			  NOT NULL IDENTITY(1,1)		--Surrogate key 
	,PlayListKey		int			  NOT NULL						--dim key
	,SongKey			int			  NOT NULL						--dim key
	,UpdatedDT			smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_FactPlayListSong PRIMARY KEY NONCLUSTERED (PlayListSongKey)
	,CONSTRAINT UQ_FactPlayListSong UNIQUE (PlayListKey, SongKey)
	);
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactPlayListSong ON FactPlayListSong; 
CREATE INDEX IX_PlayListKey ON FactPlayListSong (PlayListKey);
CREATE INDEX IX_SongKey ON FactPlayListSong (SongKey);
--END - FactPlayListSong - Factless Fact -----------------------------------------------------------------------------------


--FactPlayHistory - Fact ---------------------------------------------------------------------------------------------------
CREATE TABLE FactPlayHistory (
	 PlayHistoryKey		int			  NOT NULL IDENTITY(1,1)		--Surrogate key 
	,ListenerKey		int			  NOT NULL						--dim key
	,SongKey			int			  NOT NULL						--dim key
	,PlayDateKey		int			  NOT NULL						--dim key
	,UpdatedDT			smalldatetime NOT NULL DEFAULT GETDATE()
	,CONSTRAINT PK_FactPlayHistory PRIMARY KEY NONCLUSTERED (PlayHistoryKey)
	,CONSTRAINT UQ_FactPlayHistory UNIQUE (ListenerKey, SongKey, PlayDateKey)
	);
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactPlayHistory ON FactPlayHistory;
CREATE INDEX IX_ListenerKey ON FactPlayHistory (ListenerKey);
CREATE INDEX IX_SongKey ON FactPlayHistory (SongKey);
CREATE INDEX IX_PlayDateKey ON FactPlayHistory (PlayDateKey);
--END - FactPlayHistory - Fact ---------------------------------------------------------------------------------------------

GO
--END - Create Tables -----------------------------------------------------------------------------

SET NOEXEC OFF


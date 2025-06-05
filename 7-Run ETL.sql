USE [MusicStreamDW]
GO

DECLARE	@return_value int

EXEC	@return_value = [dbo].[usp_ETL]

SELECT	'Return Value' = @return_value

GO

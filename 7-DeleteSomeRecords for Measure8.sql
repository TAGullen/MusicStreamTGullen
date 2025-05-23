USE MusicStreamDW

DELETE F2
FROM DimSong DS2
	JOIN FactPlayHistory F2 
			ON DS2.SongKey = F2.SongKey
	JOIN DimDate D2 
			ON F2.PlayDateKey = D2.DateKey
WHERE D2.FullDate >= DATEADD(MONTH, -1, GETDATE())
  AND DS2.Genre IN ('GEc', 'GEe')
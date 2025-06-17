*********************************************
** InfoTrack Music Streaming Platform
** 
** This project is based on 
** https://vertabelo.com/blog/schema-diagram/
** Example 6
**
** Author: Temel A Gullen
** Date  : June 2025
*********************************************

-----Databases-----
1  - Scripts are for MSSQL Server.  
2  - Scripts are to be run on the local server or on an EC2 instance.  
3  - Scripts have been numbered. Please execute them from 1 to 9 successively.  

-----Dashboard-----
4  - Dashboard requires Power BI to be already installed.
5  - Open "10-MusicStreamMetrics.pbix".

-----Reconnect-----
6  - Go to Home tab and click Transform Data.
7  - Click Data source settings.
8  - In the window that opens, select the existing SQL Server data source.
9  - Click Change Source.
10 - In the Data Source dialog, enter the SQL Server instance where MusicStreamDW is. 
11 - Database name should remain the same (MusicStreamDW).
12 - Click close.
13 - Power BI will ask for credentials for the new SQL Server.
     Choose Windows Authentication or enter SQL Server credentials.
14 - Click Connect.

-----Refresh-----
18 - Go to Home, click Refresh.
19 - If you get "Microsoft SQL: A network-related or instance-specific error occurred..."
     This means your connection does not work.
20 - If you get an error like below 
     "Query '01-AvgSong...' references other queries ... rebuild this data combination."
     PLEASE REFRESH AGAIN 2 ~ 3 TIMES

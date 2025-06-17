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

-----Databases-----<br>
1  - Scripts are for MSSQL Server.<br>
2  - Scripts are to be run on the local server or on an EC2 instance.<br>
3  - Scripts have been numbered. Please execute them from 1 to 9 successively.<br>

-----Dashboard-----<br>
4  - Dashboard requires Power BI to be already installed.<br>
5  - Open "10-MusicStreamMetrics.pbix".<br>

-----Reconnect-----<br>
6  - Go to Home tab and click Transform Data.<br>
7  - Click Data source settings.<br>
8  - In the window that opens, select the existing SQL Server data source.<br>
9  - Click Change Source.<br>
10 - In the Data Source dialog, enter the SQL Server instance where MusicStreamDW is.<br>
11 - Database name should remain the same (MusicStreamDW).<br>
12 - Click close.<br>
13 - Power BI will ask for credentials for the new SQL Server.<br>
     Choose Windows Authentication or enter SQL Server credentials.<br>
14 - Click Connect.<br>

-----Refresh-----<br>
18 - Go to Home, click Refresh.<br>
19 - If you get "Microsoft SQL: A network-related or instance-specific error occurred..."<br>
&nbsp&nbsp&nbsp&nbsp&nbsp
     This means your connection does not work.<br>
20 - If you get an error like below<br>
&nbsp&nbsp&nbsp&nbsp&nbsp
     "Query '01-AvgSong...' references other queries ... rebuild this data combination."<br>
&nbsp&nbsp&nbsp&nbsp&nbsp     
     PLEASE REFRESH AGAIN 2 ~ 3 TIMES<br>

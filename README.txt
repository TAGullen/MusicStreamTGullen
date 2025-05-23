*********************************************
** InfoTrack Music Streaming Platform
** 
** This project is based on 
** https://vertabelo.com/blog/schema-diagram/
** Example 6
*********************************************

1 - Scripts are for MSSQL Server.
2 - Scripts are to be run on the local server or on an EC2 instance.
3 - Scripts have been numbered. Please execute them from 1 to 6 successively.
4 - '5-ETL.sql' script can be re-executed after updates to OLTP data.
5 - Dimension SCD types are explained in '4-CreateDW.sql' script.

*** For The Dashboard ***
6 - Please execute "7-DeleteSomeRecords for Measure8.sql". This is so measure 8 will have something to return.
7 - Open the Excel file "8-MusicStreamMetrics.xlsx"
8 - There will be a security warning "External Data Conn disabled"
9 - Click on "Enable Content"
10- Click on top ribbon menu item DATA
11- Click on GetData on the left 
12- Near the bottom of the menu, click on Data Source Settings
13- Select (local);MusicStreamDW
14- At the bottom, click Change Source
15- This is where you point to the SQL Server where MusicStreamDW exists.
16- Click OK and Close
17- Still on Data top menu, click Refresh All. This will refresh the data in Excel from DW database
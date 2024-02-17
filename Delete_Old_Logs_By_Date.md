# Command to delete old logs by date

**find . -type f -mtime +XXX -maxdepth 1 -exec rm {} \;**

**find . -type f -mtime +2 -exec rm {} \;**

* The syntax of this is as follows.*

+ find  – the command that finds the files
+ . – the dot signifies the current folder.  You can change this to something like /home/someuser/ or whatever path you need
+ -type f – this means only files.  Do not look at or delete folders
+ -mtime +XXX – replace XXX with the number of days you want to go back. 
   for example, if you put -mtime +5, it will delete everything OLDER then 5 days.
+ -maxdepth 1 – this means it will not go into sub folders of the working directory
+ -exec rm {} \; – this deletes any files that match the previous settings.
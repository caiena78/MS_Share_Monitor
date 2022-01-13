

# Microsoft Share Monitor
  Microsoft Share Monitor is used to monitor file share changed. This includes permission modifications along with adding and removing share folders.



# USAGE
  "Server1","Server2","Server3"| .\MS_Share_Monitor.ps1


# folder
   \Server - This folder holds the .json and hash files for each server.
   
   \Temp  - This folder holds the temp .json and hash files used to compare to the files in the \Server folder.
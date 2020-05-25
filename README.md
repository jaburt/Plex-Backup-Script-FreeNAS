# Plex-Backup-Script-FreeNAS
A FreeBSD bash script to automate the backup of Plex Media Server's configuration files and databases.

It’s recommended that you backup your Plex Media Server databases and configuration files, and I have created a script (plexbackup.sh) to automate this; see the below for the script.

You need to create a cron job via the Tasks section of the FreeNAS GUI which runs the script plexbackup.sh, I suggest you schedule this to run at a time when the server is not in used, to stop any impact affecting users, as well as deciding how often you want it run, I have scheduled it to run at 2:24am every 3 days.

This script (plexbackup.sh) when run will stop the Plex Media Server, perform some database integrity checks, and backup the databases and configuration files to a location on your FreeNAS server.  The script finishes with an email status update, which includes the status of the database checks.

There are five variables at the beginning of the script which you will need to complete to personalise the script for your FreeNAS Server: 

*	plexMSJailName 		The Plex Media Server Jail name.
*	backupDestination	Destination where you want your backup file saved.
*	beta 				      Are you using the BETA version of Plex (yes/no)?
*	keepBackups			  Amount of backup archive files to keep (rest will be deleted).
*	your_email 			  Your email address (defaults to root)

#!/bin/bash

### Notes ###
# Script to backup the Plex Media Server databases and configuration files, it will 
# also verify the integrity of the SQL databases. It runs from the main FreeNAS sever, 
# so no need to be within the Jails.
#
# The script is based on FreeNAS v11.3-U3.1 or greater with iocage Jails.  It may work 
# on earlier version of FreeNAS, but I cannot guarantee this.
#
# This script has been checked for bugs with the online ShellCheck website:
#	https://www.shellcheck.net/
### End ###

### Change Log ###
# 25/05/2020: A reworking of the code, to support both plexmediaserver (Stable edition) 
# and plexmediaserver_plexpass (BETA edition), as well as fixing some minor errors.  Will
# also removed old backup archives based on the "keepBackups" variable.
#
### End ###

### Usage ###
# You need to create a cron job via the Tasks section of the FreeNAS GUI which runs this 
# script, plexbackup.sh, I suggest you schedule this to run at a time when the server is 
# not in used, to stop any impact affecting users, as well as deciding how often you want
# it to run, I have scheduled it to run at 2:24am every 3 days.
#
# Upon completion the backup will be stored in your custom location and you will also 
# receive an email with the status of the database check.
#
# There are five variables at the beginning of the script which you will need to complete 
# to personalise the script for your FreeNAS Server: 
#
#	plexMSJailName 		The Plex Media Server Jail name.
#	backupDestination	Destination where you want your backup file saved.
#	beta 				Are you using the BETA version of Plex (yes/no)?
#	keepBackups			Amount of backup archive files to keep (rest will be deleted).
#	your_email 			Your email address (defaults to root)
#
# You may need to edit the following two variables if you are not using default install 
# locations on your server.
#
#	iocageLoc 			The location where iocage has been installed.
#	plexMSInstall		The location where your Plex Metadata has been saved.
#
### End ###

### User defined variables ###
# What's the name of the Jail where Plex Media Server is installed?
plexMSJailName="PMS"

# Backup Destination.  The trailing slash is NOT needed. This is the absolute location
# within your FreeNAS server, ideally in a separate dataset from the Plex Jail dataset.
backupDestination="/mnt/tank/Sysadmin/plex_backup"

# Are you using the BETA version of Plex Media Server (yes or no)?
beta="no"

# How many backup achives do you want to keep in the "backupDestination"?
keepBackups=10

# Your email, so the script can send a report at the end.
your_email=root
### End ###

### Paths (you may need to edit if you use non-default paths on your server) ###
# This script assumes that iocage has been enabled in the default position of: /mnt/tank/iocage
# If this is not the case, edit the variable "iocageloc". The trailing slash is NOT needed.
iocageLoc="/mnt/tank/iocage"

# This script also assumes that Plex Media Server has been installed via "pkg" and is 
# installed in the default directories.  If this is not the case than you will need to edit 
# the variable "plexMSInstall" accordingly.  For example, you have mounted the Metadata in 
# an external dataset.
if [[ ${beta} = "yes" ]] ; then
	plexMSInstall="/usr/local/plexdata-plexpass/Plex Media Server"
	serviceName=plexmediaserver_plexpass
else
#	plexMSInstall="/usr/local/plexdata/Plex Media Server"
	plexMSInstall="/mnt/Metadata/Plex Media Server"
	serviceName=plexmediaserver
fi
### Paths ###

#################################################################
##### THERE IS NO NEED TO EDIT ANYTHING BEYOUND THIS POINT  #####
#################################################################

### Prepare ###
# Calculate full path
plexPath="$iocageLoc/jails/$plexMSJailName/root$plexMSInstall"

# Stop Plex Media Server
iocage exec "${plexMSJailName}" service "${serviceName}" stop

# Prepare the .tar.gz filename
tarfile="/tmp/jab_plexbackup.tar.gz"
filename="$(date "+plex_backup_%Y-%m-%d")"

# Prepare the logfile filename
log_file="/tmp/jab_plexbackuplog.txt"

# Prepare the email filename
emailFile="/tmp/jab_plexbackupemail.txt"
### End ###

### Log file pre-formatting. ###
(
	echo "The backup of the Plex Media Server databases and configuration files (excluding the cache)"
	echo "was completed on: $(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "\\r\\n"
	echo "The backup file has been saved at: ${backupDestination}/${filename}.tar.gz"
	echo -e "\\r\\n"
) > ${log_file}
### End ###

### Check for any corruptions in the database files. ###
# Before we can do the "pragma integrity_check", we need to do some pre-work to the database file, 
# as per the notes on https://support.plex.tv/articles/201100678-repair-a-corrupt-database/ 
cd "${plexPath}/Plug-in Support/Databases/" || exit
cp com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
sqlite3 com.plexapp.plugins.library.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.db "DELETE from schema_migrations where version='20180501000000'"
cp com.plexapp.plugins.library.blobs.db com.plexapp.plugins.library.blobs.db.original
sqlite3 com.plexapp.plugins.library.blobs.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.blobs.db "DELETE from schema_migrations where version='20180501000000'"
# Pre-work complete

# Checking PlexMS databases.
# Checking com.plexapp.plugins.library.db.

if ! [ "$(sqlite3 "${plexPath}/Plug-in Support/Databases/com.plexapp.plugins.library.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "Warning: com.plexapp.plugins.library.db FAILED the sqlite3 pragma integrity_check!" >> ${log_file}
	) 
else
	(
		echo "Good News: com.plexapp.plugins.library.db PASSED the sqlite3 pragma integrity_check!"  >> ${log_file}
	)
fi
	
# Checking com.plexapp.plugins.library.blobs.db.
if ! [ "$(sqlite3 "${plexPath}/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "Warning: com.plexapp.plugins.library.blobs.db FAILED the sqlite3 pragma integrity_check!" >> ${log_file}
	)
else
	(
		echo "Good News: com.plexapp.plugins.library.blobs.db PASSED the sqlite3 pragma integrity_check!" >> ${log_file}
	) 
fi
	
# Checking com.plexapp.dlna.db.
if ! [ "$(sqlite3 "${plexPath}/Plug-in Support/Databases/com.plexapp.dlna.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "Warning: com.plexapp.dlna.db FAILED the sqlite3 pragma integrity_check!" >> ${log_file}
	) 
else
	(
		echo "Good News: com.plexapp.dlna.db PASSED the sqlite3 pragma integrity_check!" >> ${log_file}
	) 
fi
### End ###

### Add footer to email ###
(
	echo -e "\\r\\n"
	echo "------------------------------------------------------------------------------------------------------------------------------"
	echo "Please Note: The latest version of this script can be found at: https://www.github.com/jaburt"
	echo "------------------------------------------------------------------------------------------------------------------------------"
) >> ${log_file}
### End ###

### Creation of backup.tar.gz files. ###
# The tar file holds all the PlexMS files needed for a restore.  It excludes the cache folder for PlexMS, 
# as this is not needed and it saves an awful lot of space!
cd /tmp || exit
tar --exclude="${plexPath}/Cache/" -czf "${tarfile}" "${log_file}" "${plexPath}/"
### End ###

### Re-start services ###
# Restart Plex.
iocage exec "${plexMSJailName}" service "${serviceName}" start

### Copy tar file to backup location. ###
cp "${tarfile}" "${backupDestination}/${filename}.tar.gz"
### End ###

### prepare the email ###
(
    echo "To: ${your_email}"
	echo "Subject: Integrity Check and Backup of Plex Media Server databases and configs"
	echo "MIME-Version: 1.0"
    echo "Content-Type: text/html"
    echo -e "\\r\\n"
	echo "Please Note:"
	echo "If any of the messages below state Warning, then you will need to check why the database(s)"
	echo "failed the integrity checks, and fix them as soon as possible.  This may require a restore"
	echo "from a previous backup."
	echo -e "\\r\\n"
	cat ${log_file}
) > ${emailFile}
### End ###

### Send email ###
# Send the email.
sendmail -t < ${emailFile}
### End ###

### Clean up
# Remove tempfiles.
rm ${tarfile}
rm ${log_file}
rm ${emailFile}

# Delete old backups and only keep the newest "keepBackups"
# cd to the correct directory before executing (for the paranoid!)
cd ${backupDestination} || exit
ls -1t | tail -n +$((${keepBackups}+1)) | xargs rm -f
### End ###

### Finished ###

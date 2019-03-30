#!/bin/bash

### Notes ###
## Script to backup the Plex configuration files. ##
## Will also verify the integrity of the sql databases. ##
## Can be run from the main FreeNAS sever, no need to be within the Jails. ##
### End ###

### User defined variables ###
## Plex database & configuration location.  The trailing slash is NOT needed. ##
## This is the absolute location within the Jail, from the FreeNAS server. ##
## Note: Default location for a clean install in a FreeNAS v11.0-U2 Jail, ##
##       is: /usr/local/plexdata/Plex Media Server ##
plexMSDatabase="/mnt/iocage/jails/PlexMS/root/usr/local/plexdata-plexpass/Plex Media Server"
plexMSJailName="PlexMS"

## Backup Location.  The trailing slash is NOT needed. ##
## This is the absolute location within the Jail, from the FreeNAS server, ##
## ideally in a separate dataset from the Plex Jail datasets. ##
backupLocation="/mnt/tank/Sysadmin/plex_backup"

## Your email, so the script can send a report at the end. ##
email="YOUR_EMAIL_ADDRESS"
### End ###

### Prepare ###
## Stop Plex. ##
iocage exec "${plexMSJailName}" service plexmediaserver_plexpass stop
##Create .tar.gz filename##
tarfile="tempworking.tar.gz"
filename="$(date "+plex_backup_%Y-%m-%d")"
### End ###

### Log file pre-formatting. ###
(
	echo "The backup of the Plex Media Server databases and configuration files (excluding the cache)"
	echo "was completed on: <b>$(date "+%Y-%m-%d %H:%M:%S")</b>"
	echo -e "\\r\\n"
	echo "The backup file has been saved at: <b>${backupLocation}/${filename}.tar.gz</b>"
	echo -e "\\r\\n"
) > /tmp/plexbackup.log
### End ###

### Check for any corruptions in the database files. ###

# Before we can do the "pragma integrity_check", we need to do some pre-work to the database file, #
# as per the notes on https://support.plex.tv/articles/201100678-repair-a-corrupt-database/ #
cd "${plexMSDatabase}/Plug-in Support/Databases/" || exit
cp com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
sqlite3 com.plexapp.plugins.library.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.db "DELETE from schema_migrations where version='20180501000000'"
cp com.plexapp.plugins.library.blobs.db com.plexapp.plugins.library.blobs.db.original
sqlite3 com.plexapp.plugins.library.blobs.db "DROP index 'index_title_sort_naturalsort'"
sqlite3 com.plexapp.plugins.library.blobs.db "DELETE from schema_migrations where version='20180501000000'"
# Pre-work complete #

## Checking PlexMS databases. ##
## Checking com.plexapp.plugins.library.db. ##

if ! [ "$(sqlite3 "${plexMSDatabase}/Plug-in Support/Databases/com.plexapp.plugins.library.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "<b>Warning</b>: com.plexapp.plugins.library.db FAILED the sqlite3 pragma integrity_check!" >> /tmp/plexbackup.log
	) 
else
	(
		echo "<b>Good News</b>: com.plexapp.plugins.library.db PASSED the sqlite3 pragma integrity_check!"  >> /tmp/plexbackup.log
	)
fi
echo -e "\\r\\n" >> /tmp/plexbackup.log
	
## Checking com.plexapp.plugins.library.blobs.db. ##
if ! [ "$(sqlite3 "${plexMSDatabase}/Plug-in Support/Databases/com.plexapp.plugins.library.blobs.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "<b>Warning</b>: com.plexapp.plugins.library.blobs.db FAILED the sqlite3 pragma integrity_check!" >> /tmp/plexbackup.log
	)
else
	(
		echo "<b>Good News</b>: com.plexapp.plugins.library.blobs.db PASSED the sqlite3 pragma integrity_check!" >> /tmp/plexbackup.log
	) 
fi
echo -e "\\r\\n" >> /tmp/plexbackup.log
	
## Checking com.plexapp.dlna.db. ##
if ! [ "$(sqlite3 "${plexMSDatabase}/Plug-in Support/Databases/com.plexapp.dlna.db" "pragma integrity_check;")" = "ok" ]; then
	(
		echo "<b>Warning</b>: com.plexapp.dlna.db FAILED the sqlite3 pragma integrity_check!" >> /tmp/plexbackup.log
	) 
else
	(
		echo "<b>Good News</b>: com.plexapp.dlna.db PASSED the sqlite3 pragma integrity_check!" >> /tmp/plexbackup.log
	) 
fi
echo -e "\\r\\n" >> /tmp/plexbackup.log
### End ###

### Creation of backup.tar.gz files. ###
## The tar file holds all the PlexMS files needed for a restore  ##
## It excludes the cache folder for PlexMS, as this is not needed and it saves an ##
## awful lot of space! ##
cd /tmp || exit
tar --exclude="${plexMSDatabase}/Cache/" -czf "${tarfile}" "plexbackup.log" "${plexMSDatabase}/"
### End ###

### Re-start services ###
## Restart Plex. ##
iocage exec "${plexMSJailName}" service plexmediaserver_plexpass start

### Copy tar file to backup location. ###
cp "${tarfile}" "${backupLocation}/${filename}.tar.gz"
### End ###

### prepare the email ###
(
    echo "To: ${email}"
	echo "Subject: Integrity Check and Backup of Plex Media Server databases and configs"
	echo "MIME-Version: 1.0"
    echo "Content-Type: text/html"
    echo -e "\\r\\n"
    echo "<pre style=\"font-size:14px\">"
	echo "<i>Please Note:</i>"
	echo "If the any of the messages below state <b>Warning</b>, then you will need to check"
	echo "why the database(s) failed the integrity checks, and fix them as soon as possible."
	echo "This may entail a restore from a previous backup."
	echo -e "\\r\\n"
	cat /tmp/plexbackup.log
    echo "</pre>"	
) > /tmp/plexbackup.eml
### End ###

### Send email ###
## Send the email. ##
sendmail -t < /tmp/plexbackup.eml

## Remove the temp files. ##
rm "/tmp/${tarfile}"
rm /tmp/plexbackup.log
rm /tmp/plexbackup.eml
### End ###

### Finished ###
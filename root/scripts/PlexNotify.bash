#!/usr/bin/env bash
PLEXURL="http://plexIp:32400"
PLEXTOKEN="plexToken"
lidarrApiKey="$(grep "<ApiKey>" /config/config.xml | sed "s/\  <ApiKey>//;s/<\/ApiKey>//")"
lidarrUrl="http://127.0.0.1:8686"
lidarrRootFolderPath="$(dirname "$Lidarr_Artist_Path")"
plexfolder="$Lidarr_Artist_Path"
exec &>> "/config/scripts/PlexNotify.log"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

if [ "$Lidarr_EventType" == "Test" ]; then
	log "Tested"
	exit 0	
fi

plexlibraries="$(curl -s "$PLEXURL/library/sections?X-Plex-Token=$PLEXTOKEN" | xq .)"
if echo "$plexlibraries" | grep "$lidarrRootFolderPath" | read; then
	plexlibrarykey="$(echo "$plexlibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$lidarrRootFolderPath\") | .\"@key\"" | head -n 1)"
	if [ -z "$plexlibrarykey" ]; then
		log "ERROR: No Plex Library key found for \"$lidarrRootFolderPath\""
		exit 1
	fi
else
	log "ERROR: No Plex Library found containing path \"/$lidarrRootFolderPath\""
	log "ERROR: Add \"/$lidarrRootFolderPath\" as a folder to a Plex Music Library"
	exit 1
fi

plexfolderencoded="$(jq -R -r @uri <<<"${plexfolder}")"
curl -s "$PLEXURL/library/sections/$plexlibrarykey/refresh?path=$plexfolderencoded&X-Plex-Token=$PLEXTOKEN"
log  "Plex Scan notification sent! ($plexfolder)"

exit 0

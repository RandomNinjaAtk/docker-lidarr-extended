#!/usr/bin/env bash
lidarrApiKey="$(grep "<ApiKey>" /config/config.xml | sed "s/\  <ApiKey>//;s/<\/ApiKey>//")"
lidarrUrl="http://127.0.0.1:8686"
lidarrRootFolderPath="$(dirname "$Lidarr_Artist_Path")"
exec &>> "/config/logs/PlexNotify.log"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

if [ "$Lidarr_EventType" == "Test" ]; then
	log "Tested"
	exit 0	
fi

plexLibraries="$(curl -s "$plexUrl/library/sections?X-Plex-Token=$plexToken" | xq .)"
if echo "$plexLibraries" | grep "$lidarrRootFolderPath" | read; then
	plexlibrarykey="$(echo "$plexLibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$lidarrRootFolderPath\") | .\"@key\"" | head -n 1)"
	if [ -z "$plexlibrarykey" ]; then
		log "ERROR: No Plex Library key found for \"$lidarrRootFolderPath\""
		exit 1
	fi
else
	log "ERROR: No Plex Library found containing path \"/$lidarrRootFolderPath\""
	log "ERROR: Add \"/$lidarrRootFolderPath\" as a folder to a Plex Music Library"
	exit 1
fi

plexFolderEncoded="$(jq -R -r @uri <<<"$Lidarr_Artist_Path")"
curl -s "$plexUrl/library/sections/$plexlibrarykey/refresh?path=$plexFolderEncoded&X-Plex-Token=$plexToken"
log  "Plex Scan notification sent! ($Lidarr_Artist_Path)"

exit 0

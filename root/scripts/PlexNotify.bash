#!/usr/bin/env bash
PLEXURL="http://Your_Plex_IP:32400"
PLEXTOKEN="Your_Plex_Token"
lidarrApiKey="$(grep "<ApiKey>" /config/config.xml | sed "s/\  <ApiKey>//;s/<\/ApiKey>//")"
lidarrUrl="http://127.0.0.1:8686"
seriesId=$sonarr_series_id
seriesData=$(curl -s "http://localhost:8989/api/v3/series/$seriesId?apikey=$sonarrApiKey")
seriesPath="$(echo "$seriesData" | jq -r ".path")"
seriesRootFolderPath="$(echo "$seriesData" | jq -r ".rootFolderPath")"
plexfolder="$seriesPath"
exec &>> "/config/scripts/PlexNotify.log"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

if [ "$sonarr_eventtype" == "Test" ]; then
	log "Tested"
	exit 0	
fi

plexlibraries="$(curl -s "$PLEXURL/library/sections?X-Plex-Token=$PLEXTOKEN" | xq .)"
if echo "$plexlibraries" | grep "$seriesRootFolderPath" | read; then
	plexlibrarykey="$(echo "$plexlibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$seriesRootFolderPath\") | .\"@key\"" | head -n 1)"
	if [ -z "$plexlibrarykey" ]; then
		log "ERROR: No Plex Library key found for \"$seriesRootFolderPath\""
		exit 1
	fi
else
	log "ERROR: No Plex Library found containing path \"/$seriesRootFolderPath\""
	log "ERROR: Add \"/$seriesRootFolderPath\" as a folder to a Plex TV Library"
	exit 1
fi

plexfolderencoded="$(jq -R -r @uri <<<"${plexfolder}")"
curl -s "$PLEXURL/library/sections/$plexlibrarykey/refresh?path=$plexfolderencoded&X-Plex-Token=$PLEXTOKEN"
log  "Plex Scan notification sent! ($plexfolder)"

exit 0

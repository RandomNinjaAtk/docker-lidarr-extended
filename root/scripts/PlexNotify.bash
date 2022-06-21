#!/usr/bin/env bash
lidarrRootFolderPath="$(dirname "$lidarr_artist_path")"
# auto-clean up log file to reduce space usage
if [ -f "/config/logs/PlexNotify.txt" ]; then
	find /config/logs -type f -name "PlexNotify.txt" -size +1024k -delete
fi
exec &>> "/config/logs/PlexNotify.txt"
chmod 777 "/config/logs/PlexNotify.txt"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: "$1
}

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

until false
do
	taskCount=$(ps aux | grep Plex_MusicVideos.bash | grep -v grep | wc -l)
	if [ "$taskCount" -ge "1" ]; then
		sleep 1
	else
		break
	fi
done

plexLibraries="$(curl -s "$plexUrl/library/sections?X-Plex-Token=$plexToken" | xq .)"
if echo "$plexLibraries" | grep "$lidarrRootFolderPath" | read; then
	if echo "$plexLibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$lidarrRootFolderPath\") | .\"@key\"" &>/dev/null; then
		plexlibrarykey="$(echo "$plexLibraries" | jq -r ".MediaContainer.Directory[] | select(.Location.\"@path\"==\"$lidarrRootFolderPath\") | .\"@key\"" | head -n 1)"
	else
		plexlibrarykey="$(echo "$plexLibraries" | jq -r ".MediaContainer.Directory | select(.Location.\"@path\"==\"$lidarrRootFolderPath\") | .\"@key\"" | head -n 1)"
	fi
	if [ -z "$plexlibrarykey" ]; then
		log "ERROR: No Plex Library key found for \"$lidarrRootFolderPath\""
		exit 1
	fi
else
	if echo "$plexLibraries" | grep -i "Unauthorized" | read; then
		log "ERROR :: Cannot connect to Plex"
		log "ERROR :: plexUrl or plexToken is invalid"
		log "ERROR :: plexUrl is currently set to \"$plexUrl\""
		log "ERROR :: plexToken is currently set to \"$plexToken\""
		exit 1
	else
		log "ERROR: No Plex Library found containing path \"$lidarrRootFolderPath\""
		log "ERROR: Add \"$lidarrRootFolderPath\" as a folder to a Plex Music Library"
		exit 1
	fi
fi

plexFolderEncoded="$(jq -R -r @uri <<<"$lidarr_artist_path")"
curl -s "$plexUrl/library/sections/$plexlibrarykey/refresh?path=$plexFolderEncoded&X-Plex-Token=$plexToken"
log  "Plex Scan notification sent! ($lidarr_artist_path)"

exit 0

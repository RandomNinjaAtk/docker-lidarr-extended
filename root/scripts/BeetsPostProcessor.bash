#!/usr/bin/env bash
version=1.0.002
if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" == "null" ]; then
		lidarrUrlBase=""
	else
		lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
	fi
	lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
	lidarrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
	lidarrUrl="http://127.0.0.1:${lidarrPort}${lidarrUrlBase}"
fi

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: BeetsPostProcessor :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/BeetsPostProcessor.txt" ]; then
	find /config/logs -type f -name "BeetsPostProcessor.txt" -size +1024k -delete
	sleep 0.01
fi
exec &> >(tee -a "/config/logs/BeetsPostProcessor.txt")
touch "/config/logs/BeetsPostProcessor.txt"
chmod 666 "/config/logs/BeetsPostProcessor.txt"

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi


getTrackPath="$(curl -s "$lidarrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"

ProcessWithBeets () {
	# Input
	# $1 Download Folder to process
	if [ -f /config/library-postprocessor.blb ]; then
		rm /config/library-postprocessor.blb
		sleep 0.1
	fi
	if [ -f /config/extended/logs/beets.log ]; then 
		rm /config/extended/logs/beets.log
		sleep 0.1
	fi

	if [ -f "/config/beets-postprocessor-match" ]; then 
		rm "/config/beets-postprocessor-match"
		sleep 0.1
	fi
	touch "/config/beets-postprocessor-match"
	sleep 0.1

    log "$1 :: Being matching with beets!"
	beet -c /config/extended/scripts/beets-config.yaml -l /config/library-postprocessor.blb -d "$1" import -qC "$1"
	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-postprocessor-match" | wc -l) -gt 0 ]; then
		log "$1 :: SUCCESS: Matched with beets!"
		find "$1" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
			metaflac --remove-tag=ALBUMARTIST "$file"
			metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
			metaflac --remove-tag=ALBUMARTISTSORT "$file"
			metaflac --remove-tag=ALBUM_ARTIST "$file"
			metaflac --remove-tag="ALBUM ARTIST" "$file"
			metaflac --remove-tag=ARTISTSORT "$file"
		done
	else
		log "$1 :: ERROR :: Unable to match using beets to a musicbrainz release..."
	fi	

	if [ -f "/config/beets-postprocessor-match" ]; then 
		rm "/config/beets-postprocessor-match"
		sleep 0.1
	fi

	if [ -f /config/library-postprocessor.blb ]; then
		rm /config/library-postprocessor.blb
		sleep 0.1
	fi
	if [ -f /config/extended/logs/beets.log ]; then 
		rm /config/extended/logs/beets.log
		sleep 0.1
	fi
}

ProcessWithBeets "$getFolderPath"

exit

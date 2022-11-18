#!/usr/bin/env bash
scriptVersion=1.0.011
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

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/MetadataPostProcess.txt" ]; then
	find /config/logs -type f -name "MetadataPostProcess.txt" -size +1024k -delete
	sleep 0.01
fi
exec &> >(tee -a "/config/logs/MetadataPostProcess.txt")
touch "/config/logs/MetadataPostProcess.txt"
chmod 666 "/config/logs/MetadataPostProcess.txt"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: MetadataPostProcess :: $scriptVersion :: "$1
}

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

getAlbumArtist="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.artistName)"
getAlbumArtistPath="$(curl -s "$lidarrUrl/api/v1/album/$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .artist.path)"
getTrackPath="$(curl -s "$lidarrUrl/api/v1/trackFile?albumId=$lidarr_album_id" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].path | head -n1)"
getFolderPath="$(dirname "$getTrackPath")"

if echo "$getFolderPath" | grep "$getAlbumArtistPath" | read; then
	if [ ! -d "$getFolderPath" ]; then
		log "ERROR :: \"$getFolderPath\" Folder is missing :: Exiting..."
        exit
	fi
else 
	log "ERROR :: $getAlbumArtistPath not found within \"$getFolderPath\" :: Exiting..."
	exit
fi

find "$getFolderPath" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' file; do
    fileName=$(basename -- "$file")
    fileExt="${fileName##*.}"

    if [ ! -f "$getFolderPath/folder.jpg" ] && [ ! -f "$getFolderPath/folder.jpeg" ]; then
        ffmpeg -i "$file" -an -vcodec copy "$getFolderPath/folder.jpg" &> /dev/null
        if [ -f "$getFolderPath/folder.jpg" ] && [ -f "$getFolderPath/folder.jpeg" ]; then
            log "Processing :: $getFolderPath :: Album Artwork Extracted to: $getFolderPath/folder.jpg"
            chmod 666 "$getFolderPath/folder.jpg"
        fi
    fi

    if ls "$getFolderPath" | grep "lrc" | read; then
        log "Removing existing lrc files"
        find "$getFolderPath" -type f -iname "*.lrc" -delete
    fi

    if [ "$fileExt" == "flac" ]; then
        getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.LYRICS" | sed "s/null//g" | sed "/^$/d")"
        getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"
    fi

    if [ "$fileExt" == "opus" ]; then
        getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".streams[].tags.LYRICS" | sed "s/null//g" | sed "/^$/d")"
    fi

    if [ ! -z "$getLyrics" ]; then
        lrcFile="${file%.*}.lrc"
        log "Processing :: $file :: Extracting Lyrics..."
        echo -n "$getLyrics" > "$lrcFile"
        log "Processing :: $file :: Lyrics extracted to: $lrcFile"
        chmod 666 "$lrcFile"
    fi

    if [ "$fileExt" == "flac" ]; then
        if [ ! -z "$getArtistCredit" ]; then
            log "Processing :: $file :: Setting ARTIST tag to match ARTIST_CREDIT tag..."
            metaflac --remove-tag=ARTIST "$file"
            metaflac --set-tag=ARTIST="$getArtistCredit" "$file"
        fi
    fi

done

exit

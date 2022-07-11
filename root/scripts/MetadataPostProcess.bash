#!/usr/bin/env bash
version=1.0.003
if [ -z "$lidarr_artist_path" ]; then
	lidarr_artist_path="$1"
	notfidedBy=Extended_Script
else
	notfidedBy=Lidarr
fi

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/MetadataPostProcess.txt" ]; then
	find /config/logs -type f -name "MetadataPostProcess.txt" -size +1024k -delete
fi

exec &>> "/config/logs/MetadataPostProcess.txt"
chmod 777 "/config/logs/MetadataPostProcess.txt"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: $notfidedBy :: "$1
}

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

log "Processing :: $lidarr_trackfile_path"
albumFolder=$(dirname "$lidarr_trackfile_path")
if [ -d "$albumFolder" ]; then
    if [ -f "$albumFolder/folder.jpg" ]; then
        log "Processing :: $albumFolder :: Album Artwork Found"
    else
        ffmpeg -i "$lidarr_trackfile_path" -an -vcodec copy "$albumFolder/folder.jpg" &> /dev/null
        if [ -f "$albumFolder/folder.jpg" ]; then
            log "Processing :: $albumFolder :: Album Artwork Extracted to: $albumFolder/folder.jpg"
        fi
    fi
else
    log "Processing :: ERROR :: $albumFolder :: folder missing..."
fi

lrcFile="${lidarr_trackfile_path%.*}.lrc"
if [ -f "$lrcFile" ]; then
    rm "$lrcFile"
fi
getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$lidarr_trackfile_path" | jq -r ".format.tags.LYRICS")"
if [ "$getLyrics" != "null" ]; then
    log "Processing :: $lidarr_trackfile_path :: Extracting Lyrics..."
    ffprobe -loglevel 0 -print_format json -show_format -show_streams "$lidarr_trackfile_path" | jq -r ".format.tags.LYRICS" > "$lrcFile"
    log "Processing :: $lidarr_trackfile_path :: Lyrics extracted to: $lrcFile"
fi

exit

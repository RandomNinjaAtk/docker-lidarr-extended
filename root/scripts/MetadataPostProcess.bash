#!/usr/bin/env bash
version=1.0.005
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
    if [ ! -f "$albumFolder/folder.jpg" ]; then
        ffmpeg -i "$lidarr_trackfile_path" -an -vcodec copy "$albumFolder/folder.jpg" &> /dev/null
        if [ -f "$albumFolder/folder.jpg" ]; then
            log "Processing :: $albumFolder :: Album Artwork Extracted to: $albumFolder/folder.jpg"
            chmod 666 "$albumFolder/folder.jpg"
            chown abc:abc "$albumFolder/folder.jpg"
        fi
    fi
else
    log "Processing :: ERROR :: $albumFolder :: folder missing..."
fi

lrcFile="${lidarr_trackfile_path%.*}.lrc"
if [ -f "$lrcFile" ]; then
    rm "$lrcFile"
fi
fileName=$(basename -- "$lidarr_trackfile_path")
fileExt="${fileName##*.}"

if [ "$fileExt" == "flac" ]; then
    getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$lidarr_trackfile_path" | jq -r ".format.tags.LYRICS" | sed "s/null//g" | sed "/^$/d")"
    processLyrics=true
fi

if [ "$fileExt" == "opus" ]; then
    getLyrics="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$lidarr_trackfile_path" | jq -r ".streams[].tags.LYRICS" | sed "s/null//g" | sed "/^$/d")"
fi

if [ ! -z "$getLyrics" ]; then
    log "Processing :: $lidarr_trackfile_path :: Extracting Lyrics..."
    echo -n "$getLyrics" > "$lrcFile"
    log "Processing :: $lidarr_trackfile_path :: Lyrics extracted to: $lrcFile"
    chmod 666 "$lrcFile"
fi

exit

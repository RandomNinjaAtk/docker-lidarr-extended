#!/usr/bin/env bash
version=1.0.001
if [ -z "$lidarr_artist_path" ]; then
	lidarr_artist_path="$1"
	notfidedBy=Extended_Script
else
	notfidedBy=Lidarr
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
        log "Processing :: $albumFolder :: Albunm Artwork Found"
    else
        ffmpeg -i "$lidarr_trackfile_path" -an -vcodec copy "$albumFolder/folder.jpg" &> /dev/null
        if [ -f "$albumFolder/folder.jpg" ]; then
            log "Processing :: $albumFolder :: Album Artwork Extracted to: $albumFolder/folder.jpg"
        fi
    fi
else
    log "Processing :: ERROR :: $albumFolder :: folder missing..."
fi

exit

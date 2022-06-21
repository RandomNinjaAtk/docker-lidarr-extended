#!/usr/bin/env bash
lidarrArtistId=$lidarr_artist_id

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/Plex_MusicVideos.txt" ]; then
	find /config/logs -type f -name "Plex_MusicVideos.txt" -size +1024k -delete
fi
exec &>> "/config/logs/Plex_MusicVideos.txt"
chmod 777 "/config/logs/Plex_MusicVideos.txt"

log () {
    m_time=`date "+%F %T"`
    echo $m_time" :: "$1
}

if [ "$lidarr_eventtype" == "Test" ]; then
	log "Tested Successfully"
	exit 0	
fi

lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
if [ "$lidarrUrlBase" = "null" ]; then
	lidarrUrlBase=""
else
	lidarrUrlBase="/${lidarrUrlBase}"
fi
lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
lidarrUrl="http://127.0.0.1:8686${lidarrUrlBase}"
lidarrRootFolderPath="$(dirname "$lidarr_artist_path")"
lidarrArtistData="$(curl -s "$lidarrUrl/api/v1/artist/$lidarrArtistId?apikey=${lidarrApiKey}")"
lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"

if [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	skipTidal=false
	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		log "TIDAL :: ERROR :: tidal-dl client not configured, please run the main script \"/config/extended/scripts/download.sh\" to configure the client"
		log "Exiting..."
		exit 0
	fi	
else
	skipTidal=true
fi

if [ "$skipTidal" = "false" ]; then
	if [ -z "$tidalArtistUrl" ]; then 
		log "TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-arist-id-not-found.txt\" for more detail..."
		touch "/config/logs/tidal-arist-id-not-found.txt" 
		if cat "/config/logs/tidal-arist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships" | read; then
			sleep 0.01
		else
			echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/tidal-arist-id-not-found.txt"
			chmod 666 "/config/logs/tidal-arist-id-not-found.txt"
			chown abc:abc "/config/logs/tidal-arist-id-not-found.txt"
		fi
		skipTidal=true
	fi
fi

if [ "$skipTidal" = "false" ]; then
	if [ ! -d /config/extended/cache/tidal ]; then
		mkdir -p /config/extended/cache/tidal
	fi
						
	if [ ! -f /config/extended/cache/tidal/$tidalArtistId-videos.json ]; then
		log "Caching Artist Videos List"
		curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/videos?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-videos.json
	fi

fi

if [ "$skipTidal" = "false" ]; then
	tidalArtistVideoCount=$(cat /config/extended/cache/tidal/$tidalArtistId-videos.json | jq -r '.items | sort_by(.duration) | .[].id' | wc -l)
	if [ $tidalArtistVideoCount -ge 1 ]; then
		for i in $(cat /config/extended/cache/tidal/$tidalArtistId-videos.json | jq -r '.items | sort_by(.duration) | .[].id'); do
			tidalVideoTitle=$(cat /config/extended/cache/tidal/$tidalArtistId-videos.json | jq -r ".items[] | select(.id==$i) | .title" | sed "s/ (official video)//gi")
			if find "$lidarrArtistPath" -type f -regex ".*- $tidalVideoTitle\.\(flac\|opus\|m4a\|mp3\)" | read; then
				matchedFile="$(find "$lidarrArtistPath" -type f -regex ".*- $tidalVideoTitle\.\(flac\|opus\|m4a\|mp3\)" | head -n1)"
				log "Video :: $i :: $tidalVideoTitle :: Matched :: $matchedFile"
				fileDirectory="$(dirname "$matchedFile")"
				fileName="$(basename "$matchedFile")"
				fileNameNoExt="${fileName%.*}"

				if [ ! -f "$fileDirectory/$fileNameNoExt.mkv" ]; then
					if [ ! -d /downloads/lidarr-extended/music-videos ]; then
						mkdir -p /downloads/lidarr-extended/music-videos
						chmod 777 /downloads/lidarr-extended/music-videos
						chown abc:abc /downloads/lidarr-extended/music-videos
					else
						rm -rf /downloads/lidarr-extended/music-videos/*
					fi

					tidal-dl -r P1080
					tidal-dl -o /downloads/lidarr-extended/music-videos -l "https://tidal.com/browse/video/$i"

					find "/downloads/lidarr-extended/music-videos" -type f -iname "*.mp4" -print0 | while IFS= read -r -d '' video; do
						ffmpeg \
						-i "${video}" \
						-vcodec copy \
						-acodec copy \
						"$fileDirectory/$fileNameNoExt.mkv"
					done
					log "Downloaded Video to: $fileDirectory/$fileNameNoExt.mkv"
					chmod 666 "$fileDirectory/$fileNameNoExt.mkv"
					chown abc:abc "$fileDirectory/$fileNameNoExt.mkv"
					rm -rf /downloads/lidarr-extended/music-videos/*
				else
					log "ERROR :: Previously Downloaded $fileDirectory/$fileNameNoExt.mkv ($i)"
				fi

			else
				log "ERROR :: No vidoes found that match local tracks"
			fi
		done
	else
		log "ERROR :: No videos found for the artist on Tidal"
	fi
fi

exit 0

#!/usr/bin/env bash
scriptVersion="1.0.0051"
lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
if [ "$lidarrUrlBase" = "null" ]; then
	lidarrUrlBase=""
else
	lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
fi
lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
lidarrUrl="http://127.0.0.1:8686${lidarrUrlBase}"
agent="lidarr-extended ( https://github.com/RandomNinjaAtk/docker-lidarr-extended )"
musicbrainzMirror=https://musicbrainz.org

# Debugging settings
#dlClientSource=deezer
#topLimit=25
#addDeezerTopArtists=false
#addDeezerTopAlbumArtists=false
#addDeezerTopTrackArtists=false
#configureLidarrWithOptimalSettings=false
#audioFormat=opus
#audioBitrate=160

log () {
	m_time=`date "+%F %T"`
	echo $m_time" "$1
}

mkdir -p /config/xdg

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	log ""
	log ""
	sleep 2
	log "############# $dockerTitle"
	log "############# SCRIPT VERSION $scriptVersion"
	log "############# DOCKER VERSION $dockerVersion"
	
	if [ -z $topLimit ]; then
		topLimit=10
	fi

	if [ "$addDeezerTopArtists" = "true" ]; then
		log ":: Add Deezer Top $topLimit Artists is enabled"
	else
		log ":: Add Deezer Top Artists is disabled (enable by setting addDeezerTopArtists=true)"
	fi

	if [ "$addDeezerTopAlbumArtists" = "true" ]; then
		log ":: Add Deezer Top $topLimit Album Artists is enabled"
	else
		log ":: Add Deezer Top Album Artists is disabled (enable by setting addDeezerTopAlbumArtists=true)"
	fi

	if [ "$addDeezerTopTrackArtists" = "true" ]; then
		log ":: Add Deezer Top $topLimit Track Artists is enabled"
	else
		log ":: Add Deezer Top Track Artists is disabled (enable by setting addDeezerTopTrackArtists=true)"
	fi

	if [ "$addRelatedArtists" = "true" ]; then
		log ":: Add Deezer Related Artists is enabled"
		
	else
		log ":: Add Deezer Related Artists is disabled (enable by setting addRelatedArtists=true)"
	fi

	if [ "$configureLidarrWithOptimalSettings" = "true" ]; then
		log ":: Configure Lidarr with optimal settings is enabled"
		
	else
		log ":: Configure Lidarr with optimal settings is disabled (enable by setting configureLidarrWithOptimalSettings=true)"
	fi

	log ":: Output format = $audioFormat"
	log ":: Output bitrate = $audioBitrate"

	if [ $audioLyricType = both ] || [ $audioLyricType = explicit ] || [ $audioLyricType = explicit ]; then
		log ":: Preferred audio lyric type: $audioLyricType"
	fi
	log ":: Tidal Country Code set to: $tidalCountryCode"
}

DownloadFormat () {
	if [ $audioFormat = native ]; then
		if [ $audioBitrate = lossless ]; then
			tidal-dl -q HiFi
			deemixQuality=flac
		elif [ $audioBitrate = high ]; then
			tidal-dl -q High
			deemixQuality=320
		elif [ $audioBitrate = low ]; then
			tidal-dl -q Normal
			deemixQuality=128
		else
			log ":: ERROR :: Invalid audioFormat and audioBitrate options set..."
			log ":: ERROR :: Change audioBitrate to a low, high, or lossless..."
			log ":: ERROR :: Exiting..."
			exit
		fi
	else
		if [ $audioBitrate = lossless ] || [ $audioBitrate = high ] || [ $audioBitrate = low ]; then
			log ":: ERROR :: Invalid audioFormat and audioBitrate options set..."
			log ":: ERROR :: Change audioBitrate to a desired bitrate number, example: 192..."
			log ":: ERROR :: Exiting..."
			exit
		else
			tidal-dl -q HiFi
			deemixQuality=flac
		fi
	fi
}

AddDeezerTopArtists () {
	getDeezerArtistsIds=($(curl -s "https://api.deezer.com/chart/0/artists?limit=$1" | jq -r ".data[].id"))
	getDeezerArtistsIdsCount=$(curl -s "https://api.deezer.com/chart/0/artists?limit=$1" | jq -r ".data[].id" | wc -l)
	description="Top Artists"
	AddDeezerArtistToLidarr
}

AddDeezerTopAlbumArtists () {
	getDeezerArtistsIds=($(curl -s "https://api.deezer.com/chart/0/albums?limit=$1" | jq -r ".data[].artist.id"))
	getDeezerArtistsIdsCount=$(curl -s "https://api.deezer.com/chart/0/albums?limit=$1" | jq -r ".data[].artist.id" | wc -l)
	description="Top Album Artists"
	AddDeezerArtistToLidarr
}

AddDeezerTopTrackArtists () {
	getDeezerArtistsIds=($(curl -s "https://api.deezer.com/chart/0/tracks?limit=$1" | jq -r ".data[].artist.id"))
	getDeezerArtistsIdsCount=$(curl -s "https://api.deezer.com/chart/0/tracks?limit=$1" | jq -r ".data[].artist.id" | wc -l)
	description="Top Track Artists"
	AddDeezerArtistToLidarr
}

AddDeezerArtistToLidarr () {
	lidarrArtistsData="$(curl -s "$lidarrUrl/api/v1/artist?apikey=${lidarrApiKey}")"
	lidarrArtistIds="$(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId")"
	deezerArtistsUrl=$(echo "${lidarrArtistsData}" | jq -r ".[].links | .[] | select(.name==\"deezer\") | .url")
	deezeArtistIds="$(echo "$deezerArtistsUrl" | grep -o '[[:digit:]]*' | sort -u)"
	log ":: Finding $description..."
	log ":: $getDeezerArtistsIdsCount $description Found..."
	for id in ${!getDeezerArtistsIds[@]}; do
		currentprocess=$(( $id + 1 ))
		deezerArtistId="${getDeezerArtistsIds[$id]}"
		deezerArtistName="$(curl -s https://api.deezer.com/artist/$deezerArtistId | jq -r .name)"
		log ":: $currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Searching Musicbrainz for Deezer artist id ($deezerArtistId)"

		if echo "$deezeArtistIds" | grep "^${deezerArtistId}$" | read; then
			log ":: $currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: $deezerArtistId already in Lidarr..."
			continue
		fi

		query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://www.deezer.com/artist/${deezerArtistId}%22&fmt=json")
		count=$(echo "$query_data" | jq -r ".count")
		if [ "$count" == "0" ]; then
			sleep 1.5
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://www.deezer.com/artist/${deezerArtistId}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
			sleep 1.5
		fi
							
		if [ "$count" == "0" ]; then
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://deezer.com/artist/${deezerArtistId}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
			sleep 1.5
		fi
							
		if [ "$count" == "0" ]; then
			query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://deezer.com/artist/${deezerArtistId}%22&fmt=json")
			count=$(echo "$query_data" | jq -r ".count")
		fi
							
		if [ "$count" != "0" ]; then
			musicbrainz_main_artist_id=$(echo "$query_data" | jq -r '.urls[]."relation-list"[].relations[].artist.id' | head -n 1)
			sleep 1.5
			artist_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/$musicbrainz_main_artist_id?fmt=json")
			artist_sort_name="$(echo "$artist_data" | jq -r '."sort-name"')"
			artist_formed="$(echo "$artist_data" | jq -r '."begin-area".name')"
			artist_born="$(echo "$artist_data" | jq -r '."life-span".begin')"
			gender="$(echo "$artist_data" | jq -r ".gender")"
			matched_id=true
			data=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$musicbrainz_main_artist_id" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[]")
			artistName="$(echo "$data" | jq -r ".artist.artistName")"
			foreignId="$(echo "$data" | jq -r ".foreignId")"
			data=$(curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[]")
			path="$(echo "$data" | jq -r ".path")"
			qualityProfileId="$(echo "$data" | jq -r ".defaultQualityProfileId")"
			metadataProfileId="$(echo "$data" | jq -r ".defaultMetadataProfileId")"
			data="{
				\"artistName\": \"$artistName\",
				\"foreignArtistId\": \"$foreignId\",
				\"qualityProfileId\": $qualityProfileId,
				\"metadataProfileId\": $metadataProfileId,
				\"monitored\":true,
				\"monitor\":\"all\",
				\"rootFolderPath\": \"$path\"
				}"

			if echo "$lidarrArtistIds" | grep "^${musicbrainz_main_artist_id}$" | read; then
				log ":: $currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Already in Lidarr ($musicbrainz_main_artist_id), skipping..."
				continue
			fi
			log ":: $currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Adding $artistName to Lidarr ($musicbrainz_main_artist_id)..."
			LidarrTaskStatusCheck
			lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
		else
			log ":: $currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Artist not found in Musicbrainz, please add \"https://deezer.com/artist/${deezerArtistId}\" to the correct artist on Musicbrainz"
		fi
	done
}

DArtistAlbumList () {
	
	albumcount="$(python3 /config/extended/scripts/discography.py "$1" | sort -u | wc -l)"
	
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Searching for \"$1\" All Albums...."
	if [ $albumcount -gt 0 ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle ::  $albumcount Albums found!"
	else
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: $albumcount Albums found, skipping..."
		return
	fi
	albumids=($(python3 /config/extended/scripts/discography.py "$1" | sort -u))
		
	for id in ${!albumids[@]}; do
		currentprocess=$(( $id + 1 ))
		albumid="${albumids[$id]}"
		if [ ! -d /config/extended/cache/deezer/ ]; then
			mkdir -p /config/extended/cache/deezer
			chmod 777 /config/extended/cache/deezer
			chown -R abc:abc /config/extended/cache/deezer
		fi

		if [ ! -f /config/extended/cache/deezer/${albumid}.json ]; then
			if wget "https://api.deezer.com/album/${albumid}" -O "/config/extended/cache/deezer/${albumid}.json" -q; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Downloading Album info..."
				chmod 666 /config/extended/cache/deezer/${albumid}.json
				chown abc:abc /config/extended/cache/deezer/${albumid}.json			
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Error getting album information"
			fi
		else
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Album info already downloaded"
		fi
	done
	
	if [ -f /config/extended/cache/deezer/$1-albums-temp.json ]; then
		rm /config/extended/cache/deezer/$1-albums-temp.json
	fi

	if [ -f /config/extended/cache/deezer/$1-albums.json ]; then
		testFile=$(cat /config/extended/cache/deezer/$1-albums.json)
		if jq -e . >/dev/null 2>&1 <<<"$testFile"; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Existing album list verified..."
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Checking album list age..."
			if find /config/extended/cache/deezer -type f -name "$1-albums.json" -mtime +1 | read; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Existing Album list older than 1 day, purging to create updated list..."
				find /config/extended/cache/deezer -type f -name "$1-albums.json" -mtime +1 -delete
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Existing Album list is not older than 1 day..."
			fi
		else
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Existing album list failed verification..."
			rm /config/extended/cache/deezer/$1-albums.json
		fi
	fi
	
	if [ ! -f /config/extended/cache/deezer/$1-albums.json ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Creating album list from $albumcount found albums..."
		echo "[" >> /config/extended/cache/deezer/$1-albums-temp.json
		for id in ${!albumids[@]}; do
			albumid="${albumids[$id]}"
			cat "/config/extended/cache/deezer/${albumid}.json" | jq -r | sed 's/^/ /' | sed '$s/}/},/g' >> /config/extended/cache/deezer/$1-albums-temp.json
		done
		cat /config/extended/cache/deezer/$1-albums-temp.json | sed '$ d' >> /config/extended/cache/deezer/$1-albums.json
		echo " }" >> /config/extended/cache/deezer/$1-albums.json
		echo "]" >> /config/extended/cache/deezer/$1-albums.json
		rm /config/extended/cache/deezer/$1-albums-temp.json
	fi
	
}

TidalClientSetup () {
	log ":: TIDAL :: Verifying tidal-dl configuration"
	touch /config/xdg/.tidal-dl.log
	if [ -f /config/xdg/.tidal-dl.json ]; then
		rm /config/xdg/.tidal-dl.json
	fi
	if [ ! -f /config/xdg/.tidal-dl.json ]; then
		log ":: TIDAL :: No default config found, importing default config \"tidal.json\""
		if [ -f /config/extended/scripts/tidal-dl.json ]; then
			cp /config/extended/scripts/tidal-dl.json /config/xdg/.tidal-dl.json
			chmod 777 -R /config/xdg/
		fi

	fi
	tidal-dl -o /downloads/lidarr-extended/incomplete
	DownloadFormat

	# check for backup token and use it if exists
	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		if [ -f /config/backup/tidal-dl.token.json ]; then
			cp -p /config/backup/tidal-dl.token.json /root/.tidal-dl.token.json
			# remove backup token
			rm /config/backup/tidal-dl.token.json
		fi
	fi

	if [ -f /config/xdg/.tidal-dl.token.json ]; then
		if [[ $(find "/config/xdg/.tidal-dl.token.json" -mtime +6 -print) ]]; then
			log ":: TIDAL :: ERROR :: Token expired, removing..."
			rm /config/xdg/.tidal-dl.token.json
		else
			# create backup of token to allow for container updates
			if [ ! -d /config/backup ]; then
				mkdir -p /config/backup
			fi
			cp -p /config/xdg/.tidal-dl.token.json /config/backup/tidal-dl.token.json
		fi
	fi

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		log ":: TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		tidal-dl
	fi
	
	if [ -d /config/extended/cache/tidal ]; then
		log ":: TIDAL :: Purging album list cache..."
		find /config/extended/cache/tidal -type f -name "*.json" -delete
	fi

	if [ ! -d "/downloads/lidarr-extended" ]; then
		mkdir -p /downloads/lidarr-extended
		chmod 777 /downloads/lidarr-extended
		chown abc:abc /downloads/lidarr-extended
	fi
	
	if [ ! -d "/downloads/lidarr-extended/incomplete" ]; then
		mkdir -p /downloads/lidarr-extended/incomplete
		chmod 777 /downloads/lidarr-extended/incomplete
		chown abc:abc /downloads/lidarr-extended/incomplete
	else
		rm -rf /downloads/lidarr-extended/incomplete/*
	fi
	
	tidal-dl -o /downloads/lidarr-extended/incomplete -l "60261268"
	
	downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		log ":: tidal-dl client setup verification :: ERROR :: Download failed"
		log ":: tidal-dl client setup verification :: ERROR :: Please review log for errors in client"
		log ":: tidal-dl client setup verification :: ERROR :: Exiting..."
		rm -rf /downloads/lidarr-extended/incomplete/*
		exit
	else
		rm -rf /downloads/lidarr-extended/incomplete/*
		log ":: tidal-dl client setup verification :: Download Verification Success"
	fi
}

DownloadProcess () {
	downloadedAlbumTitleClean="$(echo "$downloadedAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"

	if [ ! -d "/downloads/lidarr-extended" ]; then
		mkdir -p /downloads/lidarr-extended
		chmod 777 /downloads/lidarr-extended
		chown abc:abc /downloads/lidarr-extended
	fi
	
	if [ ! -d "/downloads/lidarr-extended/incomplete" ]; then
		mkdir -p /downloads/lidarr-extended/incomplete
		chmod 777 /downloads/lidarr-extended/incomplete
		chown abc:abc /downloads/lidarr-extended/incomplete
	else
		rm -rf /downloads/lidarr-extended/incomplete/*
	fi
	
	if [ ! -d "/downloads/lidarr-extended/complete" ]; then
		mkdir -p /downloads/lidarr-extended/complete
		chmod 777 /downloads/lidarr-extended/complete
		chown abc:abc /downloads/lidarr-extended/complete
	fi

	if [ ! -d "/config/extended/logs" ]; then
		mkdir -p /config/extended/logs
		chmod 777 /config/extended/logs
		chown abc:abc /config/extended/logs
	fi

	if [ ! -d "/config/extended/logs/downloaded" ]; then
		mkdir -p /config/extended/logs/downloaded
		chmod 777 /config/extended/logs/downloaded
		chown abc:abc /config/extended/logs/downloaded
	fi

	if [ ! -d "/config/extended/logs/downloaded/deezer" ]; then
		mkdir -p /config/extended/logs/downloaded/deezer
		chmod 777 /config/extended/logs/downloaded/deezer
		chown abc:abc /config/extended/logs/downloaded/deezer
	fi

	if [ ! -d "/config/extended/logs/downloaded/tidal" ]; then
		mkdir -p /config/extended/logs/downloaded/tidal
		chmod 777 /config/extended/logs/downloaded/tidal
		chown abc:abc /config/extended/logs/downloaded/tidal
	fi
    
    if [ "$2" = "DEEZER" ]; then
        deemix -b $deemixQuality -p /downloads/lidarr-extended/incomplete "https://www.deezer.com/album/$1"
		if [ -d "/tmp/deemix-imgs" ]; then
			rm -rf /tmp/deemix-imgs
		fi
        touch /config/extended/logs/downloaded/deezer/$1
        downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
        if [ $downloadCount -le 0 ]; then
            log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: download failed"
            return
        fi
    elif [ "$2" = "TIDAL" ]; then
        tidal-dl -o /downloads/lidarr-extended/incomplete -l "https://tidal.com/browse/album/$1"
        touch /config/extended/logs/downloaded/tidal/$1
        downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
        if [ $downloadCount -le 0 ]; then
            log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: download failed"
            return
        fi
    else
        return
    fi

	if [ $audioFormat != native ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Converting Flac Audio to  ${audioFormat^^} ${audioBitrate}k"
		if [ $audioFormat = opus ]; then
			options="-acodec libopus -ab ${audioBitrate}k -application audio -vbr off"
		    extension="opus"
		fi

		if [ $audioFormat = mp3 ]; then
			options="-acodec libmp3lame -ab ${audioBitrate}k"
			extension="mp3"
		fi

		if [ $audioFormat = aac ]; then
			options="-c:a libfdk_aac -b:a ${audioBitrate}k -movflags faststart"
			extension="m4a"
		fi

		if [ $audioFormat = alac ]; then
			options="-c:a alac -movflags faststart"
			extension="m4a"
		fi

		find "/downloads/lidarr-extended/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' audio; do
			file="${audio}"
			filename="$(basename "$audio")"
			foldername="$(dirname "$audio")"
        	filenamenoext="${filename%.*}"
			if ffmpeg -loglevel warning -hide_banner -nostats -i "$file" -n -vn $options "$foldername/${filenamenoext}.$extension" < /dev/null; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $filename :: Conversion to $audioFormat (${audioBitrate}k) successful"
				rm "$file"
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $filename :: ERROR :: Conversion Failed"
				rm "$foldername/${filenamenoext}.$extension"
			fi
		done

	fi

    albumquality="$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1 | egrep -i -E -o "\.{1}\w*$" | sed  's/\.//g')"
    downloadedAlbumFolder="$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-${albumquality^^}-$2"

    find "/downloads/lidarr-extended/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' audio; do
        file="${audio}"
        filenoext="${file%.*}"
        filename="$(basename "$audio")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        if [ ! -d "/downloads/lidarr-extended/complete" ]; then
            mkdir -p /downloads/lidarr-extended/complete
            chmod 777 /downloads/lidarr-extended/complete
            chown abc:abc /downloads/lidarr-extended/complete
        fi
        mkdir -p "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
        mv "$file" "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"/
        
    done
    chmod -R 777 /downloads/lidarr-extended/complete
    chown -R abc:abc /downloads/lidarr-extended/complete

    ProcessWithBeets "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" "${albumquality^^}" "$2"

    if [ -d "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" ]; then
        NotifyLidarrForImport "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
    fi
    rm -rf /downloads/lidarr-extended/incomplete/*
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$lidarrUrl/api/v1/command" --header "X-Api-Key:"${lidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

DeemixClientSetup () {
	log ":: DEEZER :: Verifying deemix configuration"
	if [ ! -z "$arlToken" ]; then
		# Create directories
		mkdir -p /config/xdg/deemix
		if [ -f "/config/xdg/deemix/.arl" ]; then
			rm "/config/xdg/deemix/.arl"
		fi
		if [ ! -f "/config/xdg/deemix/.arl" ]; then
			echo -n "$arlToken" > "/config/xdg/deemix/.arl"
		fi
		log ":: DEEZER :: ARL Token: Configured"
	else
		log ":: DEEZER :: ERROR :: arlToken setting invalid, currently set to: $arlToken"
	fi
	
	if [ -d /config/extended/cache/deezer ]; then
		log ":: DEEZER :: Purging album list cache..."
		find /config/extended/cache/deezer -type f -name "*-albums.json" -delete
	fi
	
	if [ ! -d "/downloads/lidarr-extended" ]; then
		mkdir -p /downloads/lidarr-extended
		chmod 777 /downloads/lidarr-extended
		chown abc:abc /downloads/lidarr-extended
	fi
	
	if [ ! -d "/downloads/lidarr-extended/incomplete" ]; then
		mkdir -p /downloads/lidarr-extended/incomplete
		chmod 777 /downloads/lidarr-extended/incomplete
		chown abc:abc /downloads/lidarr-extended/incomplete
	else
		rm -rf /downloads/lidarr-extended/incomplete/*
	fi

	deemix -b $deemixQuality -p /downloads/lidarr-extended/incomplete "https://www.deezer.com/album/197472472"
	if [ -d "/tmp/deemix-imgs" ]; then
		rm -rf /tmp/deemix-imgs
	fi
    downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
    if [ $downloadCount -le 0 ]; then
		log ":: deemix client setup verification :: ERROR :: Download failed"
    	log ":: deemix client setup verification :: ERROR :: Please review log for errors in client"
		log ":: deemix client setup verification :: ERROR :: Exiting..."
		rm -rf /downloads/lidarr-extended/incomplete/*
		exit
    else
		rm -rf /downloads/lidarr-extended/incomplete/*
		log ":: deemix client setup verification :: Download Verification Success"
	fi
}

ConfigureLidarrWithOptimalSettings () {

	log ":: Configuring Lidarr Track Naming Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/naming" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"renameTracks":true,"replaceIllegalCharacters":true,"standardTrackFormat":"{Artist Name} - {Album Type} - {Release Year} - {Album Title}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track Title}","multiDiscTrackFormat":"{Artist Name} - {Album Type} - {Release Year} - {Album Title}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track Title}","artistFolderFormat":"{Artist Name}{ (Artist Disambiguation)}","includeArtistName":false,"includeAlbumTitle":false,"includeQuality":false,"replaceSpaces":false,"id":1}')

	log ":: Configuring Lidarr Media Management Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/mediamanagement" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"autoUnmonitorPreviouslyDownloadedTracks":false,"recycleBin":"","recycleBinCleanupDays":7,"downloadPropersAndRepacks":"preferAndUpgrade","createEmptyArtistFolders":true,"deleteEmptyFolders":true,"fileDate":"none","watchLibraryForChanges":true,"rescanAfterRefresh":"always","allowFingerprinting":"newFiles","setPermissionsLinux":true,"chmodFolder":"777","chownGroup":"abc","skipFreeSpaceCheckWhenImporting":false,"minimumFreeSpaceWhenImporting":100,"copyUsingHardlinks":true,"importExtraFiles":true,"extraFileExtensions":"jpg,png,lrc","id":1}')

	log ":: Configuring Lidarr Metadata ConsumerSettings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadata/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"enable":true,"name":"Kodi (XBMC) / Emby","fields":[{"name":"artistMetadata","value":true},{"name":"albumMetadata","value":true},{"name":"artistImages","value":true},{"name":"albumImages","value":true}],"implementationName":"Kodi (XBMC) / Emby","implementation":"XbmcMetadata","configContract":"XbmcMetadataSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#xbmcmetadata","tags":[],"id":1}')

	log ":: Configuring Lidarr Metadata Provider Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/metadataProvider" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"metadataSource":"","writeAudioTags":"sync","scrubAudioTags":true,"id":1}')

	log ":: Configuring Lidarr Custom Scripts"
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "PlexNotify.bash" | read; then
		log ":: PlexNotify.bash Already added to Lidarr custom scripts"
	else
		log ":: Adding PlexNotify.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlexNotify.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":true,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"PlexNotify.bash","fields":[{"name":"path","value":"/config/extended/scripts/PlexNotify.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
	fi
	
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "Plex_MusicVideos.bash" | read; then
		log ":: Plex_MusicVideos.bash Already added to Lidarr custom scripts"
	else
		log ":: Adding Plex_MusicVideos.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlex_MusicVideos.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":true,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"Plex_MusicVideos.bash","fields":[{"name":"path","value":"/config/extended/scripts/Plex_MusicVideos.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
	fi

	log ":: Configuring Lidarr UI Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/ui" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"firstDayOfWeek":0,"calendarWeekColumnHeader":"ddd M/D","shortDateFormat":"MMM D YYYY","longDateFormat":"dddd, MMMM D YYYY","timeFormat":"h(:mm)a","showRelativeDates":true,"enableColorImpairedMode":true,"uiLanguage":1,"expandAlbumByDefault":true,"expandSingleByDefault":true,"expandEPByDefault":true,"expandBroadcastByDefault":true,"expandOtherByDefault":true,"id":1}')

	if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log ":: ERROR :: No root folder found"
		log ":: Configuring root folder..."
		getSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fmusic&allowFoldersWithoutTrailingSlashes=false&includeFiles=false" -H "X-Api-Key: ${lidarrApiKey}")
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/rootFolder?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"defaultTags":[],"defaultQualityProfileId":1,"defaultMetadataProfileId":1,"name":"Music","path":"/music"}')
	fi

	log ":: Configuring Lidarr Standard Metadata Profile"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadataprofile/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"name":"Standard","primaryAlbumTypes":[{"albumType":{"id":2,"name":"Single"},"allowed":true},{"albumType":{"id":4,"name":"Other"},"allowed":true},{"albumType":{"id":1,"name":"EP"},"allowed":true},{"albumType":{"id":3,"name":"Broadcast"},"allowed":true},{"albumType":{"id":0,"name":"Album"},"allowed":true}],"secondaryAlbumTypes":[{"albumType":{"id":0,"name":"Studio"},"allowed":true},{"albumType":{"id":3,"name":"Spokenword"},"allowed":true},{"albumType":{"id":2,"name":"Soundtrack"},"allowed":true},{"albumType":{"id":7,"name":"Remix"},"allowed":true},{"albumType":{"id":9,"name":"Mixtape/Street"},"allowed":true},{"albumType":{"id":6,"name":"Live"},"allowed":true},{"albumType":{"id":4,"name":"Interview"},"allowed":true},{"albumType":{"id":8,"name":"DJ-mix"},"allowed":true},{"albumType":{"id":10,"name":"Demo"},"allowed":true},{"albumType":{"id":1,"name":"Compilation"},"allowed":true}],"releaseStatuses":[{"releaseStatus":{"id":3,"name":"Pseudo-Release"},"allowed":false},{"releaseStatus":{"id":1,"name":"Promotion"},"allowed":false},{"releaseStatus":{"id":0,"name":"Official"},"allowed":true},{"releaseStatus":{"id":2,"name":"Bootleg"},"allowed":false}],"id":1}')

	touch /config/extended/logs/autoconfig
	chmod 666 /config/extended/logs/autoconfig
	chown abc:abc /config/extended/logs/autoconfig

}

LidarrRootFolderCheck () {
	if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log ":: ERROR :: No root folder found"
		log ":: ERROR :: Configure root folder in Lidarr to continue..."
		log ":: ERROR :: Exiting..."
		exit
	fi
}

GetMissingCutOffList () {
    log ":: Downloading missing list..."
    missingAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1000000000&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
    missingAlbumIdsTotal=$(echo "$missingAlbumIds" | sed -r '/^\s*$/d' | wc -l)
    log ":: FINDING MISSING ALBUMS: ${missingAlbumIdsTotal} Found"

    log ":: Downloading cutoff list..."
    cutoffAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1000000000&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
    cutoffAlbumIdsTotal=$(echo "$cutoffAlbumIds" | sed -r '/^\s*$/d'| wc -l)
    log ":: FINDING CUTOFF ALBUMS: ${cutoffAlbumIdsTotal} Found"

    wantedListAlbumIds="$(echo "${missingAlbumIds}" && echo "${cutoffAlbumIds}")"
    wantedListAlbumTotal=$(echo "$wantedListAlbumIds" | sed -r '/^\s*$/d' | wc -l)
    log ":: Searching for $wantedListAlbumTotal items"

    if [ $wantedListAlbumTotal = 0 ]; then
        log ":: No items to find, end"
        exit
    fi
}

SearchProcess () {
    wantedListAlbumIds=($(echo "${missingAlbumIds}" && echo "${cutoffAlbumIds}"))
    for id in ${!wantedListAlbumIds[@]}; do
		processNumber=$(( $id + 1 ))
        wantedAlbumId="${wantedListAlbumIds[$id]}"
        lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$wantedAlbumId?apikey=${lidarrApiKey}")"
        lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
        lidarrAlbumTitleClean=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleCleanSpaces=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleFirstWord=${lidarrAlbumTitleCleanSpaces%% *}
		lidarrAlbumForeignAlbumId=$(echo "$lidarrAlbumData" | jq -r ".foreignAlbumId")
        lidarrAlbumReleases=$(echo "$lidarrAlbumData" | jq -r ".releases")
		lidarrAlbumReleasesMinTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort | head -n1)
		lidarrAlbumReleasesMaxTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort -r | head -n1)
        #echo $lidarrAlbumData | jq -r 
        lidarrAlbumWordCount=$(echo $lidarrAlbumTitle | wc -w)
        #echo $lidarrAlbumReleases | jq -r 
        lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
        lidarrArtistId=$(echo "${lidarrArtistData}" | jq -r ".artistMetadataId")
        lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
        lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
        lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"
		lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
        tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
        tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
        deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
        deezeArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
		lidarrAlbumReleaseDate=${lidarrAlbumReleaseDate:0:10}
		lidarrAlbumReleaseDateClean="$(echo $lidarrAlbumReleaseDate | sed -e "s%[^[:digit:]]%%g")"
		currentDate="$(date "+%F")"
		currentDateClean="$(echo "$currentDate" | sed -e "s%[^[:digit:]]%%g")"

		if [[ ${currentDateClean} -gt ${lidarrAlbumReleaseDateClean} ]]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Starting Search..."
		else
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Album ($lidarrAlbumReleaseDate) has not been released, skipping..."
			continue
		fi

		if [ -f "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId" ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Previously Not Found, skipping..."
			continue
		fi

		if [ "$dlClientSource" = "deezer" ];then
			skipTidal=true
			skipDeezer=false
		fi

		if [ "$dlClientSource" = "tidal" ];then
			skipDeezer=true
			skipTidal=false
		fi

		if [ "$dlClientSource" = "both" ];then
            skipDeezer=false
            skipTidal=false
        fi
		
		if [ "$skipDeezer" = "false" ]; then
			if [ -z "$deezerArtistUrl" ]; then 
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/deezer-arist-id-not-found.txt\" for more detail..."
				touch "/config/logs/deezer-arist-id-not-found.txt"
				if cat "/config/logs/deezer-arist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Deezer Artist Link" >> "/config/logs/deezer-arist-id-not-found.txt"
					chmod 666 "/config/logs/deezer-arist-id-not-found.txt"
					chown abc:abc "/config/logs/deezer-arist-id-not-found.txt"
				fi
				skipDeezer=true
			fi
		fi

		if [ "$skipDeezer" = "false" ]; then
			for dId in ${!deezeArtistIds[@]}; do
				deezeArtistId="${deezeArtistIds[$dId]}"
				if [ ! -d /config/extended/cache/deezer ]; then
					mkdir -p /config/extended/cache/deezer
				fi
				if [ ! -f "/config/extended/cache/deezer/$deezeArtistId-albums.json" ]; then
					DArtistAlbumList "$deezeArtistId"
				fi
			done
		fi
        
        if [ "$skipTidal" = "false" ]; then
			if [ -z "$tidalArtistUrl" ]; then 
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-arist-id-not-found.txt\" for more detail..."
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
				curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/videos?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-videos.json
			fi

			if [ ! -f /config/extended/cache/tidal/$tidalArtistId-albums.json ]; then
				curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-albums.json
			fi

			tidalArtistAlbumsData=$(cat "/config/extended/cache/tidal/$tidalArtistId-albums.json" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
			tidalArtistAlbumsIds=($(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="true") | .id"))
		fi	
	
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
			continue
		fi
		
		# Search for explicit matches
		if [ $audioLyricType = both ] || [ $audioLyricType = explicit ]; then
			# Deezer search
			if [ "$skipDeezer" = "false" ]; then
				for dId in ${!deezeArtistIds[@]}; do
					deezeArtistId="${deezeArtistIds[$dId]}"
					if [ ! -f "/config/extended/cache/deezer/$deezeArtistId-albums.json" ]; then
						continue
					fi

					deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$deezeArtistId-albums.json" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics) | reverse | .[] | select((.nb_tracks <= $lidarrAlbumReleasesMaxTrackCount) and .nb_tracks >= $lidarrAlbumReleasesMinTrackCount)")
				
					deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="true") | select(.title | test(\"^$lidarrAlbumTitleFirstWord\";\"i\")) | .id"))

					if echo "${deezerArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
						for id in ${!deezerArtistAlbumsIds[@]}; do
							processNumberTwo=$(( $id + 1 ))
							deezerArtistAlbumId="${deezerArtistAlbumsIds[$id]}"
							deezerArtistAlbumData=$(echo "$deezerArtistAlbumsData" | jq -r "select(.id=="$deezerArtistAlbumId")")
							deezerArtistAlbumTitleClean=$(echo ${deezerArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
							if echo ${deezerArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
								downloadedAlbumTitle="$(echo ${deezerArtistAlbumData} | jq -r .title)"
								downloadedReleaseDate="$(echo ${deezerArtistAlbumData} | jq -r .release_date)"
								downloadedReleaseYear="${downloadedReleaseDate:0:4}"
								log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumTitleClean vs $deezerArtistAlbumTitleClean :: Explicit Deezer MATCH Found"
								if [ -f /config/extended/logs/downloaded/deezer/$deezerArtistAlbumId ]; then
									log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Previously Downloaded, skipping..."
									continue
								fi
								DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear"
							fi
							LidarrTaskStatusCheck
						done
					else
						log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: No Explicit Deezer Match Found"
					fi 
					
				done
			fi

			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
			if [ $alreadyImported = true ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
				continue
			fi

			# Tidal search
			if [ "$skipTidal" = "false" ]; then
				if echo "${tidalArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
					for id in ${!tidalArtistAlbumsIds[@]}; do
						processNumberTwo=$(( $id + 1 ))
						tidalArtistAlbumId="${tidalArtistAlbumsIds[$id]}"
						tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
						tidalArtistAlbumTitleClean=$(echo ${tidalArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
						if echo ${tidalArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
							downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
							downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
							if [ "$downloadedReleaseDate" = "null" ]; then
								downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
							fi
							downloadedReleaseYear="${downloadedReleaseDate:0:4}"
							log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumTitleClean vs $tidalArtistAlbumTitleClean :: Explicit Tidal Match Found"
							if [ -f /config/extended/logs/downloaded/tidal/$tidalArtistAlbumId ]; then
								log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Previously Downloaded, skipping..."
								continue
							fi
							DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear"
						fi
						LidarrTaskStatusCheck
					done
				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: No Explicit Tidal Match Found"
				fi
			fi

			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
			if [ $alreadyImported = true ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
				continue
			fi
		fi

		# Search for clean matches
		if [ $audioLyricType = both ] || [ $audioLyricType = clean ]; then
			# Deezer search
			if [ "$skipDeezer" = "false" ]; then
				for dId in ${!deezeArtistIds[@]}; do
					deezeArtistId="${deezeArtistIds[$dId]}"
					if [ ! -f "/config/extended/cache/deezer/$deezeArtistId-albums.json" ]; then
						continue
					fi
					deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$deezeArtistId-albums.json" | jq -r "sort_by(.nb_tracks) | sort_by(.explicit_lyrics) | reverse | .[] | select((.nb_tracks <= $lidarrAlbumReleasesMaxTrackCount) and .nb_tracks >= $lidarrAlbumReleasesMinTrackCount)")
					deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="false") | select(.title | test(\"^$lidarrAlbumTitleFirstWord\";\"i\")) | .id"))

					if echo "${deezerArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
						for id in ${!deezerArtistAlbumsIds[@]}; do
							processNumberTwo=$(( $id + 1 ))
							deezerArtistAlbumId="${deezerArtistAlbumsIds[$id]}"
							deezerArtistAlbumData=$(echo "$deezerArtistAlbumsData" | jq -r "select(.id=="$deezerArtistAlbumId")")
							deezerArtistAlbumExplicit=$(echo ${deezerArtistAlbumData} | jq -r .explicit_lyrics)
							deezerArtistAlbumTitleClean=$(echo ${deezerArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
							if echo ${deezerArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
								downloadedAlbumTitle="$(echo ${deezerArtistAlbumData} | jq -r .title)"
								downloadedReleaseDate="$(echo ${deezerArtistAlbumData} | jq -r .release_date)"
								downloadedReleaseYear="${downloadedReleaseDate:0:4}"
								log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumTitleClean vs $deezerArtistAlbumTitleClean :: CLEAN Deezer MATCH Found"
								if [ -f /config/extended/logs/downloaded/deezer/$deezerArtistAlbumId ]; then
								log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Previously Downloaded, skipping..."
									continue
								fi
								DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear"
							fi
							LidarrTaskStatusCheck
						done
					else
						log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: No Clean Deezer Match Found"
					fi
					LidarrTaskStatusCheck
				done
			fi

			LidarrTaskStatusCheck

			CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
			if [ $alreadyImported = true ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
				continue
			fi

			# Tidal search
			if [ "$skipTidal" = "false" ]; then

				tidalArtistAlbumsIds=($(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="false") | .id"))

				if echo "${tidalArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
					for id in ${!tidalArtistAlbumsIds[@]}; do
						processNumberTwo=$(( $id + 1 ))
						tidalArtistAlbumId="${tidalArtistAlbumsIds[$id]}"
						tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
						tidalArtistAlbumTitleClean=$(echo ${tidalArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
						if echo ${tidalArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
							downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
							downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
							if [ "$downloadedReleaseDate" = "null" ]; then
								downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
							fi
							downloadedReleaseYear="${downloadedReleaseDate:0:4}"
							log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumTitleClean vs $tidalArtistAlbumTitleClean :: CLEAN Tidal Match Found"
							if [ -f /config/extended/logs/downloaded/tidal/$tidalArtistAlbumId ]; then
								log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Previously Downloaded, skipping..."
								continue
							fi
							DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear"
						fi
						LidarrTaskStatusCheck
					done
				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: No Clean Tidal Match Found"
				fi
			fi
		fi

		mkdir -p /config/extended/logs/downloaded/notfound
		touch /config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId
	done
}

ProcessWithBeets () {
	
	trackcount=$(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)

	if [ -f /scripts/library.blb ]; then
		rm /scripts/library.blb
		sleep 0.1
	fi
	if [ -f /scripts/beets.log ]; then 
		rm /scripts/beets.log
		sleep 0.1
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi
	touch "/config/beets-match"
	sleep 0.1

	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l) -gt 0 ]; then
		beet -c /scripts/beets-config.yaml -l /scripts/library.blb -d "$1" import -qC "$1"
		if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-match" | wc -l) -gt 0 ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: SUCCESS: Matched with beets!"
		else
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Unable to match using beets to a musicbrainz release, marking download as failed..."
			touch "/config/beets-match-error"
		fi	
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi

	if [ -f "/config/beets-match-error" ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Beets could not match album, skipping..."
		rm "/config/beets-match-error"
        rm -rf "$1"
		return
	else
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: BEETS MATCH FOUND!"
	fi

	GetFile=$(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n1)
	if [ $albumquality = opus ]; then
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".streams[].tags")
	else
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".format.tags")
	fi
	if [ $albumquality = flac ] || [ $albumquality = opus ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASEGROUPID")"
	elif [ $albumquality = mp3 ] || [ $albumquality = m4a ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r '."MusicBrainz Release Group Id"')"
	fi
	if [ $albumquality = m4a ]; then
		if [ $audioFormat = alac ]; then
			albumquality=alac
		else	
			albumquality=aac
		fi
	fi
	matchedLidarrAlbumData=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$matchedTagsAlbumReleaseGroupId" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[].album")
	matchedTagsAlbumTitle="$(echo $matchedLidarrAlbumData | jq -r ".title")"
	matchedTagsAlbumTitleClean="$(echo "$matchedTagsAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
	matchedTagsAlbumReleaseDate="$(echo $matchedLidarrAlbumData | jq -r ".releaseDate")"
	matchedTagsAlbumYear="${matchedTagsAlbumReleaseDate:0:4}"
	matchedLidarrAlbumArtistId="$(echo "$matchedLidarrAlbumData" | jq -r ".artist.foreignArtistId")"
	matchedLidarrAlbumArtistName="$(echo "$matchedLidarrAlbumData" | jq -r ".artist.artistName")"
	matchedLidarrAlbumArtistCleanName="$(echo "$matchedLidarrAlbumData" | jq -r ".artist.cleanName")"

	if [ ! -d /config/extended/logs/downloaded/found ]; then
		mkdir -p /config/extended/logs/downloaded/found
	fi

	touch /config/extended/logs/downloaded/found/$matchedTagsAlbumReleaseGroupId
	
	CheckLidarrBeforeImport "$matchedTagsAlbumReleaseGroupId" "beets"
	if [ $alreadyImported = true ]; then
		rm -rf "$1"
		return
	fi

	if [ "$matchedLidarrAlbumArtistId" = "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $matchedLidarrAlbumArtistName is Varoius Artists, skipping..."
		rm -rf "$1"
		return
	else
		if [ "${matchedLidarrAlbumArtistCleanName}" != "null" ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId) found in Lidarr"
		else
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId) NOT found in Lidarr"
			data=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$matchedLidarrAlbumArtistId" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[]")
			artistName="$(echo "$data" | jq -r ".artist.artistName")"
			foreignId="$(echo "$data" | jq -r ".foreignId")"
			data=$(curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[]")
			path="$(echo "$data" | jq -r ".path")"
			qualityProfileId="$(echo "$data" | jq -r ".defaultQualityProfileId")"
			metadataProfileId="$(echo "$data" | jq -r ".defaultMetadataProfileId")"
			data="{
				\"artistName\": \"$artistName\",
				\"foreignArtistId\": \"$foreignId\",
				\"qualityProfileId\": $qualityProfileId,
				\"metadataProfileId\": $metadataProfileId,
				\"rootFolderPath\": \"$path\"
				}"
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Adding Missing Artist to Lidarr :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId)..."
			lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Allowing Lidarr Artist Update, pause for 2 min..."
			LidarrTaskStatusCheck
		fi
	fi
	matchedLidarrAlbumArtistCleanName="$(echo "$matchedLidarrAlbumArtistName" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"


	downloadedAlbumFolder="${matchedLidarrAlbumArtistCleanName}-${matchedTagsAlbumTitleClean} ($matchedTagsAlbumYear)-${albumquality^^}-$3"
	if [ "$1" != "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" ];then
		mv "$1" "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
	fi
	chmod -R 777 "/downloads/lidarr-extended/complete"
	chown -R abc:abc "/downloads/lidarr-extended/complete"
}

CheckLidarrBeforeImport () {

	alreadyImported=false
	if [ "$2" = "beets" ]; then
		lidarrAlbumData=$(curl -s --header "X-Api-Key:"${lidarrApiKey} --request GET  "$lidarrUrl/api/v1/album/" | jq -r ".[]")

		lidarrPercentOfTracks=$(echo "$lidarrAlbumData" | jq -r "select(.foreignAlbumId==\"$1\") | .statistics.percentOfTracks")
		if [ "$lidarrPercentOfTracks" = "null" ]; then
			lidarrPercentOfTracks=0
		fi
		if [ $lidarrPercentOfTracks -gt 0 ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Already Imported"
			alreadyImported=true
			return
		fi
	fi

	if [ "$2" = "notbeets" ]; then
		if [ -f "/config/extended/logs/downloaded/found/$1" ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Previously Found, skipping..."
			alreadyImported=true
			return
		fi
	fi
}

AddRelatedArtists () {
	lidarrArtistsData="$(curl -s "$lidarrUrl/api/v1/artist?apikey=${lidarrApiKey}")"
	lidarrArtistTotal=$(echo "${lidarrArtistsData}"| jq -r '.[].sortName' | wc -l)
	lidarrArtistList=($(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId"))
	lidarrArtistIds="$(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId")"
	lidarrArtistLinkDeezerIds="$(echo "${lidarrArtistsData}" | jq -r ".[] | .links[] | select(.name==\"deezer\") | .url" | grep -o '[[:digit:]]*')"
	log ":: $lidarrArtistTotal Artists Found"
	deezerArtistsUrl=$(echo "${lidarrArtistsData}" | jq -r ".[].links | .[] | select(.name==\"deezer\") | .url")
	deezeArtistIds="$(echo "$deezerArtistsUrl" | grep -o '[[:digit:]]*' | sort -u)"

	for id in ${!lidarrArtistList[@]}; do
		artistNumber=$(( $id + 1 ))
		musicbrainzId="${lidarrArtistList[$id]}"
		lidarrArtistData=$(echo "${lidarrArtistsData}" | jq -r ".[] | select(.foreignArtistId==\"${musicbrainzId}\")")
		lidarrArtistName="$(echo "${lidarrArtistData}" | jq -r " .artistName")"
		deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
		deezerArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))

		for dId in ${!deezerArtistIds[@]}; do
			deezerArtistId="${deezerArtistIds[$dId]}"
			deezerRelatedArtistData=$(curl -sL --fail "https://api.deezer.com/artist/$deezerArtistId/related")
			getDeezerArtistsIds=($(echo $deezerRelatedArtistData | jq -r .data[].id))
			getDeezerArtistsIdsCount=$(echo $deezerRelatedArtistData | jq -r .data[].id | wc -l)
			description="$lidarrArtistName Related Artists"
			AddDeezerArtistToLidarr			
		done
	done
}

LidarrTaskStatusCheck () {
	until false
	do
		taskCount=$(curl -s "$lidarrUrl/api/v1/command?apikey=${lidarrApiKey}" | jq -r .[].status | grep -v completed | grep -v failed | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			sleep 1
		else
			break
		fi
	done
}

Configuration

if [ "$configureLidarrWithOptimalSettings" = "true" ]; then
	if [ ! -f /config/extended/logs/autoconfig ]; then
		ConfigureLidarrWithOptimalSettings
	else
		log ":: Lidarr previously configured with optimal settings, skipping..."
		log ":: To re-configure Lidarr, delete the following file:"
		log ":: /config/extended/logs/autoconfig" 
	fi
fi

LidarrRootFolderCheck

DownloadFormat

if [ "$dlClientSource" = "deezer" ] || [ "$dlClientSource" = "both" ]; then
	DeemixClientSetup
fi

if [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	TidalClientSetup
fi

if [ "$addDeezerTopArtists" = "true" ]; then
	AddDeezerTopArtists "$topLimit"
fi

if [ "$addDeezerTopAlbumArtists" = "true" ]; then
	AddDeezerTopAlbumArtists "$topLimit"
fi

if [ "$addDeezerTopTrackArtists" = "true" ]; then
	AddDeezerTopTrackArtists "$topLimit"
fi

if [ "$addRelatedArtists" = "true" ]; then
	AddRelatedArtists
fi

if [ "$dlClientSource" = "deezer" ] || [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	GetMissingCutOffList
	SearchProcess
else
	log ":: ERROR :: No valid dlClientSource set"
	log ":: ERROR :: Expected configuration :: deezer or tidal or both"
	log ":: ERROR :: dlClientSource set as: \"$dlClientSource\""
fi

exit

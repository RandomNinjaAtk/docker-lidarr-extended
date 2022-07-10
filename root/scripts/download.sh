#!/usr/bin/env bash
scriptVersion="1.0.128"
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
#dlClientSource=tidal
#topLimit=3
#addDeezerTopArtists=true
#addDeezerTopAlbumArtists=true
#addDeezerTopTrackArtists=true
#configureLidarrWithOptimalSettings=false
#audioFormat=opus
#audioBitrate=160
#addRelatedArtists=true
#numberOfRelatedArtistsToAddPerArtist=1
#beetsMatchPercentage=85

sleepTimer=0.5

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Script "$1
}

verifyApiAccess () {
	until false
	do
		lidarrTest=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .branch)
		if [ $lidarrTest = nightly ]; then
			lidarrVersion=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .version)
			log ":: Lidarr Version: $lidarrVersion"
			break
		else
			log ":: Lidarr is not ready, sleeping until valid response..."
			sleep 1
		fi
	done
}

echo "-----------------------------------------------------------------"
echo "           |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
echo "           |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
echo "              Presents: lidarr-extended ($scriptVersion)"
echo "                Docker Version: $dockerVersion"
echo "                  May the beats be with you!"
echo "-----------------------------------------------------------------"
echo "Donate: https://github.com/sponsors/RandomNinjaAtk"
echo "Project: https://github.com/RandomNinjaAtk/docker-lidarr-extended"
echo "Support: https://discord.gg/JumQXDc"
echo "-----------------------------------------------------------------"
sleep 5
echo ""
echo "Lift off in..."; sleep 0.5
echo "5"; sleep 1
echo "4"; sleep 1
echo "3"; sleep 1
echo "2"; sleep 1
echo "1"; sleep 1



if [ ! -d /config/xdg ]; then
	mkdir -p /config/xdg
fi

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "download.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log ":: To kill script, use the following command:"
	log ":: kill -9 $processstartid"
	log ":: kill -9 $processdownloadid"
	sleep 2
	
	if [ -z $topLimit ]; then
		topLimit=10
	fi

	verifyApiAccess

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
		log ":: Add $numberOfRelatedArtistsToAddPerArtist Deezer related Artist for each Lidarr Artist"
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

	log ":: Beets Matching Threshold ${beetsMatchPercentage}%"
	beetsMatchPercentage=$(expr 100 - $beetsMatchPercentage )
	if cat /config/extended/scripts/beets-config.yaml | grep "strong_rec_thresh: 0.04" | read; then
		log ":: Configuring Beets Matching Threshold"
		sed -i "s/strong_rec_thresh: 0.04/strong_rec_thresh: 0.${beetsMatchPercentage}/g" /config/extended/scripts/beets-config.yaml
	fi
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

DownloadFolderCleaner () {
	# check for completed download folder
	if [ -d "/downloads/lidarr-extended/complete" ]; then
		log ":: Removing prevously completed downloads that failed to import..."
		# check for completed downloads older than 1 day
		if find /downloads/lidarr-extended/complete -mindepth 1 -type d -mtime +1 | read; then
			# delete completed downloads older than 1 day, these most likely failed to import due to Lidarr failing to match
			find /downloads/lidarr-extended/complete -mindepth 1 -type d -mtime +1 -exec rm -rf "{}" \; &>/dev/null
		fi
	fi
}

NotFoundFolderCleaner () {
	# check for completed download folder
	if [ -d /config/extended/logs/downloaded/notfound ]; then
		log ":: Removing prevously notfound lidarr album ids older than 7 days to give them a retry..."
		# check for notfound entries older than 7 days
		if find /config/extended/logs/downloaded/notfound -mindepth 1 -type f -mtime +7 | read; then
			# delete ntofound entries older than 7 days
			find /config/extended/logs/downloaded/notfound -mindepth 1 -type f -mtime +7 -delete
		fi
	fi
}

AddDeezerTopArtists () {
	getDeezerArtistsIds=$(curl -s "https://api.deezer.com/chart/0/artists?limit=$1" | jq -r ".data[].id")
	getDeezerArtistsIdsCount=$(echo "$getDeezerArtistsIds" | wc -l)
	getDeezerArtistsIds=($(echo "$getDeezerArtistsIds"))
	sleep $sleepTimer
	description="Top Artists"
	AddDeezerArtistToLidarr
}

AddDeezerTopAlbumArtists () {
	getDeezerArtistsIds=$(curl -s "https://api.deezer.com/chart/0/albums?limit=$1" | jq -r ".data[].artist.id")
	getDeezerArtistsIdsCount=$(echo "$getDeezerArtistsIds" | wc -l)
	getDeezerArtistsIds=($(echo "$getDeezerArtistsIds"))
	sleep $sleepTimer
	description="Top Album Artists"
	AddDeezerArtistToLidarr
}

AddDeezerTopTrackArtists () {
	getDeezerArtistsIds=$(curl -s "https://api.deezer.com/chart/0/tracks?limit=$1" | jq -r ".data[].artist.id")
	getDeezerArtistsIdsCount=$(echo "$getDeezerArtistsIds" | wc -l)
	getDeezerArtistsIds=($(echo "$getDeezerArtistsIds"))
	sleep $sleepTimer
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
		sleep $sleepTimer
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
				\"rootFolderPath\": \"$path\",
				\"addOptions\":{\"searchForMissingAlbums\":false}
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
		LidarrTaskStatusCheck
	done
}

DArtistAlbumList () {
	
	albumids=$(python3 /config/extended/scripts/discography.py "$1" | sort -u)
	albumcount="$(echo "$albumids" | wc -l)"
	
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Searching Artist ID \"$1\" for All Albums...."
	if [ $albumcount -gt 0 ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle ::  $albumcount Albums found!"
	else
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: $albumcount Albums found, skipping..."
		return
	fi
	albumids=($(echo "$albumids"))
		
	for id in ${!albumids[@]}; do
		currentprocess=$(( $id + 1 ))
		albumid="${albumids[$id]}"
		if [ ! -d /config/extended/cache/deezer/ ]; then
			mkdir -p /config/extended/cache/deezer
			chmod 777 /config/extended/cache/deezer
			chown -R abc:abc /config/extended/cache/deezer
		fi

		if [ -f /config/extended/cache/deezer/${albumid}.json ]; then
			if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/${albumid}.json)"; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Album info already downloaded and verified..."
				continue
			else
				rm "/config/extended/cache/deezer/${albumid}.json"
			fi
		fi

		until false
		do
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Downloading Album info..."
			curl -s "https://api.deezer.com/album/${albumid}" -o "/config/extended/cache/deezer/${albumid}.json"
			sleep $sleepTimer
			if [ -f "/config/extended/cache/deezer/${albumid}.json" ]; then
				if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/${albumid}.json)"; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Album info downloaded and verified..."
					chmod 666 /config/extended/cache/deezer/${albumid}.json
					chown abc:abc /config/extended/cache/deezer/${albumid}.json	
					albumInfoVerified=true
					break
				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Error getting album information"
					if [ -f "/config/extended/cache/deezer/${albumid}.json" ]; then
						rm "/config/extended/cache/deezer/${albumid}.json"
					fi
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: Retrying..."
				fi
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $currentprocess of $albumcount :: ERROR :: Download Failed"
			fi
		done

		if [ $albumInfoVerified = true ]; then
			continue
		fi
	done
	
	if [ -f /config/extended/cache/deezer/$1-albums-temp.json ]; then
		rm /config/extended/cache/deezer/$1-albums-temp.json
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

	if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/$1-albums.json)"; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Album list verified..."
	else
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Existing album list failed verification..."
		rm /config/extended/cache/deezer/$1-albums.json
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

	
	if [ -f /config/xdg/.tidal-dl.token.json ]; then
		if [[ $(find "/config/xdg/.tidal-dl.token.json" -mtime +5 -print) ]]; then
			log ":: TIDAL :: ERROR :: Token expired, removing..."
			rm /config/xdg/.tidal-dl.token.json
		fi
	fi

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		log ":: TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		pip3 install tidal-dl==2022.3.4.2
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
	
	log ":: TIDAL :: Upgrade tidal-dl to the latest..."
	pip3 install tidal-dl --upgrade
	tidal-dl -o /downloads/lidarr-extended/incomplete -l "166356219"
	
	downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		if [ -f /config/xdg/.tidal-dl.token.json ]; then
			rm /config/xdg/.tidal-dl.token.json
		fi
		log ":: tidal-dl client setup verification :: ERROR :: Download failed"
		log ":: tidal-dl client setup verification :: ERROR :: You will need to re-authenticate on next script run..."
		log ":: tidal-dl client setup verification :: ERROR :: Exiting..."
		rm -rf /downloads/lidarr-extended/incomplete/*
		exit
	else
		rm -rf /downloads/lidarr-extended/incomplete/*
		log ":: tidal-dl client setup verification :: Download Verification Success"
	fi
}

DownloadProcess () {

	# Required Input Data
	# $1 = Album ID to download from online Service
	# $2 = Download Client Type (DEEZER or TIDAL)
	# $3 = Album Year that matches Album ID Metadata
	# $4 = Album Title that matches Album ID Metadata

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

	downloadedAlbumTitleClean="$(echo "$4" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
    downloadedAlbumFolder="$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-${albumquality^^}-$2"
	
	if find /downloads/lidarr-extended/complete -type d -iname "$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-*-$2" | read; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Previously Downloaded..."
		return
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
        tidal-dl -o /downloads/lidarr-extended/incomplete -l "$1"
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

    # ProcessWithBeets "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" "${albumquality^^}" "$2"

    if [ -d "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" ]; then
        NotifyLidarrForImport "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
    fi
    rm -rf /downloads/lidarr-extended/incomplete/*

	# NotifyPlexToScan
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$lidarrUrl/api/v1/command" --header "X-Api-Key:"${lidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

NotifyPlexToScan () {
	LidarrTaskStatusCheck
	CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
	if [ $alreadyImported = true ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Notifying Plex to Scan :: $lidarrArtistPath"
		bash /config/extended/scripts/PlexNotify.bash "$lidarrArtistPath"
	fi
}


DeemixClientSetup () {
	log ":: DEEZER :: Verifying deemix configuration"
	if [ ! -z "$arlToken" ]; then
		arlToken="$(echo $arlToken | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
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
	
	if [ -f "/config/xdg/deemix/config.json" ]; then
		rm /config/xdg/deemix/config.json
	fi
	
	if [ -f "/config/extended/scripts/deemix_config.json" ]; then
		log ":: DEEZER :: Configuring deemix client"
		cp /config/extended/scripts/deemix_config.json /config/xdg/deemix/config.json
		chmod 777 /config/xdg/deemix/config.json
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

	log ":: DEEZER :: Upgrade deemix to the latest..."
	pip3 install deemix --upgrade

	deemix -b $deemixQuality -p /downloads/lidarr-extended/incomplete "https://www.deezer.com/album/197472472"
	if [ -d "/tmp/deemix-imgs" ]; then
		rm -rf /tmp/deemix-imgs
	fi
	downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		log ":: deemix client setup verification :: ERROR :: Download failed"
		log ":: deemix client setup verification :: ERROR :: Please review log for errors in client"
		log ":: deemix client setup verification :: ERROR :: Try updating your ARL Token to possibly resolve the issue..."
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
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/metadataProvider" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"metadataSource":"","writeAudioTags":"allFiles","scrubAudioTags":false,"id":1}')

	log ":: Configuring Lidarr Custom Scripts"
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "PlexNotify.bash" | read; then
		log ":: PlexNotify.bash Already added to Lidarr custom scripts"
	else
		log ":: Adding PlexNotify.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlexNotify.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":false,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"PlexNotify.bash","fields":[{"name":"path","value":"/config/extended/scripts/PlexNotify.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
	fi
	
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "Plex_MusicVideos.bash" | read; then
		log ":: Plex_MusicVideos.bash Already added to Lidarr custom scripts"
	else
		log ":: Adding Plex_MusicVideos.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlex_MusicVideos.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":false,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"Plex_MusicVideos.bash","fields":[{"name":"path","value":"/config/extended/scripts/Plex_MusicVideos.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
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
        
	if [ -d  /config/extended/cache/lidarr/list ]; then
		rm -rf  /config/extended/cache/lidarr/list
		sleep 0.1
	fi

	mkdir -p /config/extended/cache/lidarr/list

	# Get missing album list
	lidarrMissingTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r .totalRecords)
	log ":: FINDING MISSING ALBUMS"

	if [ $lidarrMissingTotalRecords -le 1000 ]; then
		amountPerPull=500
	elif [ $lidarrMissingTotalRecords -le 10000 ]; then
		amountPerPull=1000
	elif [ $lidarrMissingTotalRecords -le 20000 ]; then
		amountPerPull=2000
	elif [ $lidarrMissingTotalRecords -le 30000 ]; then
		amountPerPull=3000
	elif [ $lidarrMissingTotalRecords -le 40000 ]; then
		amountPerPull=4000
	elif [ $lidarrMissingTotalRecords -le 50000 ]; then
		amountPerPull=5000
	elif [ $lidarrMissingTotalRecords -le 60000 ]; then
		amountPerPull=6000
	elif [ $lidarrMissingTotalRecords -le 70000 ]; then
		amountPerPull=7000
	elif [ $lidarrMissingTotalRecords -le 80000 ]; then
		amountPerPull=8000
	elif [ $lidarrMissingTotalRecords -le 90000 ]; then
		amountPerPull=9000
	else
		amountPerPull=10000
	fi

	if [ $lidarrMissingTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrMissingTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ $dlnumber -gt $lidarrMissingTotalRecords ]; then
				dlnumber=$lidarrMissingTotalRecords
			fi
			log ":: Downloading page $page... ($offset - $dlnumber of $lidarrMissingTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=$page&pagesize=$amountPerPull&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			for lidarrRecordId in $(echo $lidarrRecords); do
				touch /config/extended/cache/lidarr/list/${lidarrRecordId}-missing
			done
		done
	fi

	log ":: ${lidarrMissingTotalRecords} MISSING ALBUMS FOUND"

	# Get cutoff album list
	lidarrCutoffTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r .totalRecords)

	log ":: FINDING CUTOFF ALBUMS"

	if [ $lidarrCutoffTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrCutoffTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ $dlnumber -gt $lidarrCutoffTotalRecords ]; then
				dlnumber=$lidarrCutoffTotalRecords
			fi
			log ":: Downloading page $page... ($offset - $dlnumber of $lidarrCutoffTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=$page&pagesize=$amountPerPull&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			for lidarrRecordId in $(echo $lidarrRecords); do
				touch /config/extended/cache/lidarr/list/${lidarrRecordId}-cutoff
			done
		done
	fi

	log ":: ${lidarrCutoffTotalRecords} CUTOFF ALBUMS FOUND"
	
	wantedListAlbumTotal=$(( $lidarrMissingTotalRecords + $lidarrCutoffTotalRecords ))
    
	log ":: Searching for $wantedListAlbumTotal items"
}

SearchProcess () {

	if [ $wantedListAlbumTotal = 0 ]; then
        log ":: No items to find, end"
        return
    fi

    processNumber=0
	for lidarrMissingId in $(ls -tr /config/extended/cache/lidarr/list); do
		processNumber=$(( $processNumber + 1 ))
		wantedAlbumId=$(echo $lidarrMissingId | sed -e "s%[^[:digit:]]%%g")
		wantedAlbumListSource=$(echo $lidarrMissingId | sed -e "s%[^[:alpha:]]%%g")
		lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$wantedAlbumId?apikey=${lidarrApiKey}")"
		lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
		lidarrAlbumTitleClean=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleCleanSpaces=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleFirstWord=${lidarrAlbumTitleCleanSpaces%% *}
		lidarrAlbumForeignAlbumId=$(echo "$lidarrAlbumData" | jq -r ".foreignAlbumId")
		lidarrAlbumReleases=$(echo "$lidarrAlbumData" | jq -r ".releases")
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
		tidalArtistIds="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
		deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
		lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
		lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
		lidarrAlbumReleaseDate=${lidarrAlbumReleaseDate:0:10}
		lidarrAlbumReleaseDateClean="$(echo $lidarrAlbumReleaseDate | sed -e "s%[^[:digit:]]%%g")"
		lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
		
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

		# Search Musicbrainz for Deezer Album ID
		if [ $audioLyricType = both ]; then
			if [ "$skipDeezer" = "false" ]; then
				# Verify it's not already imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
					continue
				fi

				# Search Musicbrainz
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Deezer Album ID :: Searching for Album ID..."
				msuicbrainzDeezerDownloadAlbumID=$(curl -s "https://musicbrainz.org/ws/2/release?release-group=$lidarrAlbumForeignAlbumId&inc=url-rels&fmt=json" | jq -r | grep "deezer.com" | grep "album" | head -n 1 | sed -e "s%[^[:digit:]]%%g")
				sleep 1.5
				
				# Process Album ID if found
				if [ ! -z $msuicbrainzDeezerDownloadAlbumID ]; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Deezer Album ID :: FOUND!"
					if [ -f "/config/extended/cache/deezer/${msuicbrainzDeezerDownloadAlbumID}.json" ]; then
						deezerArtistAlbumData="$(cat "/config/extended/cache/deezer/${msuicbrainzDeezerDownloadAlbumID}.json")"
					else
						deezerArtistAlbumData="$(curl -s "https://api.deezer.com/album/${msuicbrainzDeezerDownloadAlbumID}")"
					fi
		
					DownloadProcess "$msuicbrainzDeezerDownloadAlbumID" "DEEZER" "$lidarrAlbumReleaseYear" "$lidarrAlbumTitle"

					# Verify it was successfully imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
						continue
					fi
				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Deezer Album ID :: NOT FOUND!"
				fi
			fi
		fi

		# Search Musicbrainz for Tidal Album ID
		if [ $audioLyricType = both ]; then
			if [ "$skipTidal" = "false" ]; then
				# Verify it's not already imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
					continue
				fi

				# Search Musicbrainz
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Tidal Album ID :: Searching for Album ID..."
				msuicbrainzTidalDownloadAlbumID=$(curl -s "https://musicbrainz.org/ws/2/release?release-group=$lidarrAlbumForeignAlbumId&inc=url-rels&fmt=json" | jq -r | grep "tidal.com" | head -n 1 | sed -e "s%[^[:digit:]]%%g")
				sleep 1.5

				# Process Album ID if found
				if [ ! -z $msuicbrainzTidalDownloadAlbumID ]; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Tidal Album ID :: FOUND!"
					tidalArtistAlbumData="$(curl -s "https://api.tidal.com/v1/albums/${msuicbrainzTidalDownloadAlbumID}?countryCode=$tidalCountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')"
					DownloadProcess "$msuicbrainzTidalDownloadAlbumID" "TIDAL" "$lidarrAlbumReleaseYear" "$lidarrAlbumTitle"

					# Verify it was successfully imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
						continue
					fi
				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Musicbrainz Tidal Album ID :: NOT FOUND!"
				fi
			fi
		fi

		# Skip Various Artists album search that is not supported...
		if [ "$lidarrArtistForeignArtistId" = "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
			if [ $audioLyricType = both ]; then
				if [ "$skipDeezer" = "false" ]; then

					# Verify it's not already imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
						continue
					fi
					
					FuzzyDeezerSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId"

					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Various Artists is not supported by normal search, skipping..."
					continue

				else
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Various Artists is not supported by normal search, skipping..."
					continue
				fi
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Various Artists is not supported by normal search, skipping..."
				continue
			fi
		fi
		
		if [ "$skipDeezer" = "false" ]; then

			# fallback to musicbrainz db for link
			if [ -z "$deezerArtistUrl" ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: DEEZER :: Fallback to musicbrainz for Deezer ID"
				musicbrainzArtistData=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/${lidarrArtistForeignArtistId}?inc=url-rels&fmt=json")
				deezerArtistUrl=$(echo "$musicbrainzArtistData" | jq -r '.relations | .[] | .url | select(.resource | contains("deezer")) | .resource')
			fi

			if [ -z "$deezerArtistUrl" ]; then 
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/deezer-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/deezer-artist-id-not-found.txt"
				if cat "/config/logs/deezer-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Deezer Artist Link" >> "/config/logs/deezer-artist-id-not-found.txt"
					chmod 666 "/config/logs/deezer-artist-id-not-found.txt"
					chown abc:abc "/config/logs/deezer-artist-id-not-found.txt"
				fi
				skipDeezer=true
			fi
		fi

		if [ "$skipDeezer" = "false" ]; then
			deezeArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
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
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/tidal-artist-id-not-found.txt" 
				if cat "/config/logs/tidal-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/tidal-artist-id-not-found.txt"
					chmod 666 "/config/logs/tidal-artist-id-not-found.txt"
					chown abc:abc "/config/logs/tidal-artist-id-not-found.txt"
				fi
				skipTidal=true
			fi
		fi

		if [ "$skipTidal" = "false" ]; then
			if [ ! -d /config/extended/cache/tidal ]; then
				mkdir -p /config/extended/cache/tidal
			fi

			for tidalArtistId in $(echo $tidalArtistIds); do
						
				if [ ! -f /config/extended/cache/tidal/$tidalArtistId-videos.json ]; then
					curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/videos?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-videos.json
					sleep $sleepTimer
				fi

				if [ ! -f /config/extended/cache/tidal/$tidalArtistId-albums.json ]; then
					curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-albums.json
					sleep $sleepTimer
				fi
			done

			
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

					ArtistDeezerSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId" "$deezeArtistId" "true"
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
				for tidalArtistId in $(echo $tidalArtistIds); do
					if [ ! -f "/config/extended/cache/tidal/$tidalArtistId-albums.json" ]; then
						continue
					fi

					ArtistTidalSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId" "$tidalArtistId" "true"
				done	
			fi
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
			continue
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

					ArtistDeezerSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId" "$deezeArtistId" "false"
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

				for tidalArtistId in $(echo $tidalArtistIds); do
					if [ ! -f "/config/extended/cache/tidal/$tidalArtistId-albums.json"  ]; then
						continue
					fi

					ArtistTidalSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId" "$tidalArtistId" "false"
				done
			fi
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
			continue
		fi
		
		# Fallback/last resort Fuzzy Search
		if [ $audioLyricType = both ]; then
			if [ "$skipDeezer" = "false" ]; then
				# Verify it's not already imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
					continue
				fi
				FuzzyDeezerSearch "$processNumber of $wantedListAlbumTotal" "$wantedAlbumId"
			fi
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
			continue
		fi

		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Album Not found"
		if [ ! -d /config/extended/logs/downloaded/notfound ]; then
			mkdir -p /config/extended/logs/downloaded/notfound
			chmod 777 /config/extended/logs/downloaded/notfound
			chown abc:abc /config/extended/logs/downloaded/notfound
		fi
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Marking Album as notfound"
		if [ ! -f /config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId ]; then
			touch /config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId
			chmod 666 /config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId
			chown abc:abc /config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId
		fi
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Search Complete..." 
	done
}

ArtistDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lidarr Album ID
	# $3 Deezer Artist ID
	# $4 Lyric Type (true or false) - false = Clean, true = Explicit
	lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$2?apikey=${lidarrApiKey}")"
	lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
	lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
	lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
	lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
	lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
	lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
	lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"

	for lidarrAlbumReleaseId in $(echo "$lidarrAlbumReleaseIds"); do
		lidarrAlbumReleaseData=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$lidarrAlbumReleaseId)")
		lidarrAlbumReleaseTitle=$(echo "$lidarrAlbumReleaseData" | jq -r .title)
		lidarrAlbumReleaseTrackCount=$(echo "$lidarrAlbumReleaseData" | jq -r .trackCount)
		lidarrAlbumReleaseTitleClean=$(echo "$lidarrAlbumReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')

		log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: Searching Deezer ($3) for $lidarrAlbumReleaseTitle ($lidarrAlbumReleaseTrackCount)..."
		deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$3-albums.json" | jq -r ".[] | select(.nb_tracks==$lidarrAlbumReleaseTrackCount)")
		
		deezerArtistAlbumsIds=$(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="$4") | .id")

		for deezerArtistAlbumId in $(echo $deezerArtistAlbumsIds); do
			deezerArtistAlbumData=$(echo "$deezerArtistAlbumsData" | jq -r "select(.id=="$deezerArtistAlbumId")")
			downloadedAlbumTitle="$(echo ${deezerArtistAlbumData} | jq -r .title)"
			deezerAlbumTitleClean=$(echo ${downloadedAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
			downloadedReleaseDate="$(echo ${deezerArtistAlbumData} | jq -r .release_date)"
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"
		
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}")
			log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
			if [ "$diff" -le "5" ]; then
				log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"

				# Execute Download
				DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear" "$downloadedAlbumTitle"

				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					break 2
				fi
			else
				log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer Match Not Found :: Calculated Difference ($diff) greater than 5"
			fi
		done
	done

	if [ $alreadyImported = true ]; then
		return
	else
		if [ $4 = true ]; then
			type=Explicit
		else
			type=Clean
		fi
		log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Album not found via $type Artist Search..."
	fi
	
}

FuzzyDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lidarr Album ID
	lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$2?apikey=${lidarrApiKey}")"
	lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
	lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
	lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
	lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
	lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
	lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
	lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
	lidarrArtistNameSanitized="$(echo "$lidarrArtistName" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g")"
	albumArtistNameSearch="$(jq -R -r @uri <<<"${lidarrArtistNameSanitized}")"
	for lidarrAlbumReleaseId in $(echo "$lidarrAlbumReleaseIds"); do
		log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: Searching Deezer for Album..."
		lidarrAlbumReleaseData=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$lidarrAlbumReleaseId)")
		lidarrAlbumReleaseTitle=$(echo "$lidarrAlbumReleaseData" | jq -r .title)
		lidarrAlbumReleaseTitleClean="$(echo "$lidarrAlbumReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g")"
		albumTitleSearch="$(jq -R -r @uri <<<"${lidarrAlbumReleaseTitleClean}")"
		deezerSearch=""
		if [ "$lidarrArtistForeignArtistId" = "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
			# Search without Artist for VA albums
			deezerSearch=$(curl -s "https://api.deezer.com/search?q=album:%22${albumTitleSearch}%22&strict=on&limit=1000" | jq -r .data[])
		else
			# Search with Artist for non VA albums
			deezerSearch=$(curl -s "https://api.deezer.com/search?q=artist:%22${albumArtistNameSearch}%22%20album:%22${albumTitleSearch}%22&strict=on&limit=1000" | jq -r .data[])
		fi
		if [ ! -z "$deezerSearch" ]; then
			for deezerAlbumID in $(echo "$deezerSearch" | jq -r .album.id | sort -u); do
				deezerAlbumData="$(echo "$deezerSearch" | jq -r ".album | select(.id==$deezerAlbumID)")"
				deezerAlbumTitle=$(echo "$deezerAlbumData"| jq -r .title | head -n1)
				lidarrAlbumReleaseTitleClean=$(echo "$lidarrAlbumReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
				deezerAlbumTitleClean=$(echo ${deezerAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
				diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}")
				log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
				if [ "$diff" -le "5" ]; then
					log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"
					DownloadProcess "$deezerAlbumID" "DEEZER" "$lidarrAlbumReleaseYear" "$lidarrAlbumReleaseTitle"
					# Verify it was successfully imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						break 2
					fi
				else
					log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer Match Not Found :: Calculated Difference ($diff) greater than 5"
				fi
			done
		else
			log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: No results found via Fuzzy Search..."
		fi
	done
	
}

ArtistTidalSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lidarr Album ID
	# $3 Tidal Artist ID
	# $4 Lyric Type (true or false) - false = Clean, true = Explicit
	lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$2?apikey=${lidarrApiKey}")"
	lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
	lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
	lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
	lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
	lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
	lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
	lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"

	for lidarrAlbumReleaseId in $(echo "$lidarrAlbumReleaseIds"); do
		lidarrAlbumReleaseData=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$lidarrAlbumReleaseId)")
		lidarrAlbumReleaseTitle=$(echo "$lidarrAlbumReleaseData" | jq -r .title)
		lidarrAlbumReleaseTrackCount=$(echo "$lidarrAlbumReleaseData" | jq -r .trackCount)
		lidarrAlbumReleaseTitleClean=$(echo "$lidarrAlbumReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')

		log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: Searching Tidal ($3) for $lidarrAlbumReleaseTitle ($lidarrAlbumReleaseTrackCount)..."
		tidalArtistAlbumsData=$(cat "/config/extended/cache/tidal/$3-albums.json" | jq -r ".items[] | select(.numberOfTracks==$lidarrAlbumReleaseTrackCount)")

		tidalArtistAlbumsIds=$(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="$4") | .id")

		for tidalArtistAlbumId in $(echo $tidalArtistAlbumsIds); do

			
			tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
			downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
			tidalAlbumTitleClean=$(echo ${downloadedAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
			downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
			if [ "$downloadedReleaseDate" = "null" ]; then
				downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
			fi
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"
		
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${tidalAlbumTitleClean,,}")
			log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
			if [ "$diff" -le "5" ]; then
				log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"

				# Execute Download
				DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear" "$downloadedAlbumTitle"

				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					break 2
				fi
			else
				log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than 5"
			fi
		done
	done

	if [ $alreadyImported = true ]; then
		return
	else
		if [ $4 = true ]; then
			type=Explicit
		else
			type=Clean
		fi
		log ":: $1 :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Album not found via $type Artist Search..."
	fi
	
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
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Unable to match using beets to a musicbrainz release..."
			touch "/config/beets-match-error"
		fi	
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi

	if [ -f "/config/beets-match-error" ]; then
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Beets could not match album, falling back to Lidarr for matching and importing..."
		rm "/config/beets-match-error"
        # allow lidarr import...
		# rm -rf "$1"
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
				\"monitored\":true,
				\"monitor\":\"all\",
				\"rootFolderPath\": \"$path\",
				\"addOptions\":{\"searchForMissingAlbums\":false}
				}"
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Adding Missing Artist to Lidarr :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId)..."
			lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Allowing Lidarr Artist Update..."
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
		lidarrAlbumData=$(curl -s --header "X-Api-Key:"${lidarrApiKey} --request GET  "$lidarrUrl/api/v1/album/" | jq -r ".[] | select(.foreignAlbumId==\"$1\")")
		lidarrCheckAlbumId=$(echo "$lidarrAlbumData" | jq -r ".id")
		lidarrPercentOfTracks=$(echo "$lidarrAlbumData" | jq -r ".statistics.percentOfTracks")

		if [ "$lidarrPercentOfTracks" = "null" ]; then
			lidarrPercentOfTracks=0
			return
		fi
		if [ $lidarrPercentOfTracks -gt 0 ]; then
			if [ $wantedAlbumListSource = missing ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Already Imported Album (Missing)"
				alreadyImported=true
				return
			else
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Importing Album (Cutoff)"
				return
			fi
		fi
	fi

	if [ "$2" = "notbeets" ]; then
		if [ -f "/config/extended/logs/downloaded/found/$1" ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Previously Found, skipping..."
			alreadyImported=true
			return
		fi
		
		lidarrAlbumData=$(curl -s --header "X-Api-Key:"${lidarrApiKey} --request GET  "$lidarrUrl/api/v1/album/" | jq -r ".[] | select(.foreignAlbumId==\"$1\")")
		lidarrCheckAlbumId=$(echo "$lidarrAlbumData" | jq -r ".id")
		lidarrPercentOfTracks=$(echo "$lidarrAlbumData" | jq -r ".statistics.percentOfTracks")

		if [ "$lidarrPercentOfTracks" = "null" ]; then
			lidarrPercentOfTracks=0
			return
		fi
		if [ ${lidarrPercentOfTracks%%.*} -ge 100 ]; then
			if [ $wantedAlbumListSource = missing ]; then
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Already Imported Album (Missing), skipping..."
				alreadyImported=true
				return
			fi
		fi
	fi
}

AddRelatedArtists () {
	log ":: Begin adding Lidarr related Artists from Deezer..."
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
		lidarrArtistMonitored=$(echo "${lidarrArtistData}" | jq -r ".monitored")
		log ":: $artistNumber of $lidarrArtistTotal :: $lidarrArtistName :: Adding Related Artists..."
		if [ $lidarrArtistMonitored = false ]; then
			log ":: $artistNumber of $lidarrArtistTotal :: $lidarrArtistName :: Artist is not monitored :: skipping..."
			continue
		fi

		for dId in ${!deezerArtistIds[@]}; do
			deezerArtistId="${deezerArtistIds[$dId]}"
			deezerRelatedArtistData=$(curl -sL --fail "https://api.deezer.com/artist/$deezerArtistId/related?limit=$numberOfRelatedArtistsToAddPerArtist"| jq -r ".data | sort_by(.nb_fan) | reverse | .[]")
			sleep $sleepTimer
			getDeezerArtistsIds=($(echo $deezerRelatedArtistData | jq -r .id))
			getDeezerArtistsIdsCount=$(echo $deezerRelatedArtistData | jq -r .id | wc -l)
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
			log ":: STATUS :: LIDARR BUSY :: Waiting for all active Lidarr tasks to end..."
			sleep 1
		else
			break
		fi
	done
}

LidarrMissingAlbumSearch () {

	log ":: Begin searching for missing artist albums via Lidarr Indexers..."
	lidarrArtistIds=$(echo $lidarrMissingAlbumArtistsData | jq -r .id)
	lidarrArtistIdsCount=$(echo "$lidarrArtistIds" | wc -l)
	processCount=0
	for lidarrArtistId in $(echo $lidarrArtistIds); do
		processCount=$(( $processCount + 1))
		lidarrArtistData=$(echo $lidarrMissingAlbumArtistsData | jq -r "select(.id==$lidarrArtistId)")
		lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
		lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
		if [ -d /config/extended/logs/searched/lidarr/artist ]; then
			if [ -f /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId ]; then
				log ":: $processCount of $lidarrArtistIdsCount :: Previously Notified Lidarr to search for \"$lidarrArtistName\" :: Skipping..."
				continue
			fi
		fi
		log ":: $processCount of $lidarrArtistIdsCount :: Notified Lidarr to search for \"$lidarrArtistName\""
		startLidarrArtistSearch=$(curl -s "$lidarrUrl/api/v1/command" -X POST -H "Content-Type: application/json" -H "X-Api-Key: $lidarrApiKey"  --data-raw "{\"name\":\"ArtistSearch\",\"artistId\":$lidarrArtistId}")
		if [ ! -d /config/extended/logs/searched/lidarr/artist ]; then
			mkdir -p /config/extended/logs/searched/lidarr/artist
			chmod -R 777 /config/extended/logs/searched/lidarr/artist
			chown -R abc:abc /config/extended/logs/searched/lidarr/artist
		fi
		touch /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
		chmod 666 /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
		chown abc:abc /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
	done
}

function levenshtein {
	if (( $# != 2 )); then
		echo "Usage: $0 word1 word2" >&2
	elif (( ${#1} < ${#2} )); then
		levenshtein "$2" "$1"
	else
		local str1len=${#1}
		local str2len=${#2}
		local d

		for (( i = 0; i <= (str1len+1)*(str2len+1); i++ )); do
			d[i]=0
		done

		for (( i = 0; i <= str1len; i++ )); do
			d[i+0*str1len]=$i
		done

		for (( j = 0; j <= str2len; j++ )); do
			d[0+j*(str1len+1)]=$j
		done

		for (( j = 1; j <= str2len; j++ )); do
			for (( i = 1; i <= str1len; i++ )); do
				[ "${1:i-1:1}" = "${2:j-1:1}" ] && local cost=0 || local cost=1
				del=$(( d[(i-1)+str1len*j]+1 ))
				ins=$(( d[i+str1len*(j-1)]+1 ))
				alt=$(( d[(i-1)+str1len*(j-1)]+cost ))
				d[i+str1len*j]=$( echo -e "$del\n$ins\n$alt" | sort -n | head -1 )
			done
		done
		echo ${d[str1len+str1len*(str2len)]}
	fi
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

# Perform Completed Download Folder Cleanup process
DownloadFolderCleaner

# Perform NotFound Folder Cleanup process
NotFoundFolderCleaner

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

# Get artist list for LidarrMissingAlbumSearch process, to prevent searching for artists that will not be processed by the script
lidarrMissingAlbumArtistsData=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/artist?apikey=$lidarrApiKey" | jq -r .[])

if [ "$dlClientSource" = "deezer" ] || [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	GetMissingCutOffList
	SearchProcess	
else
	log ":: ERROR :: No valid dlClientSource set"
	log ":: ERROR :: Expected configuration :: deezer or tidal or both"
	log ":: ERROR :: dlClientSource set as: \"$dlClientSource\""
fi

if [ "$addDeezerTopArtists" = "true" ] || [ "$addDeezerTopAlbumArtists" = "true" ] || [ "$addDeezerTopTrackArtists" = "true" ] || [ "$addRelatedArtists" = "true" ]; then
	LidarrMissingAlbumSearch
fi

log ":: Script end..."
exit

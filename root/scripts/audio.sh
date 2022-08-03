#!/usr/bin/env bash
scriptVersion="1.0.224"
if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" = "null" ]; then
		lidarrUrlBase=""
	else
		lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
	fi
	lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
	lidarrUrl="http://127.0.0.1:8686${lidarrUrlBase}"
fi
agent="lidarr-extended ( https://github.com/RandomNinjaAtk/docker-lidarr-extended )"
musicbrainzMirror=https://musicbrainz.org

# Debugging settings
#dlClientSource=both
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
#requireQuality=true
#searchSort=album

sleepTimer=0.5

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Audio :: "$1
}

verifyApiAccess () {
	until false
	do
		lidarrTest=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .branch)
		if [ $lidarrTest = master ]; then
			lidarrVersion=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .version)
			log "Lidarr Version: $lidarrVersion"
			break
		else
			log "Lidarr is not ready, sleeping until valid response..."
			sleep 1
		fi
	done
}

log "-----------------------------------------------------------------------------"
log " |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
log " |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
log " Presents: lidarr-extended ($scriptVersion)"
log " Docker Version: $dockerVersion"
log " May the beats be with you!"
log "-----------------------------------------------------------------------------"
log "Donate: https://github.com/sponsors/RandomNinjaAtk"
log "Project: https://github.com/RandomNinjaAtk/docker-lidarr-extended"
log "Support: https://github.com/RandomNinjaAtk/docker-lidarr-extended/discussions"
log "-----------------------------------------------------------------------------"
sleep 5
log ""
log "Lift off in..."; sleep 0.5
log "5"; sleep 1
log "4"; sleep 1
log "3"; sleep 1
log "2"; sleep 1
log "1"; sleep 1



if [ ! -d /config/xdg ]; then
	mkdir -p /config/xdg
fi

Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start_audio.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "audio.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	sleep 2
	
	if [ -z $topLimit ]; then
		topLimit=10
	fi

	verifyApiAccess

	if [ "$addDeezerTopArtists" = "true" ]; then
		log "Add Deezer Top $topLimit Artists is enabled"
	else
		log "Add Deezer Top Artists is disabled (enable by setting addDeezerTopArtists=true)"
	fi

	if [ "$addDeezerTopAlbumArtists" = "true" ]; then
		log "Add Deezer Top $topLimit Album Artists is enabled"
	else
		log "Add Deezer Top Album Artists is disabled (enable by setting addDeezerTopAlbumArtists=true)"
	fi

	if [ "$addDeezerTopTrackArtists" = "true" ]; then
		log "Add Deezer Top $topLimit Track Artists is enabled"
	else
		log "Add Deezer Top Track Artists is disabled (enable by setting addDeezerTopTrackArtists=true)"
	fi

	if [ "$addRelatedArtists" = "true" ]; then
		log "Add Deezer Related Artists is enabled"
		log "Add $numberOfRelatedArtistsToAddPerArtist Deezer related Artist for each Lidarr Artist"
	else
		log "Add Deezer Related Artists is disabled (enable by setting addRelatedArtists=true)"
	fi

	if [ "$configureLidarrWithOptimalSettings" = "true" ]; then
		log "Configure Lidarr with optimal settings is enabled"
		
	else
		log "Configure Lidarr with optimal settings is disabled (enable by setting configureLidarrWithOptimalSettings=true)"
	fi
	
	log "Download Location :: $downloadPath"
	log "Output format = $audioFormat"
	log "Output bitrate = $audioBitrate"

	if [ "$requireQuality" = "true" ]; then
		log "Download Quality Check Enabled"
	else
		log "Download Quality Check Disabled (enable by setting: requireQuality=true"
	fi

	if [ $audioLyricType = both ] || [ $audioLyricType = explicit ] || [ $audioLyricType = explicit ]; then
		log "Preferred audio lyric type: $audioLyricType"
	fi
	log "Tidal Country Code set to: $tidalCountryCode"

	if [ $enableReplaygainTags = true ]; then
		log "Replaygain Tagging Enabled"
	else
		log "Replaygain Tagging Disabled"
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
			log "ERROR :: Invalid audioFormat and audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a low, high, or lossless..."
			log "ERROR :: Exiting..."
			exit
		fi
	else
		if [ $audioBitrate = lossless ] || [ $audioBitrate = high ] || [ $audioBitrate = low ]; then
			log "ERROR :: Invalid audioFormat and audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a desired bitrate number, example: 192..."
			log "ERROR :: Exiting..."
			exit
		else
			tidal-dl -q HiFi
			deemixQuality=flac
		fi
	fi
}

DownloadFolderCleaner () {
	# check for completed download folder
	if [ -d "$downloadPath/complete" ]; then
		log "Removing prevously completed downloads that failed to import..."
		# check for completed downloads older than 1 day
		if find $downloadPath/complete -mindepth 1 -type d -mtime +1 | read; then
			# delete completed downloads older than 1 day, these most likely failed to import due to Lidarr failing to match
			find $downloadPath/complete -mindepth 1 -type d -mtime +1 -exec rm -rf "{}" \; &>/dev/null
		fi
	fi
}

NotFoundFolderCleaner () {
	# check for completed download folder
	if [ -d /config/extended/logs/notfound ]; then
		# check for notfound entries older than 90 days
		if find /config/extended/logs/notfound -mindepth 1 -type f -mtime +90 | read; then
			log "Removing prevously notfound lidarr album ids older than 90 days to give them a retry..."
			# delete ntofound entries older than 90 days
			find /config/extended/logs/notfound -mindepth 1 -type f -mtime +90 -delete
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
	deezerArtistIds="$(echo "$deezerArtistsUrl" | grep -o '[[:digit:]]*' | sort -u)"
	log "Finding $description..."
	log "$getDeezerArtistsIdsCount $description Found..."
	for id in ${!getDeezerArtistsIds[@]}; do
		currentprocess=$(( $id + 1 ))
		deezerArtistId="${getDeezerArtistsIds[$id]}"
		deezerArtistName="$(curl -s https://api.deezer.com/artist/$deezerArtistId | jq -r .name)"
		sleep $sleepTimer
		log "$currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Searching Musicbrainz for Deezer artist id ($deezerArtistId)"

		if echo "$deezerArtistIds" | grep "^${deezerArtistId}$" | read; then
			log "$currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: $deezerArtistId already in Lidarr..."
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
				log "$currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Already in Lidarr ($musicbrainz_main_artist_id), skipping..."
				continue
			fi
			log "$currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Adding $artistName to Lidarr ($musicbrainz_main_artist_id)..."
			LidarrTaskStatusCheck
			lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
		else
			log "$currentprocess of $getDeezerArtistsIdsCount :: $deezerArtistName :: Artist not found in Musicbrainz, please add \"https://deezer.com/artist/${deezerArtistId}\" to the correct artist on Musicbrainz"
		fi
		LidarrTaskStatusCheck
	done
}

TidalClientSetup () {
	log "TIDAL :: Verifying tidal-dl configuration"
	touch /config/xdg/.tidal-dl.log
	if [ -f /config/xdg/.tidal-dl.json ]; then
		rm /config/xdg/.tidal-dl.json
	fi
	if [ ! -f /config/xdg/.tidal-dl.json ]; then
		log "TIDAL :: No default config found, importing default config \"tidal.json\""
		if [ -f /config/extended/scripts/tidal-dl.json ]; then
			cp /config/extended/scripts/tidal-dl.json /config/xdg/.tidal-dl.json
			chmod 777 -R /config/xdg/
		fi

	fi
	
	TidaldlStatusCheck
	tidal-dl -o $downloadPath/incomplete
	DownloadFormat

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		TidaldlStatusCheck
		log "TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		pip3 install tidal-dl==2022.3.4.2 --no-cache-dir &>/dev/null
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		TidaldlStatusCheck
		tidal-dl
	fi

	if [ ! -d /config/extended/cache/tidal ]; then
		mkdir -p /config/extended/cache/tidal
		chmod 777 /config/extended/cache/tidal
		chown abc:abc /config/extended/cache/tidal
	fi
	
	if [ -d /config/extended/cache/tidal ]; then
		log "TIDAL :: Purging album list cache..."
		find /config/extended/cache/tidal -type f -name "*.json" -delete
	fi
	
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p $downloadPath/incomplete
		chmod 777 $downloadPath/incomplete
		chown abc:abc $downloadPath/incomplete
	else
		rm -rf $downloadPath/incomplete/*
	fi
	
	TidaldlStatusCheck
	log "TIDAL :: Upgrade tidal-dl to newer version..."
	pip3 install tidal-dl==2022.07.06.1 --no-cache-dir &>/dev/null
	
}

TidalClientTest () { 
	log "TIDAL :: tidal-dl client setup verification..."
	TidaldlStatusCheck
	tidal-dl -o $downloadPath/incomplete -l "166356219" &>/dev/null
	
	downloadCount=$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		if [ -f /config/xdg/.tidal-dl.token.json ]; then
			rm /config/xdg/.tidal-dl.token.json
		fi
		log "TIDAL :: ERROR :: Download failed"
		log "TIDAL :: ERROR :: You will need to re-authenticate on next script run..."
		log "TIDAL :: ERROR :: Exiting..."
		rm -rf $downloadPath/incomplete/*
		exit
	else
		rm -rf $downloadPath/incomplete/*
		log "TIDAL :: Successfully Verified"
	fi
}

TidaldlStatusCheck () {
	until false
	do
        running=no
        if ps aux | grep "tidal-dl" | grep -v "grep" | read; then 
            running=yes
            log "STATUS :: TIDAL-DL :: BUSY :: Pausing/waiting for all active tidal-dl tasks to end..."
            sleep 2
            continue
        fi
		break
	done
}

DownloadProcess () {

	# Required Input Data
	# $1 = Album ID to download from online Service
	# $2 = Download Client Type (DEEZER or TIDAL)
	# $3 = Album Year that matches Album ID Metadata
	# $4 = Album Title that matches Album ID Metadata
	# $5 = Expected Track Count


	# Create Required Directories	
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p $downloadPath/incomplete
		chmod 777 $downloadPath/incomplete
		chown abc:abc $downloadPath/incomplete
	else
		rm -rf $downloadPath/incomplete/*
	fi
	
	if [ ! -d "$downloadPath/complete" ]; then
		mkdir -p $downloadPath/complete
		chmod 777 $downloadPath/complete
		chown abc:abc $downloadPath/complete
	else
		rm -rf $downloadPath/complete/*
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

	if [ ! -d /config/extended/logs/downloaded/failed/deezer ]; then
		mkdir -p /config/extended/logs/downloaded/failed/deezer
		chmod 777 /config/extended/logs/downloaded/failed/deezer
		chown abc:abc /config/extended/logs/downloaded/failed/deezer
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/tidal ]; then
		mkdir -p /config/extended/logs/downloaded/failed/tidal
		chmod 777 /config/extended/logs/downloaded/failed/tidal
		chown abc:abc /config/extended/logs/downloaded/failed/tidal
	fi

	downloadedAlbumTitleClean="$(echo "$4" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
    	
	if find $downloadPath/complete -type d -iname "$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-*-$1-$2" | read; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded..."
		return
    fi

	# check for log file
	if [ "$2" = "DEEZER" ]; then
		if [ -f /config/extended/logs/downloaded/deezer/$1 ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/deezer/$1 ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi

	# check for log file
	if [ "$2" = "TIDAL" ]; then
		if [ -f /config/extended/logs/downloaded/tidal/$1 ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/tidal/$1 ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi

	
	
	downloadTry=0
	until false
	do	
		downloadTry=$(( $downloadTry + 1 ))
		if [ -f /temp-download ]; then
			rm /temp-download
			sleep 0.1
		fi
		touch /temp-download 
		sleep 0.1

		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Download Attempt number $downloadTry"
		if [ "$2" = "DEEZER" ]; then
			if [ $downloadTry = 1 ]; then
				DeezerClientTest
			fi
			deemix -b $deemixQuality -p $downloadPath/incomplete "https://www.deezer.com/album/$1" &>/dev/null
			if [ -d "/tmp/deemix-imgs" ]; then
				rm -rf /tmp/deemix-imgs
			fi
		fi

		if [ "$2" = "TIDAL" ]; then
			if [ $downloadTry = 1 ]; then
				TidaldlStatusCheck
				TidalClientTest
			fi
			TidaldlStatusCheck
			tidal-dl -o $downloadPath/incomplete -l "$1" &>/dev/null
		fi
	
		find "$downloadPath/incomplete" -type f -iname "*.flac" -newer "/temp-download" -print0 | while IFS= read -r -d '' file; do
			audioFlacVerification "$file"
			if [ $verifiedFlacFile = 0 ]; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: Verified"
			else
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: ERROR :: Failed Verification"
				rm "$file"
			fi
		done

		downloadCount=$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
		if [ $downloadCount -ne $5 ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: download failed, missing tracks..."
			completedVerification="false"
		else
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Success"
			completedVerification="true"
		fi

		if [ "$completedVerification" = "true" ]; then
			break
		elif [ $downloadTry = 5 ]; then
			if [ -d $downloadPath/incomplete ]; then
				rm -rf $downloadPath/incomplete/*
			fi
			break
		else
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Retry Download in 1 second fix errors..."
			sleep 1
		fi
	done   

	# Consolidate files to a single folder
	if [ "$2" = "TIDAL" ]; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Consolidating files to single folder"
		find "$downloadPath/incomplete" -type f -exec mv "{}" $downloadPath/incomplete/ \;
		if [ -d $downloadPath/incomplete/atd ]; then
			rm -rf $downloadPath/incomplete/atd
		fi
	fi

	downloadCount=$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -gt 0 ]; then
		# Check download for required quality (checks based on file extension)
		DownloadQualityCheck "$downloadPath/incomplete" "$2"
	fi
	
	downloadCount=$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -ne $5 ]; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: All download Attempts failed..."
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as failed download..."


		if [ "$2" = "DEEZER" ]; then
			touch /config/extended/logs/downloaded/failed/deezer/$1
		fi
		if [ "$2" = "TIDAL" ]; then
			touch /config/extended/logs/downloaded/failed/tidal/$1
		fi
		return
	fi

	# Log Completed Download
	log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as successfully downloaded..."
	if [ "$2" = "DEEZER" ]; then
		touch /config/extended/logs/downloaded/deezer/$1
	fi
	if [ "$2" = "TIDAL" ]; then
		touch /config/extended/logs/downloaded/tidal/$1
	fi

	if [ $audioFormat != native ]; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Converting Flac Audio to  ${audioFormat^^} ${audioBitrate}k"
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

		find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' audio; do
			file="${audio}"
			filename="$(basename "$audio")"
			foldername="$(dirname "$audio")"
        		filenamenoext="${filename%.*}"
			if ffmpeg -loglevel warning -hide_banner -nostats -i "$file" -n -vn $options "$foldername/${filenamenoext}.$extension" < /dev/null; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: Conversion to $audioFormat (${audioBitrate}k) successful"
				rm "$file"
			else
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: ERROR :: Conversion Failed"
				rm "$foldername/${filenamenoext}.$extension"
			fi
		done

	fi
	
	if [ $enableReplaygainTags = true ]; then
		AddReplaygainTags "$downloadPath/incomplete"
	else
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Replaygain Tagging Disabled (set enableReplaygainTags=true to enable...)"
	fi
	
	find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
		lrcFile="${file%.*}.lrc"
		if [ -f "$lrcFile" ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Embedding lyrics (lrc) into $file"
			metaflac --remove-tag=Lyrics "$file"
			metaflac --set-tag-from-file="Lyrics=$lrcFile" "$file"
			rm "$lrcFile"
		fi
	done

	albumquality="$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1 | egrep -i -E -o "\.{1}\w*$" | sed  's/\.//g')"
	downloadedAlbumFolder="$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-${albumquality^^}-$1-$2"

	find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' audio; do
        file="${audio}"
        filenoext="${file%.*}"
        filename="$(basename "$audio")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        if [ ! -d "$downloadPath/complete" ]; then
            mkdir -p $downloadPath/complete
            chmod 777 $downloadPath/complete
            chown abc:abc $downloadPath/complete
        fi
        mkdir -p "$downloadPath/complete/$downloadedAlbumFolder"
        mv "$file" "$downloadPath/complete/$downloadedAlbumFolder"/
        
    done
	chmod -R 777 $downloadPath/complete
	chown -R abc:abc $downloadPath/complete
	
	if [ -d "$downloadPath/complete/$downloadedAlbumFolder" ]; then
		NotifyLidarrForImport "$downloadPath/complete/$downloadedAlbumFolder"
	fi
	rm -rf $downloadPath/incomplete/*

	# NotifyPlexToScan
}

DownloadQualityCheck () {

	if [ "$requireQuality" = "true" ]; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Checking for unwanted files"

		if [ $audioFormat != native ]; then
			if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
				rm "$1"/*
			else
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
			fi
		fi
		if [ $audioFormat = native ]; then
			if [ $audioBitrate = lossless ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ $2 = DEEZER ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|flac\)"| read; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ $2 = TIDAL ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|flac\|mp3\)"| read; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			fi
		fi
	else
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType ::  Skipping download quality check... (enable by setting: requireQuality=true)"
	fi
}

AddReplaygainTags () {
	# Input Data
	# $1 Folder path to scan and add tags
	log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Adding Replaygain Tags using r128gain"
	r128gain -r -a "$1" &>/dev/null
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$lidarrUrl/api/v1/command" --header "X-Api-Key:"${lidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

NotifyPlexToScan () {
	LidarrTaskStatusCheck
	CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
	if [ $alreadyImported = true ]; then
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Notifying Plex to Scan :: $lidarrArtistPath"
		bash /config/extended/scripts/PlexNotify.bash "$lidarrArtistPath"
	fi
}


DeemixClientSetup () {
	log "DEEZER :: Verifying deemix configuration"
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
		log "DEEZER :: ARL Token: Configured"
	else
		log "DEEZER :: ERROR :: arlToken setting invalid, currently set to: $arlToken"
	fi
	
	if [ -f "/config/xdg/deemix/config.json" ]; then
		rm /config/xdg/deemix/config.json
	fi
	
	if [ -f "/config/extended/scripts/deemix_config.json" ]; then
		log "DEEZER :: Configuring deemix client"
		cp /config/extended/scripts/deemix_config.json /config/xdg/deemix/config.json
		chmod 777 /config/xdg/deemix/config.json
	fi
	
	if [ -d /config/extended/cache/deezer ]; then
		log "DEEZER :: Purging album list cache..."
		find /config/extended/cache/deezer -type f -name "*-albums.json" -delete
	fi
	
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p $downloadPath/incomplete
		chmod 777 $downloadPath/incomplete
		chown abc:abc $downloadPath/incomplete
	else
		rm -rf $downloadPath/incomplete/*
	fi

	log "DEEZER :: Upgrade deemix to the latest..."
	pip install deemix --upgrade &>/dev/null

}

DeezerClientTest () {
	log "DEEZER :: deemix client setup verification..."

	deemix -b $deemixQuality -p $downloadPath/incomplete "https://www.deezer.com/album/197472472" &>/dev/null
	if [ -d "/tmp/deemix-imgs" ]; then
		rm -rf /tmp/deemix-imgs
	fi
	downloadCount=$(find $downloadPath/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
	if [ $downloadCount -le 0 ]; then
		log "DEEZER :: ERROR :: Download failed"
		log "DEEZER :: ERROR :: Please review log for errors in client"
		log "DEEZER :: ERROR :: Try updating your ARL Token to possibly resolve the issue..."
		log "DEEZER :: ERROR :: Exiting..."
		rm -rf $downloadPath/incomplete/*
		exit
	else
		rm -rf $downloadPath/incomplete/*
		log "DEEZER :: Successfully Verified"
	fi

}

ConfigureLidarrWithOptimalSettings () {
	if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log "ERROR :: No root folder found"
		log "Configuring root folder..."
		getSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fmusic&allowFoldersWithoutTrailingSlashes=false&includeFiles=false" -H "X-Api-Key: ${lidarrApiKey}")
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/rootFolder?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"defaultTags":[],"defaultQualityProfileId":1,"defaultMetadataProfileId":1,"name":"Music","path":"/music"}')
	fi

	log "Configuring Lidarr Media Management Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/mediamanagement" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"autoUnmonitorPreviouslyDownloadedTracks":false,"recycleBin":"","recycleBinCleanupDays":7,"downloadPropersAndRepacks":"preferAndUpgrade","createEmptyArtistFolders":true,"deleteEmptyFolders":true,"fileDate":"none","watchLibraryForChanges":true,"rescanAfterRefresh":"always","allowFingerprinting":"newFiles","setPermissionsLinux":true,"chmodFolder":"777","chownGroup":"abc","skipFreeSpaceCheckWhenImporting":false,"minimumFreeSpaceWhenImporting":100,"copyUsingHardlinks":true,"importExtraFiles":true,"extraFileExtensions":"jpg,png,lrc","id":1}')

	log "Configuring Lidarr Metadata ConsumerSettings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadata/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"enable":true,"name":"Kodi (XBMC) / Emby","fields":[{"name":"artistMetadata","value":true},{"name":"albumMetadata","value":true},{"name":"artistImages","value":true},{"name":"albumImages","value":false}],"implementationName":"Kodi (XBMC) / Emby","implementation":"XbmcMetadata","configContract":"XbmcMetadataSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#xbmcmetadata","tags":[],"id":1}')

	log "Configuring Lidarr Metadata Provider Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/metadataProvider" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"metadataSource":"","writeAudioTags":"allFiles","scrubAudioTags":false,"id":1}')

	log "Configuring Lidarr Custom Scripts"
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "PlexNotify.bash" | read; then
		log "PlexNotify.bash Already added to Lidarr custom scripts"
	else
		log "Adding PlexNotify.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlexNotify.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":false,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"PlexNotify.bash","fields":[{"name":"path","value":"/config/extended/scripts/PlexNotify.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
	fi
		
	if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "MetadataPostProcess.bash" | read; then
		log "MetadataPostProcess.bash Already added to Lidarr custom scripts"
	else
		log "Adding MetadataPostProcess.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FMetadataPostProcess.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":false,"onUpgrade":false,"onRename":false,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":true,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"MetadataPostProcess.bash","fields":[{"name":"path","value":"/config/extended/scripts/MetadataPostProcess.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
	fi

	log "Configuring Lidarr UI Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/ui" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"firstDayOfWeek":0,"calendarWeekColumnHeader":"ddd M/D","shortDateFormat":"MMM D YYYY","longDateFormat":"dddd, MMMM D YYYY","timeFormat":"h(:mm)a","showRelativeDates":true,"enableColorImpairedMode":true,"uiLanguage":1,"expandAlbumByDefault":true,"expandSingleByDefault":true,"expandEPByDefault":true,"expandBroadcastByDefault":true,"expandOtherByDefault":true,"id":1}')
	
	log "Configuring Lidarr Standard Metadata Profile"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadataprofile/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"name":"Standard","primaryAlbumTypes":[{"albumType":{"id":2,"name":"Single"},"allowed":true},{"albumType":{"id":4,"name":"Other"},"allowed":false},{"albumType":{"id":1,"name":"EP"},"allowed":true},{"albumType":{"id":3,"name":"Broadcast"},"allowed":false},{"albumType":{"id":0,"name":"Album"},"allowed":true}],"secondaryAlbumTypes":[{"albumType":{"id":0,"name":"Studio"},"allowed":true},{"albumType":{"id":3,"name":"Spokenword"},"allowed":true},{"albumType":{"id":2,"name":"Soundtrack"},"allowed":true},{"albumType":{"id":7,"name":"Remix"},"allowed":true},{"albumType":{"id":9,"name":"Mixtape/Street"},"allowed":true},{"albumType":{"id":6,"name":"Live"},"allowed":true},{"albumType":{"id":4,"name":"Interview"},"allowed":true},{"albumType":{"id":8,"name":"DJ-mix"},"allowed":true},{"albumType":{"id":10,"name":"Demo"},"allowed":true},{"albumType":{"id":1,"name":"Compilation"},"allowed":true}],"releaseStatuses":[{"releaseStatus":{"id":3,"name":"Pseudo-Release"},"allowed":false},{"releaseStatus":{"id":1,"name":"Promotion"},"allowed":false},{"releaseStatus":{"id":0,"name":"Official"},"allowed":true},{"releaseStatus":{"id":2,"name":"Bootleg"},"allowed":false}],"id":1}')

	log "Configuring Lidarr Track Naming Settings"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/naming" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"renameTracks":true,"replaceIllegalCharacters":true,"standardTrackFormat":"{Artist Name} - {Album Type} - {Release Year} - {Album Title}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track Title}","multiDiscTrackFormat":"{Artist Name} - {Album Type} - {Release Year} - {Album Title}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track Title}","artistFolderFormat":"{Artist Name}{ (Artist Disambiguation)}","includeArtistName":false,"includeAlbumTitle":false,"includeQuality":false,"replaceSpaces":false,"id":1}')

	touch /config/extended/logs/autoconfig
	chmod 666 /config/extended/logs/autoconfig
	chown abc:abc /config/extended/logs/autoconfig

}

LidarrRootFolderCheck () {
	if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log "ERROR :: No root folder found"
		log "ERROR :: Configure root folder in Lidarr to continue..."
		log "ERROR :: Exiting..."
		exit
	fi
}

GetMissingCutOffList () {
    
	# Remove previous search missing/cutoff list
	if [ -d  /config/extended/cache/lidarr/list ]; then
		rm -rf  /config/extended/cache/lidarr/list
		sleep 0.1
	fi

	# Create list folder if does not exist
	mkdir -p /config/extended/cache/lidarr/list

	# Create notfound log folder if does not exist
	if [ ! -d /config/extended/logs/notfound ]; then
		mkdir -p /config/extended/logs/notfound
		chmod 777 /config/extended/logs/notfound
		chown abc:abc /config/extended/logs/notfound
	fi
	
	#get notfound log files list
	getNotFound=$(ls /config/extended/logs/notfound)

	# Configure searchSort preferences based on settings
	if [ $searchSort = date ]; then
		searchOrder=releaseDate
		searchDirection=descending
	fi
	
	if [ $searchSort = album ]; then
		searchOrder=albumType
		searchDirection=ascending
	fi

	lidarrMissingTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r .totalRecords)

	log "FINDING MISSING ALBUMS :: sorted by $searchSort"

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
			log "Downloading page $page... ($offset - $dlnumber of $lidarrMissingTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			
			for lidarrRecordId in $(echo $lidarrRecords); do
				if ! echo "$getNotFound" | grep "^$lidarrRecordId--" | read; then
					touch /config/extended/cache/lidarr/list/${lidarrRecordId}-missing
				fi
			done
		done
	fi
	lidarrMissingTotalRecords=$(find /config/extended/cache/lidarr/list -type f -iname "*-missing" | wc -l)
	log "${lidarrMissingTotalRecords} MISSING ALBUMS FOUND"

	# Get cutoff album list
	lidarrCutoffTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r .totalRecords)
	log "FINDING CUTOFF ALBUMS sorted by $searchSort"

	if [ $lidarrCutoffTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrCutoffTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ $dlnumber -gt $lidarrCutoffTotalRecords ]; then
				dlnumber=$lidarrCutoffTotalRecords
			fi
			log "Downloading page $page... ($offset - $dlnumber of $lidarrCutoffTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			for lidarrRecordId in $(echo $lidarrRecords); do
				if ! echo "$getNotFound" | grep "^$lidarrRecordId--" | read; then
					touch /config/extended/cache/lidarr/list/${lidarrRecordId}-cutoff
				fi
			done
		done
	fi

	lidarrCutoffTotalRecords=$(find /config/extended/cache/lidarr/list -type f -iname "*-cutoff" | wc -l)
	log "${lidarrCutoffTotalRecords} CUTOFF ALBUMS FOUND"
	
	wantedListAlbumTotal=$(( $lidarrMissingTotalRecords + $lidarrCutoffTotalRecords ))
    
	log "Searching for $wantedListAlbumTotal items"
}

SearchProcess () {

	if [ $wantedListAlbumTotal = 0 ]; then
		log "No items to find, end"
		return
	fi

	processNumber=0
	for lidarrMissingId in $(ls -tr /config/extended/cache/lidarr/list); do
		processNumber=$(( $processNumber + 1 ))
		wantedAlbumId=$(echo $lidarrMissingId | sed -e "s%[^[:digit:]]%%g")
		checkLidarrAlbumId=$wantedAlbumId
		wantedAlbumListSource=$(echo $lidarrMissingId | sed -e "s%[^[:alpha:]]%%g")
		lidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$wantedAlbumId?apikey=${lidarrApiKey}")"
		lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
		lidarrAlbumType=$(echo "$lidarrAlbumData" | jq -r ".albumType")
		lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
		lidarrAlbumForeignAlbumId=$(echo "$lidarrAlbumData" | jq -r ".foreignAlbumId")
				
		if [ -f "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId" ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrAlbumTitle :: $lidarrAlbumType :: Previously Not Found, skipping..."
			continue
		fi
		
		if [ -f "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId" ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrAlbumTitle :: $lidarrAlbumType :: Previously Not Found, skipping..."
			rm "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId"
			touch "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			chmod 666 "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			chown abc:abc "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			continue
		fi

		
		lidarrAlbumTitleClean=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumTitleCleanSpaces=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		lidarrAlbumReleases=$(echo "$lidarrAlbumData" | jq -r ".releases")
		#echo $lidarrAlbumData | jq -r 
		lidarrAlbumWordCount=$(echo $lidarrAlbumTitle | wc -w)
		#echo $lidarrAlbumReleases | jq -r 
		lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
		lidarrArtistId=$(echo "${lidarrArtistData}" | jq -r ".artistMetadataId")
		lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
		lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
		lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
		lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"
		lidarrArtistNameSearchSanitized="$(echo "$lidarrArtistName" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g")"
		albumArtistNameSearch="$(jq -R -r @uri <<<"${lidarrArtistNameSearchSanitized}")"
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
		tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
		tidalArtistIds="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
		deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
		lidarrAlbumReleaseIds=$(echo "$lidarrAlbumData" | jq -r ".releases | sort_by(.trackCount) | reverse | .[].id")
		lidarrAlbumReleasesMinTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort -n | head -n1)
		lidarrAlbumReleasesMaxTrackCount=$(echo "$lidarrAlbumData" | jq -r ".releases[].trackCount" | sort -n -r | head -n1)
		lidarrAlbumReleaseDate=$(echo "$lidarrAlbumData" | jq -r .releaseDate)
		lidarrAlbumReleaseDate=${lidarrAlbumReleaseDate:0:10}
		lidarrAlbumReleaseDateClean="$(echo $lidarrAlbumReleaseDate | sed -e "s%[^[:digit:]]%%g")"
		lidarrAlbumReleaseYear="${lidarrAlbumReleaseDate:0:4}"
		
		currentDate="$(date "+%F")"
		currentDateClean="$(echo "$currentDate" | sed -e "s%[^[:digit:]]%%g")"

		if [[ ${currentDateClean} -gt ${lidarrAlbumReleaseDateClean} ]]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Starting Search..."
		else
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album ($lidarrAlbumReleaseDate) has not been released, skipping..."
			continue
		fi

		if [ "$dlClientSource" = "deezer" ]; then
			skipTidal=true
			skipDeezer=false
		fi

		if [ "$dlClientSource" = "tidal" ]; then
			skipDeezer=true
			skipTidal=false
		fi

		if [ "$dlClientSource" = "both" ]; then
			skipDeezer=false
			skipTidal=false
		fi	

		if [ "$skipDeezer" = "false" ]; then

			# fallback to musicbrainz db for link
			if [ -z "$deezerArtistUrl" ]; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: DEEZER :: Fallback to musicbrainz for Deezer ID"
				musicbrainzArtistData=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/${lidarrArtistForeignArtistId}?inc=url-rels&fmt=json")
				deezerArtistUrl=$(echo "$musicbrainzArtistData" | jq -r '.relations | .[] | .url | select(.resource | contains("deezer")) | .resource')
			fi

			if [ -z "$deezerArtistUrl" ]; then 
				sleep 1.5
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/deezer-artist-id-not-found.txt\" for more detail..."
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
			deezerArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		fi

        if [ "$skipTidal" = "false" ]; then
			# fallback to musicbrainz db for link
			if [ -z "$tidalArtistUrl" ]; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: TIDAL :: Fallback to musicbrainz for Tidal ID"
				musicbrainzArtistData=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/artist/${lidarrArtistForeignArtistId}?inc=url-rels&fmt=json")
				tidalArtistUrl=$(echo "$musicbrainzArtistData" | jq -r '.relations | .[] | .url | select(.resource | contains("tidal")) | .resource')
			fi

			if [ -z "$tidalArtistUrl" ]; then 
				sleep 1.5
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-artist-id-not-found.txt\" for more detail..."
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

		# Begin cosolidated search process
		if [ $audioLyricType = both ]; then
			endLoop=2
		else
			endLoop=1
		fi


		# Get Release Titles & Disambiguation
		if [ -f /temp-release-list ]; then
			rm /temp-release-list 
		fi
		for releaseId in $(echo "$lidarrAlbumReleaseIds"); do
			releaseTitle=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$releaseId) | .title")
			releaseDisambiguation=$(echo "$lidarrAlbumData" | jq -r ".releases[] | select(.id==$releaseId) | .disambiguation")
			if [ -z "$releaseDisambiguation" ]; then
				releaseDisambiguation=""
			else
				releaseDisambiguation=" ($releaseDisambiguation)" 
			fi
			echo "${releaseTitle}${releaseDisambiguation}" >> /temp-release-list 
			echo "$lidarrAlbumTitle" >> /temp-release-list 
		done

		# Get Release Titles
		OLDIFS="$IFS"
		IFS=$'\n'
		lidarrReleaseTitles=$(cat /temp-release-list | awk '{ print length, $0 }' | sort -u -n -s -r | cut -d" " -f2-)
		lidarrReleaseTitles=($(echo "$lidarrReleaseTitles"))
		IFS="$OLDIFS"

		loopCount=0
		until false
		do
			loopCount=$(( $loopCount + 1 ))
			if [ $loopCount = 1 ]; then
				# First loop is either explicit or clean depending on script settings
				if [ $audioLyricType = both ] || [ $audioLyricType = explicit ]; then
					lyricFilter=true
				else
					lyricFilter=false
				fi
			else
				# 2nd loop is always clean
				lyricFilter=false
			fi
			
			releaseProcessCount=0
			for title in ${!lidarrReleaseTitles[@]}; do
				releaseProcessCount=$(( $releaseProcessCount + 1))
				lidarrReleaseTitle="${lidarrReleaseTitles[$title]}"
				lidarrAlbumReleaseTitleClean=$(echo "$lidarrReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
				lidarrAlbumReleaseTitleSearchClean="$(echo "$lidarrReleaseTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
				lidarrAlbumReleaseTitleFirstWord="$(echo "$lidarrReleaseTitle"  | awk '{ print $1 }')"
				lidarrAlbumReleaseTitleFirstWord="${lidarrAlbumReleaseTitleFirstWord:0:3}"
				albumTitleSearch="$(jq -R -r @uri <<<"${lidarrAlbumReleaseTitleSearchClean}")"
				#echo "Debugging :: $loopCount :: $releaseProcessCount :: $lidarrArtistForeignArtistId :: $lidarrReleaseTitle :: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount :: $lidarrAlbumReleaseTitleFirstWord :: $albumArtistNameSearch :: $albumTitleSearch"

				# Skip Various Artists album search that is not supported...
				if [ "$lidarrArtistForeignArtistId" != "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
					# Lidarr Status Check
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						break 2
					fi
						
					# Tidal Artist search
					if [ "$skipTidal" = "false" ]; then
						for tidalArtistId in $(echo $tidalArtistIds); do
							ArtistTidalSearch "$processNumber of $wantedListAlbumTotal" "$tidalArtistId" "$lyricFilter"
							sleep 0.01
						done	
					fi

					# Lidarr Status Check
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						break 2
					fi

					# Deezer artist search
					if [ "$skipDeezer" = "false" ]; then
						for dId in ${!deezerArtistIds[@]}; do
							deezerArtistId="${deezerArtistIds[$dId]}"
							ArtistDeezerSearch "$processNumber of $wantedListAlbumTotal" "$deezerArtistId" "$lyricFilter"
							sleep 0.01
						done
					fi
				fi
				
				# Lidarr Status Check
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
					break 2
				fi

				# Tidal fuzzy search
				if [ "$dlClientSource" = "both" ] || [ "$dlClientSource" = "tidal" ]; then
					FuzzyTidalSearch "$processNumber of $wantedListAlbumTotal" "$lyricFilter"
					sleep 0.01
				fi

				# Lidarr Status Check
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
					break 2
				fi

				# Deezer fuzzy search
				if [ "$dlClientSource" = "both" ] || [ "$dlClientSource" = "deezer" ]; then
					FuzzyDeezerSearch "$processNumber of $wantedListAlbumTotal" "$lyricFilter"
					sleep 0.01
				fi

			done
				
			# Break after all operations are complete
			if [ $loopCount = $endLoop ]; then
				break
			fi
		done
		
		
		# Lidarr Status Check
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi

		# Search Musicbrainz for Tidal Album ID
		if [ $audioLyricType = both ]; then
			if [ "$skipTidal" = "false" ]; then
				
				# Search Musicbrainz
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Tidal :: Searching for Album ID..."
				msuicbrainzTidalDownloadAlbumID=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/release?release-group=$lidarrAlbumForeignAlbumId&inc=url-rels&fmt=json" | jq -r | grep "tidal.com" | head -n 1 | sed -e "s%[^[:digit:]]%%g")

				# Process Album ID if found
				if [ ! -z $msuicbrainzTidalDownloadAlbumID ]; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Tidal ::: FOUND!"
					tidalArtistAlbumData="$(curl -s "https://api.tidal.com/v1/albums/${msuicbrainzTidalDownloadAlbumID}?countryCode=$tidalCountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU')"
					tidalAlbumTrackCount="$(echo "$tidalArtistAlbumData" | jq -r .numberOfTracks)"
					downloadedAlbumTitle="$(echo "${tidalArtistAlbumData}" | jq -r .title)"
					downloadedReleaseDate="$(echo "${tidalArtistAlbumData}" | jq -r .releaseDate)"
					if [ "$downloadedReleaseDate" = "null" ]; then
						downloadedReleaseDate=$(echo "$tidalArtistAlbumData" | jq -r '.streamStartDate')
					fi
					downloadedReleaseYear="${downloadedReleaseDate:0:4}"
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Tidal :: Downloading $tidalAlbumTrackCount Tracks :: $downloadedAlbumTitle ($downloadedReleaseYear)"
					DownloadProcess "$msuicbrainzTidalDownloadAlbumID" "TIDAL" "$downloadedReleaseYear" "$downloadedAlbumTitle" "$tidalAlbumTrackCount"

					# Verify it was successfully imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						continue
					fi
				else
					sleep 1.5
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Tidal :: NOT FOUND!"
				fi
			fi
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi

		# Search Musicbrainz for Deezer Album ID
		if [ $audioLyricType = both ]; then
			if [ "$skipDeezer" = "false" ]; then
			
				# Search Musicbrainz
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Deezer :: Searching for Album ID..."
				musicbrainzDeezerDownloadAlbumID=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/release?release-group=$lidarrAlbumForeignAlbumId&inc=url-rels&fmt=json" | jq -r | grep "deezer.com" | grep "album" | head -n 1 | sed -e "s%[^[:digit:]]%%g")
				
				# Process Album ID if found
				if [ ! -z $musicbrainzDeezerDownloadAlbumID ]; then
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Deezer :: FOUND!"
					GetDeezerAlbumInfo "${musicbrainzDeezerDownloadAlbumID}"
					deezerArtistAlbumData=$(cat "/config/extended/cache/deezer/$musicbrainzDeezerDownloadAlbumID.json")
					deezerAlbumTrackCount="$(echo "$deezerArtistAlbumData" | jq -r .nb_tracks)"
					deezerAlbumTitle="$(echo "$deezerArtistAlbumData"| jq -r .title)"
					downloadedReleaseDate="$(echo "$deezerArtistAlbumData" | jq -r .release_date)"
					downloadedReleaseYear="${downloadedReleaseDate:0:4}"
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Deezer :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
					DownloadProcess "$musicbrainzDeezerDownloadAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"

					# Verify it was successfully imported into Lidarr
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
					if [ $alreadyImported = true ]; then
						log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						continue
					fi
				else
					log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Musicbrainz URL :: Deezer :: NOT FOUND!"
				fi
			fi
		fi
		
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi
				
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album Not found"
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Marking Album as notfound"
		if [ ! -f "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId" ]; then
			touch "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			chmod 666 "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			chown abc:abc "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
		fi
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Search Complete..." 
	done
}

GetDeezerAlbumInfo () {
	until false
	do
		log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Getting Album info..."
		if [ ! -f "/config/extended/cache/deezer/$1.json" ]; then
			curl -s "https://api.deezer.com/album/$1" -o "/config/extended/cache/deezer/$1.json"
			sleep $sleepTimer
		fi
		if [ -f "/config/extended/cache/deezer/$1.json" ]; then
			if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/$1.json)"; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Album info downloaded and verified..."
				chmod 666 /config/extended/cache/deezer/$1.json
				chown abc:abc /config/extended/cache/deezer/$1.json	
				albumInfoVerified=true
				break
			else
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Error getting album information"
				if [ -f "/config/extended/cache/deezer/$1.json" ]; then
					rm "/config/extended/cache/deezer/$1.json"
				fi
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Retrying..."
			fi
		else
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: Download Failed"
		fi
	done

}

ArtistDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Deezer Artist ID
	# $3 Lyric Type (true or false) - false = Clean, true = Explicit

	# Get deezer artist album list
	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi
	if [ ! -f "/config/extended/cache/deezer/$2-albums.json" ]; then
		getDeezerArtistAlbums=$(curl -s "https://api.deezer.com/artist/$2/albums?limit=1000" > "/config/extended/cache/deezer/$2-albums.json")
		sleep $sleepTimer
		getDeezerArtistAlbumsCount=$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .total)
	fi
	
	if [ $getDeezerArtistAlbumsCount = 0 ]; then
		return
	fi

	if [ $3 = true ]; then
		type=Explicit
	else
		type=Clean
	fi
	
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching $2... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."		
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Filtering results by lyric type and \"$lidarrAlbumReleaseTitleFirstWord\"..."
	deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .data[])
	deezerArtistAlbumsIds=$(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="$3") | select(.title | test(\"^$lidarrAlbumReleaseTitleFirstWord\";\"i\")) | .id")

	resultsCount=$(echo "$deezerArtistAlbumsIds" | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $resultsCount search results found"
	for deezerAlbumID in $(echo "$deezerArtistAlbumsIds"); do
		deezerAlbumData="$(echo "$deezerSearch" | jq -r ".album | select(.id==$deezerAlbumID)")"
		deezerAlbumTitle="$(echo "$deezerAlbumData" | jq -r ".title")"
		deezerAlbumTitleClean="$(echo ${deezerAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"

		# String Character Count test, quicker than the levenshtein method to allow faster processing
		characterMath=$(( ${#deezerAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
		if [ $characterMath -gt 5 ]; then
			continue
		elif [ $characterMath -lt 0 ]; then
			continue
		fi
		GetDeezerAlbumInfo "${deezerAlbumID}"
		deezerAlbumData="$(cat "/config/extended/cache/deezer/$deezerAlbumID.json")"
		deezerAlbumTrackCount="$(echo "$deezerAlbumData" | jq -r .nb_tracks)"
		deezerAlbumExplicitLyrics="$(echo "$deezerAlbumData" | jq -r .explicit_lyrics)"								
		deezerAlbumTitle="$(echo "$deezerAlbumData"| jq -r .title)"
		deezerAlbumTitleClean="$(echo "$deezerAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
		downloadedReleaseDate="$(echo "$deezerAlbumData" | jq -r .release_date)"
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"

		# Reject release if greater than the max track count
		if [ $deezerAlbumTrackCount -gt $lidarrAlbumReleasesMaxTrackCount ]; then
			continue
		fi

		# Reject release if less than the min track count
		if [ $deezerAlbumTrackCount -lt $lidarrAlbumReleasesMinTrackCount ]; then
			continue
		fi
		
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Similarity..."
		diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}" 2>/dev/null)
		if [ "$diff" -le "5" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer  :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"

			# Verify it was successfully imported into Lidarr
			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
			if [ $alreadyImported = true ]; then
				break
			fi
		fi
	done

	if [ $alreadyImported = true ]; then
		return
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: Albums found, but none matching search criteria..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: Album not found..."
	fi
	
}

FuzzyDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $3 Lyric Type (explicit = true, clean = false)

	if [ $2 = true ]; then
		type=Explicit
	else
		type=Clean
	fi

	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)"

	deezerSearch=""
	if [ "$lidarrArtistForeignArtistId" = "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		# Search without Artist for VA albums
		deezerSearch=$(curl -s "https://api.deezer.com/search?q=album:%22${albumTitleSearch}%22&strict=on&limit=20" | jq -r ".data[]")
	else
		# Search with Artist for non VA albums
		deezerSearch=$(curl -s "https://api.deezer.com/search?q=artist:%22${albumArtistNameSearch}%22%20album:%22${albumTitleSearch}%22&strict=on&limit=20" | jq -r ".data[]")
	fi
	resultsCount=$(echo "$deezerSearch" | jq -r .album.id | sort -u | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $resultsCount search results found"
	if [ ! -z "$deezerSearch" ]; then
		for deezerAlbumID in $(echo "$deezerSearch" | jq -r .album.id | sort -u); do
			deezerAlbumData="$(echo "$deezerSearch" | jq -r ".album | select(.id==$deezerAlbumID)")"
			deezerAlbumTitle="$(echo "$deezerAlbumData" | jq -r ".title")"
			deezerAlbumTitle="$(echo "$deezerAlbumTitle" | head -n1)"
			deezerAlbumTitleClean="$(echo "$deezerAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"

			# String Character Count test, quicker than the levenshtein method to allow faster processing
			characterMath=$(( ${#deezerAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
			if [ $characterMath -gt 5 ]; then
				continue
			elif [ $characterMath -lt 0 ]; then
				continue
			fi

			GetDeezerAlbumInfo "${deezerAlbumID}"
			deezerAlbumData="$(cat "/config/extended/cache/deezer/$deezerAlbumID.json")"
			deezerAlbumTrackCount="$(echo "$deezerAlbumData" | jq -r .nb_tracks)"
			deezerAlbumExplicitLyrics="$(echo "$deezerAlbumData" | jq -r .explicit_lyrics)"								
			deezerAlbumTitle="$(echo "$deezerAlbumData"| jq -r .title)"
			deezerAlbumTitleClean="$(echo "$deezerAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
			downloadedReleaseDate="$(echo "$deezerAlbumData" | jq -r .release_date)"
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"

			if [ "$deezerAlbumExplicitLyrics" != "$2" ]; then
				continue
			fi

			# Reject release if greater than the max track count
			if [ $deezerAlbumTrackCount -gt $lidarrAlbumReleasesMaxTrackCount ]; then
				continue
			fi

			# Reject release if less than the min track count
			if [ $deezerAlbumTrackCount -lt $lidarrAlbumReleasesMinTrackCount ]; then
				continue
			fi

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Similarity..."
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}" 2>/dev/null)
			if [ "$diff" -le "5" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$deezerAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"

				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					break
				fi
			fi
		done
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: Results found, but none matching search criteria..."
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: ERROR :: No results found via Fuzzy Search..."
	fi
	
}

ArtistTidalSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Tidal Artist ID
	# $3 Lyric Type (true or false) - false = Clean, true = Explicit

	# Get tidal artist album list
	if [ ! -f /config/extended/cache/tidal/$2-videos.json ]; then
		curl -s "https://api.tidal.com/v1/artists/$2/videos?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$2-videos.json
		sleep $sleepTimer
	fi

	if [ ! -f /config/extended/cache/tidal/$2-albums.json ]; then
		curl -s "https://api.tidal.com/v1/artists/$2/albums?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$2-albums.json
		sleep $sleepTimer
	fi

	if [ ! -f "/config/extended/cache/tidal/$2-albums.json" ]; then
		return
	fi

	if [ $3 = true ]; then
		type=Explicit
	else
		type=Clean
	fi


	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Searching $2... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."
	tidalArtistAlbumsData=$(cat "/config/extended/cache/tidal/$2-albums.json" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Filtering results by lyric type, track count and \"$lidarrAlbumReleaseTitleFirstWord\""
	tidalArtistAlbumsIds=$(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="$3") | select(.title | test(\"^$lidarrAlbumReleaseTitleFirstWord\";\"i\")) | .id")

	if [ -z "$tidalArtistAlbumsIds" ]; then
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: No search results found..."
		return
	fi

	searchResultCount=$(echo "$tidalArtistAlbumsIds" | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $searchResultCount search results found"
	for tidalArtistAlbumId in $(echo $tidalArtistAlbumsIds); do
			
		tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
		downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
		tidalAlbumTitleClean=$(echo ${downloadedAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
		downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
		if [ "$downloadedReleaseDate" = "null" ]; then
			downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
		fi
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"
		downloadedTrackCount=$(echo "$tidalArtistAlbumData"| jq -r .numberOfTracks)

		# String Character Count test, quicker than the levenshtein method to allow faster processing
		characterMath=$(( ${#tidalAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
		if [ $characterMath -gt 5 ]; then
			continue
		elif [ $characterMath -lt 0 ]; then
			continue
		fi

		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Similarity..."
		diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${tidalAlbumTitleClean,,}" 2>/dev/null)
		if [ "$diff" -le "5" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $downloadedAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear" "$downloadedAlbumTitle" "$downloadedTrackCount"

			# Verify it was successfully imported into Lidarr
			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
			if [ $alreadyImported = true ]; then
				break
			fi
		else
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than 5"
		fi
	done

	if [ $alreadyImported = true ]; then
		return
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: Albums found, but none matching search criteria..."	
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: Album not found"
	fi
	
}

FuzzyTidalSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Lyric Type (explicit = true, clean = false)

	if [ $2 = true ]; then
		type=Explicit
	else
		type=Clean
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."
	
	if [ "$lidarrArtistForeignArtistId" = "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		# Search without Artist for VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	else
		# Search with Artist for non VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumArtistNameSearch}%20${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[]| select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	fi
	sleep $sleepTimer
	searchResultCount=$(echo "$tidalSearch" | jq -r "select(.title | test(\"^$lidarrAlbumReleaseTitleFirstWord\";\"i\")) | .id" | sort -u | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $searchResultCount search results found ($lidarrAlbumReleaseTitleFirstWord)"
	if [ ! -z "$tidalSearch" ]; then
		for tidalAlbumID in $(echo "$tidalSearch" | jq -r .id | sort -u); do
			tidalAlbumData="$(echo "$tidalSearch" | jq -r "select(.id==$tidalAlbumID)")"
			tidalAlbumTitle=$(echo "$tidalAlbumData"| jq -r .title)
			tidalAlbumTitleClean=$(echo ${tidalAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
			downloadedReleaseDate="$(echo ${tidalAlbumData} | jq -r .releaseDate)"
			if [ "$downloadedReleaseDate" = "null" ]; then
				downloadedReleaseDate=$(echo $tidalAlbumData | jq -r '.streamStartDate')
			fi
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"
			downloadedTrackCount=$(echo "$tidalAlbumData"| jq -r .numberOfTracks)

			# String Character Count test, quicker than the levenshtein method to allow faster processing
			characterMath=$(( ${#tidalAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
			if [ $characterMath -gt 5 ]; then
				continue
			elif [ $characterMath -lt 0 ]; then
				continue
			fi

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Similarity..."
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${tidalAlbumTitleClean,,}" 2>/dev/null)
			if [ "$diff" -le "5" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $tidalAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$tidalAlbumID" "TIDAL" "$downloadedReleaseYear" "$tidalAlbumTitle" "$downloadedTrackCount"
				
				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId" "notbeets"
				if [ $alreadyImported = true ]; then
					break
				fi

			else
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than 5"
			fi
		done
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: Albums found, but none matching search criteria..."
	else
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: ERROR :: No results found..."
	fi	
}


CheckLidarrBeforeImport () {

	alreadyImported=false
	if [ "$2" = "beets" ]; then
		getLidarrAlbumId=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$1&apikey=$lidarrApiKey" | jq -r .[].album.releases[].albumId | sort -u)
		checkLidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$getLidarrAlbumId?apikey=${lidarrApiKey}")"
		checkLidarrAlbumPercentOfTracks=$(echo "$checkLidarrAlbumData" | jq -r ".statistics.percentOfTracks")

		if [ "$checkLidarrAlbumPercentOfTracks" = "null" ]; then
			checkLidarrAlbumPercentOfTracks=0
			return
		fi
		if [ ${checkLidarrAlbumPercentOfTracks%%.*} -ge 100 ]; then
			if [ $wantedAlbumListSource = missing ]; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Already Imported Album (Missing)"
				alreadyImported=true
				return
			else
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: Importing Album (Cutoff)"
				return
			fi
		fi
	fi

	if [ "$2" = "notbeets" ]; then
		if [ -f "/config/extended/logs/downloaded/found/$1" ]; then
			log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Found, skipping..."
			alreadyImported=true
			return
		fi
		
		checkLidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$1?apikey=${lidarrApiKey}")"
		checkLidarrAlbumPercentOfTracks=$(echo "$checkLidarrAlbumData" | jq -r ".statistics.percentOfTracks")

		if [ "$checkLidarrAlbumPercentOfTracks" = "null" ]; then
			checkLidarrAlbumPercentOfTracks=0
			return
		fi
		if [ ${checkLidarrAlbumPercentOfTracks%%.*} -ge 100 ]; then
			if [ $wantedAlbumListSource = missing ]; then
				log "$processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Already Imported Album (Missing), skipping..."
				alreadyImported=true
				return
			fi
		fi
	fi
}

AddRelatedArtists () {
	log "Begin adding Lidarr related Artists from Deezer..."
	lidarrArtistsData="$(curl -s "$lidarrUrl/api/v1/artist?apikey=${lidarrApiKey}")"
	lidarrArtistTotal=$(echo "${lidarrArtistsData}"| jq -r '.[].sortName' | wc -l)
	lidarrArtistList=($(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId"))
	lidarrArtistIds="$(echo "${lidarrArtistsData}" | jq -r ".[].foreignArtistId")"
	lidarrArtistLinkDeezerIds="$(echo "${lidarrArtistsData}" | jq -r ".[] | .links[] | select(.name==\"deezer\") | .url" | grep -o '[[:digit:]]*')"
	log "$lidarrArtistTotal Artists Found"
	deezerArtistsUrl=$(echo "${lidarrArtistsData}" | jq -r ".[].links | .[] | select(.name==\"deezer\") | .url")
	deezerArtistIds="$(echo "$deezerArtistsUrl" | grep -o '[[:digit:]]*' | sort -u)"

	for id in ${!lidarrArtistList[@]}; do
		artistNumber=$(( $id + 1 ))
		musicbrainzId="${lidarrArtistList[$id]}"
		lidarrArtistData=$(echo "${lidarrArtistsData}" | jq -r ".[] | select(.foreignArtistId==\"${musicbrainzId}\")")
		lidarrArtistName="$(echo "${lidarrArtistData}" | jq -r " .artistName")"
		deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
		deezerArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		lidarrArtistMonitored=$(echo "${lidarrArtistData}" | jq -r ".monitored")
		log "$artistNumber of $lidarrArtistTotal :: $lidarrArtistName :: Adding Related Artists..."
		if [ $lidarrArtistMonitored = false ]; then
			log "$artistNumber of $lidarrArtistTotal :: $lidarrArtistName :: Artist is not monitored :: skipping..."
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
	alerted=no
	until false
	do
		taskCount=$(curl -s "$lidarrUrl/api/v1/command?apikey=${lidarrApiKey}" | jq -r .[].status | grep -v completed | grep -v failed | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			if [ "$alerted" = "no" ]; then
				alerted=yes
				log "STATUS :: LIDARR BUSY :: Pausing/waiting for all active Lidarr tasks to end..."
			fi
			sleep 2
		else
			break
		fi
	done
}

LidarrMissingAlbumSearch () {

	log "Begin searching for missing artist albums via Lidarr Indexers..."
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
				log "$processCount of $lidarrArtistIdsCount :: Previously Notified Lidarr to search for \"$lidarrArtistName\" :: Skipping..."
				continue
			fi
		fi
		log "$processCount of $lidarrArtistIdsCount :: Notified Lidarr to search for \"$lidarrArtistName\""
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

audioFlacVerification () {
	# Test Flac File for errors
	# $1 File for verification
	verifiedFlacFile=""
	verifiedFlacFile=$(flac --totally-silent -t "$1"; echo $?)
}

Configuration

if [ "$configureLidarrWithOptimalSettings" = "true" ]; then
	if [ ! -f /config/extended/logs/autoconfig ]; then
		ConfigureLidarrWithOptimalSettings
	else
		log "Lidarr previously configured with optimal settings, skipping..."
		log "To re-configure Lidarr, delete the following file:"
		log "/config/extended/logs/autoconfig" 
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
	log "ERROR :: No valid dlClientSource set"
	log "ERROR :: Expected configuration :: deezer or tidal or both"
	log "ERROR :: dlClientSource set as: \"$dlClientSource\""
fi

if [ "$addDeezerTopArtists" = "true" ] || [ "$addDeezerTopAlbumArtists" = "true" ] || [ "$addDeezerTopTrackArtists" = "true" ] || [ "$addRelatedArtists" = "true" ]; then
	LidarrMissingAlbumSearch
fi

log "Script end..."
exit

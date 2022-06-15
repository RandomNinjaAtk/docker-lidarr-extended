#!/usr/bin/with-contenv bash
lidarrUrlBase="/$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
lidarrUrl="http://127.0.0.1:8686${lidarrUrlBase}"
agent="lidarr-extended ( https://github.com/RandomNinjaAtk/docker-lidarr-extended )"
musicbrainzMirror=https://musicbrainz.org
CountryCode=US

log () {
	m_time=`date "+%F %T"`
	echo $m_time" "$1
}

mkdir -p /config/xdg


DArtistAlbumList () {
	
	albumcount="$(python3 /config/extended/scripts/discography.py "$1" | sort -u | wc -l)"
	
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Searching for All Albums...."
	log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle ::  $albumcount Albums found!"
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
	if [ -f /config/extended/cache/deezer/$1-albums.json ]; then
		rm /config/extended/cache/deezer/$1-albums.json
	fi
	if [ -f /config/extended/cache/deezer/$1-albums-temp.json ]; then
		rm /config/extended/cache/deezer/$1-albums-temp.json
	fi
	echo "[" >> /config/extended/cache/deezer/$1-albums-temp.json
	for id in ${!albumids[@]}; do
		albumid="${albumids[$id]}"
		cat "/config/extended/cache/deezer/${albumid}.json" | jq -r | sed 's/^/ /' | sed '$s/}/},/g' >> /config/extended/cache/deezer/$1-albums-temp.json
	done
	cat /config/extended/cache/deezer/$1-albums-temp.json | sed '$ d' >> /config/extended/cache/deezer/$1-albums.json
	echo " }" >> /config/extended/cache/deezer/$1-albums.json
	echo "]" >> /config/extended/cache/deezer/$1-albums.json
	rm /config/extended/cache/deezer/$1-albums-temp.json
}

TidalClientSetup () {
	touch /config/xdg/.tidal-dl.log
	if [ ! -f /config/xdg/.tidal-dl.json ]; then
		log "TIDAL :: No default config found, importing default config \"tidal.json\""
		if [ -f /config/extended/scripts/tidal-dl.json ]; then
			cp /config/extended/scripts/tidal-dl.json /config/xdg/.tidal-dl.json
			chmod 777 -R /config/xdg/
		fi
		tidal-dl -o /downloads/lidarr-extended/incomplete
		tidal-dl -r P1080
		tidal-dl -q HiFi
	fi

	# check for backup token and use it if exists
	if [ ! -f /root/.tidal-dl.token.json ]; then
		if [ -f /config/backup/tidal-dl.token.json ]; then
			cp -p /config/backup/tidal-dl.token.json /root/.tidal-dl.token.json
			# remove backup token
			rm /config/backup/tidal-dl.token.json
		fi
	fi

	if [ -f /root/.tidal-dl.token.json ]; then
		if [[ $(find "/config/xdg/.tidal-dl.token.json" -mtime +6 -print) ]]; then
			log "TIDAL :: ERROR :: Token expired, removing..."
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
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		tidal-dl
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
        deemix -b flac -p /downloads/lidarr-extended/incomplete "https://www.deezer.com/us/album/$1"
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
        tidal-dl -l "https://tidal.com/browse/album/$1"
        touch /config/extended/logs/downloaded/tidal/$1
        downloadCount=$(find /downloads/lidarr-extended/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
        if [ $downloadCount -le 0 ]; then
            log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: ERROR :: download failed"
            return
        fi
    else
        return
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
    chmod 777 "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
    chown abc:abc "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
    chmod 666 "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"/*
    chown abc:abc "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"/*

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
	if [ ! -z "$arlToken" ]; then
		# Create directories
		mkdir -p /config/xdg/deemix
		if [ -f "/config/xdg/deemix/.arl" ]; then
			rm "/config/xdg/deemix/.arl"
		fi
		if [ ! -f "/config/xdg/deemix/.arl" ]; then
			echo -n "$arlToken" > "/config/xdg/deemix/.arl"
		fi
		log "ARL Token: Configured"
	else
		log "ERROR: arlToken setting invalid, currently set to: $arlToken"
	fi
}

GetMissingCutOffList () {
    log "Downloading missing list..."
    missingAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1000000000&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
    missingAlbumIdsTotal=$(echo "$missingAlbumIds" | sed -r '/^\s*$/d' | wc -l)
    log "FINDING MISSING ALBUMS: ${missingAlbumIdsTotal} Found"

    log "Downloading cutoff list..."
    cutoffAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1000000000&sortKey=releaseDate&sortDirection=desc&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
    cutoffAlbumIdsTotal=$(echo "$cutoffAlbumIds" | sed -r '/^\s*$/d'| wc -l)
    log "FINDING CUTOFF ALBUMS: ${cutoffAlbumIdsTotal} Found"

    wantedListAlbumIds="$(echo "${missingAlbumIds}" && echo "${cutoffAlbumIds}")"
    wantedListAlbumTotal=$(echo "$wantedListAlbumIds" | sed -r '/^\s*$/d' | wc -l)
    log "Searching for $wantedListAlbumTotal items"

    if [ $wantedListAlbumTotal = 0 ]; then
        log "No items to find, end"
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
        tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
        deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
        deezeArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Starting Search..."
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
		
		if [ "$skipDeezer" = "false" ]; then
			if [ -z "$deezerArtistUrl" ]; then 
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/error/$lidarrArtistNameSanitized.log\" for more detail..."
				if [ ! -d /config/extended/logs/error ]; then
					mkdir -p /config/extended/logs/error
				fi
				if [ ! -f "/config/extended/logs/error/$lidarrArtistNameSanitized.log" ]; then          
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Deezer Artist Link" >> "/config/logs/error/$lidarrArtistNameSanitized.log"
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
				DArtistAlbumList "$deezeArtistId"
			done
		fi
        
        if [ "$skipTidal" = "false" ]; then
			if [ -z "$tidalArtistUrl" ]; then 
				log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/error/$lidarrArtistNameSanitized.log\" for more detail..."
				if [ ! -d /config/extended/logs/error ]; then
					mkdir -p /config/extended/logs/error
				fi
				if [ ! -f "/config/extended/logs/error/$lidarrArtistNameSanitized.log" ]; then          
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/relationships for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/error/$lidarrArtistNameSanitized.log"
				fi
				skipTidal=true
			fi
		fi

		if [ "$skipTidal" = "false" ]; then
			if [ ! -d /config/extended/cache/tidal ]; then
				mkdir -p /config/extended/cache/tidal
			fi
			if [ ! -f /config/extended/cache/tidal/$tidalArtistId-videos.json ]; then
				curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/videos?limit=10000&countryCode=$CountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-videos.json
			fi
			if [ ! -f /config/extended/cache/tidal/$tidalArtistId-albums.json ]; then
				curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=10000&countryCode=$CountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$tidalArtistId-albums.json
			fi
			tidalArtistAlbumsData=$(cat "/config/extended/cache/tidal/$tidalArtistId-albums.json" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[]")
			tidalArtistAlbumsIds=($(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="true") | .id"))
		fi
	
		if [ "$skipDeezer" = "false" ]; then
			for dId in ${!deezeArtistIds[@]}; do
				deezeArtistId="${deezeArtistIds[$dId]}"
				deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$deezeArtistId-albums.json" | jq -r "sort_by(.release_date) | sort_by(.explicit_lyrics) | reverse | .[]")
				deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="true") | .id"))
			done
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$lidarrAlbumForeignAlbumId" "notbeets"
		if [ $alreadyImported = true ]; then
			log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Already Imported, skipping..."
			continue
		fi
		
		if [ "$skipDeezer" = "false" ]; then
			for dId in ${!deezeArtistIds[@]}; do
				deezeArtistId="${deezeArtistIds[$dId]}"
				deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$deezeArtistId-albums.json" | jq -r "sort_by(.release_date) | sort_by(.explicit_lyrics) | reverse | .[]")
				deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="true") | .id"))

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

		if [ "$skipDeezer" = "false" ]; then
			for dId in ${!deezeArtistIds[@]}; do
				deezeArtistId="${deezeArtistIds[$dId]}"
				deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$deezeArtistId-albums.json" | jq -r "sort_by(.release_date) | sort_by(.explicit_lyrics) | reverse | .[]")
				deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="false") | .id"))

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

	GetFile=$(find "$1" -type f -iname "*.flac" | head -n1)
	matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".format.tags")
	matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASEGROUPID")"
	matchedTagsAlbumTitle="$(echo $matchedTags | jq -r ".ALBUM")"
	matchedTagsAlbumTitleClean="$(echo "$matchedTagsAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
	matchedTagsAlbumArtist="$(echo $matchedTags | jq -r ".album_artist")"
	matchedTagsAlbumYear="$(echo $matchedTags | jq -r ".YEAR")"
	matchedTagsAlbumType="$(echo $matchedTags | jq -r ".RELEASETYPE")"
	matchedLidarrAlbumData=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$matchedTagsAlbumReleaseGroupId" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[].album")
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
		sleep 2m
	fi
	matchedLidarrAlbumArtistCleanName="$(echo "$matchedLidarrAlbumArtistName" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"


	downloadedAlbumFolder="${matchedLidarrAlbumArtistCleanName}-${matchedTagsAlbumTitleClean} ($matchedTagsAlbumYear)-$2-$3"
    if [ "$1" != "/downloads/lidarr-extended/complete/$downloadedAlbumFolder" ];then
	    mv "$1" "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
	    chmod 777 "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
        chown abc:abc "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"
        chmod 666 "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"/*
        chown abc:abc "/downloads/lidarr-extended/complete/$downloadedAlbumFolder"/*
    fi
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
	log "$lidarrArtistTotal Artists Found"
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
			deezerRelatedArtistIds=($(echo $deezerRelatedArtistData | jq -r .data[].id))

			for dRId in ${!deezerRelatedArtistIds[@]}; do
				deezerRelatedArtistId="${deezerRelatedArtistIds[$dRId]}"

				if echo "$deezeArtistIds" | grep "^${deezerRelatedArtistId}$" | read; then
					log "$deezerRelatedArtistId already in Lidarr..."
					continue
				fi
				query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://www.deezer.com/artist/${deezerRelatedArtistId}%22&fmt=json")
				count=$(echo "$query_data" | jq -r ".count")
				if [ "$count" == "0" ]; then
					sleep 1.5
					query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://www.deezer.com/artist/${deezerRelatedArtistId}%22&fmt=json")
					count=$(echo "$query_data" | jq -r ".count")
					sleep 1.5
				fi
							
				if [ "$count" == "0" ]; then
					query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22http://deezer.com/artist/${deezerRelatedArtistId}%22&fmt=json")
					count=$(echo "$query_data" | jq -r ".count")
					sleep 1.5
				fi
							
				if [ "$count" == "0" ]; then
					query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://deezer.com/artist/${deezerRelatedArtistId}%22&fmt=json")
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
						log "$artistName to already in Lidarr ($musicbrainz_main_artist_id)..."
						continue
					fi
					log "Adding $artistName to Lidarr ($musicbrainz_main_artist_id)..."

					LidarrTaskStatusCheck

					lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
					
				else
					matched_id=false
				fi

			done
			
		done
	done

}

LidarrTaskStatusCheck () {
	until false
	do
		taskCount=$(curl -s "$lidarrUrl/api/v1/command?apikey=${lidarrApiKey}" | jq -r .[].status | grep -v completed | grep -v failed | wc -l)
		if [ "$taskCount" -gt "3" ]; then
			sleep 1
		else
			break
		fi
	done
}

if [ "$dlClientSource" = "deezer" ] || [ "$dlClientSource" = "both" ]; then
	DeemixClientSetup
fi

if [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	TidalClientSetup
fi

if [ "$dlClientSource" = "deezer" ] || [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	GetMissingCutOffList
	SearchProcess
else
	log ":: ERROR :: No valid dlClientSource set"
	log ":: ERROR :: Expected configuration :: deezer or tidal or both"
	log ":: ERROR :: dlClientSource set as: \"$dlClientSource\""
fi

if [ "$AddRelatedArtists" = "true" ]; then
	AddRelatedArtists
else
	log ":: ERROR :: AddRelatedArtists is disabled"
fi

exit

#!/usr/bin/with-contenv bash
lidarrApiKey="$(grep "<ApiKey>" /config/config.xml | sed "s/\  <ApiKey>//;s/<\/ApiKey>//")"
lidarrUrl="http://127.0.0.1:8686"
XDG_CONFIG_HOME="/config/deemix/xdg"
export XDG_CONFIG_HOME="/config/deemix/xdg"
CountryCode=US

log () {
    m_time=`date "+%F %T"`
    echo $m_time" "$1
}

DownloadProcess () {
    downloadedAlbumTitleClean="$(echo "$downloadedAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
    
    if [ ! -d "/downloads/lidarr" ]; then
        mkdir -p /downloads/lidarr
        chmod 777 /downloads/lidarr
        chown abc:abc /downloads/lidarr
    fi
    if [ ! -d "/downloads/lidarr/incomplete" ]; then
        mkdir -p /downloads/lidarr/incomplete
        chmod 777 /downloads/lidarr/incomplete
        chown abc:abc /downloads/lidarr/incomplete
    fi

    if [ "$2" = "DEEZER" ]; then
        deemix -b flac -p /downloads/lidarr/incomplete "https://www.deezer.com/us/album/$1"
        if [ ! -d "/config/logs" ]; then
            mkdir -p /config/logs
            chmod 777 /config/logs
            chown abc:abc /config/logs
        fi
        if [ ! -d "/config/logs/downloaded" ]; then
            mkdir -p /config/logs/downloaded
            chmod 777 /config/logs/downloaded
            chown abc:abc /config/logs/downloaded
        fi
        if [ ! -d "/config/logs/downloaded/deezer" ]; then
            mkdir -p /config/logs/downloaded/deezer
            chmod 777 /config/logs/downloaded/deezer
            chown abc:abc /config/logs/downloaded/deezer
        fi
        touch /config/logs/downloaded/deezer/$1
        downloadCount=$(find /downloads/lidarr/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
        if [ $downloadCount -le 0 ]; then
            echo "download failed"
            return
        fi
    else
        return
    fi


    albumquality="$(find /downloads/lidarr/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1 | egrep -i -E -o "\.{1}\w*$" | sed  's/\.//g')"
    downloadedAlbumFolder="$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-${albumquality^^}-$2"

    find "/downloads/lidarr/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' audio; do
        file="${audio}"
        filenoext="${file%.*}"
        filename="$(basename "$audio")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        if [ ! -d "/downloads/lidarr/complete" ]; then
            mkdir -p /downloads/lidarr/complete
            chmod 777 /downloads/lidarr/complete
            chown abc:abc /downloads/lidarr/complete
        fi
        mkdir -p "/downloads/lidarr/complete/$downloadedAlbumFolder"
        mv "$file" "/downloads/lidarr/complete/$downloadedAlbumFolder"/
        
    done
    chmod 777 "/downloads/lidarr/complete/$downloadedAlbumFolder"
    chown abc:abc "/downloads/lidarr/complete/$downloadedAlbumFolder"
    chmod 666 "/downloads/lidarr/complete/$downloadedAlbumFolder"/*
    chown abc:abc "/downloads/lidarr/complete/$downloadedAlbumFolder"/*

    ProcessWithBeets "/downloads/lidarr/complete/$downloadedAlbumFolder" "${albumquality^^}" "$2"

    if [ -d "/downloads/lidarr/complete/$downloadedAlbumFolder" ]; then
        NotifyLidarrForImport "/downloads/lidarr/complete/$downloadedAlbumFolder"
    fi
    rm -rf /downloads/lidarr/incomplete/*
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$lidarrUrl/api/v1/command" --header "X-Api-Key:"${lidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	echo "LIDARR IMPORT NOTIFICATION SENT! :: $1"
}


if [ ! -z "$arlToken" ]; then
    # Create directories
    mkdir -p /config/{cache,logs,deemix/xdg/deemix}
	if [ -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
		rm "$XDG_CONFIG_HOME/deemix/.arl"
	fi
	if [ ! -f "$XDG_CONFIG_HOME/deemix/.arl" ]; then
		echo -n "$arlToken" > "$XDG_CONFIG_HOME/deemix/.arl"
	fi
    log "ARL Token: Configured"
else
	log "ERROR: arlToken setting invalid, currently set to: $arlToken"
fi


GetMissingCutOffList () {
    log "Downloading missing list..."
    missingAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1000000000&sortDir=desc&sortKey=releaseDate&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
    missingAlbumIdsTotal=$(echo "$missingAlbumIds" | sed -r '/^\s*$/d' | wc -l)
    log "FINDING MISSING ALBUMS: ${missingAlbumIdsTotal} Found"

    log "Downloading cutoff list..."
    cutoffAlbumIds=$(curl -s "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1000000000&sortDir=desc&sortKey=releaseDate&apikey=${lidarrApiKey}" | jq -r '.records | .[] | .id')
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
        lidarrAlbumTitleClean=$(echo "$lidarrAlbumTitle" | sed -e "s%[^[:alpha:][:digit:] ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
        lidarrAlbumReleases=$(echo "$lidarrAlbumData" | jq -r ".releases")
        #echo $lidarrAlbumData | jq -r 
        lidarrAlbumWordCount=$(echo $lidarrAlbumTitle | wc -w)
        #echo $lidarrAlbumReleases | jq -r 
        lidarrArtistData=$(echo "${lidarrAlbumData}" | jq -r ".artist")
        lidarrArtistId=$(echo "${lidarrArtistData}" | jq -r ".artistMetadataId")
        lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
        lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
        lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g')"
        tidalArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"tidal\") | .url")
        tidalArtistId="$(echo "$tidalArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
        deezerArtistUrl=$(echo "${lidarrArtistData}" | jq -r ".links | .[] | select(.name==\"deezer\") | .url")
        deezeArtistId="$(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u)"
        log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Starting Search..."
        if [ -f /config/logs/downloaded/notfound/$wantedAlbumId ]; then
            log ":: $processNumber of $wantedListAlbumTotal :: $lidarrArtistNameSanitized :: $lidarrAlbumTitle :: Previously Not Found, skipping..."
            continue
        fi
        
        if [ ! -d /config/cache/deezer ]; then
            mkdir -p /config/cache/deezer
        fi
        if [ ! -f /config/cache/deezer/$deezeArtistId-albums.json ]; then
            curl -s "https://api.deezer.com/artist/$deezeArtistId/albums?limit=1000" > /config/cache/deezer/$deezeArtistId-albums.json
        fi
        if [ ! -d /config/cache/tidal ]; then
            mkdir -p /config/cache/tidal
        fi
        if [ ! -f /config/cache/tidal/$tidalArtistId-videos.json ]; then
            curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/videos?limit=10000&countryCode=$CountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/cache/tidal/$tidalArtistId-videos.json
        fi
        if [ ! -f /config/cache/tidal/$tidalArtistId-albums.json ]; then
            curl -s "https://api.tidal.com/v1/artists/${tidalArtistId}/albums?limit=10000&countryCode=$CountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/cache/tidal/$tidalArtistId-albums.json
        fi


        deezerArtistAlbumsData=$(cat "/config/cache/deezer/$deezeArtistId-albums.json" | jq -r ".data | sort_by(.release_date) | sort_by(.explicit_lyrics) | reverse | .[]")
        deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="true") | .id"))
        tidalArtistAlbumsData=$(cat "/config/cache/tidal/$tidalArtistId-albums.json" | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[]")
        tidalArtistAlbumsIds=($(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="true") | .id"))

        echo "$lidarrAlbumTitle"
        if echo "${deezerArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
            for id in ${!deezerArtistAlbumsIds[@]}; do
                processNumberTwo=$(( $id + 1 ))
                deezerArtistAlbumId="${deezerArtistAlbumsIds[$id]}"
                deezerArtistAlbumData=$(echo "$deezerArtistAlbumsData" | jq -r "select(.id=="$deezerArtistAlbumId")")
                deezerArtistAlbumTitleClean=$(echo ${deezerArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:] ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
                if echo ${deezerArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
                    downloadedAlbumTitle="$(echo ${deezerArtistAlbumData} | jq -r .title)"
                    downloadedReleaseDate="$(echo ${deezerArtistAlbumData} | jq -r .release_date)"
                    downloadedReleaseYear="${downloadedReleaseDate:0:4}"
                    echo "Deezer Explicit MATCH"
                    if [ -f /config/logs/downloaded/deezer/$deezerArtistAlbumId ]; then
                        continue
                    fi
                    DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear"
                fi
            done
        else
            echo "No Explicit Deezer Match Found"
        fi 

        if echo "${tidalArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
            for id in ${!tidalArtistAlbumsIds[@]}; do
                processNumberTwo=$(( $id + 1 ))
                tidalArtistAlbumId="${tidalArtistAlbumsIds[$id]}"
                tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
                tidalArtistAlbumTitleClean=$(echo ${tidalArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:] ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
                if echo ${tidalArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
                    downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
                    downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
                    if [ "$downloadedReleaseDate" = "null" ]; then
                        downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
                    fi
                    downloadedReleaseYear="${downloadedReleaseDate:0:4}"
                    echo "Tidal Explicit MATCH"
                    DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear"
                fi
            done
        else
            echo "No Explicit Tidal Match Found"
        fi

        deezerArtistAlbumsIds=($(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="false") | .id"))

        if echo "${deezerArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
            for id in ${!deezerArtistAlbumsIds[@]}; do
                processNumberTwo=$(( $id + 1 ))
                deezerArtistAlbumId="${deezerArtistAlbumsIds[$id]}"
                deezerArtistAlbumData=$(echo "$deezerArtistAlbumsData" | jq -r "select(.id=="$deezerArtistAlbumId")")
                deezerArtistAlbumExplicit=$(echo ${deezerArtistAlbumData} | jq -r .explicit_lyrics)
                deezerArtistAlbumTitleClean=$(echo ${deezerArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:] ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
                if echo ${deezerArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
                    downloadedAlbumTitle="$(echo ${deezerArtistAlbumData} | jq -r .title)"
                    downloadedReleaseDate="$(echo ${deezerArtistAlbumData} | jq -r .release_date)"
                    downloadedReleaseYear="${downloadedReleaseDate:0:4}"
                    echo "CLEAN Deezer MATCH"
                    if [ -f /config/logs/downloaded/deezer/$deezerArtistAlbumId ]; then
                        continue
                    fi
                    DownloadProcess "$deezerArtistAlbumId" "DEEZER" "$downloadedReleaseYear"
                fi
            done
        else
            echo "No Clean Deezer Match Found"
        fi

        tidalArtistAlbumsIds=($(echo "${tidalArtistAlbumsData}" | jq -r "select(.explicit=="false") | .id"))

        if echo "${tidalArtistAlbumsData}" | jq -r .title | grep -i "^$lidarrAlbumTitle" | read; then
            for id in ${!tidalArtistAlbumsIds[@]}; do
                processNumberTwo=$(( $id + 1 ))
                tidalArtistAlbumId="${tidalArtistAlbumsIds[$id]}"
                tidalArtistAlbumData=$(echo "$tidalArtistAlbumsData" | jq -r "select(.id=="$tidalArtistAlbumId")")
                tidalArtistAlbumTitleClean=$(echo ${tidalArtistAlbumData} | jq -r .title | sed -e "s%[^[:alpha:][:digit:] ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
                if echo ${tidalArtistAlbumTitleClean} | grep -i "^$lidarrAlbumTitleClean" | read; then
                    downloadedAlbumTitle="$(echo ${tidalArtistAlbumData} | jq -r .title)"
                    downloadedReleaseDate="$(echo ${tidalArtistAlbumData} | jq -r .releaseDate)"
                    if [ "$downloadedReleaseDate" = "null" ]; then
                        downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
                    fi
                    downloadedReleaseYear="${downloadedReleaseDate:0:4}"
                    echo "CLEAN Tidal MATCH"
                    DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear"
                fi
            done
        else
            echo "No Clean Tidal Match Found"
        fi
        mkdir -p /config/logs/downloaded/notfound
        touch /config/logs/downloaded/notfound/$wantedAlbumId
    done
}

ProcessWithBeets () {
	
	trackcount=$(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)

	if [ -f /config/beets_temp_library.blb ]; then
		rm /config/beets_temp_library.blb
		sleep 0.1
		fi
	if [ -f /config/beets_temp.log ]; then 
		rm /config/beets_temp.log
		sleep 0.1
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi
	touch "/config/beets-match"
	sleep 0.1

	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l) -gt 0 ]; then
		beet -l /config/beets_temp_library.blb -d "$1" import -qC "$1"
		if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-match" | wc -l) -gt 0 ]; then
			log ":: SUCCESS: Matched with beets!"
		else
			log ": ERROR :: Unable to match using beets to a musicbrainz release, marking download as failed..."
			touch "/config/beets-match-error"
		fi	
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi

	if [ -f "/config/beets-match-error" ]; then
		log ":: ERROR :: Beets could not match album, skipping..."
		rm "/config/beets-match-error"
        rm -rf "$1"
		return
	else
		log ": BEETS MATCH FOUND!"
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
	if [ "${matchedLidarrAlbumArtistCleanName}" != "null" ]; then
		log "$position :: $idNumber of $idListCount :: $tidalId :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId) found in Lidarr"
	else
		log "$position :: $idNumber of $idListCount :: $tidalId :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId) NOT found in Lidarr"
		data=$(curl -s "$LidarrUrl/api/v1/search?term=lidarr%3A$matchedLidarrAlbumArtistId" -H "X-Api-Key: $LidarrApiKey" | jq -r ".[]")
		artistName="$(echo "$data" | jq -r ".artist.artistName")"
		foreignId="$(echo "$data" | jq -r ".foreignId")"
		data=$(curl -s "$LidarrUrl/api/v1/rootFolder" -H "X-Api-Key: $LidarrApiKey" | jq -r ".[]")
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
		log "$position :: $idNumber of $idListCount :: $tidalId :: Adding Missing Artist to Lidarr :: $matchedLidarrAlbumArtistName ($matchedLidarrAlbumArtistId)..."
		lidarrAddArtist=$(curl -s "$LidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $LidarrApiKey" --data-raw "$data")
		log "$position :: $idNumber of $idListCount :: $tidalId :: Allowing Lidarr Artist Update, pause for 2 min..."
		sleep 2m
	fi
	matchedLidarrAlbumArtistCleanName="$(echo "$matchedLidarrAlbumArtistName" | sed -e "s%[^[:alpha:][:digit:]._()' -]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"


	downloadedAlbumFolder="${matchedLidarrAlbumArtistCleanName}-${matchedTagsAlbumTitleClean} ($matchedTagsAlbumYear)-$2-$3"
    if [ "$1" != "/downloads/lidarr/complete/$downloadedAlbumFolder" ];then
	    mv "$1" "/downloads/lidarr/complete/$downloadedAlbumFolder"
	    chmod 777 "/downloads/lidarr/complete/$downloadedAlbumFolder"
        chown abc:abc "/downloads/lidarr/complete/$downloadedAlbumFolder"
        chmod 666 "/downloads/lidarr/complete/$downloadedAlbumFolder"/*
        chown abc:abc "/downloads/lidarr/complete/$downloadedAlbumFolder"/*
    fi
}


GetMissingCutOffList
SearchProcess

exit

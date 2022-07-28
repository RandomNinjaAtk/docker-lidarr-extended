#!/usr/bin/env bash
scriptVersion="1.0.000"
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

# Debugging Settings
sourcePreference=tidal

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Video :: "$1
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
log "|~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
log "|~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
log "Presents: lidarr-extended ($scriptVersion)"
log "Docker Version: $dockerVersion"
log "May the vidz be with you!"
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


Configuration () {
	processstartid="$(ps -A -o pid,cmd|grep "start_video.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	processdownloadid="$(ps -A -o pid,cmd|grep "video.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processstartid"
	log "kill -9 $processdownloadid"
	sleep 2
	
	verifyApiAccess
}

CacheMusicbrainzRecords () {
    lidarrArtists=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/artist?apikey=$lidarrApiKey" | jq -r .[])
	lidarrArtistIds=$(echo $lidarrArtists | jq -r .id)
	lidarrArtistIdsCount=$(echo "$lidarrArtistIds" | wc -l)
	processCount=0
	for lidarrArtistId in $(echo $lidarrArtistIds); do
		processCount=$(( $processCount + 1))
        lidarrArtistData=$(echo $lidarrArtists | jq -r "select(.id==$lidarrArtistId)")
		lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
		lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
        lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
		lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
        lidarrArtistNameSanitized="$(echo "$lidarrArtistFolder" | sed 's% (.*)$%%g')"

        if  [ "$lidarrArtistName" == "Various Artists" ]; then
		    log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Skipping, not processed by design..."
            continue
        fi

        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Processing..."
        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Checking Musicbrainz for recordings..."
        musicbrainzArtistRecordings=$(curl -s -A "$agent" "$musicbrainzMirror/ws/2/recording?artist=$lidarrArtistMusicbrainzId&limit=1&offset=0&fmt=json")
		sleep 1
		musicbrainzArtistRecordingsCount=$(echo "$musicbrainzArtistRecordings" | jq -r '."recording-count"')
        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: $musicbrainzArtistRecordingsCount recordings found..."
        
        if [ ! -d /config/extended/cache/musicbrainz ]; then
            mkdir -p /config/extended/cache/musicbrainz
            chmod 777 /config/extended/cache/musicbrainz
            chown abc:abc /config/extended/cache/musicbrainz
        fi

        if [ -f "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" ]; then
            if ! [[ $(find "/config/extended/cache/musicbrainz" -type f -name "$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" -mtime +7 -print) ]]; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Previously cached, skipping..."
            else
                rm "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
            fi
        fi

        if [ ! -f "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" ]; then
            offsetcount=$(( $musicbrainzArtistRecordingsCount / 100 ))
            for ((i=0;i<=$offsetcount;i++)); do
                if [ $i != 0 ]; then
                    offset=$(( $i * 100 ))
                    dlnumber=$(( $offset + 100))
                else
                    offset=0
                    dlnumber=$(( $offset + 100))
                fi

                log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Downloading page $i... ($offset - $dlnumber Results)"
                curl -s -A "$agent" "$musicbrainzMirror/ws/2/recording?artist=$lidarrArtistMusicbrainzId&inc=url-rels&limit=100&offset=$offset&fmt=json" | jq -r ".recordings[]" >> "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
                sleep 1
        
            done
        fi

        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: Checking records for videos..."
        musibrainzArtistVideoRecordings=$(cat "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" | jq -r "select(.video==true)")
        musibrainzArtistVideoRecordingsCount=$(echo "$musibrainzArtistVideoRecordings" | jq -r .id | wc -l)
        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: $musibrainzArtistVideoRecordingsCount videos found..."
        musibrainzArtistVideoRecordingsDataWithUrl=$(echo "$musibrainzArtistVideoRecordings" | jq -r "select(.relations[])")
        musibrainzArtistVideoRecordingsDataWithUrlIds=$(echo "$musibrainzArtistVideoRecordingsDataWithUrl" | jq -r .id)
        musibrainzArtistVideoRecordingsDataWithUrlIdsCount=$(echo "$musibrainzArtistVideoRecordingsDataWithUrl" | jq -r .id | wc -l)
        log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: $musibrainzArtistVideoRecordingsDataWithUrlIdsCount videos found with URL..."

        if [ $musibrainzArtistVideoRecordingsDataWithUrlIdsCount = 0 ]; then
            log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: ERROR :: No vidoes with URLs to process, skipping..."
            continue
        fi

        for musicbrainzVideoId in $(echo "$musibrainzArtistVideoRecordingsDataWithUrlIds"); do
            musibrainzVideoRecordingData=$(echo "$musibrainzArtistVideoRecordingsDataWithUrl" | jq -r "select(.id==\"$musicbrainzVideoId\")")
            musibrainzVideoTitle="$(echo "$musibrainzVideoRecordingData" | jq -r .title)"
            musibrainzVideoTitleClean="$(echo "$musibrainzVideoTitle" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
            musibrainzVideoDisambiguation=""
            musibrainzVideoDisambiguation="$(echo "$musibrainzVideoRecordingData" | jq -r .disambiguation)"
            if [ ! -z "$musibrainzVideoDisambiguation" ]; then
                musibrainzVideoDisambiguationClean=" ($(echo "$musibrainzVideoDisambiguation" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g'))"
            else
                musibrainzVideoDisambiguationClean=""
            fi
            musibrainzVideoRelations="$(echo "$musibrainzVideoRecordingData" | jq -r .relations[].url.resource)"

            if [ $sourcePreference = tidal ]; then
                if echo "$musibrainzVideoRelations" | grep -i "tidal" | read; then
                    videoDownloadUrl="$(echo "$musibrainzVideoRelations" | grep -i "tidal" | head -n1)"
                else
                    videoDownloadUrl="$(echo "$musibrainzVideoRelations" | grep -i "youtube" | head -n1)"
                fi
            else
                videoDownloadUrl="$(echo "$musibrainzVideoRelations" | grep -i "youtube" | head -n1)"
            fi

            log "$processCount of $lidarrArtistIdsCount :: MBZDB CACHE :: $lidarrArtistName :: $musibrainzVideoTitle ($musibrainzVideoDisambiguation) :: $videoDownloadUrl..."

            if [ ! -d "/music-videos/$lidarrArtistFolder" ]; then
                mkdir -p "/music-videos/$lidarrArtistFolder"
                chmod 777 "/music-videos/$lidarrArtistFolder"
                chown abc:abc "/music-videos/$lidarrArtistFolder"
            fi 

            yt-dlp -o "/music-videos/$lidarrArtistFolder/$lidarrArtistNameSanitized - ${musibrainzVideoTitleClean}${musibrainzVideoDisambiguationClean}" --embed-subs --sub-lang en --merge-output-format mkv --remux-video mkv --no-mtime --geo-bypass "$videoDownloadUrl"

            if [ -f "/music-videos/$lidarrArtistFolder/$lidarrArtistNameSanitized - ${musibrainzVideoTitleClean}${musibrainzVideoDisambiguationClean}" ]; then
                chmod 666 "/music-videos/$lidarrArtistFolder/$lidarrArtistNameSanitized - ${musibrainzVideoTitleClean}${musibrainzVideoDisambiguationClean}.mkv"
                chown abc:abc "/music-videos/$lidarrArtistFolder/$lidarrArtistNameSanitized - ${musibrainzVideoTitleClean}${musibrainzVideoDisambiguationClean}.mkv"
            fi
        done
    done
}

Configuration
CacheMusicbrainzRecords

exit

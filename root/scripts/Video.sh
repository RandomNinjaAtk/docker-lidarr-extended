#!/usr/bin/env bash
scriptVersion="1.0.061"

if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" = "null" ]; then
		lidarrUrlBase=""
	else
		lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
	fi
	lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
	lidarrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
	lidarrUrl="http://127.0.0.1:${lidarrPort}${lidarrUrlBase}"
fi

agent="lidarr-extended ( https://github.com/RandomNinjaAtk/docker-lidarr-extended )"
musicbrainzMirror=https://musicbrainz.org

# Debugging Settings
#addFeaturedVideoArtists=true
#videoFormat=bestvideo+best+bestaudio

if [ "$dlClientSource" = "tidal" ] || [ "$dlClientSource" = "both" ]; then
	sourcePreference=tidal
fi

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Video :: $scriptVersion :: "$1
}

verifyApiAccess () {
	until false
	do
		lidarrTest=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .appName)
		if [ "$lidarrTest" == "Lidarr" ]; then
			lidarrVersion=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/system/status?apikey=${lidarrApiKey}" | jq -r .version)
			log "Lidarr Version: $lidarrVersion"
			break
		else
			log "Lidarr is not ready, sleeping until valid response..."
			sleep 1
		fi
	done
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/Video.txt" ]; then
	find /config/logs -type f -name "Video.txt" -size +5000k -delete
	sleep 0.01
fi
exec &> >(tee -a "/config/logs/Video.txt")
touch "/config/logs/Video.txt"
chmod 666 "/config/logs/Video.txt"

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
	processdownloadid="$(ps -A -o pid,cmd|grep "Video.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processdownloadid"
	sleep 2
	
	verifyApiAccess

	downloadPath="$downloadPath/videos"
	log "CONFIG :: Download Location :: $downloadPath"
	log "CONFIG :: Music Video Location :: $videoPath"
	log "CONFIG :: Subtitle Language set to: $youtubeSubtitleLanguage"
	log "CONFIG :: yt-dlp format: $videoFormat"
	if [ -n "$videoDownloadTag" ]; then
		log "CONFIG :: Video download tag set to: $videoDownloadTag"
	fi
	if [ -f "/config/cookies.txt" ]; then
		cookiesFile="/config/cookies.txt"
		log "CONFIG :: Cookies File Found! (/config/cookies.txt)"
	    else
		log "CONFIG :: ERROR :: Cookies File Not Found!"
		log "CONFIG :: ERROR :: Add yt-dlp compatible cookies.txt to the following location: /config/cookies.txt"
		cookiesFile=""
	    fi
	log "CONFIG :: Complete"
}

CacheMusicbrainzRecords () {


        log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Processing..."
        log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Checking Musicbrainz for recordings..."
        musicbrainzArtistRecordings=$(curl -s -A "$agent" "$musicbrainzMirror/ws/2/recording?artist=$lidarrArtistMusicbrainzId&limit=1&offset=0&fmt=json")
		sleep 1
		musicbrainzArtistRecordingsCount=$(echo "$musicbrainzArtistRecordings" | jq -r '."recording-count"')
        log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: $musicbrainzArtistRecordingsCount recordings found..."
        
        if [ ! -d /config/extended/cache/musicbrainz ]; then
            mkdir -p /config/extended/cache/musicbrainz
            chmod 777 /config/extended/cache/musicbrainz
        fi

        if [ -f "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" ]; then
            if ! [[ $(find "/config/extended/cache/musicbrainz" -type f -name "$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" -mtime +7 -print) ]]; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Previously cached, skipping..."
                return
            fi            
        fi

        if [ -f "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" ]; then
            musicbrainzArtistDownloadedRecordingsCount=$(cat "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" | jq -r .id | wc -l)
            if [ $musicbrainzArtistRecordingsCount -ne $musicbrainzArtistDownloadedRecordingsCount  ]; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Previously cached, data needs to be updated..."
                rm "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
            fi
        fi
        
        if [ -f "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" ]; then
            if ! cat "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" | grep -i "artist-credit" | read; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Previously cached, data needs to be updated..."
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

                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Downloading page $i... ($offset - $dlnumber Results)"
                curl -s -A "$agent" "$musicbrainzMirror/ws/2/recording?artist=$lidarrArtistMusicbrainzId&inc=artist-credits+url-rels+recording-rels+release-rels+release-group-rels&limit=100&offset=$offset&fmt=json" | jq -r ".recordings[]" >> "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
                sleep 1
        
            done
        fi

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
	tidal-dl -o "$downloadPath/incomplete"
		
	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		TidaldlStatusCheck
		#log "TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		#pip install tidal-dl==2022.3.4.2 --no-cache-dir &>/dev/null
		TidaldlStatusCheck
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		NotifyWebhook "Error" "TIDAL requires authentication, please authenticate now (check logs)"
		tidal-dl
	fi
		
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p $downloadPath/incomplete
		chmod 777 $downloadPath/incomplete
	fi
	
    TidaldlStatusCheck
	#log "TIDAL :: Upgrade tidal-dl to newer version..."
	#pip install tidal-dl==2022.07.06.1 --no-cache-dir &>/dev/null
	
}

TidalClientTest () { 
	log "TIDAL :: tidal-dl client setup verification..."
	i=0
	while [ $i -lt 3 ]; do
		i=$(( $i + 1 ))
		TidaldlStatusCheck
		tidal-dl -q Normal -o "$downloadPath"/incomplete -l "166356219"
		downloadCount=$(find "$downloadPath"/incomplete -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
		if [ $downloadCount -le 0 ]; then
			continue
		else
			break
		fi
	done

	if [ $downloadCount -le 0 ]; then
		if [ -f /config/xdg/.tidal-dl.token.json ]; then
			rm /config/xdg/.tidal-dl.token.json
		fi
		log "TIDAL :: ERROR :: Download failed"
		log "TIDAL :: ERROR :: You will need to re-authenticate on next script run..."
		log "TIDAL :: ERROR :: Exiting..."
		rm -rf "$downloadPath"/incomplete/*
		NotifyWebhook "Error" "TIDAL not authenticated but configured"
		exit
	else
		rm -rf "$downloadPath"/incomplete/*
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

ImvdbCache () {
    
    if [ -z "$artistImvdbSlug" ]; then
        return
    fi
    if [ ! -d "/config/extended/cache/imvdb" ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Creating Cache Folder..."
        mkdir -p "/config/extended/cache/imvdb"
        chmod 777 "/config/extended/cache/imvdb"
    fi
    
    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Caching Records..."

    if [ ! -f /config/extended/cache/imvdb/$artistImvdbSlug ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Recording Artist Slug into cache"
        echo -n "$lidarrArtistName" > /config/extended/cache/imvdb/$artistImvdbSlug
    fi
    artistImvdbVideoUrls=$(curl -s "https://imvdb.com/n/$artistImvdbSlug" | grep "$artistImvdbSlug" | grep -Eoi '<a [^>]+>' |  grep -Eo 'href="[^\"]+"' | grep -Eo '(http|https)://[^"]+' |  grep -i ".com/video/$artistImvdbSlug/" | sed "s%/[0-9]$%%g" | sort -u)
    artistImvdbVideoUrlsCount=$(echo "$artistImvdbVideoUrls" | wc -l)
    cachedArtistImvdbVideoUrlsCount=$(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--* 2>/dev/null | wc -l)

    if [ "$artistImvdbVideoUrlsCount" ==  "$cachedArtistImvdbVideoUrlsCount" ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Chache is already up-to-date, skipping..."
        return
    fi

    sleep 0.5
    imvdbProcessCount=0
    for imvdbVideoUrl in $(echo "$artistImvdbVideoUrls"); do
        imvdbProcessCount=$(( $imvdbProcessCount + 1 ))
        imvdbVideoUrlSlug=$(basename "$imvdbVideoUrl")
        imvdbVideoData="/config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--$imvdbVideoUrlSlug.json"
        #echo "$imvdbVideoUrl :: $imvdbVideoUrlSlug :: $imvdbVideoId"
        
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Caching video data..."
        if [ -f "$imvdbVideoData" ]; then
            if [ ! -s "$imvdbVideoData"  ]; then # if empty, delete file
                rm "$imvdbVideoData"
            fi
        fi

        if [ -f "$imvdbVideoData" ]; then 
            if jq -e . >/dev/null 2>&1 <<<"$(cat "$imvdbVideoData")"; then # verify file is valid json
                log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Video Data already downloaded"
                continue
            fi
        fi

        if [ ! -f "$imvdbVideoData" ]; then
            count=0
            until false; do
                count=$(( $count + 1 ))
                #echo "$count"
                if [ ! -f "$imvdbVideoData" ]; then
                    imvdbVideoId=$(curl -s "$imvdbVideoUrl" | grep "<p>ID:" | grep -o "[[:digit:]]*")
                    imvdbVideoJsonUrl="https://imvdb.com/api/v1/video/$imvdbVideoId?include=sources,countries,featured,credits,bts,popularity"
                    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount ::  Downloading Video data"
                    curl -s "$imvdbVideoJsonUrl" -o "$imvdbVideoData"
                    sleep 0.5
                fi
                if [ -f "$imvdbVideoData" ]; then
                    if [ ! -s "$imvdbVideoData"  ]; then
                        rm "$imvdbVideoData"
                        if [ $count = 2 ]; then
                            log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Download Failed, skipping..."
                            break
                        fi
                    elif jq -e . >/dev/null 2>&1 <<<"$(cat "$imvdbVideoData")"; then
                        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: $imvdbProcessCount of $artistImvdbVideoUrlsCount :: Download Complete"
                        break
                    else
                        rm "$imvdbVideoData"
                    fi
                fi
            done
        fi
    done
}

DownloadVideo () {

    if [ -d "$downloadPath/incomplete" ]; then
        rm -rf "$downloadPath/incomplete"
    fi

    if [ ! -d "$downloadPath/incomplete" ]; then
        mkdir -p "$downloadPath/incomplete"
        chmod 777 "$downloadPath/incomplete"
    fi 

    if echo "$1" | grep -i "youtube" | read; then
        if [ ! -z "$cookiesFile" ]; then
            yt-dlp -f "$videoFormat" --no-video-multistreams --cookies "$cookiesFile" -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --merge-output-format mkv --remux-video mkv --no-mtime --geo-bypass "$1"
        else
            yt-dlp -f "$videoFormat" --no-video-multistreams -o "$downloadPath/incomplete/${2}${3}" --embed-subs --sub-lang $youtubeSubtitleLanguage --merge-output-format mkv --remux-video mkv --no-mtime --geo-bypass "$1"
        fi
        if [ -f "$downloadPath/incomplete/${2}${3}.mkv" ]; then
            chmod 666 "$downloadPath/incomplete/${2}${3}.mkv"
            downloadFailed=false
        else
            downloadFailed=true
        fi
    fi
    
    if echo "$1" | grep -i "tidal" | read; then
        TidalClientTest
        sleep 1
        TidaldlStatusCheck
        tidal-dl -o "$downloadPath/incomplete" -l "$1"
        find "$downloadPath/incomplete" -type f -exec mv "{}" "$downloadPath/incomplete"/ \;
        find "$downloadPath/incomplete" -mindepth 1 -type d -exec rm -rf "{}" \; &>/dev/null
        find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
            file="${video}"
            filenoext="${file%.*}"
            filename="$(basename "$video")"
            extension="${filename##*.}"
            filenamenoext="${filename%.*}"
            mv "$file" "$downloadPath/incomplete/${2}${3}.mp4"
        done
        if [ -f "$downloadPath/incomplete/${2}${3}.mp4" ]; then
            chmod 666 "$downloadPath/incomplete/${2}${3}.mp4"
            downloadFailed=false
        else
            downloadFailed=true
        fi
    fi

}

DownloadThumb () {

    curl -s "$1" -o "$downloadPath/incomplete/${2}${3}.jpg"
    chmod 666 "$downloadPath/incomplete/${2}${3}.jpg"

}

VideoProcessWithSMA () {
    find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
        count=$(($count+1))
        file="${video}"
        filenoext="${file%.*}"
        filename="$(basename "$video")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"

        if python3 /usr/local/sma/manual.py --config "/config/extended/scripts/sma.ini" -i "$file" -nt &>/dev/null; then
            sleep 0.01
            log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: Processed with SMA..."
            rm  /usr/local/sma/config/*log*
        else
            log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: ERROR: SMA Processing Error"
            rm "$video"
            log "$processCount of $lidarrArtistIdsCount :: $1 :: $lidarrArtistName :: $2 :: INFO: deleted: $filename"
        fi
    done
}

VideoTagProcess () {
    find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(mkv\|mp4\)"  -print0 | while IFS= read -r -d '' video; do
        count=$(($count+1))
        file="${video}"
        filenoext="${file%.*}"
        filename="$(basename "$video")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        artistGenres=""
        OLDIFS="$IFS"
		IFS=$'\n'
		artistGenres=($(echo $lidarrArtistData | jq -r ".genres[]"))
		IFS="$OLDIFS"

        if [ ! -z "$artistGenres" ]; then
            for genre in ${!artistGenres[@]}; do
                artistGenre="${artistGenres[$genre]}"
                OUT=$OUT"$artistGenre / "
            done
            genre="${OUT%???}"
        else
            genre=""
        fi

        mv "$filenoext.mkv" "$filenoext-temp.mkv"
		log "$processCount of $lidarrArtistIdsCount :: $4 :: $lidarrArtistName :: ${1}${2} $3 :: Tagging file"
		ffmpeg -y \
			-i "$filenoext-temp.mkv" \
			-c copy \
			-metadata TITLE="${1}" \
			-metadata DATE_RELEASE="$3" \
			-metadata DATE="$3" \
			-metadata YEAR="$3" \
			-metadata GENRE="$genre" \
			-metadata ARTIST="$lidarrArtistName" \
			-metadata ALBUMARTIST="$lidarrArtistName" \
			-metadata ENCODED_BY="lidarr-extended" \
			-attach "$downloadPath/incomplete/${1}${2}.jpg" -metadata:s:t mimetype=image/jpeg \
			"$filenoext.mkv" &>/dev/null
        rm "$filenoext-temp.mkv"
        chmod 666 "$filenoext.mkv"
    done
}

VideoNfoWriter () {
    log "$processCount of $lidarrArtistIdsCount :: $7 :: $lidarrArtistName :: ${3} :: Writing NFO"
    nfo="$downloadPath/incomplete/${1}${2}.nfo"
    if [ -f "$nfo" ]; then
        rm "$nfo"
    fi
    echo "<musicvideo>" >> "$nfo"
    echo "	<title>${3}${4}</title>" >> "$nfo"
    echo "	<userrating/>" >> "$nfo"
    echo "	<track/>" >> "$nfo"
    echo "	<studio/>" >> "$nfo"
    artistGenres=""
    OLDIFS="$IFS"
	IFS=$'\n'
	artistGenres=($(echo $lidarrArtistData | jq -r ".genres[]"))
	IFS="$OLDIFS"
    if [ ! -z "$artistGenres" ]; then
        for genre in ${!artistGenres[@]}; do
            artistGenre="${artistGenres[$genre]}"
            echo "	<genre>$artistGenre</genre>" >> "$nfo"
        done
    fi
    echo "	<premiered/>" >> "$nfo"
    echo "	<year>$6</year>" >> "$nfo"
    if [ "$5" = "musicbrainz" ]; then
        OLDIFS="$IFS"
        IFS=$'\n'
        for artistName in $(echo "$musicbrainzVideoArtistCreditsNames"); do 
            echo "	<artist>$artistName</artist>" >> "$nfo"
        done
        IFS="$OLDIFS"
    fi
    if [ "$5" = "imvdb" ]; then
        echo "	<artist>$lidarrArtistName</artist>" >> "$nfo"
        for featuredArtistSlug in $(echo "$imvdbVideoFeaturedArtistsSlug"); do
            if [ -f /config/extended/cache/imvdb/$featuredArtistSlug ]; then
                featuredArtistName="$(cat /config/extended/cache/imvdb/$featuredArtistSlug)"
                echo "	<artist>$featuredArtistName</artist>" >> "$nfo"
            fi
        done
    fi
    echo "	<albumArtistCredits>" >> "$nfo"
	echo "		<artist>$lidarrArtistName</artist>" >> "$nfo"
	echo "		<musicBrainzArtistID>$lidarrArtistMusicbrainzId</musicBrainzArtistID>" >> "$nfo"
	echo "	</albumArtistCredits>" >> "$nfo"
    echo "	<thumb>${1}${2}.jpg</thumb>" >> "$nfo"
    echo "</musicvideo>" >> "$nfo"
    tidy -w 2000 -i -m -xml "$nfo" &>/dev/null
    chmod 666 "$nfo"

}

LidarrTaskStatusCheck () {
	alerted=no
	until false
	do
		taskCount=$(curl -s "$lidarrUrl/api/v1/command?apikey=${lidarrApiKey}" | jq -r .[].status | grep -v completed | grep -v failed | wc -l)
		if [ "$taskCount" -ge "3" ]; then
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

AddFeaturedVideoArtists () {
    if [ "$addFeaturedVideoArtists" != "true" ]; then
        log "-----------------------------------------------------------------------------"
        log "Add Featured Music Video Artists to Lidarr :: DISABLED"    
        log "-----------------------------------------------------------------------------"
        return
    fi
    log "-----------------------------------------------------------------------------"
    log "Add Featured Music Video Artists to Lidarr :: ENABLED"    
    log "-----------------------------------------------------------------------------"
    lidarrArtistsData="$(curl -s "$lidarrUrl/api/v1/artist?apikey=${lidarrApiKey}" | jq -r ".[]")"
    artistImvdbUrl=$(echo $lidarrArtistsData | jq -r '.links[] | select(.name=="imvdb") | .url')
    videoArtists=$(ls /config/extended/cache/imvdb/ | grep -Ev ".*--.*")
    videoArtistsCount=$(ls /config/extended/cache/imvdb/ | grep -Ev ".*--.*" | wc -l)
    if [ "$videoArtistsCount" == "0" ]; then
        log "$videoArtistsCount Artists found for processing, skipping..."
        return
    fi
    loopCount=0
    for slug in $(echo $videoArtists); do
        loopCount=$(( $loopCount + 1))
        artistName="$(cat /config/extended/cache/imvdb/$slug)"
        if echo "$artistImvdbUrl" | grep -i "^https://imvdb.com/n/${slug}$" | read; then
            log "$loopCount of $videoArtistsCount :: $artistName :: Already added to Lidarr, skipping..."
            continue
        fi
        log "$loopCount of $videoArtistsCount :: $artistName :: Processing url :: https://imvdb.com/n/$slug"
        query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://imvdb.com/n/$slug%22&fmt=json")
        count=$(echo "$query_data" | jq -r ".count")			
        if [ "$count" != "0" ]; then
            musicbrainzArtistId="$(echo "$query_data" | jq -r ".urls[].\"relation-list\"[].relations[].artist.id")"
            sleep 1
        else
            log "$loopCount of $videoArtistsCount :: $artistName :: ERROR : Musicbrainz ID Not Found, skipping..."
            continue
        fi

        data=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A$musicbrainzArtistId" -H "X-Api-Key: $lidarrApiKey" | jq -r ".[]")
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

		if echo "$lidarrArtistIds" | grep "^${musicbrainzArtistId}$" | read; then
			log "$loopCount of $videoArtistsCount :: $artistName :: Already in Lidarr ($musicbrainzArtistId), skipping..."
			continue
		fi
		log "$loopCount of $videoArtistsCount :: $artistName :: Adding $artistName to Lidarr ($musicbrainzArtistId)..."
		LidarrTaskStatusCheck
		lidarrAddArtist=$(curl -s "$lidarrUrl/api/v1/artist" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" --data-raw "$data")
    done

}

NotifyWebhook () {
	if [ "$webHook" ]
	then
		content="$1: $2"
		curl -X POST "{$webHook}" -H 'Content-Type: application/json' -d '{"event":"'"$1"'", "message":"'"$2"'", "content":"'"$content"'"}'
	fi
}

Configuration
if [ "$sourcePreference" == "tidal" ]; then
    TidalClientSetup
fi
AddFeaturedVideoArtists

log "-----------------------------------------------------------------------------"
log "Finding Videos"    
log "-----------------------------------------------------------------------------"
if [ -z "$videoDownloadTag" ]; then
	lidarrArtists=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/artist?apikey=$lidarrApiKey" | jq -r .[])
	lidarrArtistIds=$(echo $lidarrArtists | jq -r .id)
else
	lidarrArtists=$(curl -s "$lidarrUrl/api/v1/tag/detail" -H 'Content-Type: application/json' -H "X-Api-Key: $lidarrApiKey" | jq -r -M ".[] | select(.label == \"$videoDownloadTag\") | .artistIds")
	lidarrArtistIds=$(echo $lidarrArtists | jq -r .[])
fi
lidarrArtistIdsCount=$(echo "$lidarrArtistIds" | wc -l)
processCount=0
for lidarrArtistId in $(echo $lidarrArtistIds); do
	processCount=$(( $processCount + 1))
    lidarrArtistData=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/artist/$lidarrArtistId?apikey=$lidarrApiKey")
	lidarrArtistName=$(echo $lidarrArtistData | jq -r .artistName)
	lidarrArtistMusicbrainzId=$(echo $lidarrArtistData | jq -r .foreignArtistId)
    
    if  [ "$lidarrArtistName" == "Various Artists" ]; then
        log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: Skipping, not processed by design..."
        continue
    fi
     
    if [ -d /config/extended/logs/video/complete ]; then
        if [ -f "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId" ]; then
            log "$processCount of $lidarrArtistIdsCount :: $lidarrArtistName :: Music Videos previously downloaded, skipping..."
            continue            
        fi
    fi

    lidarrArtistPath="$(echo "${lidarrArtistData}" | jq -r " .path")"
    lidarrArtistFolder="$(basename "${lidarrArtistPath}")"
    lidarrArtistFolderNoDisambig="$(echo "$lidarrArtistFolder" | sed "s/ (.*)$//g" | sed "s/\.$//g")" # Plex Sanitization, remove disambiguation
    lidarrArtistNameSanitized="$(echo "$lidarrArtistFolderNoDisambig" | sed 's% (.*)$%%g')"
    artistImvdbUrl=$(echo $lidarrArtistData | jq -r '.links[] | select(.name=="imvdb") | .url')
    artistImvdbSlug=$(basename "$artistImvdbUrl")
    
     if [ -z "$artistImvdbUrl" ]; then
	tempmbzartistinfo="$(curl -s -A "$agent" "$musicbrainzMirror/ws/2/artist/$lidarrArtistId?inc=url-rels+genres&fmt=json")"
	sleep 1
	artistImvdbUrl="$(echo "$tempmbzartistinfo" | jq -r ".relations | .[] | .url | select(.resource | contains(\"imvdb\")) | .resource")"
	artistImvdbSlug=$(basename "$artistImvdbUrl")
    fi

    CacheMusicbrainzRecords
    ImvdbCache

    log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: Checking records for videos..."
    musicbrainzArtistVideoRecordings=$(cat "/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json" | jq -r "select(.video==true)")
    musicbrainzArtistVideoRecordingsCount=$(echo "$musicbrainzArtistVideoRecordings" | jq -r .id | wc -l)
    log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: $musicbrainzArtistVideoRecordingsCount videos found..."
    musicbrainzArtistVideoRecordingsDataWithUrl=$(echo "$musicbrainzArtistVideoRecordings" | jq -r "select(.relations[].url)" | jq -s "." | jq -r "unique | .[] | select(.disambiguation | test(\"official\";\"i\"))")
    musicbrainzArtistVideoRecordingsDataWithUrlIds=$(echo "$musicbrainzArtistVideoRecordingsDataWithUrl" | jq -r ".id")
    musicbrainzArtistVideoRecordingsDataWithUrlIdsCount=$(echo -n "$musicbrainzArtistVideoRecordingsDataWithUrlIds" | wc -l)
    log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: $musicbrainzArtistVideoRecordingsDataWithUrlIdsCount \"Official\" videos found with URL..."

    if [ $musicbrainzArtistVideoRecordingsDataWithUrlIdsCount = 0 ]; then
        log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: No vidoes with URLs to process, skipping..."
    else

        for musicbrainzVideoId in $(echo "$musicbrainzArtistVideoRecordingsDataWithUrlIds"); do
            musicbrainzVideoRecordingData=$(echo "$musicbrainzArtistVideoRecordingsDataWithUrl" | jq -r "select(.id==\"$musicbrainzVideoId\")")
            musicbrainzVideoTitle="$(echo "$musicbrainzVideoRecordingData" | jq -r .title)"
            musicbrainzVideoTitleClean="$(echo "$musicbrainzVideoTitle" | sed -e "s/[^[:alpha:][:digit:]$^&_+=()'%;{},.@#]/ /g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
            musicbrainzVideoArtistCredits="$(echo "$musicbrainzVideoRecordingData" |  jq -r ".\"artist-credit\"[]")"
            musicbrainzVideoArtistCreditsNames="$(echo "$musicbrainzVideoArtistCredits" |  jq -r ".artist.name")"
            musicbrainzVideoArtistCreditId="$(echo "$musicbrainzVideoArtistCredits" |  jq -r ".artist.id" | head -n1)"
            musicbrainzVideoDisambiguation=""
            musicbrainzVideoDisambiguation="$(echo "$musicbrainzVideoRecordingData" | jq -r .disambiguation)"
            if [ ! -z "$musicbrainzVideoDisambiguation" ]; then
                musicbrainzVideoDisambiguation=" ($musicbrainzVideoDisambiguation)"
                musicbrainzVideoDisambiguationClean=" ($(echo "$musicbrainzVideoDisambiguation" | sed -e "s%[^[:alpha:][:digit:]]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g'))"
            else
                musicbrainzVideoDisambiguation=""
                musicbrainzVideoDisambiguationClean=""
            fi
            musicbrainzVideoRelations="$(echo "$musicbrainzVideoRecordingData" | jq -r .relations[].url.resource)"

            if [ "$sourcePreference" == "tidal" ]; then
                if echo "$musicbrainzVideoRelations" | grep -i "tidal" | read; then
                    videoDownloadUrl="$(echo "$musicbrainzVideoRelations" | grep -i "tidal" | head -n1)"
                else
                    videoDownloadUrl="$(echo "$musicbrainzVideoRelations" | grep -i "youtube" | head -n1)"
                fi
            else
                videoDownloadUrl="$(echo "$musicbrainzVideoRelations" | grep -i "youtube" | head -n1)"
            fi

            log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: ${musicbrainzVideoTitle}${musicbrainzVideoDisambiguation} :: $videoDownloadUrl..."

            if echo "$musicbrainzVideoDisambiguation" | grep -i "lyric" | read; then
                plexVideoType="-lyrics"
                videoDisambiguationTitle=" (lyric)"
            else
                plexVideoType="-video"
                videoDisambiguationTitle=""
            fi
            if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                if [ -f "$videoPath/$lidarrArtistFolderNoDisambig/${musicbrainzVideoTitleClean}${plexVideoType}.mkv" ]; then
                    log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: ${musicbrainzVideoTitle}${musicbrainzVideoDisambiguation} :: Previously Downloaded, skipping..."
                    continue
                fi
            fi

            if [ "$musicbrainzVideoArtistCreditId" != "$lidarrArtistMusicbrainzId" ]; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: ${musicbrainzVideoTitle}${musicbrainzVideoDisambiguation} :: First artist does not match album arist, skipping..."
                continue
            fi

            if echo "$videoDownloadUrl" | grep -i "tidal" | read; then
                videoId="$(echo "$videoDownloadUrl" | grep -o '[[:digit:]]*')"
                videoData="$(curl -s "https://api.tidal.com/v1/videos/$videoId?countryCode=$tidalCountryCode" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r)"
                videoDate="$(echo "$videoData" | jq -r ".releaseDate")"
                videoYear="${videoDate:0:4}"
                videoImageId="$(echo "$videoData" | jq -r ".imageId")"
                videoImageIdFix="$(echo "$videoImageId" | sed "s/-/\//g")"
                videoThumbnail="https://resources.tidal.com/images/$videoImageIdFix/750x500.jpg"
            fi

            if echo "$videoDownloadUrl" | grep -i "youtube" | read; then

                if [ ! -z "$cookiesFile" ]; then
                    videoData="$(yt-dlp --cookies "$cookiesFile" -j "$videoDownloadUrl")"
                else
                    videoData="$(yt-dlp -j "$videoDownloadUrl")"
                fi
                videoThumbnail="$(echo "$videoData" | jq -r .thumbnail)"
                videoUploadDate="$(echo "$videoData" | jq -r .upload_date)"
                videoYear="${videoUploadDate:0:4}"
            fi

            DownloadVideo "$videoDownloadUrl" "$musicbrainzVideoTitleClean" "$plexVideoType" "MBZDB"
            if [ "$downloadFailed" = "true" ]; then
                log "$processCount of $lidarrArtistIdsCount :: MBZDB :: $lidarrArtistName :: ${musicbrainzVideoTitle}${musicbrainzVideoDisambiguation} :: Download failed, skipping..."
                continue
            fi
            DownloadThumb "$videoThumbnail" "$musicbrainzVideoTitleClean" "$plexVideoType" "MBZDB"
            VideoProcessWithSMA "MBZDB" "$musicbrainzVideoTitle"
            VideoTagProcess "$musicbrainzVideoTitleClean" "$plexVideoType" "$videoYear" "MBZDB"
            VideoNfoWriter "$musicbrainzVideoTitleClean" "$plexVideoType" "$musicbrainzVideoTitle" "" "musicbrainz" "$videoYear" "MBZDB"
                
            if [ ! -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                mkdir -p "$videoPath/$lidarrArtistFolderNoDisambig"
                chmod 777 "$videoPath/$lidarrArtistFolderNoDisambig"
            fi

            mv $downloadPath/incomplete/* "$videoPath/$lidarrArtistFolderNoDisambig"/
        done
    fi

    if [ -z "$artistImvdbSlug" ]; then
        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: No IMVDB artist link found, skipping..."
	# Create log of missing IMVDB url...
	if [ ! -d "/config/extended/logs/video/imvdb-link-missing" ]; then
		mkdir -p "/config/extended/logs/video/imvdb-link-missing"
		chmod 777 "/config/extended/logs/video"
		chmod 777 "/config/extended/logs/video/imvdb-link-missing"
	fi
	if [ -d "/config/extended/logs/video/imvdb-link-missing" ]; then
		log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Logging missing IMVDB artist in folder: /config/extended/logs/video/imvdb-link-missing"
		touch "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}"
	fi       
    else
    	# Remove missing IMVDB log file, now that it is found...
    	if [ -f "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}" ]; then
		rm "/config/extended/logs/video/imvdb-link-missing/${lidarrArtistFolderNoDisambig}--mbid-${lidarrArtistMusicbrainzId}"
	fi
	
        imvdbArtistVideoCount=$(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--*.json 2>/dev/null | wc -l)
        if [ $imvdbArtistVideoCount = 0 ]; then
            log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: No videos found, skipping..."
            
        else

            log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: Processing $imvdbArtistVideoCount Videos!"
            find /config/extended/cache/imvdb -type f -empty -delete # delete empty files
            
            imvdbProcessCount=0
            for imvdbVideoData in $(ls /config/extended/cache/imvdb/$lidarrArtistMusicbrainzId--*.json); do
                imvdbProcessCount=$(( $imvdbProcessCount + 1 ))
                imvdbVideoTitle="$(cat "$imvdbVideoData" | jq -r .song_title)"
                videoTitleClean="$(echo "$imvdbVideoTitle" | sed -e "s/[^[:alpha:][:digit:]$^&_+=()'%;{},.@#]/ /g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
                imvdbVideoYear="$(cat "$imvdbVideoData" | jq -r .year)"
                imvdbVideoImage="$(cat "$imvdbVideoData" | jq -r .image.o)"
                imvdbVideoArtistsSlug="$(cat "$imvdbVideoData" | jq -r .artists[].slug)"
                echo "$lidarrArtistName" > /config/extended/cache/imvdb/$imvdbVideoArtistsSlug
                imvdbVideoFeaturedArtistsSlug="$(cat "$imvdbVideoData" | jq -r .featured_artists[].slug)"
                imvdbVideoYoutubeId="$(cat "$imvdbVideoData" | jq -r ".sources[] | select(.is_primary==true) | select(.source==\"youtube\") | .source_data")"
                #"/config/extended/cache/musicbrainz/$lidarrArtistId--$lidarrArtistMusicbrainzId--recordings.json"
                #echo "$imvdbVideoTitle :: $imvdbVideoYear :: $imvdbVideoYoutubeId :: $imvdbVideoArtistsSlug"
                if [ -z "$imvdbVideoYoutubeId" ]; then
                    continue
                fi
                videoDownloadUrl="https://www.youtube.com/watch?v=$imvdbVideoYoutubeId"
                plexVideoType="-video"
                
                if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                    if [ -f "$videoPath/$lidarrArtistFolderNoDisambig/${videoTitleClean}${plexVideoType}.mkv" ]; then
                        log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: Previously Downloaded, skipping..."
                        continue
                    fi
                fi

                if [ ! -z "$imvdbVideoFeaturedArtistsSlug" ]; then
                    for featuredArtistSlug in $(echo "$imvdbVideoFeaturedArtistsSlug"); do
                        if [ -f /config/extended/cache/imvdb/$featuredArtistSlug ]; then
                            featuredArtistName="$(cat /config/extended/cache/imvdb/$featuredArtistSlug)"
                        else
                            query_data=$(curl -s -A "$agent" "https://musicbrainz.org/ws/2/url?query=url:%22https://imvdb.com/n/$featuredArtistSlug%22&fmt=json")
                            count=$(echo "$query_data" | jq -r ".count")			
                            if [ "$count" != "0" ]; then
                                featuredArtistName="$(echo "$query_data" | jq -r ".urls[].\"relation-list\"[].relations[].artist.name")"
                                echo -n "$featuredArtistName" > /config/extended/cache/imvdb/$featuredArtistSlug
                                sleep 1
                            fi
                        fi
                        find /config/extended/cache/imvdb -type f -empty -delete # delete empty files
                        if [ -z "$featuredArtistName" ]; then
                            continue
                        fi
                    done
                fi

                
                
                if [ ! -z "$cookiesFile" ]; then
                    videoData="$(yt-dlp --cookies "$cookiesFile" -j "$videoDownloadUrl")"
                else
                    videoData="$(yt-dlp -j "$videoDownloadUrl")"
                fi
                
                videoThumbnail="$imvdbVideoImage"   
                videoUploadDate="$(echo "$videoData" | jq -r .upload_date)"
                videoYear="${videoUploadDate:0:4}"
                
                log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: $videoDownloadUrl..."
                DownloadVideo "$videoDownloadUrl" "$videoTitleClean" "$plexVideoType" "IMVDB"
                if [ "$downloadFailed" = "true" ]; then
                    log "$processCount of $lidarrArtistIdsCount :: IMVDB :: $lidarrArtistName :: ${imvdbVideoTitle} :: Download failed, skipping..."
                    continue
                fi
                DownloadThumb "$imvdbVideoImage" "$videoTitleClean" "$plexVideoType" "IMVDB"
                VideoProcessWithSMA "IMVDB" "$imvdbVideoTitle" 
                VideoTagProcess "$videoTitleClean" "$plexVideoType" "$videoYear" "IMVDB"
                VideoNfoWriter "$videoTitleClean" "$plexVideoType" "$imvdbVideoTitle" "" "imvdb" "$videoYear" "IMVDB"
                    
                if [ ! -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
                    mkdir -p "$videoPath/$lidarrArtistFolderNoDisambig"
                    chmod 777 "$videoPath/$lidarrArtistFolderNoDisambig"
                fi 

                mv $downloadPath/incomplete/* "$videoPath/$lidarrArtistFolderNoDisambig"/
            done

        fi

    fi

    if [ ! -d /config/extended/logs/video ]; then
        mkdir -p /config/extended/logs/video
        chmod 777 /config/extended/logs/video
    fi

    if [ ! -d /config/extended/logs/video/complete ]; then
        mkdir -p /config/extended/logs/video/complete 
        chmod 777 /config/extended/logs/video/complete 
    fi

    touch "/config/extended/logs/video/complete/$lidarrArtistMusicbrainzId"

    # Import Artist.nfo file
    if [ -d "$lidarrArtistPath" ]; then
        if [ -d "$videoPath/$lidarrArtistFolderNoDisambig" ]; then
            if [ -f "$lidarrArtistPath/artist.nfo" ]; then
                if [ ! -f "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo" ]; then
                    log "$processCount of $lidarrArtistIdsCount :: Copying Artist NFO to music-video artist directory"
                    cp "$lidarrArtistPath/artist.nfo" "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo"
                    chmod 666 "$videoPath/$lidarrArtistFolderNoDisambig/artist.nfo"
                fi
            fi
        fi
    fi
done

#CacheMusicbrainzRecords
#ImvdbCache

exit

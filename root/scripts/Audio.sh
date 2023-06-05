#!/usr/bin/env bash
scriptVersion="1.0.9"
if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" == "null" ]; then
		lidarrUrlBase=""
	else
		lidarrUrlBase="/$(echo "$lidarrUrlBase" | sed "s/\///g")"
	fi
	lidarrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
	lidarrAgentInstanceId="$(echo "$lidarrApiKey" | cut -c1-10)"
	lidarrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
	lidarrUrl="http://localhost:${lidarrPort}${lidarrUrlBase}"
fi

# Debugging settings
#dlClientSource="tidal"
#topLimit="3"
#addDeezerTopArtists="true"
#addDeezerTopAlbumArtists="true"
#addDeezerTopTrackArtists="true"
#audioFormat="aac"
#audioBitrate="160"
#addRelatedArtists="true"
#numberOfRelatedArtistsToAddPerArtist="1"
#beetsMatchPercentage="90"
#requireQuality="true"
#searchSort="album"
#arlToken=""
#matchDistance=10
#enableBeetsTagging=true

sleepTimer=0.5
tidaldlFail=0
deemixFail=0

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Audio :: $scriptVersion :: "$1
}

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/Audio.txt" ]; then
	find /config/logs -type f -name "Audio.txt" -size +5000k -delete
	sleep 0.01
fi
touch "/config/logs/Audio.txt"
exec &> >(tee -a "/config/logs/Audio.txt")
chmod 666 "/config/logs/Audio.txt"

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
	processdownloadid="$(ps -A -o pid,cmd|grep "Audio.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
	log "To kill script, use the following command:"
	log "kill -9 $processdownloadid"
	sleep 2
	
	if [ -z $topLimit ]; then
		topLimit=10
	fi

	verifyApiAccess

	if [ "$addDeezerTopArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Artists is enabled"
	else
		log "Add Deezer Top Artists is disabled (enable by setting addDeezerTopArtists=true)"
	fi

	if [ "$addDeezerTopAlbumArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Album Artists is enabled"
	else
		log "Add Deezer Top Album Artists is disabled (enable by setting addDeezerTopAlbumArtists=true)"
	fi

	if [ "$addDeezerTopTrackArtists" == "true" ]; then
		log "Add Deezer Top $topLimit Track Artists is enabled"
	else
		log "Add Deezer Top Track Artists is disabled (enable by setting addDeezerTopTrackArtists=true)"
	fi

	if [ "$addRelatedArtists" == "true" ]; then
		log "Add Deezer Related Artists is enabled"
		log "Add $numberOfRelatedArtistsToAddPerArtist Deezer related Artist for each Lidarr Artist"
	else
		log "Add Deezer Related Artists is disabled (enable by setting addRelatedArtists=true)"
	fi
	
	log "Download Location: $downloadPath"


	log "Output format: $audioFormat"

	if [ "$audioFormat" != "native" ]; then 
		if [ "$audioFormat" == "alac" ]; then
			audioBitrateText="LOSSLESS"
		else
			audioBitrateText="${audioBitrate}k"
		fi
	fi

	log "Output bitrate: $audioBitrateText"

	if [ "$requireQuality" == "true" ]; then
		log "Download Quality Check Enabled"
	else
		log "Download Quality Check Disabled (enable by setting: requireQuality=true"
	fi

	if [ "$audioLyricType" == "both" ] || [ "$audioLyricType" == "explicit" ] || [ "$audioLyricType" == "explicit" ]; then
		log "Preferred audio lyric type: $audioLyricType"
	fi
	log "Tidal Country Code set to: $tidalCountryCode"

	if [ "$enableReplaygainTags" == "true" ]; then
		log "Replaygain Tagging Enabled"
	else
		log "Replaygain Tagging Disabled"
	fi

	log "Match Distance: $matchDistance"

	if [ $enableBeetsTagging = true ]; then
		log "Beets Tagging Enabled"
		log "Beets Matching Threshold ${beetsMatchPercentage}%"
		beetsMatchPercentage=$(expr 100 - $beetsMatchPercentage )
		if cat /config/extended/scripts/beets-config.yaml | grep "strong_rec_thresh: 0.04" | read; then
			log "Configuring Beets Matching Threshold"
			sed -i "s/strong_rec_thresh: 0.04/strong_rec_thresh: 0.${beetsMatchPercentage}/g" /config/extended/scripts/beets-config.yaml
		fi
	else
		log "Beets Tagging Disabled"
	fi
	
}

DownloadFormat () {

	if [ "$audioFormat" == "native" ]; then
		if [ "$audioBitrate" == "master" ]; then
			tidalQuality=Master
			deemixQuality=flac
		elif [ "$audioBitrate" == "lossless" ]; then
			tidalQuality=HiFi
			deemixQuality=flac
		elif [ "$audioBitrate" == "high" ]; then
			tidalQuality=High
			deemixQuality=320
		elif [ "$audioBitrate" == "low" ]; then
			tidalQuality=128
			deemixQuality=128
		else
			log "ERROR :: Invalid audioFormat and audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a low, high, or lossless..."
			log "ERROR :: Exiting..."
			NotifyWebhook "FatalError" "Invalid audioFormat and audioBitrate options set"
			exit
		fi
	else
		bitrateError="false"
		audioFormatError="false"
		tidalQuality=HiFi
		deemixQuality=flac

		case "$audioBitrate" in
			lossless | high | low)
				bitrateError="true"
				;;
			*)
				bitrateError="false"
				;;
		esac

		if [ "$bitrateError" == "true" ]; then
			log "ERROR :: Invalid audioBitrate options set..."
			log "ERROR :: Change audioBitrate to a desired bitrate number, example: 192..."
			log "ERROR :: Exiting..."
			NotifyWebhook "FatalError" "audioBitrate options set"
			exit
		fi

		case "$audioFormat" in
			mp3 | alac | opus | aac)
				audioFormatError="false"
				;;
			*)
				audioFormatError="true"
				;;
		esac

		if [ "$audioFormatError" == "true" ]; then		
			log "ERROR :: Invalid audioFormat options set..."
			log "ERROR :: Change audioFormat to a desired format (opus or mp3 or aac or alac)"
			NotifyWebhook "FatalError" "audioFormat options set"
			exit
		fi

		tidal-dl -q HiFi
		deemixQuality=flac
		bitrateError=""
		audioFormatError=""
	fi
}

DownloadFolderCleaner () {
	# check for completed download folder
	if [ -d "$downloadPath/complete" ]; then
		log "Removing prevously completed downloads that failed to import..."
		# check for completed downloads older than 1 day
		if find "$downloadPath"/complete -mindepth 1 -type d -mtime +1 | read; then
			# delete completed downloads older than 1 day, these most likely failed to import due to Lidarr failing to match
			find "$downloadPath"/complete -mindepth 1 -type d -mtime +1 -exec rm -rf "{}" \; &>/dev/null
		fi
	fi
}

NotFoundFolderCleaner () {
	# check for completed download folder
	if [ -d /config/extended/logs/notfound ]; then
		# check for notfound entries older than X days
		if find /config/extended/logs/notfound -mindepth 1 -type f -mtime +$retryNotFound | read; then
			log "Removing prevously notfound lidarr album ids older than $retryNotFound days to give them a retry..."
			# delete ntofound entries older than X days
			find /config/extended/logs/notfound -mindepth 1 -type f -mtime +$retryNotFound -delete
		fi
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
	tidal-dl -o "$downloadPath"/incomplete
	DownloadFormat

	if [ ! -f /config/xdg/.tidal-dl.token.json ]; then
		TidaldlStatusCheck
		#log "TIDAL :: ERROR :: Downgrade tidal-dl for workaround..."
		#pip3 install tidal-dl==2022.3.4.2 --no-cache-dir &>/dev/null
		log "TIDAL :: ERROR :: Loading client for required authentication, please authenticate, then exit the client..."
		NotifyWebhook "FatalError" "TIDAL requires authentication, please authenticate now (check logs)"
		TidaldlStatusCheck
		tidal-dl
	fi

	if [ ! -d /config/extended/cache/tidal ]; then
		mkdir -p /config/extended/cache/tidal
		chmod 777 /config/extended/cache/tidal
	fi
	
	if [ -d /config/extended/cache/tidal ]; then
		log "TIDAL :: Purging album list cache..."
		rm /config/extended/cache/tidal/*-albums.json &>/dev/null
	fi
	
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p "$downloadPath"/incomplete
		chmod 777 "$downloadPath"/incomplete
	else
		rm -rf "$downloadPath"/incomplete/*
	fi
	
	TidaldlStatusCheck
	#log "TIDAL :: Upgrade tidal-dl to newer version..."
	#pip3 install tidal-dl==2022.07.06.1 --no-cache-dir &>/dev/null
	
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
		mkdir -p "$downloadPath"/incomplete
		chmod 777 "$downloadPath"/incomplete
	else
		rm -rf "$downloadPath"/incomplete/*
	fi
	
	if [ ! -d "$downloadPath/complete" ]; then
		mkdir -p "$downloadPath"/complete
		chmod 777 "$downloadPath"/complete
	else
		rm -rf "$downloadPath"/complete/*
	fi

	if [ ! -d "/config/extended/logs" ]; then
		mkdir -p /config/extended/logs
		chmod 777 /config/extended/logs
	fi

	if [ ! -d "/config/extended/logs/downloaded" ]; then
		mkdir -p /config/extended/logs/downloaded
		chmod 777 /config/extended/logs/downloaded
	fi

	if [ ! -d "/config/extended/logs/downloaded/deezer" ]; then
		mkdir -p /config/extended/logs/downloaded/deezer
		chmod 777 /config/extended/logs/downloaded/deezer
	fi

	if [ ! -d "/config/extended/logs/downloaded/tidal" ]; then
		mkdir -p /config/extended/logs/downloaded/tidal
		chmod 777 /config/extended/logs/downloaded/tidal
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/deezer ]; then
		mkdir -p /config/extended/logs/downloaded/failed/deezer
		chmod 777 /config/extended/logs/downloaded/failed/deezer
	fi

	if [ ! -d /config/extended/logs/downloaded/failed/tidal ]; then
		mkdir -p /config/extended/logs/downloaded/failed/tidal
		chmod 777 /config/extended/logs/downloaded/failed/tidal
	fi

	downloadedAlbumTitleClean="$(echo "$4" | sed -e "s%[^[:alpha:][:digit:]._' ]% %g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
    	
	if find "$downloadPath"/complete -type d -iname "$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-*-$1-$2" | read; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded..."
		return
    fi

	# check for log file
	if [ "$2" == "DEEZER" ]; then
		if [ -f /config/extended/logs/downloaded/deezer/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/deezer/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
			return
		fi
	fi

	# check for log file
	if [ "$2" == "TIDAL" ]; then
		if [ -f /config/extended/logs/downloaded/tidal/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Downloaded ($1)..."
			return
		fi
		if [ -f /config/extended/logs/downloaded/failed/tidal/$1 ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Previously Attempted Download ($1)..."
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

		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Download Attempt number $downloadTry"
		if [ "$2" == "DEEZER" ]; then
			
			deemix -b $deemixQuality -p "$downloadPath"/incomplete "https://www.deezer.com/album/$1"
			
			if [ -d "/tmp/deemix-imgs" ]; then
				rm -rf /tmp/deemix-imgs
			fi

			# Verify Client Works...
			clientTestDlCount=$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
			if [ $clientTestDlCount -le 0 ]; then
				# Add +1 to failed attempts
				deemixFail=$(( $deemixFail + 1))
			else
				# Reset for successful download
				deemixFail=0
			fi
			
			# If download failes 6 times, exit with error...
			if [ $deemixFail -eq 6 ]; then
				log "DEEZER :: ERROR :: Download failed"
				log "DEEZER :: ERROR :: Please review log for errors in client"
				log "DEEZER :: ERROR :: Try updating your ARL Token to possibly resolve the issue..."
				log "DEEZER :: ERROR :: Exiting..."
				rm -rf "$downloadPath"/incomplete/*
				NotifyWebhook "FatalError" "DEEZER not authenticated but configured"
				exit
			fi
		fi

		if [ "$2" == "TIDAL" ]; then
			TidaldlStatusCheck

			tidal-dl -q $tidalQuality -o "$downloadPath/incomplete" -l "$1"

			# Verify Client Works...
			clientTestDlCount=$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | wc -l)
			if [ $clientTestDlCount -le 0 ]; then
				# Add +1 to failed attempts
				tidaldlFail=$(( $tidaldlFail + 1))
			else
				# Reset for successful download
				tidaldlFail=0
			fi
			
			# If download failes 6 times, exit with error...
			if [ $tidaldlFail -eq 6 ]; then
				if [ -f /config/xdg/.tidal-dl.token.json ]; then
					rm /config/xdg/.tidal-dl.token.json
				fi
				log "TIDAL :: ERROR :: Download failed"
				log "TIDAL :: ERROR :: You will need to re-authenticate on next script run..."
				log "TIDAL :: ERROR :: Exiting..."
				rm -rf "$downloadPath"/incomplete/*
				NotifyWebhook "FatalError" "TIDAL not authenticated but configured"
				exit
			fi
		fi

		find "$downloadPath/incomplete" -type f -iname "*.flac" -newer "/temp-download" -print0 | while IFS= read -r -d '' file; do
			audioFlacVerification "$file"
			if [ "$verifiedFlacFile" == "0" ]; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: Verified"
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Flac Verification :: $file :: ERROR :: Failed Verification"
				rm "$file"
			fi
		done

		downloadCount=$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
		if [ "$downloadCount" -ne "$5" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: download failed, missing tracks..."
			completedVerification="false"
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Success"
			completedVerification="true"
		fi

		if [ "$completedVerification" == "true" ]; then
			break
		elif [ "$downloadTry" == "2" ]; then
			if [ -d "$downloadPath"/incomplete ]; then
				rm -rf "$downloadPath"/incomplete/*
			fi
			break
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Retry Download in 1 second fix errors..."
			sleep 1
		fi
	done   

	# Consolidate files to a single folder
	if [ "$2" == "TIDAL" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Consolidating files to single folder"
		find "$downloadPath/incomplete" -type f -exec mv "{}" "$downloadPath"/incomplete/ \;
		if [ -d "$downloadPath"/incomplete/atd ]; then
			rm -rf "$downloadPath"/incomplete/atd
		fi
	fi

	downloadCount=$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
	if [ "$downloadCount" -gt "0" ]; then
		# Check download for required quality (checks based on file extension)
		DownloadQualityCheck "$downloadPath/incomplete" "$2"
	fi
	
	downloadCount=$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|m4a\|mp3\)" | wc -l)
	if [ "$downloadCount" -ne "$5" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: All download Attempts failed..."
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as failed download..."


		if [ "$2" == "DEEZER" ]; then
			touch /config/extended/logs/downloaded/failed/deezer/$1
		fi
		if [ "$2" == "TIDAL" ]; then
			touch /config/extended/logs/downloaded/failed/tidal/$1
		fi
		return
	fi

	# Log Completed Download
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Logging $1 as successfully downloaded..."
	if [ "$2" == "DEEZER" ]; then
		touch /config/extended/logs/downloaded/deezer/$1
	fi
	if [ "$2" == "TIDAL" ]; then
		touch /config/extended/logs/downloaded/tidal/$1
	fi

	# Correct Artist/albumartist Flac files
	find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Setting ARTIST/ALBUMARTIST tag to \"$lidarrArtistName\" :: $file"
		metaflac --remove-tag=ALBUMARTIST "$file"
		metaflac --remove-tag=ARTIST "$file"
		metaflac --remove-tag=MUSICBRAINZ_ARTISTID "$file"
		metaflac --remove-tag=MUSICBRAINZ_ALBUMARTISTID "$file"
		metaflac --remove-tag=ALBUM "$file"
		metaflac --remove-tag=MUSICBRAINZ_ALBUMID "$file"
		metaflac --set-tag=ALBUMARTIST="$lidarrArtistName" "$file"
		metaflac --set-tag=ARTIST="$lidarrArtistName" "$file"
		metaflac --set-tag=MUSICBRAINZ_ARTISTID="$lidarrArtistForeignArtistId" "$file"
		metaflac --set-tag=MUSICBRAINZ_ALBUMARTISTID="$lidarrArtistForeignArtistId" "$file"
		metaflac --set-tag=ALBUM="$lidarrAlbumTitle" "$file"
		metaflac --set-tag=MUSICBRAINZ_ALBUMID="$lidarrAlbumForeignAlbumId" "$file"
	done

	# Tag with beets
	if [ "$enableBeetsTagging" == "true" ]; then
		if [ -f /config/extended/beets-error ]; then
			rm /config/extended/beets-error
		fi
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Processing files with beets..."
		ProcessWithBeets "$downloadPath/incomplete"

		if [ -f /config/extended/beets-error ]; then
			return
		fi 
	fi

	# Embed Lyrics into Flac files
	find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
		lrcFile="${file%.*}.lrc"
		if [ -f "$lrcFile" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Embedding lyrics (lrc) into $file"
			metaflac --remove-tag=Lyrics "$file"
			metaflac --set-tag-from-file="Lyrics=$lrcFile" "$file"
			rm "$lrcFile"
		fi
	done
	
	if [ "$audioFormat" != "native" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Converting Flac Audio to  ${audioFormat^^} ($audioBitrateText)"
		if [ "$audioFormat" == "opus" ]; then
			options="-c:a libopus -b:a ${audioBitrate}k -application audio -vbr off"
		    extension="opus"
		fi

		if [ "$audioFormat" == "mp3" ]; then
			options="-c:a libmp3lame -b:a ${audioBitrate}k"
			extension="mp3"
		fi

		if [ "$audioFormat" == "aac" ]; then
			options="-c:a aac -b:a ${audioBitrate}k -movflags faststart"
			extension="m4a"
		fi

		if [ "$audioFormat" == "alac" ]; then
			options="-c:a alac -movflags faststart"
			extension="m4a"
		fi

		find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' audio; do
			file="${audio}"
			filename="$(basename "$audio")"
			foldername="$(dirname "$audio")"
        	filenamenoext="${filename%.*}"
			if [ "$audioFormat" == "opus" ]; then
				if opusenc --bitrate ${audioBitrate} --vbr --music "$file" "$foldername/${filenamenoext}.$extension"; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: Conversion to $audioFormat ($audioBitrateText) successful"
					rm "$file"
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: ERROR :: Conversion Failed"
					rm "$foldername/${filenamenoext}.$extension"
				fi
				continue
			fi
			
			if ffmpeg -loglevel warning -hide_banner -nostats -i "$file" -n -vn $options "$foldername/${filenamenoext}.$extension" < /dev/null; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: Conversion to $audioFormat ($audioBitrateText) successful"
				rm "$file"
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $filename :: ERROR :: Conversion Failed"
				rm "$foldername/${filenamenoext}.$extension"
			fi
		done

	fi
	
	if [ "$enableReplaygainTags" == "true" ]; then
		AddReplaygainTags "$downloadPath/incomplete"
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Replaygain Tagging Disabled (set enableReplaygainTags=true to enable...)"
	fi
	
	albumquality="$(find "$downloadPath"/incomplete/ -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n 1 | egrep -i -E -o "\.{1}\w*$" | sed  's/\.//g')"
	downloadedAlbumFolder="$lidarrArtistNameSanitized-$downloadedAlbumTitleClean ($3)-${albumquality^^}-$1-$2"

	find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -print0 | while IFS= read -r -d '' audio; do
        file="${audio}"
        filenoext="${file%.*}"
        filename="$(basename "$audio")"
        extension="${filename##*.}"
        filenamenoext="${filename%.*}"
        if [ ! -d "$downloadPath/complete" ]; then
            mkdir -p "$downloadPath"/complete
            chmod 777 "$downloadPath"/complete
        fi
        mkdir -p "$downloadPath/complete/$downloadedAlbumFolder"
        mv "$file" "$downloadPath/complete/$downloadedAlbumFolder"/
        
    done
	chmod -R 777 "$downloadPath"/complete
	
	if [ -d "$downloadPath/complete/$downloadedAlbumFolder" ]; then
		NotifyLidarrForImport "$downloadPath/complete/$downloadedAlbumFolder"
		
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			rm -rf "$downloadPath"/incomplete/*
		fi
	fi
	
	if [ -d "$downloadPath/complete/$downloadedAlbumFolder" ]; then
		NotifyLidarrForImport "$downloadPath/complete/$downloadedAlbumFolder"
		
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			rm -rf "$downloadPath"/incomplete/*
		fi
	fi
	
	if [ -d "$downloadPath/complete/$downloadedAlbumFolder" ]; then
		NotifyLidarrForImport "$downloadPath/complete/$downloadedAlbumFolder"
		
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			rm -rf "$downloadPath"/incomplete/*
		fi
	fi

	if [ -d "$downloadPath/complete/$downloadedAlbumFolder" ]; then
		rm -rf "$downloadPath"/incomplete/*
	fi
	# NotifyPlexToScan
}

ProcessWithBeets () {
	# Input
	# $1 Download Folder to process
	if [ -f /config/extended/beets-library.blb ]; then
		rm /config/extended/beets-library.blb
		sleep 0.5
	fi
	if [ -f /config/extended/logs/beets.log ]; then 
		rm /config/extended/logs/beets.log
		sleep 0.5
	fi

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.5
	fi
	touch "/config/beets-match"
	sleep 0.5

	beet -c /config/extended/scripts/beets-config.yaml -l /config/extended/beets-library.blb -d "$1" import -qC "$1"
	if [ $(find "$1" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" -newer "/config/beets-match" | wc -l) -gt 0 ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: SUCCESS: Matched with beets!"
		find "$downloadPath/incomplete" -type f -iname "*.flac" -print0 | while IFS= read -r -d '' file; do
			getArtistCredit="$(ffprobe -loglevel 0 -print_format json -show_format -show_streams "$file" | jq -r ".format.tags.ARTIST_CREDIT" | sed "s/null//g" | sed "/^$/d")"
			metaflac --remove-tag=ALBUMARTIST "$file"
			metaflac --remove-tag=ALBUMARTIST_CREDIT "$file"
			metaflac --remove-tag=ALBUMARTISTSORT "$file"
			metaflac --remove-tag=ALBUM_ARTIST "$file"
			metaflac --remove-tag="ALBUM ARTIST" "$file"
			metaflac --remove-tag=ARTISTSORT "$file"
			metaflac --remove-tag=ARTIST "$file"
			metaflac --remove-tag=MUSICBRAINZ_ARTISTID "$file"
			metaflac --remove-tag=MUSICBRAINZ_ALBUMARTISTID "$file"
			metaflac --remove-tag=ALBUM "$file"
			metaflac --remove-tag=MUSICBRAINZ_ALBUMID "$file"
			metaflac --set-tag=ARTIST="$lidarrArtistName" "$file"
			metaflac --set-tag=ALBUMARTIST="$lidarrArtistName" "$file"
			metaflac --set-tag=MUSICBRAINZ_ARTISTID="$lidarrArtistForeignArtistId" "$file"
			metaflac --set-tag=MUSICBRAINZ_ALBUMARTISTID="$lidarrArtistForeignArtistId" "$file"
			metaflac --set-tag=ALBUM="$lidarrAlbumTitle" "$file"
			metaflac --set-tag=MUSICBRAINZ_ALBUMID="$lidarrAlbumForeignAlbumId" "$file"
		done
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Unable to match using beets to a musicbrainz release..."
		return
	fi	

	if [ -f "/config/beets-match" ]; then 
		rm "/config/beets-match"
		sleep 0.1
	fi

	# Get file metadata
	GetFile=$(find "$downloadPath/incomplete" -type f -regex ".*/.*\.\(flac\|opus\|m4a\|mp3\)" | head -n1)
	extension="${GetFile##*.}"
	if [ "$extension" == "opus" ]; then
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".streams[].tags")
	else
		matchedTags=$(ffprobe -hide_banner -loglevel fatal -show_error -show_format -show_streams -show_programs -show_chapters -show_private_data -print_format json "$GetFile" | jq -r ".format.tags")
	fi

	# Get Musicbrainz Release Group ID and Album Artist ID from tagged file
	if [ "$extension" == "flac" ] || [ "$extension" == "opus" ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_RELEASEGROUPID")"
		matchedTagsAlbumArtistId="$(echo $matchedTags | jq -r ".MUSICBRAINZ_ALBUMARTISTID")"
	elif [ "$extension" == "mp3" ] || [ "$extension" == "m4a" ]; then
		matchedTagsAlbumReleaseGroupId="$(echo $matchedTags | jq -r '."MusicBrainz Release Group Id"')"
		matchedLidarrAlbumArtistId="$(echo $matchedTags | jq -r '."MusicBrainz Ablum Artist Id"')"
	fi

	if [ ! -d "/config/extended/logs/downloaded/musicbrainz_matched" ]; then
		mkdir -p "/config/extended/logs/downloaded/musicbrainz_matched"
		chmod 777 "/config/extended/logs/downloaded/musicbrainz_matched"
	fi	

	if [ ! -f "/config/extended/logs/downloaded/musicbrainz_matched/$matchedTagsAlbumReleaseGroupId" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Marking MusicBrainz Release Group ($matchedTagsAlbumReleaseGroupId) as succesfully downloaded..."
		touch "/config/extended/logs/downloaded/musicbrainz_matched/$matchedTagsAlbumReleaseGroupId"

	fi

	getLidarrAlbumId=$(curl -s "$lidarrUrl/api/v1/search?term=lidarr%3A${matchedTagsAlbumReleaseGroupId}&apikey=$lidarrApiKey" | jq -r .[].album.releases[].albumId | sort -u)
	checkLidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$getLidarrAlbumId?apikey=${lidarrApiKey}")"
	checkLidarrAlbumPercentOfTracks=$(echo "$checkLidarrAlbumData" | jq -r ".statistics.percentOfTracks")

	if [ "$checkLidarrAlbumPercentOfTracks" = "null" ]; then
		checkLidarrAlbumPercentOfTracks=0
		return
	fi

	if [ ${checkLidarrAlbumPercentOfTracks%%.*} -ge 100 ]; then
		if [ "$wantedAlbumListSource" == "missing" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: ERROR :: Already Imported Album (Missing)"
			rm -rf "$downloadPath/incomplete"/*
			touch /config/extended/beets-error
			return
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Importing Album (Cutoff)"
			return
		fi
	fi
	
	
}

DownloadQualityCheck () {

	if [ "$requireQuality" == "true" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Checking for unwanted files"

		if [ "$audioFormat" != "native" ]; then
			if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
				rm "$1"/*
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
			fi
		fi
		if [ "$audioFormat" == "native" ]; then
			if [ "$audioBitrate" == "master" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$audioBitrate" == "lossless" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$2" == "DEEZER" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|m4a\|flac\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			elif [ "$2" == "TIDAL" ]; then
				if find "$1" -type f -regex ".*/.*\.\(opus\|flac\|mp3\)"| read; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Unwanted files found!"
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Performing cleanup..."
					rm "$1"/*
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: No unwanted files found!"
				fi
			fi
		fi
	else
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType ::  Skipping download quality check... (enable by setting: requireQuality=true)"
	fi
}

AddReplaygainTags () {
	# Input Data
	# $1 Folder path to scan and add tags
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Adding Replaygain Tags using r128gain"
	r128gain -r -c 1 -a "$1" &>/dev/null
}

NotifyLidarrForImport () {
	LidarrProcessIt=$(curl -s "$lidarrUrl/api/v1/command" --header "X-Api-Key:"${lidarrApiKey} -H "Content-Type: application/json" --data "{\"name\":\"DownloadedAlbumsScan\", \"path\":\"$1\"}")
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: LIDARR IMPORT NOTIFICATION SENT! :: $1"
}

NotifyPlexToScan () {
	LidarrTaskStatusCheck
	CheckLidarrBeforeImport "$checkLidarrAlbumId"
	if [ "$alreadyImported" == "true" ]; then
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Notifying Plex to Scan :: $lidarrArtistPath"
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
		rm /config/extended/cache/deezer/*-albums.json &>/dev/null
	fi
	
	if [ ! -d "$downloadPath/incomplete" ]; then
		mkdir -p "$downloadPath"/incomplete
		chmod 777 "$downloadPath"/incomplete
	else
		rm -rf "$downloadPath"/incomplete/*
	fi

	#log "DEEZER :: Upgrade deemix to the latest..."
	#pip install deemix --upgrade &>/dev/null

}

LidarrRootFolderCheck () {
	if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
		log "ERROR :: No root folder found"
		log "ERROR :: Configure root folder in Lidarr to continue..."
		log "ERROR :: Exiting..."
		NotifyWebhook "FatalError" "No root folder found"
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
	fi
	
	# Configure searchSort preferences based on settings
	if [ "$searchSort" == "date" ]; then
		searchOrder="releaseDate"
		searchDirection="descending"
	fi
	
	if [ "$searchSort" == "album" ]; then
		searchOrder="albumType"
		searchDirection="ascending"
	fi

	lidarrMissingTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r .totalRecords)

	log "FINDING MISSING ALBUMS :: sorted by $searchSort"

	amountPerPull=1000
	page=0
	log "$lidarrMissingTotalRecords Missing Albums Found!"
	log "Getting Missing Album IDs"
	if [ $lidarrMissingTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrMissingTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ "$dlnumber" -gt "$lidarrMissingTotalRecords" ]; then
				dlnumber="$lidarrMissingTotalRecords"
			fi
			log "$page :: missing :: Downloading page $page... ($offset - $dlnumber of $lidarrMissingTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/missing?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			log "$page :: missing :: Filtering Album IDs by removing previously searched Album IDs (/config/extended/logs/notfound/<files>)"
			for lidarrRecordId in $(echo $lidarrRecords); do
				if [ ! -f /config/extended/logs/notfound/$lidarrRecordId--* ]; then
					touch "/config/extended/cache/lidarr/list/${lidarrRecordId}-missing"
				fi
			done
			
			lidarrMissingRecords=$(ls /config/extended/cache/lidarr/list 2>/dev/null | wc -l)
			log "$page :: missing :: ${lidarrMissingRecords} albums found to process!"
			wantedListAlbumTotal=$lidarrMissingRecords

			if [ ${lidarrMissingRecords} -gt 0 ]; then
				log "$page :: missing :: Searching for $wantedListAlbumTotal items"
				SearchProcess
				rm /config/extended/cache/lidarr/list/*-missing
			fi
		done
	fi
	

	# Get cutoff album list
	lidarrCutoffTotalRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=1&pagesize=1&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r .totalRecords)
	log "FINDING CUTOFF ALBUMS sorted by $searchSort"
	log "$lidarrCutoffTotalRecords CutOff Albums Found Found!"
	log "Getting CutOff Album IDs"
	page=0
	if [ $lidarrCutoffTotalRecords -ge 1 ]; then
		offsetcount=$(( $lidarrCutoffTotalRecords / $amountPerPull ))
		for ((i=0;i<=$offsetcount;i++)); do
			page=$(( $i + 1 ))
			offset=$(( $i * $amountPerPull ))
			dlnumber=$(( $offset + $amountPerPull ))
			if [ "$dlnumber" -gt "$lidarrCutoffTotalRecords" ]; then
				dlnumber="$lidarrCutoffTotalRecords"
			fi

			log "$page :: cutoff :: Downloading page $page... ($offset - $dlnumber of $lidarrCutoffTotalRecords Results)"
			lidarrRecords=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/wanted/cutoff?page=$page&pagesize=$amountPerPull&sortKey=$searchOrder&sortDirection=$searchDirection&apikey=${lidarrApiKey}" | jq -r '.records[].id')
			log "$page :: cutoff :: Filtering Album IDs by removing previously searched Album IDs (/config/extended/logs/notfound/<files>)"
			
			for lidarrRecordId in $(echo $lidarrRecords); do
				if [ ! -f /config/extended/logs/notfound/$lidarrRecordId--* ]; then
					touch /config/extended/cache/lidarr/list/${lidarrRecordId}-cutoff
				fi
			done

			lidarrCutoffRecords=$(ls /config/extended/cache/lidarr/list/*-cutoff 2>/dev/null | wc -l)
			log "$page :: cutoff :: ${lidarrCutoffRecords} ablums found to process!"
			wantedListAlbumTotal=$lidarrCutoffRecords

			if [ ${lidarrCutoffRecords} -gt 0 ]; then
				log "$page :: cutoff :: Searching for $wantedListAlbumTotal items"
				SearchProcess
				rm /config/extended/cache/lidarr/list/*-cutoff
			fi

		done
	fi    
}

SearchProcess () {

	if [ "$wantedListAlbumTotal" == "0" ]; then
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
		lidarrArtistName=$(echo "${lidarrArtistData}" | jq -r ".artistName")
		lidarrArtistForeignArtistId=$(echo "${lidarrArtistData}" | jq -r ".foreignArtistId")
		lidarrAlbumType=$(echo "$lidarrAlbumData" | jq -r ".albumType")
		lidarrAlbumTitle=$(echo "$lidarrAlbumData" | jq -r ".title")
		lidarrAlbumForeignAlbumId=$(echo "$lidarrAlbumData" | jq -r ".foreignAlbumId")
		
		LidarrTaskStatusCheck
				
		if [ -f "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $wantedAlbumListSource :: $lidarrAlbumType :: $wantedAlbumListSource :: $lidarrArtistName :: $lidarrAlbumTitle :: Previously Not Found, skipping..."
			continue
		fi

		if [ "$enableVideoScript" == "true" ]; then
			# Skip Video Check for Various Artists album searches because videos are not supported...
			if [ "$lidarrArtistForeignArtistId" != "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
				if [ -d /config/extended/logs/video/complete ]; then
					if [ ! -f "/config/extended/logs/video/complete/$lidarrArtistForeignArtistId" ]; then
						log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumType :: $wantedAlbumListSource :: $lidarrArtistName :: $lidarrAlbumTitle :: Skipping until all videos are processed for the artist..."
						continue
					fi
				else
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumType :: $wantedAlbumListSource :: $lidarrArtistName :: $lidarrAlbumTitle :: Skipping until all videos are processed for the artist..."
					continue
				fi
			fi
		fi
		
		if [ -f "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrAlbumTitle :: $lidarrAlbumType :: Previously Not Found, skipping..."
			rm "/config/extended/logs/downloaded/notfound/$lidarrAlbumForeignAlbumId"
			touch "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			chmod 777 "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
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
		lidarrArtistNameSanitized="$(basename "${lidarrArtistPath}" | sed 's% (.*)$%%g' | sed 's/-/ /g')"
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

		

		if [[ ${currentDateClean} -ge ${lidarrAlbumReleaseDateClean} ]]; then
			skipNotFoundLogCreation="false"
			releaseDateComparisonInDays=$(( ${currentDateClean} - ${lidarrAlbumReleaseDateClean} ))
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Starting Search..."
			if [ $releaseDateComparisonInDays -lt 8 ]; then
				skipNotFoundLogCreation="true"
			fi
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album ($lidarrAlbumReleaseDate) has not been released, skipping..."
			continue
		fi

		if [ "$dlClientSource" == "deezer" ]; then
			skipTidal=true
			skipDeezer=false
		fi

		if [ "$dlClientSource" == "tidal" ]; then
			skipDeezer=true
			skipTidal=false
		fi

		if [ "$dlClientSource" == "both" ]; then
			skipDeezer=false
			skipTidal=false
		fi	

		if [ "$skipDeezer" == "false" ]; then

			if [ -z "$deezerArtistUrl" ]; then 
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: DEEZER :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Deezer link, see: \"/config/logs/deezer-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/deezer-artist-id-not-found.txt"
				if cat "/config/logs/deezer-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit for \"${lidarrArtistName}\" with Deezer Artist Link" >> "/config/logs/deezer-artist-id-not-found.txt"
					chmod 777 "/config/logs/deezer-artist-id-not-found.txt"
					NotifyWebhook "ArtistError" "Update Musicbrainz Relationship Page: <https://musicbrainz.org/artist/${lidarrArtistForeignArtistId}/edit> for ${lidarrArtistName} with Deezer Artist Link"
				fi
				skipDeezer=true
			fi
			deezerArtistIds=($(echo "$deezerArtistUrl" | grep -o '[[:digit:]]*' | sort -u))
		fi

        if [ "$skipTidal" == "false" ]; then

			if [ -z "$tidalArtistUrl" ]; then 
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: TIDAL :: ERROR :: musicbrainz id: $lidarrArtistForeignArtistId is missing Tidal link, see: \"/config/logs/tidal-artist-id-not-found.txt\" for more detail..."
				touch "/config/logs/tidal-artist-id-not-found.txt" 
				if cat "/config/logs/tidal-artist-id-not-found.txt" | grep "https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit" | read; then
					sleep 0.01
				else
					echo "Update Musicbrainz Relationship Page: https://musicbrainz.org/artist/$lidarrArtistForeignArtistId/edit for \"${lidarrArtistName}\" with Tidal Artist Link" >> "/config/logs/tidal-artist-id-not-found.txt"
					chmod 777 "/config/logs/tidal-artist-id-not-found.txt"
					NotifyWebhook "ArtistError" "Update Musicbrainz Relationship Page: <https://musicbrainz.org/artist/${lidarrArtistForeignArtistId}/edit> for ${lidarrArtistName} with Tidal Artist Link"
				fi
				skipTidal=true
			fi
		fi

		# Begin cosolidated search process
		if [ "$audioLyricType" == "both" ]; then
			endLoop="2"
		else
			endLoop="1"
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
			LidarrTaskStatusCheck
			loopCount=$(( $loopCount + 1 ))
			if [ "$loopCount" == "1" ]; then
				# First loop is either explicit or clean depending on script settings
				if [ "$audioLyricType" == "both" ] || [ "$audioLyricType" == "explicit" ]; then
					lyricFilter="true"
				else
					lyricFilter="false"
				fi
			else
				# 2nd loop is always clean
				lyricFilter="false"
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
				LidarrTaskStatusCheck
				# Skip Various Artists album search that is not supported...
				if [ "$lidarrArtistForeignArtistId" != "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
					# Lidarr Status Check
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId"
					if [ "$alreadyImported" == "true" ]; then
						log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						break 2
					fi
						
					# Tidal Artist search
					if [ "$skipTidal" == "false" ]; then
						for tidalArtistId in $(echo $tidalArtistIds); do
							ArtistTidalSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$tidalArtistId" "$lyricFilter"
							sleep 0.01
						done	
					fi

					# Lidarr Status Check
					LidarrTaskStatusCheck
					CheckLidarrBeforeImport "$checkLidarrAlbumId"
					if [ "$alreadyImported" == "true" ]; then
						log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
						break 2
					fi

					# Deezer artist search
					if [ "$skipDeezer" == "false" ]; then
						for dId in ${!deezerArtistIds[@]}; do
							deezerArtistId="${deezerArtistIds[$dId]}"
							ArtistDeezerSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$deezerArtistId" "$lyricFilter"
							sleep 0.01
						done
					fi
				fi
				
				# Lidarr Status Check
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId"
				if [ "$alreadyImported" == "true" ]; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
					break 2
				fi

				# Tidal fuzzy search
				if [ "$dlClientSource" == "both" ] || [ "$dlClientSource" == "tidal" ]; then
					FuzzyTidalSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$lyricFilter"
					sleep 0.01
				fi

				# Lidarr Status Check
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId"
				if [ "$alreadyImported" == "true" ]; then
					log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
					break 2
				fi

				# Deezer fuzzy search
				if [ "$dlClientSource" == "both" ] || [ "$dlClientSource" == "deezer" ]; then
					FuzzyDeezerSearch "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal" "$lyricFilter"
					sleep 0.01
				fi

			done
				
			# Break after all operations are complete
			if [ "$loopCount" == "$endLoop" ]; then
				break
			fi
		done
		
		
		# Lidarr Status Check
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi

		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi
		
		LidarrTaskStatusCheck
		CheckLidarrBeforeImport "$checkLidarrAlbumId"
		if [ "$alreadyImported" == "true" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported, skipping..."
			continue
		fi
				
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Album Not found"
		if [ "$skipNotFoundLogCreation" == "false" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Marking Album as notfound"
			if [ ! -f "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId" ]; then
				touch "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
				chmod 777 "/config/extended/logs/notfound/$wantedAlbumId--$lidarrArtistForeignArtistId--$lidarrAlbumForeignAlbumId"
			fi
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Skip marking album as not found because it's a new release for 7 days..."
		fi
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Search Complete..." 
	done
}

GetDeezerAlbumInfo () {
	until false
	do
		log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Getting Album info..."
		if [ ! -f "/config/extended/cache/deezer/$1.json" ]; then
			curl -s "https://api.deezer.com/album/$1" -o "/config/extended/cache/deezer/$1.json"
			sleep $sleepTimer
		fi
		if [ -f "/config/extended/cache/deezer/$1.json" ]; then
			if jq -e . >/dev/null 2>&1 <<<"$(cat /config/extended/cache/deezer/$1.json)"; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Album info downloaded and verified..."
				chmod 777 /config/extended/cache/deezer/$1.json
				albumInfoVerified=true
				break
			else
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Error getting album information"
				if [ -f "/config/extended/cache/deezer/$1.json" ]; then
					rm "/config/extended/cache/deezer/$1.json"
				fi
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: Retrying..."
			fi
		else
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: ERROR :: Download Failed"
		fi
	done

}

ArtistDeezerSearch () {
	# Required Inputs
	# $1 Process ID
	# $2 Deezer Artist ID
	# $3 Lyric Type (true or false) - false == Clean, true == Explicit

	# Get deezer artist album list
	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi
	if [ ! -f "/config/extended/cache/deezer/$2-albums.json" ]; then
		getDeezerArtistAlbums=$(curl -s "https://api.deezer.com/artist/$2/albums?limit=1000" > "/config/extended/cache/deezer/$2-albums.json")
		sleep $sleepTimer
		getDeezerArtistAlbumsCount="$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .total)"
	fi
	
	if [ "$getDeezerArtistAlbumsCount" == "0" ]; then
		return
	fi

	if [ "$3" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi
	
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching $2... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."		
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: Filtering results by lyric type and \"$lidarrAlbumReleaseTitleFirstWord\"..."
	deezerArtistAlbumsData=$(cat "/config/extended/cache/deezer/$2-albums.json" | jq -r .data[])
	deezerArtistAlbumsIds=$(echo "${deezerArtistAlbumsData}" | jq -r "select(.explicit_lyrics=="$3") | select(.title | test(\"^$lidarrAlbumReleaseTitleFirstWord\";\"i\")) | .id")

	resultsCount=$(echo "$deezerArtistAlbumsIds" | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $resultsCount search results found"
	for deezerAlbumID in $(echo "$deezerArtistAlbumsIds"); do
		deezerAlbumData="$(echo "$deezerArtistAlbumsData" | jq -r "select(.id==$deezerAlbumID)")"
		deezerAlbumTitle="$(echo "$deezerAlbumData" | jq -r ".title")"
		deezerAlbumTitleClean="$(echo ${deezerAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
		# String Character Count test, quicker than the levenshtein method to allow faster processing
		characterMath=$(( ${#deezerAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
		if [ "$characterMath" -gt "$matchDistance" ]; then
			continue
		elif [ "$characterMath" -lt "0" ]; then
			continue
		fi
		GetDeezerAlbumInfo "$deezerAlbumID"
		deezerAlbumData="$(cat "/config/extended/cache/deezer/$deezerAlbumID.json")"
		deezerAlbumTrackCount="$(echo "$deezerAlbumData" | jq -r .nb_tracks)"
		deezerAlbumExplicitLyrics="$(echo "$deezerAlbumData" | jq -r .explicit_lyrics)"								
		deezerAlbumTitle="$(echo "$deezerAlbumData"| jq -r .title)"
		deezerAlbumTitleClean="$(echo "$deezerAlbumTitle" | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')"
		downloadedReleaseDate="$(echo "$deezerAlbumData" | jq -r .release_date)"
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"

		# Reject release if greater than the max track count
		if [ "$deezerAlbumTrackCount" -gt "$lidarrAlbumReleasesMaxTrackCount" ]; then
			continue
		fi

		# Reject release if less than the min track count
		if [ "$deezerAlbumTrackCount" -lt "$lidarrAlbumReleasesMinTrackCount" ]; then
			continue
		fi
		
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Similarity..."
		diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}" 2>/dev/null)
		if [ "$diff" -le "$matchDistance" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Deezer  :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$deezerAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"

			# Verify it was successfully imported into Lidarr
			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$checkLidarrAlbumId"
			if [ "$alreadyImported" == "true" ]; then
				break
			fi
		fi
	done

	if [ "$alreadyImported" == "true" ]; then
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

	if [ "$2" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi

	if [ ! -d /config/extended/cache/deezer ]; then
		mkdir -p /config/extended/cache/deezer
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)"

	deezerSearch=""
	if [ "$lidarrArtistForeignArtistId" == "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
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
			if [ "$characterMath" -gt "$matchDistance" ]; then
				continue
			elif [ "$characterMath" -lt "0" ]; then
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
			if [ "$deezerAlbumTrackCount" -gt "$lidarrAlbumReleasesMaxTrackCount" ]; then
				continue
			fi

			# Reject release if less than the min track count
			if [ "$deezerAlbumTrackCount" -lt "$lidarrAlbumReleasesMinTrackCount" ]; then
				continue
			fi

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Calculating Similarity..."
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${deezerAlbumTitleClean,,}" 2>/dev/null)
			if [ "$diff" -le "$matchDistance" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $deezerAlbumTitleClean :: Deezer MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Deezer :: $type :: $lidarrReleaseTitle :: Downloading $deezerAlbumTrackCount Tracks :: $deezerAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$deezerAlbumID" "DEEZER" "$downloadedReleaseYear" "$deezerAlbumTitle" "$deezerAlbumTrackCount"

				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId"
				if [ "$alreadyImported" == "true" ]; then
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
	if [ ! -f /config/extended/cache/tidal/$2-albums.json ]; then
		curl -s "https://api.tidal.com/v1/artists/$2/albums?limit=10000&countryCode=$tidalCountryCode&filter=ALL" -H 'x-tidal-token: CzET4vdadNUFQ5JU' > /config/extended/cache/tidal/$2-albums.json
		sleep $sleepTimer
	fi

	if [ ! -f "/config/extended/cache/tidal/$2-albums.json" ]; then
		return
	fi

	if [ "$3" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
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
		if [ "$downloadedReleaseDate" == "null" ]; then
			downloadedReleaseDate=$(echo $tidalArtistAlbumData | jq -r '.streamStartDate')
		fi
		downloadedReleaseYear="${downloadedReleaseDate:0:4}"
		downloadedTrackCount=$(echo "$tidalArtistAlbumData"| jq -r .numberOfTracks)

		# String Character Count test, quicker than the levenshtein method to allow faster processing
		characterMath=$(( ${#tidalAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
		if [ "$characterMath" -gt "$matchDistance" ]; then
			continue
		elif [ "$characterMath" -lt "0" ]; then
			continue
		fi

		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
		log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Similarity..."
		diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${tidalAlbumTitleClean,,}" 2>/dev/null)
		if [ "$diff" -le "$matchDistance" ]; then
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"

			# Execute Download
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $downloadedAlbumTitle ($downloadedReleaseYear)"
			
			DownloadProcess "$tidalArtistAlbumId" "TIDAL" "$downloadedReleaseYear" "$downloadedAlbumTitle" "$downloadedTrackCount"

			# Verify it was successfully imported into Lidarr
			LidarrTaskStatusCheck
			CheckLidarrBeforeImport "$checkLidarrAlbumId"
			if [ "$alreadyImported" == "true" ]; then
				break
			fi
		else
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Artist Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal Match Not Found :: Calculated Difference ($diff) greater than 5"
		fi
	done

	if [ "$alreadyImported" == "true" ]; then
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

	if [ "$2" == "true" ]; then
		type="Explicit"
	else
		type="Clean"
	fi

	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Searching... (Track Count: $lidarrAlbumReleasesMinTrackCount-$lidarrAlbumReleasesMaxTrackCount)..."
	
	if [ "$lidarrArtistForeignArtistId" == "89ad4ac3-39f7-470e-963a-56509c546377" ]; then
		# Search without Artist for VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[] | select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	else
		# Search with Artist for non VA albums
		tidalSearch=$(curl -s "https://api.tidal.com/v1/search/albums?query=${albumArtistNameSearch}%20${albumTitleSearch}&countryCode=${tidalCountryCode}&limit=20" -H 'x-tidal-token: CzET4vdadNUFQ5JU' | jq -r ".items | sort_by(.numberOfTracks) | sort_by(.explicit) | reverse |.[]| select(.explicit=="$2") | select((.numberOfTracks <= $lidarrAlbumReleasesMaxTrackCount) and .numberOfTracks >= $lidarrAlbumReleasesMinTrackCount)")
	fi
	sleep $sleepTimer
	tidalSearch=$(echo "$tidalSearch" | jq -r "select(.title | test(\"^$lidarrAlbumReleaseTitleFirstWord\";\"i\"))")
	searchResultCount=$(echo "$tidalSearch" | jq -r ".id" | sort -u | wc -l)
	log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $searchResultCount search results found ($lidarrAlbumReleaseTitleFirstWord)"
	if [ ! -z "$tidalSearch" ]; then
		for tidalAlbumID in $(echo "$tidalSearch" | jq -r .id | sort -u); do
			tidalAlbumData="$(echo "$tidalSearch" | jq -r "select(.id==$tidalAlbumID)")"
			tidalAlbumTitle=$(echo "$tidalAlbumData"| jq -r .title)
			tidalAlbumTitleClean=$(echo ${tidalAlbumTitle} | sed -e "s%[^[:alpha:][:digit:]]%%g" -e "s/  */ /g" | sed 's/^[.]*//' | sed  's/[.]*$//g' | sed  's/^ *//g' | sed 's/ *$//g')
			downloadedReleaseDate="$(echo ${tidalAlbumData} | jq -r .releaseDate)"
			if [ "$downloadedReleaseDate" == "null" ]; then
				downloadedReleaseDate=$(echo $tidalAlbumData | jq -r '.streamStartDate')
			fi
			downloadedReleaseYear="${downloadedReleaseDate:0:4}"
			downloadedTrackCount=$(echo "$tidalAlbumData"| jq -r .numberOfTracks)

			# String Character Count test, quicker than the levenshtein method to allow faster processing
			characterMath=$(( ${#tidalAlbumTitleClean} - ${#lidarrAlbumReleaseTitleClean} ))
			if [ "$characterMath" -gt "$matchDistance" ]; then
				continue
			elif [ "$characterMath" -lt "0" ]; then
				continue
			fi

			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Checking for Match..."
			log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Calculating Similarity..."
			diff=$(levenshtein "${lidarrAlbumReleaseTitleClean,,}" "${tidalAlbumTitleClean,,}" 2>/dev/null)
			if [ "$diff" -le "$matchDistance" ]; then
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: $lidarrAlbumReleaseTitleClean vs $tidalAlbumTitleClean :: Tidal MATCH Found :: Calculated Difference = $diff"
				log "$1 :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Fuzzy Search :: Tidal :: $type :: $lidarrReleaseTitle :: Downloading $downloadedTrackCount Tracks :: $tidalAlbumTitle ($downloadedReleaseYear)"
				
				DownloadProcess "$tidalAlbumID" "TIDAL" "$downloadedReleaseYear" "$tidalAlbumTitle" "$downloadedTrackCount"
				
				# Verify it was successfully imported into Lidarr
				LidarrTaskStatusCheck
				CheckLidarrBeforeImport "$checkLidarrAlbumId"
				if [ "$alreadyImported" == "true" ]; then
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
	checkLidarrAlbumData="$(curl -s "$lidarrUrl/api/v1/album/$1?apikey=${lidarrApiKey}")"
	checkLidarrAlbumPercentOfTracks=$(echo "$checkLidarrAlbumData" | jq -r ".statistics.percentOfTracks")
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Checking Lidarr for existing files"
	log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: $checkLidarrAlbumPercentOfTracks% Tracks found"
	if [ "$checkLidarrAlbumPercentOfTracks" == "null" ]; then
		checkLidarrAlbumPercentOfTracks=0
		return
	fi
	if [ "${checkLidarrAlbumPercentOfTracks%%.*}" -ge "100" ]; then
		if [ "$wantedAlbumListSource" == "missing" ]; then
			log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported Album (Missing), skipping..."
			alreadyImported=true
			return
		fi

		if [ "$wantedAlbumListSource" == "cutoff" ]; then
			checkLidarrAlbumFiles="$(curl -s "$lidarrUrl/api/v1/trackFile?albumId=$1?apikey=${lidarrApiKey}")"
			checkLidarrAlbumQualityCutoffNotMet=$(echo "$checkLidarrAlbumFiles" | jq -r ".[].qualityCutoffNotMet")
			if echo "$checkLidarrAlbumQualityCutoffNotMet" | grep "true" | read; then
				log "$page :: $wantedAlbumListSource :: $processNumber of $wantedListAlbumTotal :: $lidarrArtistName :: $lidarrAlbumTitle :: $lidarrAlbumType :: Already Imported Album (CutOff - $checkLidarrAlbumQualityCutoffNotMet), skipping..."
				alreadyImported=true
				return
			fi
		fi
	fi
}

LidarrTaskStatusCheck () {
	alerted=no
	until false
	do
		taskCount=$(curl -s "$lidarrUrl/api/v1/command?apikey=${lidarrApiKey}" | jq -r '.[] | select(.status=="started") | .name' | wc -l)
		if [ "$taskCount" -ge "1" ]; then
			if [ "$alerted" == "no" ]; then
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
		fi
		touch /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
		chmod 777 /config/extended/logs/searched/lidarr/artist/$lidarrArtistMusicbrainzId
	done
}

function levenshtein {
	if [ "$1" == "$2" ]; then
		echo 0
	else
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
	fi
}

audioFlacVerification () {
	# Test Flac File for errors
	# $1 File for verification
	verifiedFlacFile=""
	verifiedFlacFile=$(flac --totally-silent -t "$1"; echo $?)
}

NotifyWebhook () {
	if [ "$webHook" ]
	then
		content="$1: $2"
		curl -s -X POST "{$webHook}" -H 'Content-Type: application/json' -d '{"event":"'"$1"'", "message":"'"$2"'", "content":"'"$content"'"}'
	fi
}

Configuration

# Perform Completed Download Folder Cleanup process
DownloadFolderCleaner

# Perform NotFound Folder Cleanup process
NotFoundFolderCleaner

LidarrRootFolderCheck

DownloadFormat

if [ "$dlClientSource" == "deezer" ] || [ "$dlClientSource" == "both" ]; then
	DeemixClientSetup
fi

if [ "$dlClientSource" == "tidal" ] || [ "$dlClientSource" == "both" ]; then
	TidalClientSetup
fi

LidarrTaskStatusCheck

# Get artist list for LidarrMissingAlbumSearch process, to prevent searching for artists that will not be processed by the script
lidarrMissingAlbumArtistsData=$(wget --timeout=0 -q -O - "$lidarrUrl/api/v1/artist?apikey=$lidarrApiKey" | jq -r .[])

if [ "$dlClientSource" == "deezer" ] || [ "$dlClientSource" == "tidal" ] || [ "$dlClientSource" == "both" ]; then
	GetMissingCutOffList
else
	log "ERROR :: No valid dlClientSource set"
	log "ERROR :: Expected configuration :: deezer or tidal or both"
	log "ERROR :: dlClientSource set as: \"$dlClientSource\""
fi

if [ "$addDeezerTopArtists" == "true" ] || [ "$addDeezerTopAlbumArtists" == "true" ] || [ "$addDeezerTopTrackArtists" == "true" ] || [ "$addRelatedArtists" == "true" ]; then
	LidarrTaskStatusCheck
	LidarrMissingAlbumSearch
fi

log "Script end..."
exit

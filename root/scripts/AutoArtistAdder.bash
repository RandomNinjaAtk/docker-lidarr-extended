#!/usr/bin/env bash
scriptVersion="1.0.001"
if [ -z "$lidarrUrl" ] || [ -z "$lidarrApiKey" ]; then
	lidarrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
	if [ "$lidarrUrlBase" == "null" ]; then
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

# Debugging settings
#addRelatedArtists="true"
#addDeezerTopArtists="true"
#addDeezerTopAlbumArtists="true"
#addDeezerTopTrackArtists="true"
#topLimit="3"
#addRelatedArtists="true"
#numberOfRelatedArtistsToAddPerArtist="1"


touch "/config/logs/AutoArtistAdder.txt"
chmod 666 "/config/logs/AutoArtistAdder.txt"
exec &> >(tee -a "/config/logs/AutoArtistAdder.txt")

sleepTimer=0.5

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: AutoArtistAdder :: $scriptVersion :: "$1
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
		log "$artistNumber of $lidarrArtistTotal :: $wantedAlbumListSource :: $lidarrArtistName :: Adding Related Artists..."
		if [ "$lidarrArtistMonitored" == "false" ]; then
			log "$artistNumber of $lidarrArtistTotal :: $wantedAlbumListSource :: $lidarrArtistName :: Artist is not monitored :: skipping..."
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

if [ "$addDeezerTopArtists" == "true" ]; then
	AddDeezerTopArtists "$topLimit"
fi

if [ "$addDeezerTopAlbumArtists" == "true" ]; then
	AddDeezerTopAlbumArtists "$topLimit"
fi

if [ "$addDeezerTopTrackArtists" == "true" ]; then
	AddDeezerTopTrackArtists "$topLimit"
fi

if [ "$addRelatedArtists" == "true" ]; then
	AddRelatedArtists
fi

exit

#!/usr/bin/env bash
scriptVersion="1.0.2"
agent="ERA ( https://github.com/Makario1337/ExtendedReleaseAdder )"
ArtistsJSON=$(jq '.artists[]' /config/artists.json)

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Release Adder :: "$1
}

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

LidarrAudiobookRootFolder=$(curl -s GET "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | grep '\/audiobooks\/')
log "-----------------------------------------------------------------------------"
log " |\/| _ |  _ ._o _ '|~/~/~/"
log " |  |(_||<(_|| |(_) |_)_)/ "
log " AND"
log " |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
log " |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
log " Presents: Extended Release Adder ($scriptVersion)"
log " Docker Version: $dockerVersion"
log "-----------------------------------------------------------------------------"
log " Donate to the original creator: https://github.com/sponsors/RandomNinjaAtk"
log " Original Project: https://github.com/RandomNinjaAtk/docker-lidarr-extended"
log " Extended Release Adder can be found under: "
log " https://github.com/Makario1337/ExtendedReleaseAdder"
log "-----------------------------------------------------------------------------"
sleep 5
log ""
log "Lift off in..."; sleep 0.5
log "5"; sleep 1
log "4"; sleep 1
log "3"; sleep 1
log "2"; sleep 1
log "1"; sleep 1

if [ -z "$LidarrAudiobookRootFolder" ]; then
    log "ERROR :: Audiobooks folder doesn't exist... "
    log "ERROR :: Check your Docker path mappings..."
    log "ERROR :: Exiting ERA..."
    exit
fi

if [ ! -d "/audiobooks" ]; then
    log "ERROR :: Audiobooks folder doesn't exist... "
    log "ERROR :: Check your Docker path mappings..."
    log "ERROR :: Exiting ERA..."
    exit
fi

AddReleaseToLidarr() {
lidarrAlbumSearch=$(curl -X GET "$lidarrUrl/api/v1/album/lookup?term="lidarr%3A%20$1"" -H  "accept: */*" -H  "X-Api-Key: "$lidarrApiKey"" | jq '.')
lidarrAlbumSearch=$(echo $lidarrAlbumSearch  |
sed  's/"monitored": false/"monitored": true/g'| 
sed 's/"qualityProfileId": 0/"qualityProfileId": 1/g' | 
sed 's/"metadataProfileId": 0/"metadataProfileId": 2/g' | 
sed 's/"metadataProfileId": 2/"metadataProfileId": 2,\"rootFolderPath": "\/audiobooks\/" /g'| 
sed 's/"metadataProfileId": 2/"metadataProfileId": 2,\"addOptions": {"monitor": "all","searchForMissingAlbums": false}/g' |
sed 's/"grabbed": false/"grabbed": false,\"addOptions": {"searchForNewAlbum": false}/g'|
jq '.' |
cut -c 2- |
head -c -2) 
curl -X POST "$lidarrUrl/api/v1/album?apikey="$lidarrApiKey"" -H  "accept: text/plain" -H  "Content-Type: application/json" -d "$lidarrAlbumSearch" 
}
SearchRelease(){
    ReleaseName=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/release-group/$1" | grep -o "<title>.*</title>" | sed 's/<title>//g' | head -c -9 | sed 's/\&amp;/\&/g' | sed 's/???/???‎/g')
    log "Adding :: $artist :: $ReleaseName"
    AddReleaseToLidarr $1 &> /dev/null
}
SearchAllReleasesForArtist() {
offset=0
while [ $offset -le 500 ]
do
    offset=$(( $offset + 100 ))
    sleep 1.5
    SearchAllReleasesForArtist=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/release-group/?artist="$1"&limit=100&offset=$offset&fmt=json&type=other&secondary_type="audio%20drama"")
    lines=$(echo $SearchAllReleasesForArtist | jq '."release-groups"[]."id"')
    if [ -z "$lines" ]
    then
        log "ERROR :: Did not find matching release , skipping... "
        log "ERROR :: Make sure the wanted items are listed under Other + Audio Drama on Musicbrainz"
        offset=$(( $offset + 1337 ))
    else
        for line in $lines
        do
            trim=$(echo $line | cut -c 2- | head -c -2)
            SearchRelease $trim 
            sleep 1.5
        done
    fi
done
}
ArtistLookup() {
search=$(echo $1 | sed 's/\"//g')
artist=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/artist/$search" | grep -o "<name>.*</name>" | sed 's/<name>//' | sed 's/<\/name>.*//' | sed 's/???/???‎/g' )
log "Adding :: $artist"
sleep 1.5
SearchAllReleasesForArtist $search
}
if [ -z "$ArtistsJSON" ]
then
    log "ERROR :: Did not find /config/artists.json or no artists in file... "
    log "ERROR :: Exiting..."
else
    for str in ${ArtistsJSON[@]}; do
      ArtistLookup $str 
    done
fi
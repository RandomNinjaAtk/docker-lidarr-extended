#!/usr/bin/env bash
scriptVersion="1.1.3"
agent="ERA ( https://github.com/Makario1337/ExtendedReleaseAdder )"

### DEBUG ###
DEBUG=0
### DEBUG end ###

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Release Adder :: "$1
}

### Start ###
start () {

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

if [[ $DEBUG -ne 1 ]]; then
    if [ -f "/config/logs/ExtendedReleaseAdder.txt" ]; then
    find /config/logs -type f -name "ExtendedReleaseAdder.txt" -size +1024k -delete
    fi
    exec &>> "/config/logs/ExtendedReleaseAdder.txt"
    chmod 666 "/config/logs/ExtendedReleaseAdder.txt"
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
fi 
}
start
### Start end ###
AddReleaseToLidarr() {
	lidarrAlbumSearch=$(curl -s -X GET "$lidarrUrl/api/v1/album/lookup?term="lidarr%3A%20$1"" -H  "accept: */*" -H  "X-Api-Key: "$lidarrApiKey"" | jq '.')
	CheckIfAlreadyAdded=$(echo $lidarrAlbumSearch | tr -d ' ' | sed 's/^.*,"grabbed":*false,"id"://g' | sed 's/}]//g'  )
	if [[ $CheckIfAlreadyAdded =~ ^[0-9]+$ ]]; then
	    log "Adding :: $2 :: $3 :: Alreaddy Added, skipping...."
	else
	    lidarrAlbumSearch=$(echo $lidarrAlbumSearch  |
	    sed  's/"monitored": false/"monitored": true/g'| 
	    sed 's/"qualityProfileId": 0/"qualityProfileId": 1/g' | 
	    sed 's/"metadataProfileId": 0/"metadataProfileId": 1/g' | 
	    sed "s%\"metadataProfileId\": 1%\"metadataProfileId\": 1,\"rootFolderPath\": \"\" %g" | 
	    sed 's/"metadataProfileId": 1/"metadataProfileId": 1,\"addOptions": {"monitor": "all","searchForMissingAlbums": true}/g' |
	    sed 's/"grabbed": false/"grabbed": false,\"addOptions": {"searchForNewAlbum": true}/g'|
	    jq '.' |
	    cut -c 2- |
	    head -c -2)
	    curl -s -X POST "$lidarrUrl/api/v1/album?apikey="$lidarrApiKey"" -H  "accept: text/plain" -H  "Content-Type: application/json" -d "$lidarrAlbumSearch" 
	    log "Adding :: $2 :: $3 :: Release Added..."
	fi
}
SearchAllArtistsByTag(){
offset=0
tag="audio%20drama"
log "Collecting artists by tag :: Collecting..."
while [ $offset -le 5000 ]
do  
    AllArtistsByTagWget=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/artist?query=tag:"audio%20drama"&limit=100&fmt=json&offset=$offset" | jq '.artists[].id')
    AllArtistsByTag="$AllArtistsByTag $AllArtistsByTagWget"
    sleep 1.5
    offset=$(( $offset + 100 ))
done
log "Collecting artists by tag :: Done"
}
CheckIfCollectedArtistsAreInLidarrInstance(){
for artist in ${AllArtistsByTag[@]}; do
    artist=$(echo $artist | sed 's/"//g')
    ArtistInLidarr=$(curl -s -X GET "$lidarrUrl/api/v1/artist?mbId=$artist" -H  "accept: */*" -H  "X-Api-Key: "$lidarrApiKey"")
    sleep 0.1
    if [[ "$ArtistInLidarr" != "[]" ]]; then
    LidarrArtistID=$(echo $ArtistInLidarr | jq '.[].id')
    RefreshArtistList="$RefreshArtistList $LidarrArtistID"
    Temp=$(echo $ArtistInLidarr | jq '.[].foreignArtistId')
    ERAArtistsList="$ERAArtistsList $Temp"
    fi
done
}
ArtistLookupAndCallAddReleaseToLidarr() {
for artist in ${ERAArtistsList[@]}; do
    artist=$(echo $artist | sed 's/"//g')
    artistname=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/artist/$artist" | grep -o "<name>.*</name>" | sed 's/<name>//' | sed 's/<\/name>.*//')
    log "Searching :: $artistname"
    offset=0
    SearchAllReleasesForArtist=""
    while [ $offset -le 500 ]
    do
        sleep 1.5
        SearchAllReleasesForArtistWget=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/release-group/?artist=$artist&limit=100&offset=$offset&fmt=json&type=other&secondary_type="audio%20drama"")
        offset=$(( $offset + 100 ))
        SearchAllReleasesForArtist="$SearchAllReleasesForArtist $SearchAllReleasesForArtistWget"
    done
    lines=$(echo $SearchAllReleasesForArtist | jq '."release-groups"[]."id"')
    if [ -z "$lines" ]; then
        log "ERROR :: Did not find matching release, skipping... "
        offset=$(( $offset + 1337 ))
    else
        for line in $lines
        do
            trim=$(echo $line | cut -c 2- | head -c -2)
            ReleaseName=$(wget -U "$agent" --timeout=0 -q -O - "https://musicbrainz.org/ws/2/release-group/$trim" | grep -o "<title>.*</title>" | sed 's/<title>//g' | head -c -9)
            AddReleaseToLidarr $trim "$artistname" "$ReleaseName"
        done
    fi
done
}

RefreshArtists() {
    log "Refreshing all ERA artists, so new releasegroup entrys can be added"
    for artists in $RefreshArtistList
    do
        curl -s -X POST "$lidarrUrl/api/v1/command" -H  "accept: text/plain" -H  "Content-Type: application/json" -H "X-Api-Key: $lidarrApiKey" -d "{\"name\":\"RefreshArtist\",\"artistId\":$artists}"
        sleep 1.5
    done
}

CleanPreviousDownloads() {
    
    for artist in ${ERAArtistsList[@]}; do
        log "cleaning $artist"
        find /config/extended/logs/notfound -type f -name '*$(echo $artist | tail -c +2 | head -c -2 )*' -delete
    done
}

SearchAllArtistsByTag
CheckIfCollectedArtistsAreInLidarrInstance
ArtistLookupAndCallAddReleaseToLidarr
CleanPreviousDownloads
RefreshArtists
log "DONE :: Finishing..."
exit

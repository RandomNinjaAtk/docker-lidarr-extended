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
			log ":: Lidarr Version: $lidarrVersion"
			break
		else
			log ":: Lidarr is not ready, sleeping until valid response..."
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

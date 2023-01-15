#!/usr/bin/env bash
scriptVersion="1.0.0"

### DEBUG ###
DEBUG=0
### DEBUG end ###

log () {
	m_time=`date "+%F %T"`
	echo $m_time" :: Extended Config :: "$1
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
    if [ -f "/config/logs/ExtendedConfig.txt" ]; then
    find /config/logs -type f -name "ExtendedConfig.txt" -size +1024k -delete
    fi
    exec &>> "/config/logs/ExtendedConfig.txt"
    chmod 666 "/config/logs/ExtendedConfig.txt"
log "-----------------------------------------------------------------------------"
log " |\/| _ |  _ ._o _ '|~/~/~/"
log " |  |(_||<(_|| |(_) |_)_)/ "
log " AND"
log " |~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
log " |~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
log " Presents: Extended Config ($scriptVersion)"
log " Docker Version: $dockerVersion"
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
RescanFoldersInterval=$(echo $(( FolderRescanIntervalInHours * 60 )))

sqlite3 lidarr.db <<EOF
update "ScheduledTasks" set "Interval" = '${RescanFoldersInterval}' where "TypeName" = 'NzbDrone.Core.MediaFiles.Commands.RescanFoldersCommand';
EOF
log "update "ScheduledTasks" set "Interval" = '${RescanFoldersInterval}' where "TypeName" = 'NzbDrone.Core.MediaFiles.Commands.RescanFoldersCommand';"

log "DONE :: Finishing..."
exit

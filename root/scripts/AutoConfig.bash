#!/usr/bin/env bash
scriptVersion="1.0.0"

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

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/AutoConfig.txt" ]; then
	find /config/logs -type f -name "AutoConfig.txt" -size +1024k -delete
fi

exec &>> "/config/logs/AutoConfig.txt"
chmod 666 "/config/logs/AutoConfig.txt"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: AutoConfig :: "$1
}


if curl -s "$lidarrUrl/api/v1/rootFolder" -H "X-Api-Key: ${lidarrApiKey}" | sed '1q' | grep "\[\]" | read; then
	log "ERROR :: No root folder found"
	log "Configuring root folder..."
	getSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fmusic&allowFoldersWithoutTrailingSlashes=false&includeFiles=false" -H "X-Api-Key: ${lidarrApiKey}")
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/rootFolder?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"defaultTags":[],"defaultQualityProfileId":1,"defaultMetadataProfileId":1,"name":"Music","path":"/music"}')
fi

log "Configuring Lidarr Media Management Settings"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/mediamanagement" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"autoUnmonitorPreviouslyDownloadedTracks":false,"recycleBin":"","recycleBinCleanupDays":7,"downloadPropersAndRepacks":"preferAndUpgrade","createEmptyArtistFolders":true,"deleteEmptyFolders":true,"fileDate":"none","watchLibraryForChanges":true,"rescanAfterRefresh":"always","allowFingerprinting":"newFiles","setPermissionsLinux":false,"chmodFolder":"777","chownGroup":"","skipFreeSpaceCheckWhenImporting":false,"minimumFreeSpaceWhenImporting":100,"copyUsingHardlinks":true,"importExtraFiles":true,"extraFileExtensions":"jpg,png,lrc","id":1}')

log "Configuring Lidarr Metadata ConsumerSettings"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadata/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"enable":true,"name":"Kodi (XBMC) / Emby","fields":[{"name":"artistMetadata","value":true},{"name":"albumMetadata","value":true},{"name":"artistImages","value":true},{"name":"albumImages","value":true}],"implementationName":"Kodi (XBMC) / Emby","implementation":"XbmcMetadata","configContract":"XbmcMetadataSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#xbmcmetadata","tags":[],"id":1}')

log "Configuring Lidarr Metadata Provider Settings"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/metadataProvider" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"metadataSource":"","writeAudioTags":"allFiles","scrubAudioTags":false,"id":1}')

log "Configuring Lidarr Custom Scripts"
if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "PlexNotify.bash" | read; then
	log "PlexNotify.bash Already added to Lidarr custom scripts"
else
	log "Adding PlexNotify.bash to Lidarr custom scripts"
	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FPlexNotify.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":true,"onUpgrade":true,"onRename":true,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":false,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"PlexNotify.bash","fields":[{"name":"path","value":"/config/extended/scripts/PlexNotify.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
fi
		
if curl -s "$lidarrUrl/api/v1/notification" -H "X-Api-Key: ${lidarrApiKey}" | jq -r .[].name | grep "MetadataPostProcess.bash" | read; then
	log "MetadataPostProcess.bash Already added to Lidarr custom scripts"
else
	log "Adding MetadataPostProcess.bash to Lidarr custom scripts"
		postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/filesystem?path=%2Fconfig%2Fextended%2Fscripts%2FMetadataPostProcess.bash&allowFoldersWithoutTrailingSlashes=true&includeFiles=true" -H "X-Api-Key: ${lidarrApiKey}")

	postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/notification?" -X POST -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"onGrab":false,"onReleaseImport":false,"onUpgrade":false,"onRename":false,"onHealthIssue":false,"onDownloadFailure":false,"onImportFailure":false,"onTrackRetag":true,"onApplicationUpdate":false,"supportsOnGrab":true,"supportsOnReleaseImport":true,"supportsOnUpgrade":true,"supportsOnRename":true,"supportsOnHealthIssue":true,"includeHealthWarnings":false,"supportsOnDownloadFailure":false,"supportsOnImportFailure":false,"supportsOnTrackRetag":true,"supportsOnApplicationUpdate":true,"name":"MetadataPostProcess.bash","fields":[{"name":"path","value":"/config/extended/scripts/MetadataPostProcess.bash"},{"name":"arguments"}],"implementationName":"Custom Script","implementation":"CustomScript","configContract":"CustomScriptSettings","infoLink":"https://wiki.servarr.com/lidarr/supported#customscript","message":{"message":"Testing will execute the script with the EventType set to Test, ensure your script handles this correctly","type":"warning"},"tags":[]}')
fi

log "Configuring Lidarr UI Settings"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/ui" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"firstDayOfWeek":0,"calendarWeekColumnHeader":"ddd M/D","shortDateFormat":"MMM D YYYY","longDateFormat":"dddd, MMMM D YYYY","timeFormat":"h(:mm)a","showRelativeDates":true,"enableColorImpairedMode":true,"uiLanguage":1,"expandAlbumByDefault":true,"expandSingleByDefault":true,"expandEPByDefault":true,"expandBroadcastByDefault":true,"expandOtherByDefault":true,"id":1}')
	
log "Configuring Lidarr Standard Metadata Profile"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/metadataprofile/1?" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"name":"Standard","primaryAlbumTypes":[{"albumType":{"id":2,"name":"Single"},"allowed":true},{"albumType":{"id":4,"name":"Other"},"allowed":false},{"albumType":{"id":1,"name":"EP"},"allowed":true},{"albumType":{"id":3,"name":"Broadcast"},"allowed":false},{"albumType":{"id":0,"name":"Album"},"allowed":true}],"secondaryAlbumTypes":[{"albumType":{"id":0,"name":"Studio"},"allowed":true},{"albumType":{"id":3,"name":"Spokenword"},"allowed":false},{"albumType":{"id":2,"name":"Soundtrack"},"allowed":true},{"albumType":{"id":7,"name":"Remix"},"allowed":true},{"albumType":{"id":9,"name":"Mixtape/Street"},"allowed":false},{"albumType":{"id":6,"name":"Live"},"allowed":false},{"albumType":{"id":4,"name":"Interview"},"allowed":false},{"albumType":{"id":8,"name":"DJ-mix"},"allowed":false},{"albumType":{"id":10,"name":"Demo"},"allowed":false},{"albumType":{"id":1,"name":"Compilation"},"allowed":true}],"releaseStatuses":[{"releaseStatus":{"id":3,"name":"Pseudo-Release"},"allowed":false},{"releaseStatus":{"id":1,"name":"Promotion"},"allowed":false},{"releaseStatus":{"id":0,"name":"Official"},"allowed":true},{"releaseStatus":{"id":2,"name":"Bootleg"},"allowed":false}],"id":1}')

log "Configuring Lidarr Track Naming Settings"
postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/naming" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"renameTracks":true,"replaceIllegalCharacters":true,"standardTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","multiDiscTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","artistFolderFormat":"{Artist CleanName}{ (Artist Disambiguation)}","includeArtistName":false,"includeAlbumTitle":false,"includeQuality":false,"replaceSpaces":false,"id":1}')

postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/naming" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"renameTracks":true,"replaceIllegalCharacters":true,"standardTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","multiDiscTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","artistFolderFormat":"{Artist CleanName}{ (Artist Disambiguation)}","includeArtistName":false,"includeAlbumTitle":false,"includeQuality":false,"replaceSpaces":false,"id":1}')

postSettingsToLidarr=$(curl -s "$lidarrUrl/api/v1/config/naming" -X PUT -H 'Content-Type: application/json' -H "X-Api-Key: ${lidarrApiKey}" --data-raw '{"renameTracks":true,"replaceIllegalCharacters":true,"standardTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","multiDiscTrackFormat":"{Artist CleanName} - {Album Type} - {Release Year} - {Album CleanTitle}{ (Album Disambiguation)}/{medium:00}{track:00} - {Track CleanTitle}","artistFolderFormat":"{Artist CleanName}{ (Artist Disambiguation)}","includeArtistName":false,"includeAlbumTitle":false,"includeQuality":false,"replaceSpaces":false,"id":1}')

exit
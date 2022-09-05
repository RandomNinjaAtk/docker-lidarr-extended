#!/usr/bin/env bash
scriptVersion="1.0.001"

if [ -z "$arrUrl" ] || [ -z "$arrApiKey" ]; then
  arrUrlBase="$(cat /config/config.xml | xq | jq -r .Config.UrlBase)"
  if [ "$arrUrlBase" == "null" ]; then
    arrUrlBase=""
  else
    arrUrlBase="/$(echo "$arrUrlBase" | sed "s/\///g")"
  fi
  arrApiKey="$(cat /config/config.xml | xq | jq -r .Config.ApiKey)"
  arrPort="$(cat /config/config.xml | xq | jq -r .Config.Port)"
  arrUrl="http://127.0.0.1:${arrPort}${arrUrlBase}"
fi

# auto-clean up log file to reduce space usage
if [ -f "/config/logs/QueueCleaner.txt" ]; then
	find /config/logs -type f -name "QueueCleaner.txt" -size +1024k -delete
fi

exec &>> "/config/logs/QueueCleaner.txt"
chmod 666 "/config/logs/QueueCleaner.txt"

log () {
  m_time=`date "+%F %T"`
  echo $m_time" :: QueueCleaner :: "$1
}

arrQueueData="$(curl -s "$arrUrl/api/v1/queue?page=1&pagesize=1000000000&sortDirection=descending&sortKey=progress&includeUnknownArtistItems=true&apikey=${arrApiKey}" | jq -r .records[])"
arrQueueIds=$(echo "$arrQueueData" | jq -r 'select(.status=="completed") | select(.trackedDownloadStatus=="warning") | .id')
arrQueueIdsCount=$(echo "$arrQueueData" | jq -r 'select(.status=="completed") | select(.trackedDownloadStatus=="warning") | .id' | wc -l)
if [ $arrQueueIdsCount -eq 0 ]; then
  log "No items in queue to clean up..."
else
  for queueId in $(echo $arrQueueIds); do
    arrQueueItemData="$(echo "$arrQueueData" | jq -r "select(.id==$queueId)")"
    arrQueueItemTitle="$(echo "$arrQueueItemData" | jq -r .title)"
    log "Removing Failed Queue Item ID: $queueId ($arrQueueItemTitle) from Lidarr..."
    curl -sX DELETE "$arrUrl/api/v1/queue/$queueId?removeFromClient=true&blocklist=true&skipredownload=false&apikey=${arrApiKey}"
  done
fi

arrQueueData="$(curl -s "$arrUrl/api/v1/queue?page=1&pagesize=1000000000&sortDirection=descending&sortKey=progress&includeUnknownArtistItems=true&apikey=${arrApiKey}" | jq -r .records[])"
arrQueueIds=$(echo "$arrQueueData" | jq -r 'select(.status=="failed") | select(.trackedDownloadStatus=="warning") | .id')
arrQueueIdsCount=$(echo "$arrQueueData" | jq -r 'select(.status=="failed") | select(.trackedDownloadStatus=="warning") | .id' | wc -l)
if [ $arrQueueIdsCount -eq 0 ]; then
  log "No items in queue to clean up..."
else

  for queueId in $(echo $arrQueueIds); do
    arrQueueItemData="$(echo "$arrQueueData" | jq -r "select(.id==$queueId)")"
    arrQueueItemTitle="$(echo "$arrQueueItemData" | jq -r .title)"
    log "Removing Failed Queue Item ID: $queueId ($arrQueueItemTitle) from Lidarr..."
    curl -sX DELETE "$arrUrl/api/v1/queue/$queueId?removeFromClient=true&blocklist=true&skipredownload=false&apikey=${arrApiKey}"
  done
fi

exit

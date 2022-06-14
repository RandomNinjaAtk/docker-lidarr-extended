#!/usr/bin/with-contenv bash

echo "Starting Script...."
processstartid="$(ps -A -o pid,cmd|grep "/config/lidarr/scripts/start.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
echo "To kill script, use the following command:"
echo "kill -9 $processstartid"
for (( ; ; )); do
	let i++
	if [ ! -d "/config/extended/logs" ]; then
		mkdir -p "/config/extended/logs" 
		chmod 777 "/config/extended/logs" 
		chown abc:abc "/config/extended/logs" 
	fi
	bash /config/lidarr/scripts/download.sh 2>&1 | tee "/config/extended/logs/script_run_${i}_$(date +"%Y_%m_%d_%I_%M_%p").log" > /proc/1/fd/1 2>/proc/1/fd/2
	if [ -f "/config/extended/logs/log-cleanup" ]; then
		rm "/config/extended/logs/log-cleanup"
	fi
	touch -d "8 hours ago" "/config/extended/logs/log-cleanup"
	if find "/config/extended/logs" -type f -iname "*.log" -not -newer "/config/extended/logs/log-cleanup" | read; then
		find "/config/extended/logs" -type f -iname "*.log" -not -newer "/config/extended/logs/log-cleanup" -delete
	fi
	if [ -f "/config/extended/logs/log-cleanup" ]; then
		rm "/config/extended/logs/log-cleanup"
	fi
	if [ -z "$scriptInterval" ]; then
		scriptInterval="15m"
	fi
	echo "Script sleeping for $scriptInterval..."
	sleep $scriptInterval
done

exit 0

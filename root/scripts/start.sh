#!/usr/bin/with-contenv bash

echo "Starting Script...."
processstartid="$(ps -A -o pid,cmd|grep "/config/extended/scripts/start.sh" | grep -v grep | head -n 1 | awk '{print $1}')"
echo "To kill script, use the following command:"
echo "kill -9 $processstartid"
for (( ; ; )); do
	let i++
	if [ ! -d "/config/logs" ]; then
		mkdir -p "/config/logs" 
		chmod 777 "/config/logs" 
		chown abc:abc "/config/logs" 
	fi
	bash /config/extended/scripts/download.sh 2>&1 | tee "/config/logs/extended_script_run_${i}_$(date +"%Y_%m_%d_%I_%M_%p").txt" > /proc/1/fd/1 2>/proc/1/fd/2
	if [ -f "/config/extended/logs/log-cleanup" ]; then
		rm "/config/extended/logs/log-cleanup"
	fi
	touch -d "8 hours ago" "/config/extended/logs/log-cleanup"
	if find "/config/logs" -type f -iname "extended_script_run_*.txt" -not -newer "/config/extended/logs/log-cleanup" | read; then
		find "/config/logs" -type f -iname "*.txt" -not -newer "/config/logs/log-cleanup" -delete
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

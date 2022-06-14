#!/usr/bin/with-contenv bash

# create scripts directory if missing
if [ ! -d "/config/lidarr-extended/scripts" ]; then
	mkdir -p "/config/lidarr-extended/scripts"
else
	echo "Updating scripts..."
	rm -rf /config/lidarr-extended/scripts/*
fi

if [ -d "/config/lidarr-extended/scripts" ]; then
	cp -r /scripts/* /config/lidarr-extended/scripts/
fi

# create cache directory if missing
if [ ! -d "/config/lidarr-extended/cache" ]; then
	mkdir -p "/config/lidarr-extended/cache"
fi

# create logs directory if missing
if [ ! -d "/config/lidarr-extended/logs" ]; then
	mkdir -p "/config/lidarr-extended/logs"
fi


# set permissions
chmod 777 /config/lidarr-extended
chmod 777 /config/lidarr-extended/cache
chmod 777 /config/lidarr-extended/logs
chmod 666 /config/lidarr-extended/cache/*
chmod 666 /config/lidarr-extended/logs/*
chmod -R 777 /config/lidarr-extended/scripts
chown -R abc:abc /config/lidarr-extended


echo "Complete..."
exit $?

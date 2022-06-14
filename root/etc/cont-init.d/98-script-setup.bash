#!/usr/bin/with-contenv bash

# create extended directory if missing
if [ ! -d "/config/extended" ]; then
	mkdir -p "/config/extended"
fi

# create scripts directory if missing
if [ ! -d "/config/extended/scripts" ]; then
	mkdir -p "/config/extended/scripts"
else
	echo "Removing previous scripts..."
	rm -rf /config/extended/scripts/*
fi

if [ -d "/config/extended/scripts" ]; then
	echo "Importing extended scripts..."
	cp -r /scripts/* /config/extended/scripts/
fi

# create cache directory if missing
if [ ! -d "/config/extended/cache" ]; then
	mkdir -p "/config/extended/cache"
fi

# create logs directory if missing
if [ ! -d "/config/extended/logs" ]; then
	mkdir -p "/config/extended/logs"
fi

# set permissions
chmod 777 /config/extended
chmod 777 /config/extended/cache
chmod 777 /config/extended/logs
chmod 666 /config/extended/cache/*
chmod 666 /config/extended/logs/*
chmod -R 777 /config/extended/scripts
chown -R abc:abc /config/extended


echo "Complete..."
exit $?

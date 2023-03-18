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
chmod 777 -R /usr/local/sma
find /config/extended -type d -exec chmod 777 {} \;
chmod -R 777 /config/extended/scripts
chmod -R 777 /root


echo "Setting up scripts..."
echo "Downloading and setting up QueueCleaner.bash"
if [  -f "/etc/services.d/QueueCleaner.bash" ]; then
	echo "Removing old script, QueueCleaner.bash"
	rm "/etc/services.d/QueueCleaner.bash"
fi
echo "Downloading and setting up QueueCleaner.bash"
curl "https://raw.githubusercontent.com/RandomNinjaAtk/arr-scripts/main/QueueCleaner.bash" -o "/etc/services.d/QueueCleaner.bash"
chmod 777 "/etc/services.d/QueueCleaner.bash"
echo "Complete..."
exit

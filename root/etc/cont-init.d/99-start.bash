#!/usr/bin/with-contenv bash
echo "------------------------------------------------------------"
echo "|~) _ ._  _| _ ._ _ |\ |o._  o _ |~|_|_|"
echo "|~\(_|| |(_|(_)| | || \||| |_|(_||~| | |<"
echo "Presenets: lidarr-extended"
echo "------------------------------------------------------------"
echo "Donate: https://github.com/sponsors/RandomNinjaAtk"
echo "Project: https://github.com/RandomNinjaAtk/docker-lidarr-extended"
echo "Support: https://discord.gg/JumQXDc"
echo "------------------------------------------------------------"

if [ "$autoStart" = "true" ]; then
	echo "Automatic Start Enabled, starting..."
	bash /config/lidarr-extended/scripts/start.sh
else
	echo "Automatic Start Disabled, manually run using this command:"
	echo "bash /config/lidarr-extended/scripts/start.sh"
fi

exit $?

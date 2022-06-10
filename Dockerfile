FROM linuxserver/lidarr:nightly
LABEL maintainer="RandomNinjaAtk"


# ports and volumes
EXPOSE 8686
VOLUME /config /music /music-videos /downloads

FROM alpine AS builder

# Download QEMU, see https://github.com/docker/hub-feedback/issues/1261
ENV QEMU_URL https://github.com/balena-io/qemu/releases/download/v3.0.0%2Bresin/qemu-3.0.0+resin-arm.tar.gz
RUN apk add curl && curl -L ${QEMU_URL} | tar zxvf - -C . --strip-components 1

FROM linuxserver/lidarr:arm32v7-latest

# Add QEMU
COPY --from=builder qemu-arm-static /usr/bin

LABEL maintainer="RandomNinjaAtk"
ENV dockerTitle="lidarr-extended"
ENV dockerVersion="arm32v7-1.0.26"
ENV LANG=en_US.UTF-8
ENV autoStart=true
ENV configureLidarrWithOptimalSettings=false
ENV dlClientSource=deezer
ENV audioFormat=native
ENV audioBitrate=lossless
ENV audioLyricType=both
ENV addDeezerTopArtists=false
ENV addDeezerTopAlbumArtists=false
ENV addDeezerTopTrackArtists=false
ENV topLimit=10
ENV addRelatedArtists=false
ENV tidalCountryCode=US
ENV numberOfRelatedArtistsToAddPerArtist=5
ENV beetsMatchPercentage=90
ENV requireQuality=true
ENV searchSort=date
ENV enableBeetsTagging=true
ENV enableReplaygainTags=true
ENV downloadPath=/downloads-lidarr-extended
ENV SMA_PATH /usr/local/sma
ENV youtubeSubtitleLanguage=en
ENV enableAudioScript=true
ENV enableVideoScript=true

RUN \
	echo "*** install packages ***" && \
	apk add -U --upgrade --no-cache \
		flac \
		beets \
		jq \
		git \
		ffmpeg \
		python3 \
		py3-pip \
		gcc \
		libc-dev \
		yt-dlp && \
	echo "*** install python packages ***" && \
	pip install --upgrade --no-cache-dir \
		yq \
		pyacoustid \
		r128gain \
		deemix && \
	pip install tidal-dl==2022.3.4.2 --no-cache-dir && \
	echo "************ setup SMA ************" && \
	echo "************ setup directory ************" && \
	mkdir -p ${SMA_PATH} && \
	echo "************ download repo ************" && \
	git clone https://github.com/mdhiggins/sickbeard_mp4_automator.git ${SMA_PATH} && \
	mkdir -p ${SMA_PATH}/config && \
	echo "************ create logging file ************" && \
	mkdir -p ${SMA_PATH}/config && \
	touch ${SMA_PATH}/config/sma.log && \
	chgrp users ${SMA_PATH}/config/sma.log && \
	chmod g+w ${SMA_PATH}/config/sma.log && \
	echo "************ install pip dependencies ************" && \
	python3 -m pip install --user --upgrade pip && \	
	pip3 install -r ${SMA_PATH}/setup/requirements.txt

# copy local files
COPY root/ /

WORKDIR /config

# ports and volumes
EXPOSE 8686
VOLUME /config /downloads-lidarr-extended /music /music-videos

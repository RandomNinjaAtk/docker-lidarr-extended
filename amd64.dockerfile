FROM linuxserver/lidarr:amd64-nightly
LABEL maintainer="RandomNinjaAtk"

ENV dockerTitle="lidarr-extended"
ENV dockerVersion="amd64-1.0.19"
ENV LANG=en_US.UTF-8
ENV autoStart=true
ENV configureLidarrWithOptimalSettings=false
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

RUN \
	echo "*** install packages ***" && \
	apk add -U --upgrade --no-cache \
		musl-locales \
		musl-locales-lang \
		flac \
		beets \
		jq \
		git \
		gcc \
		ffmpeg \
		python3-dev \
		libc-dev \
		py3-pip \
		yt-dlp && \
	echo "*** install python packages ***" && \
	pip install --upgrade \
		yq \
		pyacoustid \
		tidal-dl \
		r128gain \
		deemix

# copy local files
COPY root/ /

WORKDIR /config

# ports and volumes
EXPOSE 8686
VOLUME /config /music /music-videos /downloads

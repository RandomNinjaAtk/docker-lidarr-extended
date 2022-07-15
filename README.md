# [RandomNinjaAtk/lidarr-extended](https://github.com/RandomNinjaAtk/docker-lidarr-extended)
[![Docker Build](https://img.shields.io/docker/cloud/automated/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Pulls](https://img.shields.io/docker/pulls/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Stars](https://img.shields.io/docker/stars/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Hub](https://img.shields.io/badge/Open%20On-DockerHub-blue?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Discord](https://img.shields.io/discord/747100476775858276.svg?style=flat-square&label=Discord&logo=discord)](https://discord.gg/JumQXDc "realtime support / chat with the community." )

[![lidarr](https://github.com/linuxserver/docker-templates/raw/master/linuxserver.io/img/lidarr.png)](https://lidarr.audio/)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| multi | ✅ | latest |
| x86-64 | ✅ | amd64 |
| arm64v8 | ✅ | arm64v8 |
| arm32v7 | ✅ | arm32v7 |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Lidarr master (stable) + Extended Scripts |

## Application Setup

Access the webui at `<your-ip>:8686`, for more information check out [Lidarr](https://lidarr.audio/).

## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container. See the [wiki](https://github.com/RandomNinjaAtk/docker-amd/wiki) to understand how it works.

| Parameter | Function |
| --- | --- |
| `-p 8686` | The port for the Lidarr webinterface |
| `-v /config` | Configuration files for Lidarr. |
| `-v /downloads` | Path to your download folder location. (<strong>required path</strong>)|
| `-v /music` | Path to your music folder location. (<strong>required path</strong>)|
| `-v /music-videos` | Path to your music-videos folder location.|
| `-e TZ=America/New_York` | Specify a timezone to use EST, America/New_York. |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e autoStart=true` | true = enabled :: Runs script automatically on startup |
| `-e configureLidarrWithOptimalSettings=true` | true = enabled :: Automatically configures Lidarr with optimal settings |
| `-e searchSort=date` | date or ablum :: Sorts the missing/cutoff list by release date (newest -> oldest) or album type (album -> single) for processing the list |
| `-e audioFormat=native` | native or alac or mp3 or aac or opus :: native is the native download client file type, selected by the matching audio bitrate |
| `-e audioBitrate=lossless` | lossless or high or low or ### :: lossless = flac files, high = 320K, low = 128k/96k, ### = the output bitrate of converted lossless files to selected audioFormat that is not native, example: 192... |
| `-e requireQuality=true` | true = enabled :: Downloads will be required to have the requested file format |
| `-e audioLyricType=both` | both or explicit or clean :: both, is explicit perferred matching, explicit is explicit releases only matching and clean is clean releases only matching |
| `-e dlClientSource=both` | deezer, tidal or both :: set to both, to use both clients, tidal requires extra steps, view logging output |
| `-e arlToken=` | User ARL token for deemix client |
| `-e tidalCountryCode=US` | Country Code required for tidal |
| `-e addDeezerTopArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Artist Chart to your existing Lidarr instance |
| `-e addDeezerTopAlbumArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Album Chart to your existing Lidarr instance |
| `-e addDeezerTopTrackArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Track Chart to your existing Lidarr instance |
| `-e topLimit=10` | This setting controls the amount of Top Artist (Albums/Tracks/Artists) to add to Lidarr from Deezer |
| `-e addRelatedArtists=false` | true = enabled :: WARNING !!! WARNING !!! Enabling this can cause an endless loop of additional artists.... Enabling this will enable the extended script to automatically add artists that are related to your existing Lidarr artists from Deezer |
| `-e numberOfRelatedArtistsToAddPerArtist=5` | 1-20 :: This will limit the number of related artists to add per artist in your library :: Minimum is 1, Maximum is 20 |
| `-e beetsMatchPercentage=90` | 1-100 :: Set this to the minimum percentage required for Beets to match the downloaded album to a musicbrainz release :: Lower percentage is less restrictive |
| `-e plexUrl=http://x.x.x.x:32400` | ONLY used if PlexNotify.bash is used...|
| `-e plexToken=` | ONLY used if PlexNotify.bash is used... |

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=lidarr-extended \
  -v /path/to/config/files:/config \
  -v /path/to/preferred/local/directory:/downloads \
  -v /path/to/preferred/local/directory:/music \
  -v /path/to/preferred/local/directory:/music-videos \
  -p 8686:8686 \
  -e TZ=America/New_York \
  -e PUID=1000 \
  -e PGID=1000 \
  -e autoStart=true \
  -e configureLidarrWithOptimalSettings=true \
  -e searchSort=date \
  -e audioFormat=native \
  -e audioBitrate=lossless \
  -e requireQuality=true \
  -e audioLyricType=both \
  -e dlClientSource=both \
  -e arlToken=Token_Goes_Here \
  -e tidalCountryCode=US \
  -e addDeezerTopArtists=true \
  -e addDeezerTopAlbumArtists=true \
  -e addDeezerTopTrackArtists=true \
  -e topLimit=10 \
  -e addRelatedArtists=false \
  -e numberOfRelatedArtistsToAddPerArtist=5 \
  -e beetsMatchPercentage=90 \
  -e plexUrl=http://x.x.x.x:32400 \
  -e plexToken=Token_Goes_Here \
  --restart unless-stopped \
  randomninjaatk/lidarr-extended:latest
```


### docker-compose

Compatible with docker-compose v2 schemas.

```
version: "2.1"
services:
  lidarr-extended:
    image: randomninjaatk/lidarr-extended:latest
    container_name: lidarr-extended
    volumes:
      - /path/to/config/files:/config
      - /path/to/preferred/local/directory:/downloads
      - /path/to/preferred/local/directory:/music
      - /path/to/preferred/local/directory:/music-videos
    environment:
      - TZ=America/New_York
      - PUID=1000
      - PGID=1000
      - autoStart=true
      - configureLidarrWithOptimalSettings=true
      - searchSort=date
      - audioFormat=native
      - audioBitrate=lossless
      - requireQuality=true
      - audioLyricType=both
      - dlClientSource=both
      - arlToken=Token_Goes_Here
      - tidalCountryCode=US
      - addDeezerTopArtists=true
      - addDeezerTopAlbumArtists=true
      - addDeezerTopTrackArtists=true
      - topLimit=10
      - addRelatedArtists=false
      - numberOfRelatedArtistsToAddPerArtist=5
      - beetsMatchPercentage=90
      - plexUrl=http://x.x.x.x:32400
      - plexToken=Token_Goes_Here
    ports:
      - 8686:8686
    restart: unless-stopped
```

# Credits
- [LinuxServer.io Team](https://github.com/linuxserver/docker-lidarr)
- [Lidarr](https://lidarr.audio/)
- [Musicbrainz](https://musicbrainz.org/)
- [Docker multi-arch example](https://github.com/ckulka/docker-multi-arch-example)
- [Deemix download client](https://deemix.app/)
- [Tidal-Media-Downloader client](https://github.com/yaronzz/Tidal-Media-Downloader)
- [r128gain](https://github.com/desbma/r128gain)
- [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance)

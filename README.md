# [RandomNinjaAtk/lidarr-extended](https://github.com/RandomNinjaAtk/docker-lidarr-extended)
[![Docker Build](https://img.shields.io/docker/cloud/automated/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Pulls](https://img.shields.io/docker/pulls/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Stars](https://img.shields.io/docker/stars/randomninjaatk/lidarr-extended?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Docker Hub](https://img.shields.io/badge/Open%20On-DockerHub-blue?style=flat-square)](https://hub.docker.com/r/randomninjaatk/lidarr-extended)
[![Discord](https://img.shields.io/discord/747100476775858276.svg?style=flat-square&label=Discord&logo=discord)](https://discord.gg/JumQXDc "realtime support / chat with the community." )

[![lidarr](https://github.com/linuxserver/docker-templates/raw/master/linuxserver.io/img/lidarr.png)](https://lidarr.audio/)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Tag |
| :----: | --- |
| x86-64 | amd64-latest |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Lidarr nightly + Extended Scripts |

## Application Setup

Access the webui at `<your-ip>:8686`, for more information check out [Lidarr](https://lidarr.audio/).

## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container. See the [wiki](https://github.com/RandomNinjaAtk/docker-amd/wiki) to understand how it works.

| Parameter | Function |
| --- | --- |
| `-p 8686` | The port for the Lidarr webinterface |
| `-v /config` | Configuration files for Lidarr. |
| `-v /downloads` | Path to your download folder location. (<strong>required path</strong>)|
| `-v /music` | Path to your music folder location.|
| `-v /music-videos` | Path to your music-videos folder location.|
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e autoStart=true` | true = enabled :: Runs script automatically on startup |
| `-e configureLidarrWithOptimalSettings=true` | true = enabled :: Automatically configures Lidarr with optimal settings |
| `-e dlClientSource=both` | deezer, tidal or both :: set to both, to use both clients, tidal requires extra steps, view logging output |
| `-e arlToken=` | User ARL token for deemix client |
| `-e addDeezerTopArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Artist Chart to your existing Lidarr instance |
| `-e addDeezerTopAlbumArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Album Chart to your existing Lidarr instance |
| `-e addDeezerTopTrackArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Track Chart to your existing Lidarr instance |
| `-e topLimit=10` | This setting controls the amount of Top Artist (Albums/Tracks/Artists) to add to Lidarr from Deezer |
| `-e addRelatedArtists=false` | true = enabled :: WARNING !!! WARNING !!! Enabling this can cause an endless loop of additional artists.... Enabling this will enable the extended script to automatically add artists that are related to your existing Lidarr artists from Deezer |
| `-e plexUrl=http://x.x.x.x:32400` | ONLY used if PlexNotify.bash is used...|
| `-e plexToken=` | ONLY used if PlexNotify.bash is used... |

# Credits
- [Deemix download client](https://deemix.app/)
- [Musicbrainz](https://musicbrainz.org/)
- [Lidarr](https://lidarr.audio/)
- [r128gain](https://github.com/desbma/r128gain)
- [Tidal-Media-Downloader client](https://github.com/yaronzz/Tidal-Media-Downloader)

# Deprecated

This repository is now deprecated, will no longer be updated and is being archived. 

Scripts/Project has moved to: https://github.com/RandomNinjaAtk/arr-scripts

# [RandomNinjaAtk/lidarr-extended](https://github.com/RandomNinjaAtk/docker-lidarr-extended)

<table>
  <tr>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/lidarr.png" width="150"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/plus.png" width="75"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/music.png" width="150"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/plus.png" width="75"></td>
    <td><img src="https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/video.png" width="150"></td>
  </tr>
 </table>
 
 ### What is Lidarr Extended:

* Linuxserver.io Lidarr docker container (develop tag)
* Additional packages and scripts added to the container to provide additional functionality

Lidarr itself is not modified in any way, all changes that are pushed to Lidarr via public Lidarr API's. This is strictly Lidarr Develop branch

For more details, visit the [Wiki](https://github.com/RandomNinjaAtk/docker-lidarr-extended/wiki)

This containers base image is provided by: [linuxserver/lidarr](https://github.com/linuxserver/docker-lidarr)
 
 ### All Arr-Extended Apps:
* [sabnzbd-extended](https://github.com/RandomNinjaAtk/docker-sabnzbd-extended)
* [lidarr-extended](https://github.com/RandomNinjaAtk/docker-lidarr-extended)
* [radarr-extended](https://github.com/RandomNinjaAtk/docker-radarr-extended)
* [sonarr-extended](https://github.com/RandomNinjaAtk/docker-sonarr-extended)
* [readarr-extended](https://github.com/RandomNinjaAtk/docker-readarr-extended)
 
## Lidarr + Extended Script Features
* [Lidarr](https://lidarr.audio/) Develop (develop branch), base image provided by [LinuxServer.io Team](https://github.com/linuxserver/docker-lidarr)
* Downloading **Music** using online sources for use in popular applications (Plex/Kodi/Emby/Jellyfin): 
  * Completely automated
  * Searches for downloads based on Lidarr's album missing & cutoff list
  * Downloads using a third party download client automatically
  * FLAC (lossless) / MP3 (320/128) / AAC (320/96) Download Quality
  * Can convert Downloaded FLAC files to preferred audio format and bitrate before import into Lidarr
  * Notifies Lidarr to automatically import downloaded files
  * Music is properly tagged and includes coverart before Lidarr Receives them
  * Can pre-match and tag files using Beets
  * Can add Replaygain tags to tracks
  * Can add top artists from online services
  * Can add artists related to your artists in your existing Library
  * Can notify Plex application to scan the individual artist folder after successful import, thus increasing the speed of Plex scanning and reducing overhead
* Downloading **Music Videos** using online sources for use in popular applications (Plex/Kodi/Emby/Jellyfin):
  * Completely automated
  * Searches Lidarr Artists (musicbrainz) video recordings for videos to download
  * Saves videos in MKV format by default
  * Can save videos in MP4 format for Plex metadata support
  * Downloads using Highest available quality for both audio and video
  * Saves thumbnail of video locally for Plex/Kodi/Jellyfin/Emby usage
  * Embed subtitles if available matching desired language
  * Automatically Add Featured Music Video Artists to Lidarr
  * Writes metadata into Kodi/Jellyfin/Emby compliant NFO file
    * Tagged Data includes
      * Title (musicbrainz)
      * Year (upload year/release year)
      * Artist (Lidarr)
      * Thumbnail Image (service thumbnail image)
      * Artist Genere Tags (Lidarr)
  * Embeds metadata into Music Video file
    * Tagged Data includes
      * Title (musicbrainz)
      * Year (upload year/release year)
      * Artist (Lidarr)
      * Thumbnail Image (service thumbnail image)
      * Artist Genere Tags (Lidarr)
* Queue Cleaner Script
  * Automatically removes downloads that have a "warning" or "failed" status that will not auto-import into Lidarr, which enables Lidarr to automatically re-search for the album
      

### Audio & Video (Plex Example)
![](https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/plex.png)

### Video Example (Kodi)
![](https://github.com/RandomNinjaAtk/docker-lidarr-extended/raw/main/.github/kodi-music-videos.png)

## Supported Architectures

The architectures supported by this image are:

| Architecture | Available | Tag |
| :----: | :----: | ---- |
| multi | ✅ | latest |
| x86-64 | ✅ | amd64 |

## Version Tags

| Tag | Description |
| :----: | --- |
| latest | Lidarr (develop) + Extended Scripts |

## Application Setup

Access the webui at `<your-ip>:8686`, for more information check out [Lidarr](https://lidarr.audio/).

## Parameters

Container images are configured using parameters passed at runtime (such as those above). These parameters are separated by a colon and indicate `<external>:<internal>` respectively. For example, `-p 8080:80` would expose port `80` from inside the container to be accessible from the host's IP on port `8080` outside the container.

| Parameter | Function |
| --- | --- |
| `-p 8686` | The port for the Lidarr webinterface |
| `-v /config` | Configuration files for Lidarr. (<strong>required path</strong>)|
| `-v /downloads-lidarr-extended` | Path for online service downloads. (<strong>required path</strong>)|
| `-v /music` | Path to your music folder location.|
| `-v /music-videos` | Path to your music-videos folder location. (<strong>required path</strong>)|
| `-e TZ=America/New_York` | Specify a timezone to use EST, America/New_York. |
| `-e PUID=1000` | for UserID - see below for explanation |
| `-e PGID=1000` | for GroupID - see below for explanation |
| `-e scriptInterval=15m` | #s or #m or #h or #d :: s = seconds, m = minutes, h = hours, d = days :: Amount of time between each script run, when autoStart is enabled |
| `-e enableAudioScript=true` | true = enabled :: Enables the Audio script to run automatically |
| `-e enableVideoScript=true` | true = enabled :: Enables the Video script to run automatically |
| `-e videoDownloadTag=VALUE` | If VALUE is specified, only artists tagged with VALUE will have videos downloaded |
| `-e configureLidarrWithOptimalSettings=true` | true = enabled :: Automatically configures Lidarr with optimal settings |
| `-e searchSort=date` | date or album :: Sorts the missing/cutoff list by release date (newest -> oldest) or album type (album -> single) for processing the list |
| `-e audioFormat=native` | native or alac or mp3 or aac or opus :: native is the native download client file type, selected by the matching audio bitrate |
| `-e videoContainer=mkv` | mkv or mp4 :: Default = mkv.  mp4 allows Plex to read metadata.  Note mp4 videos may not be as high quality as mkv due to codec limitations of mp4. |
| `-e audioBitrate=lossless` | master or lossless or high or low or ### :: master = MQA/lossless flac files, lossless = flac files, high = 320K, low = 128k/96k, ### = the output bitrate of converted lossless files to selected audioFormat that is not native, example: 192... |
| `-e requireQuality=true` | true = enabled :: Downloads will be checked for quality and require to have the requested file format & quality |
| `-e enableReplaygainTags=true` | true = enabled :: Downloads will be tagged with Replaygain Metadata |
| `-e audioLyricType=both` | both or explicit or clean :: both, is explicit preferred  matching, explicit is explicit releases only matching and clean is clean releases only matching |
| `-e dlClientSource=deezer` | deezer, tidal or both :: set to both, to use both clients, tidal requires extra steps, view logging output [(Authing information)](https://github.com/RandomNinjaAtk/docker-lidarr-extended/issues/96#issuecomment-1280672421)|
| `-e arlToken=` | OPTIONAL (fallback using Freyr) - User ARL token for deemix client, see wiki: [Wiki URL](https://github.com/RandomNinjaAtk/docker-lidarr-extended/wiki/Extended-Audio-Script-Information#q-how-do-i-get-my-arl-token)|
| `-e tidalCountryCode=US` | Country Code required for tidal |
| `-e addDeezerTopArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Artist Chart to your existing Lidarr instance |
| `-e addDeezerTopAlbumArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Album Chart to your existing Lidarr instance |
| `-e addDeezerTopTrackArtists=false` | true = enabled :: Enabling this will enable the extended script to automatically add artists that are on the Deezer Top Track Chart to your existing Lidarr instance |
| `-e topLimit=10` | This setting controls the amount of Top Artist (Albums/Tracks/Artists) to add to Lidarr from Deezer |
| `-e addRelatedArtists=false` | true = enabled :: WARNING !!! WARNING !!! Enabling this can cause an endless loop of additional artists.... Enabling this will enable the extended script to automatically add artists that are related to your existing Lidarr artists from Tidal & Deezer |
| `-e numberOfRelatedArtistsToAddPerArtist=5` | 1-20 :: This will limit the number of related artists to add per artist in your library :: Minimum is 1, Maximum is 20 |
| `-e lidarrSearchForMissing=true` | true = enabled :: When artists are added, search for them using Lidarr's built in functionality |
| `-e addFeaturedVideoArtists=false` | true = enabled :: WARNING !!! WARNING !!! Enabling this can cause an endless loop of additional artists.... Enabling this will enable the extended Video script to automatically add Music Video Featured Artists to your existing Lidarr artists from IMVDB |
| `-e plexUrl=http://x.x.x.x:32400` | ONLY used if PlexNotify.bash is used...|
| `-e plexToken=` | ONLY used if PlexNotify.bash is used... (How to obtain token, visit: [Plex Support Article](https://support.plex.tv/articles/204059436-finding-an-authentication-token-x-plex-token)|
| `-e youtubeSubtitleLanguage=en` | Desired Language Code :: For guidence, please see yt-dlp documentation.
| `-e webHook=https://myhook.mydomain.com` | POST's to this URL on error events which prevent the script from working. Content is JSON `{"event":"eventtype", "message":"eventmessage", "content":"eventtype: eventmessage"}` |
| `-e enableQueueCleaner=true` | true = enabled :: Enables QueueCleaner Script that automatically removes stuck downloads that cannot be automatically imported on a 15 minute interval |
| `-e matchDistance=5` | The number of changes required to transform the searched album title into a possible found album title match... (0, requires a perfect match) |
| `-e enableBeetsTagging=true` | true = enabled :: Downloads will be processed and tagged by Beets |
| `-e beetsMatchPercentage=90` | 1-100 :: Set this to the minimum percentage required for Beets to match the downloaded album to a musicbrainz release :: Lower percentage is less restrictive |
| `-e retryNotFound=90` | ## :: Number of days between re-attempting the download of previously notfound albums |

## Usage

Here are some example snippets to help you get started creating a container.

### docker

```
docker create \
  --name=lidarr-extended \
  -v /path/to/config/files:/config \
  -v /path/to/preferred/local/directory:/downloads-lidarr-extended \
  -v /path/to/preferred/local/directory:/music \
  -v /path/to/preferred/local/directory:/music-videos \
  -p 8686:8686 \
  -e TZ=America/New_York \
  -e PUID=1000 \
  -e PGID=1000 \
  -e enableAudioScript=true \
  -e enableVideoScript=true \
  -e scriptInterval=15m \
  -e configureLidarrWithOptimalSettings=true \
  -e searchSort=date \
  -e audioFormat=native \
  -e audioBitrate=lossless \
  -e requireQuality=false \
  -e enableReplaygainTags=true \
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
  -e lidarrSearchForMissing=true \
  -e addFeaturedVideoArtists=false \
  -e plexUrl=http://x.x.x.x:32400 \
  -e plexToken=Token_Goes_Here \
  -e youtubeSubtitleLanguage=en \
  -e enableQueueCleaner=true \
  -e matchDistance=5 \
  -e enableBeetsTagging=true \
  -e beetsMatchPercentage=90 \
  -e retryNotFound=90 \
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
      - /path/to/preferred/local/directory:/downloads-lidarr-extended
      - /path/to/preferred/local/directory:/music
      - /path/to/preferred/local/directory:/music-videos
    environment:
      - TZ=America/New_York
      - PUID=1000
      - PGID=1000
      - enableAudioScript=true
      - enableVideoScript=true
      - scriptInterval=15m
      - configureLidarrWithOptimalSettings=true
      - searchSort=date
      - audioFormat=native
      - audioBitrate=lossless
      - requireQuality=false
      - enableReplaygainTags=true
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
      - lidarrSearchForMissing=true
      - addFeaturedVideoArtists=false
      - plexUrl=http://x.x.x.x:32400
      - plexToken=Token_Goes_Here
      - youtubeSubtitleLanguage=en
      - enableQueueCleaner=true
      - matchDistance=5
      - enableBeetsTagging=true
      - beetsMatchPercentage=90
      - retryNotFound=90
    ports:
      - 8686:8686
    restart: unless-stopped
```

# Credits
- [LinuxServer.io Team](https://github.com/linuxserver/docker-lidarr)
- [Lidarr](https://lidarr.audio/)
- [Docker multi-arch example](https://github.com/ckulka/docker-multi-arch-example)
- [Beets](https://beets.io/)
- [Deemix download client](https://deemix.app/)
- [Tidal-Media-Downloader client](https://github.com/yaronzz/Tidal-Media-Downloader)
- [r128gain](https://github.com/desbma/r128gain)
- [Algorithm Implementation/Strings/Levenshtein distance](https://en.wikibooks.org/wiki/Algorithm_Implementation/Strings/Levenshtein_distance)
- Icons made by <a href="http://www.freepik.com/" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon"> www.flaticon.com</a>
- [ffmpeg](https://ffmpeg.org/)
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [SMA Conversion/Tagging Automation Script](https://github.com/mdhiggins/sickbeard_mp4_automator)
- [Freyr](https://github.com/miraclx/freyr-js)

#!/usr/bin/env python3
from deezer import Deezer
import sys

if __name__ == '__main__':
    if len(sys.argv) > 1:
        dz = Deezer()
        releases = dz.gw.get_artist_discography_tabs(sys.argv[1], 100)
        for type in releases:
            for release in releases[type]:
                print(release['id'])

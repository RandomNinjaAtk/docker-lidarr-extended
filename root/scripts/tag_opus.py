#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
import enum
import argparse
from mutagen.oggopus import OggOpus

parser = argparse.ArgumentParser(description='Optional app description')
# Argument
parser.add_argument('--file', help='A required integer positional argument')
parser.add_argument('--songartist', help='A required integer positional argument')
parser.add_argument('--songalbumartist', help='A required integer positional argument')
args = parser.parse_args()

filename = args.file
artist = args.songartist
albumartist = args.songalbumartist

audio = OggOpus(filename)
try:
    audio.pop('ALBUMARTIST')
except:
    pass
try:
    audio.pop('ALBUMARTIST_CREDIT')
except:
    pass
try:
    audio.pop('ALBUMARTISTSORT')
except:
    pass
try:
    audio.pop('ALBUM_ARTIST')
except:
    pass
try:
    audio.pop('ALBUM ARTIST')
except:
    pass
try:
    audio.pop('ARTISTSORT')
except:
    pass

audio['ARTIST'] = [artist]
audio['ALBUMARTIST'] = [albumartist]

audio.pprint();
audio.save();
#print([filename]);
#print(artist);
#print(albumartist);
#print('Tagged!');

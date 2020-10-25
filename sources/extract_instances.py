#!/usr/bin/env python3

import sys

import xmlstarlet

output_files = sys.argv[1:]

rc = xmlstarlet.select(
    '-t',
    '-m',
    '//instance',
    '-v',
    '@name',
    '-nl',
    *output_files,
)
sys.exit(rc)

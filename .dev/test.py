#!/usr/bin/env python3
# encoding=utf8

# TESTING SCRIPT FOR roblox-ltgrab
from distutils.version import StrictVersion
import subprocess
import sys
import re

if sys.version_info[0] < 3:
    from urllib import unquote
else:
    from urllib.parse import unquote

import seesaw
from seesaw.util import find_executable

if StrictVersion(seesaw.__version__) < StrictVersion('0.8.5'):
    raise Exception('This pipeline needs seesaw version 0.8.5 or higher.')


###########################################################################
# Find a useful Wget+Lua executable.
#
# WGET_AT will be set to the first path that
# 1. does not crash with --version, and
# 2. prints the required version string

class HigherVersion:
    def __init__(self, expression, min_version):
        self._expression = re.compile(expression)
        self._min_version = min_version

    def search(self, text):
        for result in self._expression.findall(text):
            if result >= self._min_version:
                print('Found version {}.'.format(result))
                return True

WGET_AT = find_executable(
    'Wget+AT',
    HigherVersion(
        r'(GNU Wget 1\.[0-9]{2}\.[0-9]{1}-at\.[0-9]{8}\.[0-9]{2})[^0-9a-zA-Z\.-_]',
        'GNU Wget 1.21.3-at.20241119.01'
    ),
    [
        './wget-at',
        '/home/warrior/data/wget-at'
    ]
)

if not WGET_AT:
    raise Exception('No usable Wget+At found.')

USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0'
wget_args = [
    WGET_AT,
    '-U', USER_AGENT,
    '-nv',
    '--no-cookies',
    '--host-lookups', 'dns',
    '--hosts-file', '/dev/null',
    '--resolvconf-file', '/dev/null',
    '--dns-servers', '9.9.9.10,149.112.112.10,2620:fe::10,2620:fe::fe:10',
    '--reject-reserved-subnets',
    #'--prefer-family', ('IPv4' if 'PREFER_IPV4' in os.environ else 'IPv6'),
    '--content-on-error',
    '--lua-script', 'roblox-ltgrab.lua',
    '-o', 'wget_TESTING.log',
    '--no-check-certificate',
    '--output-document', 'wget_TESTING.tmp',
    '--truncate-output',
    '-e', 'robots=off',
    '--recursive', '--level=inf',
    '--no-parent',
    '--page-requisites',
    '--timeout', '30',
    '--connect-timeout', '1',
    '--tries', 'inf',
    '--domains', 'roblox.com',
    '--span-hosts',
    '--waitretry', '30',
    '--warc-file', 'TESTING',
    '--warc-header', 'operator: Archive Team',
    '--warc-header', 'x-wget-at-project-version: TESTING',
    '--warc-header', 'x-wget-at-project-name: roblox-ltgrab-TEST',
    '--warc-header', 'x-testing-purposes: TRUE',
    '--warc-dedup-url-agnostic',
]


def run(cmd):
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        universal_newlines=True,
        bufsize=1,
    )

    full_output = []
    for line in proc.stdout:
        sys.stdout.write(line)
        sys.stdout.flush()
        full_output.append(line)
    proc.stdout.close()

    returncode = proc.wait()
    return returncode, ''.join(full_output)


def test(url):
    # 4 is good, even for aborting items(?)
    # -6 is lua error
    # "Not writing to WARC." is really bad
    # "Aborting item" is much worse
    code, output = run(wget_args + [url])
    if code == -6:
        print("Test failed; Lua error! Check output.")
        sys.exit(1)
    elif code == 4:
        f = False
        if "Aborting item" in output:
            print("Test failed; item was aborted! Check output.")
            f = True
        if "Not writing to WARC." in output:
            print("Test failed; some requests were not written to WARC! Check output.")
            f = True
        if f is True:
            sys.exit(1)
    else:
        print(f"\nProcess exited with code {code!r}?")


urls = [
    # users
    "https://users.roblox.com/v1/users/1",  # roblox official account
    "https://users.roblox.com/v1/users/100",  # banned user
    "https://users.roblox.com/v1/users/365193",  # banned user w/ more stuff
    "https://users.roblox.com/v1/users/29666286",  # account with open inventory
    "https://users.roblox.com/v1/users/20005",  # account with private inventory

    # places
    "https://www.roblox.com/games/1818",  # crossroads (roblox owned)
    "https://www.roblox.com/games/920587237",  # adopt me
    "https://www.roblox.com/games/11358843975",  # not viewable on web

    # universes
    "https://games.roblox.com/v1/games?universeIds=13058",  # crossroads (roblox owned)
    "https://games.roblox.com/v1/games?universeIds=83858907",  # game with badges
    "https://games.roblox.com/v1/games?universeIds=4043086988",  # hidden from public

    # groups
    "https://groups.roblox.com/v1/groups/1",  # group
    "https://groups.roblox.com/v1/groups/4285658",  # locked group

    # badges
    "https://badges.roblox.com/v1/badges/14417332",  # badge (as asset type)
    "https://badges.roblox.com/v1/badges/2124421090",  # badge (as badge type)

    # catalog
    "https://catalog.roblox.com/v1/catalog/items/15837813902/details?itemType=Asset",
    "https://catalog.roblox.com/v1/catalog/items/102232291/details?itemType=Asset",  # unviewable, should abort in case it become available again

    # bundles
    "https://catalog.roblox.com/v1/catalog/items/2738/details?itemType=Bundle",

    # thumbnails
    "https://thumbnails.roblox.com/v1/assets?assetIds=1028826",  # catalog asset
    "https://thumbnails.roblox.com/v1/users/outfits?userOutfitIds=41789",  # user outfit
    "https://thumbnails.roblox.com/v1/users/avatar?userIds=1",  # user avatar
    "https://thumbnails.roblox.com/v1/users/avatar-bust?userIds=1",  # user avatar bust
    "https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=1",  # user avatar headshot
    "https://thumbnails.roblox.com/v1/groups/icons?groupIds=34370120",  # group icon
    "https://thumbnails.roblox.com/v1/bundles/thumbnails?bundleIds=2738",  # bundles
    "https://thumbnails.roblox.com/v1/badges/icons?badgeIds=3553892029567363",  # badge icon
    "https://thumbnails.roblox.com/v1/developer-products/icons?developerProductIds=120",  # developer product icon
    "https://thumbnails.roblox.com/v1/game-passes?gamePassIds=1",  # gamepasses
    "https://thumbnails.roblox.com/v1/games/icons?universeIds=7006259506",  # universe icons
    "https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=7006259506",  # universe thumbnails
    "https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=140340489",  # universe no thumbnails
    "https://thumbnails.roblox.com/v1/places/gameicons?placeIds=1818",  # game icon

    # animated thumbnail
    "https://thumbnails.roblox.com/v1/asset-thumbnail-animated?assetId=619509955",

    # economy api (rate limit of one request per minute)
    "https://economy.roblox.com/v2/assets/1818/details",  # place
    "https://economy.roblox.com/v2/assets/14417332/details",  # badge
    "https://economy.roblox.com/v2/assets/21117259/details",  # model
]
if __name__ == "__main__":
    for u in urls:
        print("-------------------")
        print(u)
        print("-------------------")
        test(u)
    print("All tests were successful.")

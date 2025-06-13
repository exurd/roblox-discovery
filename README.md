# roblox-discovery
*And now for something completely different*

This is for considering a long term project using the [ArchiveTeam Warrior and Tracker system](https://tracker.archiveteam.org/). This will archive Roblox's public metadata, APIs, website, etc. For clarification purposes, this will not archive the DevForum which uses [Discourse](https://wiki.archiveteam.org/index.php/Discourse).

This project was initally created in response to the Asset Delivery API [becoming unavailable to unauthenticated users](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403) with short notice. Grabbing what is available before the upcoming threat of [an asset privacy update](https://devforum.roblox.com/t/creator-action-required-new-asset-delivery-api-endpoints-for-community-tools/3574403/63) is now the project's main goal. The last time a ["privacy update"](https://devforum.roblox.com/t/update-changes-to-asset-privacy-for-audio/1715717) occurred, it caused massive amounts of historical audio to disappear.

The name of this project is due to two reasons; `roblox-grab` was [already taken](https://github.com/ArchiveTeam/roblox-grab), and `roblox-metadata-grab` doesn't really inform on what the focus of this repo is. TBH, `roblox-discovery-grab` is an okay compromise since `roblox-discovery-items` would need to exist as well.

The [Roblox Fandom Wiki](https://roblox.fandom.com/wiki/ID) currently states there are 8 types of IDs:

* User ID (`users/ID`)
* Group ID (`groups/ID`, `communities/ID`)
* Asset ID (Creator Marketplace: `library/ID` or `create.roblox.com/marketplace/asset/ID`, Marketplace: `catalog/ID`, Places: `games/ID`)
* Bundle ID (`bundles/ID`)
* Pass ID (`game-pass/ID`)
* Badge ID (`badges/ID`)
* Universe ID
* Developer Product ID


## Items that should be considered when creating the `-items` repo
*Mostly for me, but can be useful for others*
-   Every asset in the [Roblox Set Archive](https://sets.pizzaboxer.xyz/) (PostgreSQL dump is available.)
-   Every Roblox-related ID from ArchiveTeam's crawl of the [Roblox Forums](https://archive.org/details/archiveteam_roblox).
    -   *Don't have access to this, so it would be nice for someone at AT to help out. Just be wary of Roblox's old URL formats...*
-   Every asset created by the official [Roblox](https://www.roblox.com/users/1/profile) account, such as:
    -   [Catalog items](https://www.roblox.com/catalog?CreatorName=Roblox&IncludeNotForSale)
    -   Creator items like [Models](https://create.roblox.com/store/models?creatorName=Roblox) & [Decals](https://create.roblox.com/store/decals?creatorName=Roblox), etc.
    -   [Games](https://www.roblox.com/users/1/profile#!/creations)
    -   and any edge cases that may appear when checking for the account's inventory.
    -   *Psst, the AssetDelivery API still works on these assets without authentication; just thought you'd wanna know...*
-   The following official Roblox groups:
    -   [Official Group of Roblox](https://www.roblox.com/communities/1200769)
    -   [Roblox Video Stars](https://www.roblox.com/communities/4199740)
    -   [Roblox Interns](https://www.roblox.com/communities/2868472)
    -   [Roblox Presents](https://www.roblox.com/communities/4111519)
    -   [Roblox Arena Events](https://www.roblox.com/communities/7384468)
-   All uncopylocked places [listed on the ArchiveTeam Wiki](https://wiki.archiveteam.org/index.php/Roblox/uncopylocked)


## Usage

```zsh
➜  ~ docker build -t at-debug -f Dockerfile_debug . --platform=linux/amd64
➜  ~ docker run -it --entrypoint=/bin/bash -v /path/to/roblox-discovery:/data --platform=linux/amd64 -i at-debug
```

```bash
warrior@9fb3cfeac873:~$ cd /data
warrior@9fb3cfeac873:/data$ /home/warrior/data/wget-at \
-U "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:136.0) Gecko/20100101 Firefox/136.0" \
-nv \
--no-cookies \
--host-lookups='dns' \
--hosts-file='/dev/null' \
--resolvconf-file='/dev/null' \
--dns-servers='9.9.9.10,149.112.112.10,2620:fe::10,2620:fe::fe:10' \
--reject-reserved-subnets \
--content-on-error \
--lua-script 'roblox-discovery.lua' \
-o 'wget.log' \
--no-check-certificate \
--output-document 'wget.tmp' \
--truncate-output \
-e 'robots=off' \
--recursive \
--level=inf \
--no-parent \
--page-requisites \
--timeout 30 \
--connect-timeout 1 \
--tries inf \
--domains 'roblox.com' \
--span-hosts \
--waitretry 30 \
--warc-file 'test' \
--warc-header 'operator: Archive Team' \
--warc-header 'x-wget-at-project-version: TESTVERSION' \
--warc-header 'x-wget-at-project-name: TEST' \
--warc-dedup-url-agnostic \
"https://URLHERE.com/PLEASE/REPLACE.ME"
```

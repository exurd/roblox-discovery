# roblox-assetdelivery-grab
it's inbetween heaven and hell, but it's not purgatory

the main focus has been on the .lua file. pipeline.py file is untested.

## Items that should be put in `-items` repo
-   Every asset in the [Roblox Set Archive](https://sets.pizzaboxer.xyz/) (PostgreSQL dump available.)
-   All of the uncopylocked places that are [listed on the ArchiveTeam Wiki](https://wiki.archiveteam.org/index.php/Roblox/uncopylocked)
-   Every [Roblox-made](https://www.roblox.com/users/1/profile) asset (catalog, models, etc.)

## Usage, Example and Output

```zsh
➜  ~ docker build -t at-debug -f Dockerfile_debug . --platform=linux/amd64
➜  ~ docker run -it --entrypoint=/bin/bash -v /path/to/roblox-assetdelivery-grab:/data --platform=linux/amd64 -i at-debug
```

```bash
warrior@9fb3cfeac873:~$ cd /data
warrior@9fb3cfeac873:~$ cp /home/warrior/data/wget-at ./wget-at
warrior@9fb3cfeac873:/data$ ./wget-at \
-U "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0" \
-nv \
--no-cookies \
--host-lookups='dns' \
--hosts-file='/dev/null' \
--resolvconf-file='/dev/null' \
--dns-servers='9.9.9.10,149.112.112.10,2620:fe::10,2620:fe::fe:10' \
--reject-reserved-subnets \
--prefer-family 'IPv6' \
--content-on-error \
--no-http-keep-alive \
--lua-script 'roblox-assetdelivery.lua' \
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
"https://assetdelivery.roblox.com/v2/assetId/1818" \
"https://assetdelivery.roblox.com/v2/assetId/1818/version/1" \
"https://assetdelivery.roblox.com/v2/assetId/17383957280/version/0"


Archiving item asset:1818
1=200 https://assetdelivery.roblox.com/v2/assetId/1818
2=200 https://sc2.rbxcdn.com/3531bd1e0747fccbf5df1aea7e3fc903?__token__=exp=1743353980~acl=/3531bd1e0747fccbf5df1aea7e3fc903*~hmac=3ffa655c72a50a932c844cbd0292ed08f89a800f7f20dcd0400d7a7abc1dd2fa&Expires=1743353980&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9zYzIucmJ4Y2RuLmNvbS8zNTMxYmQxZTA3NDdmY2NiZjVkZjFhZWE3ZTNmYzkwMyoiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3NDMzNTM5ODB9fX1dfQ__&Signature=h9DwAAZtTIQRD9vjCWFwcJo18C9+DY4G717S1Hgwp6Udp/Fpk+wSLIRZfom/Zq+FlvSWeZ0pvMndRPf5kTidpJDJRgHpVCmT2ull+6Ax17JXqPr5CdcW8NljH5ZeR7NmMxZ70OxSYbRPBEEiV5xZ9/6ITFknXoW1SCNd94fNiPqYkgICHlLJljMWyeLI2V+/QZSIB0Y6eySbTYgakdl4VvoZsHkYa22/rXDRJNY298y4egSMLaYwBrChbykadTz4jvl33S1GvAundRToHdQMNPDMtySw7QzJ5CAClW5Ipc/OJN65XatKnYkX3ycsP8eNB0MgYyNyOg5Kh3ut5FvYVA==&Key-Pair-Id=K1NHM9527CRDAW
3=302 https://assetdelivery.roblox.com/v1/asset?id=1818
Archiving item assetver:1818_1
4=200 https://assetdelivery.roblox.com/v2/assetId/1818/version/1
5=200 https://sc5.rbxcdn.com/4caebf1df59f3e62f6cff6741433fb81?__token__=exp=1743353954~acl=/4caebf1df59f3e62f6cff6741433fb81*~hmac=2f274d80f10e0cc5f9ccaaf1d7301b103637238c9b1339391dcca72fc77f8137&Expires=1743353954&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9zYzUucmJ4Y2RuLmNvbS80Y2FlYmYxZGY1OWYzZTYyZjZjZmY2NzQxNDMzZmI4MSoiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3NDMzNTM5NTR9fX1dfQ__&Signature=CYFjGhQeXaO/sYVHtykvbgh2HY46FZle+qWdzZGwvUj5OoEV12Aivdxv18TFIh1/6oRVF8MIa77nmP/pxy7UuqXHLx7gcmKmMJStTwjbhzMGSerni1Rg8cDjrwicL1zdBqD3g1ab4oBLaBSWdyh7z6x40k3hTGTkod4Wq+FdVUEZS23mZfl5zZ5v0DKq+jkSqSBX3+R1/IyEff4Ozn71M17fSDLYBBecl1jHDkA5K1oQ6+tU+80j3cLjvAlsAcZRQzOaHsSJvf4ZRkqulLLr0Nd4bknXAdvSsy97vc5/MvTSwDRw0rui0YfvKZI2xDjksc84lCn7c+3ReaZTG0gEJA==&Key-Pair-Id=K1NHM9527CRDAW
6=302 https://assetdelivery.roblox.com/v1/asset?id=1818&version=1
Archiving item assetver:17383957280_0
7=200 https://assetdelivery.roblox.com/v2/assetId/17383957280/version/0
8=200 https://sc4.rbxcdn.com/838ac54dda421bcb9bc1ab5fd03702cf?__token__=exp=1743353951~acl=/838ac54dda421bcb9bc1ab5fd03702cf*~hmac=c919a735ddb33c4d10b343251e65b3a51084f4e067f54111f6f5969438cc9cd3&Expires=1743353951&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly9zYzQucmJ4Y2RuLmNvbS84MzhhYzU0ZGRhNDIxYmNiOWJjMWFiNWZkMDM3MDJjZioiLCJDb25kaXRpb24iOnsiRGF0ZUxlc3NUaGFuIjp7IkFXUzpFcG9jaFRpbWUiOjE3NDMzNTM5NTF9fX1dfQ__&Signature=hQblq3VuigBZCQbHBpmYQMXECwiQ5ctegc+CZdg7hCwAS2rfPdnHgqws0360jdYPxJ2/vN9roRrv9thL2qAFreKhVEQp8vID+0xxC7ZDQu/18STywV5rhJHs7n0Y15JkP+VvCugP9c7Xod7YaK38E04eUnfiUsB994eyeTMKwPf2tCj280ak5Hk8WXi1McZOTm4/InZKfh8qQpGE3v/a4SMOADWBLbfES33DRblGEd9R8d++OEJQCn8m3nSpYP8rjjbNbauxvBFpKBcrSUXQ34p9FwG1sCnq2sfZ0z5iQ0pWEniC/K7pX27amcbJ5CGhcPcjYZnt0ShiGDWTpnb3Ag==&Key-Pair-Id=K1NHM9527CRDAW
9=302 https://assetdelivery.roblox.com/v1/asset?id=17383957280&version=0
queuing for	urls
queuing for	roblox-marketplace-comments
found item	asset:1008743
found item	asset:1008744
found item	asset:1008745
found item	asset:1008748
found item	asset:1013852
found item	asset:1013853
found item	asset:1014655
found item	asset:1013850
found item	asset:1014653
found item	asset:1013851
found item	asset:1014611
found item	asset:1013849
found item	asset:1014609
found item	asset:1013854
found item	asset:1014610
found item	asset:998137795
found item	asset:1014617
found item	asset:966057249
found item	asset:1014618
found item	asset:1013125588
found item	asset:1014616
found item	asset:1014631
found item	asset:1014632
found item	asset:1014475
found item	assetver:1818_0
found item	asset:1014476
found item	assetver:1818_2
found item	asset:1014541
found item	assetver:1818_4
found item	asset:1014540
found item	assetver:1818_6
found item	asset:1014542
found item	assetver:1818_8
found item	asset:1014539
found item	assetver:1818_10
found item	asset:1014650
found item	assetver:1818_12
found item	asset:1014651
found item	assetver:1818_14
found item	asset:1014652
found item	assetver:1818_16
found item	asset:1014654
found item	assetver:1818_18
found item	assetver:1818_19
found item	assetver:1818_20
found item	assetver:1818_21
found item	assetver:1818_22
found item	assetver:1818_23
found item	assetver:1818_24
found item	assetver:1818_25
found item	assetver:1818_26
found item	assetver:1818_27
found item	assetver:1818_28
found item	assetver:1818_29
found item	assetver:1818_30
found item	assetver:1818_31
found item	assetver:1818_32
found item	assetver:1818_33
found item	assetver:1818_34
found item	assetver:1818_35
found item	assetver:1818_36
found item	assetver:1818_37
found item	assetver:1818_38
found item	assetver:1818_39
found item	assetver:1818_40
found item	asset:282758645
found item	asset:17178615286
found item	asset:346842666
found item	asset:6435190288
found item	asset:16648861999
found item	asset:10642815843
found item	asset:10642815647
found item	asset:13755568622
found item	asset:443028639
found item	asset:3209474534
found item	asset:3209478119
found item	asset:3209410410
found item	asset:394314025
found item	asset:11620658753
found item	asset:1014633
found item	assetver:1818_17
found item	assetver:1818_15
found item	assetver:1818_13
found item	assetver:1818_11
found item	assetver:1818_9
found item	assetver:1818_7
found item	assetver:1818_5
found item	assetver:1818_3
found item	assetver:1818_1
```

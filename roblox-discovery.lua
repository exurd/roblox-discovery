-- roblox-discovery.lua

local urlparse = require("socket.url")
local http = require("socket.http")
local https = require("ssl.https")
local cjson = require("cjson")
local utf8 = require("utf8")
local base64 = require("base64")
local ltn12 = require("ltn12")

local zlib = require("zlib")

local item_dir = os.getenv("item_dir")
local warc_file_base = os.getenv("warc_file_base")
local concurrency = tonumber(os.getenv("concurrency"))
local item_type = nil
local item_name = nil
local item_value = nil
local item_user = nil

local url_count = 0
local tries = 0
local downloaded = {}
local seen_200 = {}
local addedtolist = {}
local abortgrab = false
local killgrab = false
local logged_response = false

local discovered_outlinks = {}
local discovered_items = {}
local bad_items = {}
local ids = {}

local retry_url = false
local is_initial_url = true

abort_item = function(item)
  abortgrab = true
  --killgrab = true
  if not item then
    item = item_name
  end
  if not bad_items[item] then
    io.stdout:write("Aborting item " .. item .. ".\n")
    io.stdout:flush()
    bad_items[item] = true
  end
end

kill_grab = function(item)
  io.stdout:write("Aborting crawling.\n")
  killgrab = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

processed = function(url)
  if downloaded[url] or addedtolist[url] then
    return true
  end
  return false
end

discover_item = function(target, item)
  if not target[item] then
--print('discovered', item)
    target[item] = true
    return true
  end
  return false
end

find_item = function(url)
  local value = nil
  local type_ = nil
  for pattern, name in pairs({
    -- thumbnails --
    -- 3d --
    ["^https?://thumbnails%.roblox%.com/v1/users/outfit%-3d%?outfitId=([0-9]+)$"]="outfit_3dthumbs",
    ["^https?://thumbnails%.roblox%.com/v1/users/avatar%-3d%?userId=([0-9]+)$"]="avatar_3dthumbs",
    ["^https?://thumbnails%.roblox%.com/v1/users/assets%-thumbnail%-3d%?assetId=([0-9]+)$"]="asset_3dthumbs",
    
    -- misc --
    ["^https?://economy%.roblox%.com/v2/assets/([0-9]+)/details$"]="economy",
    ["^https?://catalog%.roblox%.com/v1/catalog/items/([0-9]+)/details%?itemType=Asset$"]="catalog",
    ["^https?://badges%.roblox%.com/v1/badges/([0-9]+)$"]="badge",
    ["^https?://catalog%.roblox%.com/v1/catalog/items/([0-9]+)/details%?itemType=Bundle$"]="bundle",

    -- users --
    ["^https?://users%.roblox%.com/v1/users/([0-9]+)$"]="user",
    ["^https?://www%.roblox%.com/games/([0-9]+)$"]="place",

    -- groups --
    ["^https?://groups%.roblox%.com/v1/groups/([0-9]+)$"]="group",
    ["^https?://groups%.roblox%.com/v2/groups/([0-9]+)/wall/posts%?sortOrder=Asc"]="groupwall",
    ["^https?://groups%.roblox%.com/v2/groups/([0-9]+)/wall/posts%?sortOrder=Desc"]="groupwall",

    -- games --
    ["^https?://games%.roblox%.com/v1/games%?universeIds=([0-9]+)$"]="universe",

    -- assetdel --
    ["^https?://assetdelivery%.roblox%.com/v2/assetId/([0-9]+)$"]="asset",  -- for discovering how many versions (asset:16688968)
    ["^https?://assetdelivery%.roblox%.com/v2/assetId/([0-9]+/version/[0-9]+)$"]="assetver"  -- for archiving  (assetver:16688968_0)
  }) do
    value = string.match(url, pattern)
    type_ = name
    if value then
      break
    end
  end
  if value and type_ then
    return {
      ["value"]=value,
      ["type"]=type_
    }
  end
end

set_item = function(url)
  found = find_item(url)
  if found then
    item_type = found["type"]
    item_value = found["value"]
    if item_type == "assetver" then
      item_value = string.gsub(item_value, "/version/", ":")
    end
    item_name_new = item_type .. ":" .. item_value
    if item_name_new ~= item_name then
      ids = {}
      ids[item_value] = true
      if string.match(item_value, ":") then
        ids[string.match(item_value, "^([^:]+):")] = true
      end
      abortgrab = false
      tries = 0
      retry_url = false
      is_initial_url = true
      item_name = item_name_new
      print("Archiving item " .. item_name)
    end
  end
end

allowed = function(url, parenturl)
  if ids[url] then
    return true
  end

  if string.match(url, "^https?://[^/]+/login%?")
    or string.match(url, "^https?://[^/]+/[a-z][a-z]/login%?")
    or string.match(url, "^https?://[^/]+/[nN]ew[lL]ogin%?")
    or string.match(url, "^https?://[^/]+/[a-z][a-z]/[nN]ew[lL]ogin%?")
    or string.match(url, "^https?://avatar%.roblox%.com/v1/avatar/assets/[0-9]+/wear$")
    or string.match(url, "^https?://avatar%.roblox%.com/v1/avatar/assets/[0-9]+/remove$")
    or string.match(url, "^https?://[^/]+/abusereport/")
    or string.match(url, "^https?://[^/]+/[a-z][a-z]/abusereport/")
    or string.match(url, "^https://apis%.roblox%.com/voting%-api/vote/asset/[0-9]+%?vote=")
    -- we want the translated infomation/websites as creators can add their own translations
    -- or string.match(url, "^https?://www%.roblox%.com/[a-z][a-z]/catalog/")
    -- or string.match(url, "^https?://www%.roblox%.com/[a-z][a-z]/users/")
    -- or string.match(url, "^https?://www%.roblox%.com/[a-z][a-z]/groups/")
    or string.match(url, "^https?://www%.roblox%.com/messages/compose%?") then
    return false
  end

  if string.match(url, "^https?://[^/]*roblox%.com/") then
    for _, pattern in pairs({
      "([0-9]+)"
    }) do
      for s in string.gmatch(url, pattern) do
        if ids[s] then
          return true
        end
      end
    end
  end

  -- https://tr.rbxcdn.com/180DAY-4ede3908c443b6e340f59e565f435136/500/280/Image/Jpeg/noFilter
  -- https://tr.rbxcdn.com/180DAY-4ab2f5dd6264a34f6fe7d898324bb244/700/700/Head/Png/noFilter
  -- https://tr.rbxcdn.com/%E2%AC%A7q%DE(%CEo  (???)
  -- https://tr.rbxcdn.com/180DAY-be8a76bdad030dc3dbe3a3d591197140/420/420/Image/Png/%90%E0%A8%88%B0w%8E%B7P%A1%CF]Z%5C%E2%08%D6gY%ADz%15Sc  (??????)
  -- the problem is that i don't know how many different *real* tr.rbxcdn urls out there (/image, /head, /food, /animal, /mineral, /fakecategoryhere, etc.)
  if string.match(url, "^https?://tr%.rbxcdn%.com/[0-9a-z-A-Z-]+/") and not string.find(url, "%%") then
    return true
  end
  -- https://t3.rbxcdn.com/30DAY-41efa70e75ed2d805cf492e8b3a46ce8
  -- https://t5.rbxcdn.com/30DAY-34319dd2696b20284c0c2d9ca2ff56e8
  -- https://t6.rbxcdn.com/30DAY-2cd469e44d5116ac3730244ab4788866
  -- https://t5.rbxcdn.com/30DAY-f5ee2e1490b12540925eab8fc395f455
  if string.match(url, "^https?://t[0-9]%.rbxcdn%.com/[0-9a-zA-Z%-]+$") and not string.find(url, "%%") then
    return true
  end
  

  -- if string.match(url, "^https?://[^/]*roblox.com/(?:[a-z]{2}/)?(?:catalog|bundles|users|groups|communities|badges)/.*$")
  --   or string.match(url, "^https?://creator%.roblox.com/store/asset.*$")  -- https://create.roblox.com/store/asset/53326/Neutral-Spawn-Location
  --   or string.match(url, "^https?://assetdelivery%.roblox%.com/v1/asset.*$")
  --   or string.match(url, "^https?://assetdelivery%.roblox%.com/v2/assetId.*$")
    -- or string.match(url, "^https?://sc[0-9]%.rbxcdn%.com/[a-z0-9]+?__token__") then
  -- if string.match(url, "^https?://tr%.rbxcdn%.com/") then  -- https://tr.rbxcdn.com/180DAY-4ede3908c443b6e340f59e565f435136/500/280/Image/Jpeg/noFilter
  --   return true
  -- end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if allowed(url, parent["url"])
    and not processed(url)
    and string.match(url, "^https://")
    and not addedtolist[url] then
    addedtolist[url] = true
    return true
  end

  return false
end

decode_codepoint = function(newurl)
  newurl = string.gsub(
    newurl, "\\[uU]([0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])",
    function (s)
      return utf8.char(tonumber(s, 16))
    end
  )
  return newurl
end

percent_encode_url = function(newurl)
  result = string.gsub(
    newurl, "(.)",
    function (s)
      local b = string.byte(s)
      if b < 32 or b > 126 then
        return string.format("%%%02X", b)
      end
      return s
    end
  )
  return result
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  local json = nil

  downloaded[url] = true

  if abortgrab then
    return {}
  end

  local function fix_case(newurl)
    if not newurl then
      newurl = ""
    end
    if not string.match(newurl, "^https?://[^/]") then
      return newurl
    end
    if string.match(newurl, "^https?://[^/]+$") then
      newurl = newurl .. "/"
    end
    local a, b = string.match(newurl, "^(https?://[^/]+/)(.*)$")
    return string.lower(a) .. b
  end

  local function check(newurl)
    if not newurl then
      newurl = ""
    end
    newurl = decode_codepoint(newurl)
    newurl = fix_case(newurl)
    local origurl = url
    if string.len(url) == 0 or string.len(newurl) == 0 then
      return nil
    end
    local url = string.match(newurl, "^([^#]+)")
    local url_ = string.match(url, "^(.-)[%.\\]*$")
    while string.find(url_, "&amp;") do
      url_ = string.gsub(url_, "&amp;", "&")
    end
    if not processed(url_)
      and not processed(url_ .. "/")
      and allowed(url_, origurl) then
--print('queued', url_)
      table.insert(urls, {
        url=url_
      })
      addedtolist[url_] = true
      addedtolist[url] = true
    end
  end

  local function checknewurl(newurl)
    if not newurl then
      newurl = ""
    end
    newurl = decode_codepoint(newurl)
    if string.match(newurl, "['\"><]") then
      return nil
    end
    if string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^/") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^%.%./") then
      if string.match(url, "^https?://[^/]+/[^/]+/") then
        check(urlparse.absolute(url, newurl))
      else
        checknewurl(string.match(newurl, "^%.%.(/.+)$"))
      end
    elseif string.match(newurl, "^%./") then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function checknewshorturl(newurl)
    if not newurl then
      newurl = ""
    end
    newurl = decode_codepoint(newurl)
    if string.match(newurl, "^%?") then
      check(urlparse.absolute(url, newurl))
    elseif not (
      string.match(newurl, "^https?:\\?/\\?//?/?")
      or string.match(newurl, "^[/\\]")
      or string.match(newurl, "^%./")
      or string.match(newurl, "^[jJ]ava[sS]cript:")
      or string.match(newurl, "^[mM]ail[tT]o:")
      or string.match(newurl, "^vine:")
      or string.match(newurl, "^android%-app:")
      or string.match(newurl, "^ios%-app:")
      or string.match(newurl, "^data:")
      or string.match(newurl, "^irc:")
      or string.match(newurl, "^%${")
    ) then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function set_new_params(newurl, data)
    for param, value in pairs(data) do
      if value == nil then
        value = ""
      elseif type(value) == "string" then
        value = "=" .. value
      end
      if string.match(newurl, "[%?&]" .. param .. "[=&]") then
        newurl = string.gsub(newurl, "([%?&]" .. param .. ")=?[^%?&;]*", "%1" .. value)
      else
        if string.match(newurl, "%?") then
          newurl = newurl .. "&"
        else
          newurl = newurl .. "?"
        end
        newurl = newurl .. param .. value
      end
    end
    return newurl
  end

  local function increment_param(newurl, param, default, step)
    local value = string.match(newurl, "[%?&]" .. param .. "=([0-9]+)")
    if value then
      value = tonumber(value)
      value = value + step
      return set_new_params(newurl, {[param]=tostring(value)})
    else
      return set_new_params(newurl, {[param]=tostring(default)})
    end
  end

  local function flatten_json(json)
    local result = ""
    for k, v in pairs(json) do
      result = result .. " " .. k
      local type_v = type(v)
      if type_v == "string" then
        v = string.gsub(v, "\\", "")
        result = result .. " " .. v .. ' "' .. v .. '"'
      elseif type_v == "table" then
        result = result .. " " .. flatten_json(v)
      end
    end
    return result
  end

  local function check_cursor(newurl, json, cursor_key)
    local cursor = json[cursor_key]
    if cursor ~= cjson.null then
      check(set_new_params(url, {["cursor"]=cursor}))
    end
  end

  local function runcom(command)
    local handle = io.popen(command)
    local output = handle:read("*a")
    handle:close()
    handle = nil

    return output
  end

  local function decompress_gzip(file)
    local status, output = pcall(function()
      local f = assert(io.open(file, "rb"))
      local compressed_data = f:read("*all")
      f:close()

      local stream = zlib.inflate()
      local output, eof, bytes_in, bytes_out = stream(compressed_data)
      return output
    end)
    if status then
      return output
    end
  end

  if allowed(url)
    and (status_code < 300 or status_code == 302) then
    html = read_file(file)

    -- economy api start --
    -- rate limit: 1 minute PER request
    -- ... :)
    -- https://economy.roblox.com/v2/assets/94625279904133/details
    -- roblox-made items can use the assetdelivery api! (for now...?)
    if string.match(url, "^https?://economy%.roblox%.com/v2/assets/[0-9]+/details$") then
      json = cjson.decode(html)
      if json["IconImageAssetId"] ~= 0 then
        -- TODO: add icon image asset to discovery
      end
      local creator_type = json["Creator"]["CreatorType"]
      local creator_id = json["Creator"]["CreatorTargetId"]
      discover_item(discovered_items, string.lower(creator_type) .. ":" .. tostring(creator_id))
      -- should i use catalog apis' collectableitemid or this ones'?
      -- if json["CollectibleItemId"] ~= nil then
      --   -- check("https://economy.roblox.com/v1/assets/1149615185/resale-data")
      --   -- https://apis.roblox.com/marketplace-sales/v1/item/8538d6c8-ce05-4f11-a358-1a12b8086e1c/resellers?limit=100
      --   discover_item(discovered_items, "collectableitem:" .. tostring(json["CollectibleItemId"]))
      -- end
    end

    if string.match(url, "^https?://economy%.roblox%.com/v2/assets/[0-9a-z%-]+/resale-data$") then
      json = cjson.decode(html)
      if json["IconImageAssetId"] ~= 0 then
        -- add icon image asset to discovery
      end
      local creator_type = json["Creator"]["CreatorType"]
      local creator_id = json["Creator"]["CreatorTargetId"]
      discover_item(discovered_items, string.lower(creator_type) .. ":" .. tostring(creator_id))
      if json["CollectibleItemId"] ~= nil then
        discover_item(discovered_items, "collectableitem:" .. tostring(json["CollectibleItemId"]))
      end
    end

    -- economy api start --

    -- assetdelivery start --

    -- hack: i need to grab `roblox-assetversionnumber` from the api,
    -- as the version 0 is the latest version and will avoid us from doing
    -- multiple requests just to find the last version.
    -- because wget-lua does not display response headers,
    -- i have to request the url in this script. yay!
    --
    -- hack hack: http.socket sucks, just use *normal* wget
    --
    -- hack hack hack: use v2 because it's json so it doesn't redirect
    -- which confuses this script and screws up the whole thing
    -- ik it's confusing using /assetId/* and /assetId/*/version/* as different items,
    -- but this whole wget-lua is alien to me and this just works

    local asset_id = url:match("/v2/assetId/([0-9]+)$")
    if asset_id then
      local command = 'wget -q -S -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/116.0" -O /dev/null "' .. url .. '" 2>&1'
      local output = runcom(command)

      local version_number = output:match("roblox%-assetversionnumber: (%d+)")

      if version_number then
        for i=0, version_number do
          discover_item(discovered_items, "assetver:" .. asset_id .. ":" .. i)
        end
      end
      check("https://assetdelivery.roblox.com/v1/asset?id="..asset_id)
      output = nil
    end

    local asset_id, version = string.match(url, "^https?://assetdelivery%.roblox%.com/v2/assetId/([0-9]+)/version/([0-9]+)$")
    if asset_id and version then
      check("https://assetdelivery.roblox.com/v1/asset?id="..asset_id.."&version="..version)
    end
    -- assetdelivery end --


    -- direct file (sc*) start --
    local function discover_roblox_assets(content)  -- plain text
      for match in content:gmatch("https?://www%.roblox%.com//?asset/?%?id=(%d+)") do
        discover_item(discovered_items, "asset:" .. match)
      end
      for match in content:gmatch("https?://www%.roblox%.com//?asset/?%?version=%d+&amp;id=(%d+)") do
        discover_item(discovered_items, "asset:" .. match)
      end
      for match in content:gmatch("rbxassetid://(%d+)") do
        discover_item(discovered_items, "asset:" .. match)
      end
    end

    local function check_roblox_type(content)
      local a = string.match(content, "<roblox .*</roblox>")
      if a then
        discover_roblox_assets(a)
        return true
      end
      local b = string.match(content, "<roblox!.*</roblox>")
      if b then
        print("Running the binary_to_xml binary.")
        local temp = file .. "_rblx.tmp"
        local f = io.open(temp, "w")
        f:write(b)
        f:close()

        local command = "./binary_to_xml < " .. temp
        local output = runcom(command)
        if not string.match(output, "[%s]") then
          error("No output retrieved.")
        end
        discover_roblox_assets(output)
        output = nil
        return true
      end
      local c = string.match(content, "{.*}")  -- fonts are contained in a json file
      if c then
        discover_roblox_assets(c)
      end
      return false
    end


    local function xor(a, b)
      local result = 0
      local bit_val = 1
      while a > 0 or b > 0 do
        local a_bit = a % 2
        local b_bit = b % 2
        if a_bit ~= b_bit then
          result = result + bit_val
        end
        a = math.floor(a / 2)
        b = math.floor(b / 2)
        bit_val = bit_val * 2
      end
      return result
    end


    function get_hash_url(hash)
      if string.find(hash, "mats%-thumbnails%.roblox%.com") then
        return hash
      end

      local st = 31
      for i = 1, #hash do
        st = xor(st, string.byte(hash, i))
      end
      return string.format("https://t%d.rbxcdn.com/%s", st % 8, hash)
    end


    -- thumbnails api start --
    local THUMBNAIL_SIZES = {"30x30", "42x42", "50x50", "60x62", "75x75", "110x110", "140x140", "150x150", "160x100", "160x600", "250x250", "256x144", "300x250", "304x166", "384x216", "396x216", "420x420", "480x270", "512x512", "576x324", "700x700", "728x90", "768x432", "1200x80", "330x110", "660x220"}
    local THUMBANIL_FORMAT = {"Png", "Jpeg", "Webp"}
    local function check_thumbnails(id, prefix)  -- prefix = "users/avatar?userIds="
      -- user outfit id:
      -- https://thumbnails.roblox.com/v1/users/outfits?userOutfitIds=41789&size=150x150&format=Png&isCircular=false
      -- https://thumbnails.roblox.com/v1/users/outfit-3d?outfitId=1

      -- user id:
      -- https://thumbnails.roblox.com/v1/users/avatar?userIds=1&size=30x30&format=Png&isCircular=false
      -- https://thumbnails.roblox.com/v1/users/avatar-3d?userId=1
      -- https://thumbnails.roblox.com/v1/users/avatar-bust?userIds=1&size=48x48&format=Png&isCircular=false
      -- https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=1&size=48x48&format=Png&isCircular=false

      -- universe id:
      -- https://thumbnails.roblox.com/v1/games/icons?universeIds=7006259506&returnPolicy=PlaceHolder&size=50x50&format=Png&isCircular=false
      -- https://thumbnails.roblox.com/v1/games/multiget/thumbnails?universeIds=7006259506&countPerUniverse=10&defaults=true&size=768x432&format=Png&isCircular=false

      -- place id:
      -- https://thumbnails.roblox.com/v1/places/gameicons?placeIds=1818&returnPolicy=PlaceHolder&size=50x50&format=Png&isCircular=false

      -- group id:
      -- https://thumbnails.roblox.com/v1/groups/icons?groupIds=34370120&size=150x150&format=Png&isCircular=false

      -- bundle id:
      -- https://thumbnails.roblox.com/v1/bundles/thumbnails?bundleIds=2738&size=150x150&format=Png&isCircular=false
      -- https://thumbnails.roblox.com/v1/users/outfit-3d?outfitId=18176448538

      -- badge id:
      -- https://thumbnails.roblox.com/v1/badges/icons?badgeIds=3553892029567363&size=150x150&format=Png&isCircular=false

      -- catalog assets:
      -- https://thumbnails.roblox.com/v1/assets-thumbnail-3d?assetId=746767604

      -- catalog(?) animation asset:
      -- https://thumbnails.roblox.com/v1/asset-thumbnail-animated?assetId=619509955

      -- developer product id:
      -- https://thumbnails.roblox.com/v1/developer-products/icons?developerProductIds=120&size=150x150&format=Png&isCircular=false

      -- gamepass id:
      -- https://thumbnails.roblox.com/v1/game-passes?gamePassIds=1&size=150x150&format=Png&isCircular=false

      -- asset id:
      -- https://thumbnails.roblox.com/v1/assets?assetIds=746767604&format=png&isCircular=false&size=150x150

      for _, thmb_format in THUMBANIL_FORMAT do
        for _, thmb_size in THUMBNAIL_SIZES do
          check("https://thumbnails.roblox.com/v1/"..prefix..id.."&size="..thmb_size.."&format="..thmb_format)
          check("https://thumbnails.roblox.com/v1/"..prefix..id.."&size="..thmb_size.."&format="..thmb_format.."&isCircular=false")
          local a, b = thmb_size:match("^(%d+)x(%d+)$")
          if a == b then  -- isCircular
            check("https://thumbnails.roblox.com/v1/"..prefix..id.."&size="..thmb_size.."&format="..thmb_format.."&isCircular=true")
          end
        end
      end
    end

    -- 3d thumbnails --
    if string.match(url, "^https?://thumbnails%.roblox%.com/v1/users/outfit%-3d%?outfitId=[0-9]+$")
    or string.match(url, "^https?://thumbnails%.roblox%.com/v1/assets%-thumbnail%-3d%?assetId=[0-9]+$")
    or string.match(url, "^https?://thumbnails%.roblox%.com/v1/users/avatar%-3d%?userId=[0-9]+$") then
      -- {"targetId":5135830016,"state":"Pending","imageUrl":null,"version":"TN3"}
      -- {"targetId":746767604,"state":"Completed","imageUrl":"https://t0.rbxcdn.com/180DAY-fe81470b075061200d032362af72a6d0","version":"TN3"}
      json = cjson.decode(html)
      if json["state"] == "Pending" then
        -- retry_url = true  -- TODO: test if this works (it doesn't?)
        -- downloaded[url] = false
        -- print(table.show(downloaded))
        -- check(url)
        print("Thumbnail for "..item_value.." is pending; redo item once it's finished.")
        abort_item()
      end
    end

    local function check_tr_for_json(text)
      local status, json = pcall(function()
        return cjson.decode(text)
      end)
      if status then
        return json
      end
      -- check if gzipped
      local output = decompress_gzip(text)
      local status, json = pcall(function()
        return cjson.decode(output)
      end)
      if status then
        return json
      end
      return nil
    end

    if string.match(url, "^https?://t[0-9]%.rbxcdn%.com/[0-9a-zA-Z%-]+$") then
      -- check if it's a json file
      json = check_tr_for_json(html)
      if json ~= nil then
        -- 3d json example:
        -- "mtl": "180DAY-fa9a8252422e551ee5d44b62f4c6569c",
        -- "obj": "180DAY-961ee508d617cf9d5bdd2ec134e9fa40",
        -- "textures": [
        --     "180DAY-e49efe685ca4dbbc3bc89af1a912f7dc"
        -- ]
        check(get_hash_url(tostring(json["mtl"])))
        check(get_hash_url(tostring(json["obj"])))
        for _, tex in pairs(json["textures"]) do
          check(get_hash_url(tostring(tex)))
        end
      end
    end
    -- thumbnails api end --


    if string.match(url, "^https?://sc[0-9].rbxcdn.com/[a-z0-9]+?__token__") then
      -- binary: `<roblox!` to `</roblox>`
      -- xml: `<roblox ` to `</roblox>`
      -- that one `!` will make the difference between heaven and hell

      -- heaven
      if not check_roblox_type(html) then
        -- hell

        -- check if html compressed
        local output = decompress_gzip(file)

        if not output:match("not in gzip format") then
          check_roblox_type(output)
        end
        output = nil
      end
    end
    -- direct file (sc*) end --

    -- catalog and bundles start --
    if string.match(url, "^https?://catalog%.roblox%.com/v1/catalog/items/[0-9]+/details%?itemType=Asset$") then
      check("https://catalog.roblox.com/v1/catalog/items/".. item_value .."/details?itemType=asset")  -- website's webpack and .js script have two different api requests, one being lower case and the other Sentence case...
      json = cjson.decode(html)
      local creator_id = json["creatorId"] or json["creatorTargetId"]
      discover_item(discovered_items, string.lower(json["creatorType"]) .. ":" .. tostring(creator_id))
      check("https://www.roblox.com/catalog/" .. item_value)
      check("https://web.roblox.com/catalog/" .. item_value)
      check("https://catalog.roblox.com/v1/favorites/assets/" .. item_value .. "/count")
      check("https://catalog.roblox.com/v2/recommendations/assets?assetId=" .. item_value .. "&assetTypeId=".. tostring(json["assetType"]) .."&numItems=7")
      check("https://catalog.roblox.com/v2/recommendations/assets?assetId=" .. item_value .. "&assetTypeId=".. tostring(json["assetType"]) .."&numItems=50")
      -- get 3d thumbnail
      check("https://thumbnails.roblox.com/v1/assets-thumbnail-3d?assetId=" .. item_value)
    end
    if string.match(url, "^https?://catalog%.roblox%.com/v1/catalog/items/[0-9]+/details%?itemType=Bundle$") then
      -- TODO: deal with `"collectibleItemId": "a109ad8b-7c6b-49bc-914b-f7712da5f53e",` in json
      check("https://catalog.roblox.com/v1/catalog/items/".. item_value .."/details?itemType=bundle")  -- webpack and .js script have two different api requests, one being lower case and the other Sentence case...
      json = cjson.decode(html)

      local creator_id = json["creatorId"] or json["creatorTargetId"]
      discover_item(discovered_items, string.lower(json["creatorType"]) .. ":" .. tostring(creator_id))

      check("https://www.roblox.com/bundles/" .. item_value)
      check("https://web.roblox.com/bundles/" .. item_value)

      check("https://catalog.roblox.com/v1/bundles/details?bundleIds[]=" .. item_value)
      check("https://catalog.roblox.com/v1/favorites/bundles/" .. item_value .. "/count")

      check("https://catalog.roblox.com/v2/recommendations/bundles?bundleId=" .. item_value .. "&bundleTypeId=".. tostring(json["bundleType"]) .."&numItems=7")
      check("https://catalog.roblox.com/v2/recommendations/bundles?bundleId=" .. item_value .. "&bundleTypeId=".. tostring(json["bundleType"]) .."&numItems=50")
      
      for _, item in pairs(json["bundledItems"]) do
        local idStr = string.format("%.0f", item["id"])
        if item["type"] == "Asset" then
          discover_item(discovered_items, "asset:" .. idStr)
        end
        if item["type"] == "UserOutfit" then
          discover_item(discovered_items, "outfit:" .. idStr)
        end
      end
    end
    if string.match(url, "^https?://catalog%.roblox%.com/v2/recommendations/assets%?") then
      json = cjson.decode(html)
      for _, new_id in pairs(json["data"]) do
        local assetIdStr = string.format("%.0f", new_id)
        discover_item(discovered_items, "asset:" .. assetIdStr)
      end
    end
    if string.match(url, "^https?://catalog%.roblox%.com/v2/recommendations/bundles%?") then
      json = cjson.decode(html)
      for _, new_id in pairs(json["data"]) do
        local assetIdStr = string.format("%.0f", new_id)
        discover_item(discovered_items, "bundle:" .. assetIdStr)
      end
    end
    -- catalog and bundles end --


    -- user start --
    if string.match(url, "^https?://users%.roblox%.com/v1/users/[0-9]+$") then
      check("https://www.roblox.com/users/" .. item_value)
      check("https://web.roblox.com/users/" .. item_value)
      check("https://users.roblox.com/v1/users/" .. item_value)
      check("https://accountinformation.roblox.com/v1/users/" .. item_value .. "/roblox-badges")

      -- user profile showcase items
      check("https://apis.roblox.com/showcases-api/v1/users/profile/playerassets-json?assetTypeId=10&userId=" .. item_value)
      check("https://apis.roblox.com/showcases-api/v1/users/profile/playerassets-json?assetTypeId=11&userId=" .. item_value)

      -- inventory check (rate limited)
      check("https://inventory.roblox.com/v1/users/" .. item_value .. "/can-view-inventory")

      -- check("https://games.roblox.com/v2/users/" .. item_value .. "/games")

      check("https://groups.roblox.com/v1/users/" .. item_value .. "/groups/roles")
      check("https://friends.roblox.com/v1/users/" .. item_value .. "/friends/count")

      check("https://friends.roblox.com/v1/users/" .. item_value .. "/followings/count")
      check("https://friends.roblox.com/v1/users/" .. item_value .. "/followers/count")

      check("https://avatar.roblox.com/v1/users/" .. item_value .. "/currently-wearing")


      -- check if user has any player badges (NOT THE ACTUAL BADGE INVENTORY GRAB)
      check("https://badges.roblox.com/v1/users/" .. item_value .. "/badges")


      check("https://friends.roblox.com/v1/metadata?targetUserId=" .. item_value)

      discover_item(discovered_items, "user:" .. tostring(item_value) .. ":favorites")  -- public regardless of inventory
      -- check("https://www.roblox.com/users/" .. item_value .. "/favorites")
      discover_item(discovered_items, "user:" .. tostring(item_value) .. ":games")

      -- current friend limit: 1,000 (not a huge limit yet so should be fine to do in user:)
      -- discover_item(discovered_items, "user:" .. tostring(item_value) .. ":friends")
      check("https://friends.roblox.com/v1/users/" .. item_value .. "/friends/find?limit=50")
      -- check("https://www.roblox.com/users/" .. item_value .. "/friends")

      discover_item(discovered_items, "user:" .. tostring(item_value) .. ":followers")
      discover_item(discovered_items, "user:" .. tostring(item_value) .. ":following")
      -- check("https://friends.roblox.com/v1/users/" .. item_value .. "/followings?sortOrder=Desc&limit=100")
      -- check("https://friends.roblox.com/v1/users/" .. item_value .. "/followers?sortOrder=Desc&limit=100")

      check("https://groups.roblox.com/v1/users/" .. item_value .. "/groups/primary/role")
      check("https://groups.roblox.com/v1/users/" .. item_value .. "/groups/roles?includeLocked=true")

      check("https://thumbnails.roblox.com/v1/users/avatar-3d?userId=" .. item_value)
    end

    -- {"canView":false}
    -- {"canView":true}
    if string.match(url, "^https?://inventory%.roblox%.com/v1/users/[0-9]+/can-view-inventory$") then
      json = cjson.decode(html)
      print(json["canView"])
      if json["canView"] == true then  -- TODO: TEST THIS PART
        discover_item(discovered_items, "user:" .. tostring(item_value) .. ":inventory")
        discover_item(discovered_items, "user:" .. tostring(item_value) .. ":bundles")
        discover_item(discovered_items, "user:" .. tostring(item_value) .. ":gamepasses")
      end
    end

    -- player badges in user inventory *CHECK*
    -- if empty, then user has not collected any badges or has a private inventory:
      -- {"previousPageCursor":null,"nextPageCursor":null,"data":[]}
    if string.match(url, "^https?://badges%.roblox%.com/v1/users/[0-9]+/badges$") then
      json = cjson.decode(html)
      if json["data"] ~= {} then
        discover_item(discovered_items, "user:" .. tostring(item_value) .. ":badges")
      end
    end

    if string.match(url, "^https?://friends%.roblox%.com/v1/users/[0-9]+/friends/find") then
      json = cjson.decode(html)
      for _, data in pairs(json["PageItems"]) do
        discover_item(discovered_items, "user:" .. tostring(data["id"]))
      end
      check_cursor(url, json, "NextCursor")
    end

    if string.match(url, "/v1/users/[0-9]+/follow[a-z]+%?") then
      json = cjson.decode(html)
      check_cursor(url, json, "nextPageCursor")
      for _, data in pairs(json["data"]) do
        discover_item(discovered_items, "user:" .. tostring(data["id"]))
      end
    end

    -- TODO: update favorites and inventory code
    -- if string.match(url, "^https?://www%.roblox%.com/users/[0-9]+/favorites$") then
    --   check("https://inventory.roblox.com/v1/users/" .. item_value .. "/categories/favorites")
    -- end
    -- if string.match(url, "/v1/users/[0-9]+/categories/favorites$") then
    --   json = cjson.decode(html)
    --   for _, data in pairs(json["categories"]) do
    --     for _, item_data in pairs(data["items"]) do
    --       if item_data["type"] == "AssetType" then
    --         check("https://www.roblox.com/users/favorites/list-json?assetTypeId=" .. tostring(item_data["id"]) .. "&cursor=&itemsPerPage=100&userId=" .. item_value)
    --         check("https://inventory.roblox.com/v2/users/".. item_value .."/inventory/" .. tostring(item_data["id"]) .. "?cursor=&limit=100&sortOrder=Desc")
    --       end
    --     end
    --   end
    -- end

    -- favorites
    if string.match(url, "/users/favorites/list%-json%?") then
      json = cjson.decode(html)
      for _, data in pairs(json["Data"]["Items"]) do
        -- hack: avoids asset:1.2280314827044e+14 (should this be done to user ids too?)
        local assetIdStr = string.format("%.0f", data["Item"]["AssetId"])
        discover_item(discovered_items, "asset:" .. assetIdStr)
        discover_item(discovered_items, "user:" .. tostring(data["Creator"]["Id"]))
      end
      check_cursor(url, json["Data"], "NextCursor")
    end
    -- inventory
    if string.match(url, "^https?://inventory%.roblox%.com/v2/users/[0-9]+/inventory/") then
      json = cjson.decode(html)
      for _, data in pairs(json["data"]) do
        local assetIdStr = string.format("%.0f", data["assetId"])
        discover_item(discovered_items, "asset:" .. assetIdStr)
        -- discover_item(discovered_items, "user:" .. tostring(data["Creator"]["Id"]))
      end
      check_cursor(url, json, "nextPageCursor")
    end

    if string.match(url, "/v1/users/[0-9]+/groups/roles$") then
      json = cjson.decode(html)
      for _, data in pairs(json["data"]) do
        discover_item(discovered_items, "group:" .. tostring(data["group"]["id"]))
        if data["group"]["owner"] ~= cjson.null then
          discover_item(discovered_items, "user:" .. tostring(data["group"]["owner"]["userId"]))
        end
      end
    end
    if string.match(url, "/v2/users/[0-9]+/games$") then
      json = cjson.decode(html)
      for _, data in pairs(json["data"]) do
        discover_item(discovered_items, string.lower(data["creator"]["type"]) .. ":" .. tostring(data["creator"]["id"]))
      end
    end
    if string.match(url, "/v1/users/[0-9]+/currently%-wearing$") then
      json = cjson.decode(html)
      for _, new_id in pairs(json["assetIds"]) do
        local assetIdStr = string.format("%.0f", new_id)
        discover_item(discovered_items, "asset:" .. assetIdStr)
      end
    end
    -- user end --


    -- group start --
    if string.match(url, "^https?://groups%.roblox%.com/v1/groups/[0-9]+$") then
      check("https://www.roblox.com/groups/" .. item_value)
      check("https://web.roblox.com/groups/" .. item_value)
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/roles")
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/membership")
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/membership?includeNotificationPreferences=true")
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/name-history")  -- TODO: pagecursor
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/relationships/allies?maxRows=50&sortOrder=Asc&startRowIndex=0")  -- nextrowindex(? interesting)
      check("https://groups.roblox.com/v1/featured-content/event?groupId=" .. item_value)  -- TODO: find group with event
      check("https://games.roblox.com/v2/groups/" .. item_value .. "/games?accessFilter=Public&cursor=&limit=50&sortOrder=Desc")
      check("https://apis.roblox.com/community-links/v1/groups/" .. item_value .. "/community")
      check("https://catalog.roblox.com/v1/search/items?category=All&creatorTargetId=" .. item_value .. "&creatorType=Group&cursor=&limit=50&sortOrder=Desc&sortType=Updated")
      check("https://groups.roblox.com/v1/groups/" .. item_value .. "/relationships/allies?maxRows=50&sortOrder=Asc&startRowIndex=0")
      
      -- check if group has wall posts
      -- great, if you request the group wall api too many times it will 429,
      -- and what seems to last for a very long time...
      -- check("https://groups.roblox.com/v2/groups/" .. item_value .. "/wall/posts")

      -- TODO: thumbnail here
    end
    if string.match(url, "/v1/groups/[0-9]+/name-history$") then
      json = cjson.decode(html)
      check_cursor(url, json, "nextPageCursor")
    end
    if string.match(url, "/v1/groups/[0-9]+/roles$") then
      json = cjson.decode(html)
      for _, role in pairs(json["roles"]) do  -- TODO: TEST
        discover_item(discovered_items, "group:" .. tostring(json["groupId"]) .. ":role:" .. tostring(role["id"]))
      end
    end
    if string.match(url, "/v1/groups/[0-9]+/roles/[0-9]+/users%?") then  -- group:*:role:*
      json = cjson.decode(html)
      check_cursor(url, json, "nextPageCursor")
      for _, data in pairs(json["data"]) do
        discover_item(discovered_items, "user:" .. tostring(data["userId"]))
      end
    end
    if string.match(url, "/v1/search/items%?") then
      json = cjson.decode(html)
      check_cursor(url, json, "nextPageCursor")
      for _, data in pairs(json["data"]) do
        discover_item(discovered_items, string.lower(data["itemType"]) .. ":" .. tostring(data["id"]))
      end
    end
    if string.match(url, "/v1/groups/[0-9]+/relationships/allies%?") then
      json = cjson.decode(html)
      local count = 0
      for _, data in pairs(json["relatedGroups"]) do
        count = count + 1
        discover_item(discovered_items, "group:" .. tostring(data["id"]))
      end
      if count > 0 then
        check(increment_param(url, "startRowIndex", "0", json["nextRowIndex"]))
      end
    end
    -- group walls
    if string.match(url, "/v2/groups/[0-9]+/wall/posts$") then  -- wall check
      json = cjson.decode(html)
      if not json["errors"] then
        discover_item(discovered_items, "groupwall:" .. item_value)
      end
    end
    if string.match(url, "/v2/groups/[0-9]+/wall/posts%?sortOrder=") then
      json = cjson.decode(html)
      check_cursor(url, json, "nextPageCursor")
      -- this is the rate limit message:
      -- {"errors":[{"code":4,"message":"You are posting too fast, please try again in a few minutes."}]}
      -- what...?
    end
    -- group end --

    -- badges start --
    if string.match(url, "^https?://badges%.roblox%.com/v1/badges/[0-9]+$") then
      json = cjson.decode(html)

      local iconIdStr = string.format("%.0f", json["iconImageId"])
      local uniIdStr = string.format("%.0f", json["awardingUniverse"]["id"])
      local rootPlaceIdStr = string.format("%.0f", json["awardingUniverse"]["rootPlaceId"])
      discover_item(discovered_items, "asset:" .. tostring(iconIdStr))
      discover_item(discovered_items, "universe:" .. tostring(uniIdStr))
      discover_item(discovered_items, "place:" .. tostring(rootPlaceIdStr))

      check("https://www.roblox.com/badges/" .. item_value)
      check("https://web.roblox.com/badges/" .. item_value)
      discover_item(discovered_items, "thumbnail:" .. tostring(item_value) .. ":badge")
      if tonumber(item_value) < 2124421087 then
        -- badges below this number were part of the asset types
        -- check asset apis and thumbnail api
        check("https://catalog.roblox.com/v1/favorites/assets/"..item_value.."/count")
        discover_item(discovered_items, "economy:" .. tostring(item_value))
        discover_item(discovered_items, "thumbnail:" .. tostring(item_value)..":asset")
      end
    end
    -- badges end --

    -- places start --
    if string.match(url, "^https?://www%.roblox%.com/games/[0-9]+/[0-9a-zA-Z-]+$") then
      check("https://web.roblox.com/games/" .. item_value)
      check("https://www.roblox.com/games/votingservice/" .. item_value)
      check("https://apis.roblox.com/universes/v1/places/"..item_value.."/universe")  -- universe: item

      -- TODO: https://www.roblox.com/games/getgamepassesinnerpartial?startIndex=0&maxRows=50&placeId=8737899170
      discover_item(discovered_items, "economy:" .. tostring(item_value))
      discover_item(discovered_items, "thumbnail:" .. tostring(item_value)..":place")
    end

    if string.match(url, "^https?://apis%.roblox%.com/universes/v1/places/[0-9]+/universe$") then
      json = cjson.decode(html)
      local uniIdStr = string.format("%.0f", json["universeId"])
      discover_item(discovered_items, "universe:" .. tostring(uniIdStr))
    end
    -- places end --

    -- universes start --
    if string.match(url, "^https?://games%.roblox%.com/v1/games%?universeIds=[0-9]+$") then
      check("https://www.roblox.com/games/badges-section/" .. item_value)
      check("https://web.roblox.com/games/badges-section/" .. item_value)
      check("https://games.roblox.com/v1/games/recommendations/game/" .. item_value .. "?maxRows=6")
      check("https://apis.roblox.com/asset-text-filter-settings/public/universe/" .. item_value)
      check("https://apis.roblox.com/asset-text-filter-settings/public/universe/" .. item_value)

      discover_item(discovered_items, "universe:" .. tostring(item_value) .. ":badges")
      -- TODO: https://badges.roblox.com/v1/universes/7006259506/badges?limit=100&sortOrder=Asc  -- unibadges: item
    end
    -- universes end --


    if string.match(html, "^%s*{") then
      if not json then
        json = cjson.decode(html)
      end
      if json["error"] then
        error()
      end
      html = html .. flatten_json(json)
    end
    for newurl in string.gmatch(string.gsub(html, "&quot;", '"'), '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(string.gsub(html, "&#039;", "'"), "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "[^%-]href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, '[^%-]href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, ":%s*url%(([^%)]+)%)") do
      checknewurl(newurl)
    end
    if not string.match(url, "%.mpd$") then
      html = string.gsub(html, "&gt;", ">")
      html = string.gsub(html, "&lt;", "<")
      for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
        checknewurl(newurl)
      end
    end
  end

  return urls
end

-- these urls are for checking purposes
-- shouldn't be written to warcs as they could
-- return errors if data is not accessible
local url_checks = {
  "/v2/groups/[0-9]+/wall/posts$",  -- wall check
}

wget.callbacks.write_to_warc = function(url, http_stat)
  status_code = http_stat["statcode"]
  set_item(url["url"])
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. " \n")
  io.stdout:flush()
  logged_response = true
  if not item_name then
    error("No item name found.")
  end
  is_initial_url = false
  for _, u in pairs(url_checks) do
    if string.match(url["url"], u) then
      return false
    end
  end
  if http_stat["statcode"] ~= 200
    and http_stat["statcode"] ~= 301
    and http_stat["statcode"] ~= 302
    and http_stat["statcode"] ~= 307 then  -- 18=307 https://www.roblox.com/users/29666286
    retry_url = true
    return false
  end
  if string.match(url["url"], "/users/favorites/list%-json%?") then
    local json = cjson.decode(read_file(http_stat["local_file"]))
    if json["Data"]["Items"] == nil or json["Data"]["Items"] == cjson.null then
      retry_url = true
      return false
    end
  end
  if abortgrab then
    print("Not writing to WARC.")
    return false
  end
  retry_url = false
  tries = 0
  return true
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]
  -- print(table.show({url=url, err=err, http_stat=http_stat }, "httploop_result"))

  if not logged_response then
    url_count = url_count + 1
    io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. " \n")
    io.stdout:flush()
  end
  logged_response = false

  if killgrab then
    return wget.actions.ABORT
  end

  set_item(url["url"])
  if not item_name then
    error("No item name found.")
  end

  if status_code >= 300 and status_code <= 399 then
    local newloc = urlparse.absolute(url["url"], http_stat["newloc"])
    if processed(newloc) or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end

  if seen_200[url["url"]] then
    print("Received data incomplete.")
    abort_item()
    return wget.actions.EXIT
  end

  if abortgrab then
    abort_item()
    return wget.actions.EXIT
  end

  if status_code == 0 or retry_url then
    io.stdout:write("Server returned bad response. ")
    io.stdout:flush()
    tries = tries + 1
    local maxtries = 8
    if status_code == 404 then
      maxtries = 0
    elseif status_code ~= 429 then
      maxtries = 1
    end
    if tries > maxtries then
      io.stdout:write(" Skipping.\n")
      io.stdout:flush()
      tries = 0
      abort_item()
      return wget.actions.EXIT
    end
    local sleep_time = math.random(
      math.floor(math.pow(2, tries-0.5)),
      math.floor(math.pow(2, tries))
    )
    io.stdout:write("Sleeping " .. sleep_time .. " seconds.\n")
    io.stdout:flush()
    os.execute("sleep " .. sleep_time)
    return wget.actions.CONTINUE
  else
    if status_code == 200 then
      seen_200[url["url"]] = true
    end
    downloaded[url["url"]] = true
  end

  tries = 0

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local function submit_backfeed(items, key)
    local tries = 0
    local maxtries = 5
    while tries < maxtries do
      if killgrab then
        return false
      end
      -- local body, code, headers, status = http.request(
      --   "https://legacy-api.arpa.li/backfeed/legacy/" .. key,
      --   items .. "\0"
      -- )
      -- if code == 200 and body ~= nil and cjson.decode(body)["status_code"] == 200 then
      --   io.stdout:write(string.match(body, "^(.-)%s*$") .. "\n")
      --   io.stdout:flush()
      --   return nil
      -- end
      -- io.stdout:write("Failed to submit discovered URLs." .. tostring(code) .. tostring(body) .. "\n")
      -- io.stdout:flush()
      -- os.execute("sleep " .. math.floor(math.pow(2, tries)))
      -- tries = tries + 1
      print("SIMULATING SEND TO BACKFEED!")
      return nil  -- simulate sending to backfeed
    end
    kill_grab()
    error()
  end

  -- local file = io.open(item_dir .. "/" .. warc_file_base .. "_bad-items.txt", "w")
  local file = io.open("_bad-items.txt", "w")  -- debug line; remove when ready
  for url, _ in pairs(bad_items) do
    file:write(url .. "\n")
  end
  file:close()
  for key, data in pairs({
    ["roblox-discovery-DEVELOPMENT"] = discovered_items,
    ["urls-ygcue8vtvkp47f8c"] = discovered_outlinks
  }) do
    print("queuing for", string.match(key, "^(.+)%-"))
    local items = nil
    local count = 0
    for item, _ in pairs(data) do
      print("found item", item)
      if items == nil then
        items = item
      else
        items = items .. "\0" .. item
      end
      count = count + 1
      if count == 1000 then
        submit_backfeed(items, key)
        items = nil
        count = 0
      end
    end
    if items ~= nil then
      submit_backfeed(items, key)
    end
  end
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if killgrab then
    return wget.exits.IO_FAIL
  end
  if abortgrab then
    abort_item()
  end
  return exit_status
end

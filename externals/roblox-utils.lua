-- utilities module for roblox-discovery.lua

local cjson = require("cjson")

package.cpath = './externals/?.so;' .. package.cpath
local zlib = require("zlib")

local mod = {}


function mod:test()
  print("Hello, world!")
end


function mod:runcom(command)
  local handle = io.popen(command)
  local output = nil
  if handle then
    output = handle:read("*a")
    handle:close()
    handle = nil
  end
  return output
end


function mod:decompress_gzip(file)
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


function mod:xor(a, b)
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


function mod:get_hash_url(hash)
  if string.find(hash, "mats%-thumbnails%.roblox%.com") then
    return hash
  end

  local st = 31
  for i = 1, #hash do
    st = mod:xor(st, string.byte(hash, i))
  end
  return string.format("https://t%d.rbxcdn.com/%s", st % 8, hash)
end


function mod:check_tr_for_json(text, file)
  local status, json = pcall(function()
    return cjson.decode(text)
  end)
  if status then
    return json
  end
  -- check if gzipped
  local output = mod:decompress_gzip(file)
  local status, json = pcall(function()
    return cjson.decode(output)
  end)
  if status then
    return json
  end
  return nil
end


return mod

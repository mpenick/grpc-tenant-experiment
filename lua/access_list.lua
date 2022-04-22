-- access_list.lua
local _M = {}

-- Import dependencies
local lrucache = require "resty.lrucache"
local http = require "http"
local json = require "json"
local ffi = require "ffi"

-- Setup lrucache
local c, err = lrucache.new(50000)  -- allow up to 50000 items in the cache
if not c then
    error("failed to create the cache: " .. (err or "unknown"))
end

-- geoip helper
function _M.ListToSet (list)
  local set = {}
  for _, l in ipairs(list) do set[l] = true end
  return set
end

-- check if IP originates from private IP space ("is internal")
function _M.is_private_ip(remote_addr)
  if (remote_addr:match("10.%d+.%d+.%d+") or remote_addr:match("192.168.%d+.%d+") or remote_addr:match("172.1[6789].%d+.%d+") or remote_addr:match("172.2%d.%d+.%d+") or remote_addr:match("172.3[01].%d+.%d+")) then
    return true
  end
end

-- Helper to call out to OPA
function _M.call_opa(addr, cluster_id, bypass_secret, pl_endpoint_id)
  local httpc = http.new()
  local res, err = httpc:request_uri("http://opa." .. cluster_id .. ".svc.cluster.local/v1/data/astra_access", {
      method = "POST",
      body = string.format('{"input": {"address":"%s", "cluster_id":"%s", "bypass_secret":"%s", "pl_endpoint_id":"%s"}}', addr, cluster_id, bypass_secret, pl_endpoint_id)
  })
  if err then
      return nil, err
  else
    local data = json.decode(res.body)
    if data["result"] == nil then
      return true  -- OPA may not have astra_access policy yet, avoid breaking access
    else
      return data["result"]["allow"], nil
    end
  end
end

-- Helper to identify IPs with geolocation restriction (P0 list, see SE-1120), OPA TBD
function _M.is_forbidden_country(remote_addr)
  if _M.is_private_ip(remote_addr) then
    return false
  end
  local forbidden_country = _M.ListToSet {"CU", "IR", "KP", "SD", "SY", "MM", "CN", "RU"}
  local forbidden_subdivision = _M.ListToSet {"Crimea"}
  local iso_code
  local subdivision
  local geo = require 'maxminddb'
  local res,err = geo.lookup(remote_addr)
  if not res then
    ngx.log(ngx.ERR,'Failed to lookup geo-location by ip: ',err)
  else
    -- find country/iso_code
    for k, v in pairs(res) do
      if (k == "country" and type(v) == "table") then
        for k, v in pairs(v) do
          if (k == "iso_code") then
            ngx.var.country_code = v
          end
        end
      end
      -- find subdivision
      if (k == "subdivisions" and type(v) == "table") then
        for k, v in pairs(v) do
          if (type(v) == "table") then
            for k, v in pairs(v) do
              if (k == "names" and type(v) == "table") then
                for k, v in pairs(v) do
                  if (k == "en") then
                    ngx.var.country_subdivision = v
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  if forbidden_country[ngx.var.country_code] or forbidden_subdivision[ngx.var.country_subdivision] then
    return true
  end
  return false
end

function _M.denyAccess(access_type)
  print('access denied')   -- Log denial (client addr and domain included in message)
  if access_type == "cql" then
    ngx.exit(403) -- Close the connection
  elseif access_type == "http" then
    ngx.status = ngx.HTTP_FORBIDDEN  -- Respond with a 403 status
    ngx.say("")  -- Empty the response body
  elseif access_type == "http2" then
    ngx.status = ngx.HTTP_FORBIDDEN  -- Respond with a 403 status
    ngx.say("")  -- Empty the response body
  else
    print('unknown access type: ' .. access_type)
    ngx.exit(403)
  end
end

function _M.leftShift(num, shift)
	return num * (2 ^ shift);
end

-- Convert 4 digits into a 32-bit unsigned integer
function _M.bufToUInt32(num1, num2, num3, num4)
	local num = 0;
	num = num + _M.leftShift(num1, 24);
	num = num + _M.leftShift(num2, 16);
	num = num + _M.leftShift(num3, 8);
	num = num + num4;
	return num;
end

-- Convert 8 digits into a 64-bit unsigned integer
function _M.bufToUInt64(num1, num2, num3, num4, num5, num6, num7, num8)
	local num = 0ull; -- Set num to be an unsigned 64-bit integer to force cast other integers
	num = num + _M.leftShift(num1, 56);
	num = num + _M.leftShift(num2, 48);
	num = num + _M.leftShift(num3, 40);
	num = num + _M.leftShift(num4, 32);
	num = num + _M.leftShift(num5, 24);
	num = num + _M.leftShift(num6, 16);
	num = num + _M.leftShift(num7, 8);
	num = num + num8;
	return num;
end

-- Check whether a given address is allowed access to the cluster
function _M.check_access(cluster_id, access_type, bypass_secret, traffic_type)

  local remote_addr = ngx.var.remote_addr
  local cache_key = remote_addr .. "_" .. cluster_id
  local allow = true
  local pl_enabled = false
  local is_forbidden = false

  local pl_endpoint_id = ""
  local tlv_data = ""

  if traffic_type == "privatelink" then
    -- Check length of known TLV headers
    if ngx.var.proxy_protocol_tlv_0xEA ~= nil and #ngx.var.proxy_protocol_tlv_0xEA > 0 then      -- AWS
      -- https://github.com/slact/nginx_proxy_protocol_tlv_vars#proxy_protocol_tlv_aws_vpce_id-parsed-from-type-0xea
      pl_endpoint_id = ngx.var.proxy_protocol_tlv_AWS_VPCE_ID
    elseif ngx.var.proxy_protocol_tlv_0xEE ~= nil and #ngx.var.proxy_protocol_tlv_0xEE > 0 then  -- Azure
      tlv_data = ngx.var.proxy_protocol_tlv_0xEE
      -- Azure header is a 5-byte value, where the last 4 bytes are the linkID written in little-endian order
      -- We pass the right-to-left characters to a Int32 function after converting them into their numeric representation
      pl_endpoint_id = _M.bufToUInt32(string.byte(tlv_data:sub(5,5)), string.byte(tlv_data:sub(4,4)), string.byte(tlv_data:sub(3,3)), string.byte(tlv_data:sub(2,2)))
      pl_endpoint_id = string.format("%d", pl_endpoint_id) -- Convert to string, avoiding scientific notation
    elseif ngx.var.proxy_protocol_tlv_0xE0 ~= nil and #ngx.var.proxy_protocol_tlv_0xE0 > 0 then  -- GCP
      tlv_data = ngx.var.proxy_protocol_tlv_0xE0
      pl_endpoint_id = _M.bufToUInt64(string.byte(tlv_data:sub(1,1)), string.byte(tlv_data:sub(2,2)), string.byte(tlv_data:sub(3,3)), string.byte(tlv_data:sub(4,4)),
                                      string.byte(tlv_data:sub(5,5)), string.byte(tlv_data:sub(6,6)), string.byte(tlv_data:sub(7,7)), string.byte(tlv_data:sub(8,8)))
      pl_endpoint_id = string.sub(tostring(ffi.new("uint64_t", pl_endpoint_id)), 1, -4)
    else
      print("tlv data missing or unhandled")
      _M.denyAccess(access_type)
      return
    end
    ngx.var.pl_endpoint_id = pl_endpoint_id        -- Send the parsed ConnectionID back to nginx to record in the usage log
    cache_key = cache_key .. "_" .. pl_endpoint_id -- Include endpoint id at end of cache key
    pl_enabled = true
  end
  local data, stale_data = c:get(cache_key)

  if not data then
    -- Check if request is coming from internal subnet (ie, webcql), except private link which needs to be validated against OPA
    if not pl_enabled and _M.is_private_ip(remote_addr) then
      print("allowing internal traffic")
      c:set(cache_key, { allow = allow }, 3600)
      allow = true
    else
      -- print("no cache data for: " .. cache_key)
      is_forbidden = _M.is_forbidden_country(remote_addr)
      if not is_forbidden then
        allow, err = _M.call_opa(remote_addr, cluster_id, bypass_secret, pl_endpoint_id)
        if not err then
          c:set(cache_key, { allow = allow }, 300)
        else
          print("err reading OPA: " .. err)
          if stale_data then
            print("using stale cache data for key: " .. cache_key .. ", allow: " .. tostring(data["allow"]))
            allow = stale_data["allow"]
          else
            allow = true  -- TODO: How do we want to proceed if OPA is unreachable and there's no stale data?
          end
        end
      -- country forbidden based on geo-location
      else
        allow = false
        c:set(cache_key, { allow = allow }, 300)
      end
    end
  else
    -- print("found cached entry for key: " .. cache_key .. ", allow: " .. tostring(data["allow"]))
    allow = data["allow"]
  end

  if not allow then
    _M.denyAccess(access_type)
  end

end

return _M

-- Twitter API
-- Depends on https://github.com/somesocks/lua-lockbox


-- Application specific
-- generated and obtained from https://apps.twitter.com
local app_consumer_key = "dVJWptRAumKSM5r9DY2zoL9No"
local app_consumer_secret = "27hxObUkFS5Yqu0zO4uHx1Gjh4zh2LJbKEDJQ457kx3r9Fpzz7"
-- this access token can be used to make api requests on your own accounts behalf
local account_access_token = "345353224-iixJTqNLWlZFMsQif6kisDuPKIno9so2fmZYTAqN"
local account_access_token_secret = "gUelacqps4NVe0CPH5fUrudZq5yc8aMLO4j6mzEcNJLMM"


local DROPBOX = os.getenv("HOME").."/Documents/Dropbox.assets"
package.path = package.path..";"..DROPBOX.."/?.lua"

local array_encode = require("lockbox.util.array").fromString
local stream_encode = require("lockbox.util.stream").fromString
local base_64_encode = require("lockbox.util.base64").fromArray
local hmac = require "lockbox.mac.hmac"
local sha1 = require "lockbox.digest.sha1"


local function rfc_3986_encode(src)
    if not src then return "" end
    return tostring(src:gsub("[^-._~%w]", function(char)
        return string.format('%%%02X', char:byte()):upper()
    end))
end


local function generate_random_string(length)
    local charset = "qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM0123456789"
    local rndnum  = math.random(1, #charset)
    local rndchar = charset:sub(rndnum, rndnum)
    if length > 0 then return generate_random_string(length - 1)..rndchar end
    return ""
end


local function build_signature(method, url, parameters, consumer_secret, access_token_secret)
    local list = {}
    local order = {}
    local key = rfc_3986_encode(consumer_secret).."&"..rfc_3986_encode(access_token_secret)
    local signature = ""
    
    for key, value in pairs(parameters) do
        local k = rfc_3986_encode(key)
        list[k] = rfc_3986_encode(tostring(value))
        table.insert(order, k)
    end
    
    table.sort(order)
    
    for pos, key in ipairs(order) do
        local value = list[key]
        signature = signature.."&"..key.."="..value
    end
    
    signature = method:upper().."&"..rfc_3986_encode(url).."&"..rfc_3986_encode(signature:sub(2))
    
    return base_64_encode(
        hmac()
        .setBlockSize(64)
        .setDigest(sha1)
        .setKey(array_encode(key))
        .init()
        .update(stream_encode(signature))
        .finish()
        .asBytes()
    )
end


local function build_authorization_header(parameters)
    local prefix = "oauth_"
    local header = "OAuth"
    
    for key, value in pairs(parameters) do
        if key:find(prefix) then
            header = header..' '..rfc_3986_encode(key)..'="'..rfc_3986_encode(tostring(value))..'",'
        end
    end
    
    return header:sub(1, -2)
end

local function build_query_url(url, parameters)
    local prefix = "oauth_"
    local request = url.."?"
    
    for key, value in pairs(parameters) do
        if not key:find(prefix) then
            request = request..key.."="..tostring(value).."&"
        end
    end
    
    return request:sub(1, -2)
end


local function request_account_access_token()
    local url = {
        {"POST", "https://api.twitter.com/oauth/request_token"},
        {"GET", "https://api.twitter.com/oauth/authorize"},
        {"POST", "https://api.twitter.com/oauth/access_token"}
    }
    
    
    local request = {"POST", "https://api.twitter.com/oauth/request_token", {
        oauth_callback = "oob", -- pin based authentication
        oauth_version = "1.0",
        oauth_nonce = generate_random_string(32),
        oauth_timestamp = os.time() + 1,
        oauth_consumer_key = app_consumer_key,
        oauth_signature_method = "HMAC-SHA1",
        oauth_signature
    }}
    
    local authorize = {"GET", "https://api.twitter.com/oauth/authorize"}
    local access = {"POST", "https://api.twitter.com/oauth/access_token"}

end


local function report_request_success(response, status, headers)
    print(status, type(headers))
    pretty(headers)
    --(json.decode(response))
    print(response)
end


local function report_request_failure(error)
    print(error)
end


local function request_api(method, url, parameters)
    parameters.oauth_version = "1.0"
    parameters.oauth_nonce = generate_random_string(32)
    parameters.oauth_timestamp = os.time() + 1
    parameters.oauth_consumer_key = app_consumer_key
    parameters.oauth_token = account_access_token
    parameters.oauth_signature_method = "HMAC-SHA1"
    parameters.oauth_signature = build_signature(method, url, parameters, app_consumer_secret, account_access_token_secret)
    
    http.request(build_query_url(url, parameters), report_request_success, report_request_failure, {
        method = method:upper(),
        headers = {Authorization = build_authorization_header(parameters)}
    })
end


function setup()
    --request_api("GET", "https://api.twitter.com/1.1/statuses/home_timeline.json", {})
    request_api("GET", "https://api.twitter.com/1.1/statuses/user_timeline.json", {count = 1})
    --request_api("GET", "https://api.twitter.com/1.1/followers/list.json", {})
    --request_api("GET", "https://api.twitter.com/1.1/statuses/retweets_of_me.json", {})
    --request_api("GET", "https://api.twitter.com/1.1/favorites/list.json", {})
end


function draw()
    background(40, 40, 50)
end

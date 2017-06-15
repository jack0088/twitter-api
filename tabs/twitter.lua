-- Twitter Codea Client
-- Dependencies: https://github.com/somesocks/lua-lockbox
-- (c) 2017 by kontakt@herrsch.de


-- Each application musst have an identifier
-- generate yours at https://apps.twitter.com
local app_consumer_key = "dVJWptRAumKSM5r9DY2zoL9No"
local app_consumer_secret = "27hxObUkFS5Yqu0zO4uHx1Gjh4zh2LJbKEDJQ457kx3r9Fpzz7"

-- An access_token can be used to make api requests on behalf of a user account
-- by default ANY user is allowed to connect to this application
local account_access_token = readLocalData("account_access_token", "")
local account_access_token_secret = readLocalData("account_access_token_secret", "")

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


function printf(t, indent)
    if not indent then indent = "" end
    local names = {}
    for n, g in pairs(t) do
        table.insert(names, n)
    end
    table.sort(names)
    for i, n in pairs(names) do
        local v = t[n]
        if type(v) == "table" then
            if v == t then -- prevent endless loop on self reference
                print(indent..tostring(n)..": <-")
            else
                print(indent..tostring(n)..":")
                printf(v, indent.."   ")
            end
        elseif type(v) == "function" then
            print(indent..tostring(n).."()")
        else
            print(indent..tostring(n)..": "..tostring(v))
        end
    end
end


local function build_authorization_header(method, url, parameters)
    parameters = parameters or {}
    parameters.oauth_version = "1.0"
    parameters.oauth_nonce = generate_random_string(32)
    parameters.oauth_timestamp = os.time() + 1
    parameters.oauth_consumer_key = app_consumer_key
    parameters.oauth_token = account_access_token
    parameters.oauth_signature_method = "HMAC-SHA1"
    
    local list = {}
    local order = {}
    local key = rfc_3986_encode(app_consumer_secret).."&"..rfc_3986_encode(account_access_token_secret)
    local signature = ""
    local prefix = "oauth_"
    local header = "OAuth"
    
    -- Build "oauth_signature"
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
    
    -- Sign/Encode "oauth_signature" with key
    parameters.oauth_signature = base_64_encode(
        hmac()
        .setBlockSize(64)
        .setDigest(sha1)
        .setKey(array_encode(key))
        .init()
        .update(stream_encode(signature))
        .finish()
        .asBytes()
    )
    
    -- Build complete "Authorization" header string
    for key, value in pairs(parameters) do
        if key:find(prefix) then
            header = header..' '..rfc_3986_encode(key)..'="'..rfc_3986_encode(tostring(value))..'",'
        end
    end
    
    return header:sub(1, -2), parameters
end


local function build_query_url(url, parameters)
    local prefix = "oauth_"
    local request = url.."?"
    parameters = parameters or {}
    
    for key, value in pairs(parameters) do
        if not key:find(prefix) then
            request = request..key.."="..tostring(value).."&"
        end
    end
    
    return request:sub(1, -2)
end


-- This is used for debugging purposes - comment out to disable outputs
local function request_report(data, status, headers)
    ---[[
    if not status and not headers then print(data) return false end
    print("status:", status)
    print("headers:")
    printf(headers)
    print(data)
    return true
    --]]
end


-- Use this method to perform twitter api requests
local function request_api(method, url, parameters, callback_success, callback_failure)
    http.request(build_query_url(url, parameters), callback_success or request_report, callback_failure or request_report, {
        method = method:upper(),
        headers = {
            Authorization = build_authorization_header(method, url, parameters),
            ["Content-Type"] = "application/x-www-form-urlencoded"
        }
    })
end


-- Use this method to obtain authorization for requests on behalf of an user
-- This will override previous user!
-- You should customize this method to your needs. Notice that you have to provide a PIN input field inside your app interface.
local function request_access(callback_success, callback_failure)
    local function parse_response(raw_string)
        local parameters = {}
        local charset = "[^%&=]*"
        raw_string:gsub("("..charset..")=("..charset..")", function(key, value) parameters[key] = value end)
        return parameters
    end
    
    -- Pin-Based Authorization
    saveLocalData("account_access_token", nil) -- reset privious handshake
    saveLocalData("account_access_token_secret", nil)
    
    request_api("POST", "https://api.twitter.com/oauth/request_token", {oauth_callback = "oob", x_auth_access_type = "read-write-directmessages"}, function(response, status, headers)
        local parameters = parse_response(response)
        if status == 200 and parameters.oauth_callback_confirmed then
            openURL("https://api.twitter.com/oauth/authorize?oauth_token="..parameters.oauth_token, true)
            parameter.text("twitter_pin_code")
            parameter.action("twitter_connect", function()
                account_access_token = parameters.oauth_token
                account_access_token_secret = parameters.oauth_token_secret
                request_api("POST", "https://api.twitter.com/oauth/access_token", {oauth_verifier = twitter_pin_code}, function(response, status, headers)
                    parameters = parse_response(response)
                    if status == 200 then
                        -- Complete handshake and save "oauth_token" and "oauth_token_secret"
                        saveLocalData("account_access_token", parameters.oauth_token)
                        saveLocalData("account_access_token_secret", parameters.oauth_token_secret)
                        parameter.clear()
                        if callback_success then callback_success() else request_report(response, status, headers) end
                    else
                        if callback_failure then callback_failure() else request_report(response) end
                    end
                end)
            end)
        else
            if callback_failure then callback_failure() else request_report(response) end
        end
    end)
end


-- Use this method to check your authorization
-- This will automatically invoke request_access() when nessecary!
local function check_access(callback_success)
    local callback_failure = function() request_access(callback_success) end
    request_api("GET", "https://api.twitter.com/1.1/account/verify_credentials.json", nil, callback_success or request_report, callback_failure)
end


twitter = {}
twitter.check = check_access
twitter.authenticate = request_access
twitter.request = function(...)
    local params = {...}
    local callback = function() request_api(unpack(params)) end
    check_access(callback)
end

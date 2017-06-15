function setup()
    --check_access()
    --request_api("GET", "https://api.twitter.com/1.1/statuses/home_timeline.json", {})
    --request_api("GET", "https://api.twitter.com/1.1/statuses/user_timeline.json", {count = 1})
    --request_api("GET", "https://api.twitter.com/1.1/followers/list.json", {})
    --request_api("GET", "https://api.twitter.com/1.1/statuses/retweets_of_me.json", {})
    --request_api("GET", "https://api.twitter.com/1.1/favorites/list.json", {})
    
    twitter.request("GET", "https://api.twitter.com/1.1/statuses/retweets_of_me.json", nil, function(data) print("\n\n----------\n\n") print(data) end)
    twitter.request("GET", "https://api.twitter.com/1.1/statuses/user_timeline.json", {count = 1}, function(data) print("\n\n----------\n\n") print(data) end)
end


function draw()
    background(40, 40, 50)
end

function setup()
    -- Display one tweet from user's home timeline
    local function get_tweet()
        twitter.request("GET", "https://api.twitter.com/1.1/statuses/home_timeline.json", {count = 1}, function(response)
            local content = json.decode(response)
            tweet = content[1].user.name.." wrote\n"..content[1].text
            print(tweet)
        end)
    end
    
    twitter.check(get_tweet)
end


function draw()
    background(120, 126, 138, 255)
    fill(31, 37, 33, 255)
    textWrapWidth(WIDTH)
    textMode(CENTER)
    textAlign(CENTER)
    text(tweet or "Loading...", WIDTH/2, HEIGHT/2)
end

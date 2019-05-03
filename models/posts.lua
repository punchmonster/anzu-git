local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local util     = require "lapis.util"
local magick   = require "magick"
local Text     = require "models.text"
local Posts    = Model:extend("posts")

-- FUNCTION: submits new posts to database
-- arg1: table which holds key/value pairs with the following structure:
-- { feedName = <string>, threadTitle = <string>, postBody = <string>, IP = <string>, thread = <int>, postImage = { filename = <string>, contents = <binary> } }
-- RETURN: boolean, status message
function Posts:submit(arg1)

  -- check if posting cooldown is complete
  --[[if self:post_timer(arg1.feedName, arg1.IP) == false then
    return false, "err_time_limit"
  else]]
    -- retrieve last post data from database
  local post_data = db.select("* from `posts` order by postID DESC limit 1")
  local postID = post_data[1]['postID'] + 1

  -- make sure post body length is within spec
  if #arg1.postBody < 300 then

    -- write out a postImage to disk if it exists
    local imageLocation
    if arg1.postImage and arg1.postImage.filename ~= "" then

      --split file extension off
      local fileExt = arg1.postImage.filename:match("^.+(%..+)$")

      -- checks if the file is valid
      local image = magick.load_image_from_blob(arg1.postImage.content)

      if not image and (fileExt ~= ".mp4" and fileExt ~= ".webm") then
        return false, "err_invalid_file"
      end

      -- set file path and write postImage to disk
      imageLocation = 'static/media/' .. arg1.feedName .. '/' .. postID .. fileExt
      imageFile = io.open(imageLocation, 'w')
      if imageFile then
        imageFile:write(arg1.postImage.content)
        imageFile:close()
      else
        imageLocation = nil
      end
    end

    -- if no reply ID is supplied post is made first post in thread
    if arg1.threadID == nil then
      arg1.threadID = postID
    end

    if arg1.replyID == nil then
      arg1.replyID = postID
    end

    -- insert new thread data into database
    db.insert( 'posts' , {
      postID      = postID,
      replyID     = arg1.replyID,
      threadID    = arg1.threadID,
      postTime    = ngx.time(),
      userID      = arg1.userID,
      sessionID   = arg1.sessionID,
      postBody    = Text:post_sanitize(arg1.postBody, "http://yukku.org:8080"),
      postImage   = imageLocation
    })

    --[[ update thread time or cull old threads
    if postID == threadNumber then
      self:cull_threads(feed_data[1]['feedName'])
    else
      db.update( feed_data[1]['feedName'], {
        threadTime = ngx.time()
      }, {
        postID = threadNumber
      })
    end]]

    return true
  else
    return false, "err_character_limit"
  end
end

-- FUNCTION: internal checks last post time
-- feedName: name of feed / userID
-- RETURN: boolean
function Posts:post_timer(feedName, userID)

  local post_data = db.select("* from `posts` where postIP = \"" .. postIP .. "\" order by postTime DESC limit 1")

  -- check if IP exists in the database
  if #post_data < 1 then
    return true
  end

  -- check last post time
  local postDif = ngx.time() - tonumber( post_data[1]['postTime'] )
  if postDif > 30 then
    return true
  else
    return false, postDif
  end
end

-- FUNCTION: delete old threads
-- feedName: name of feed
-- RETURN: boolean
function Posts:cull_threads(feedName)
  local thread_data = db.select("* from `posts` where postID = threadID order by postTime DESC LIMIT 100 OFFSET 60")

  -- check if  threads to cull exist
  if #thread_data < 1 then
    return false
  else
    -- go through threads that should be deleted
    for k, v in pairs(thread_data) do
      db.delete("posts", { threadID = v.threadID })

      -- delete images in the threads
      local thread_images = db.select("* from `posts` where threadID = ?", v.threadID)
      for x, y in pairs(thread_images) do

        local imageLocation = 'static/media/posts/' .. y.postImage
        os.remove(imageLocation)
      end
    end
  end
end

-- FUNCTION: check thread length
-- threadID: thread ID / feedName: name of feed
-- RETURN: thread length as int
function Posts:thread_length(threadID, feedName)
  local thread_length = db.select("COUNT(*) from `" .. feedName .. "` where threadID = ?", threadID)

  return thread_length[1]['COUNT(*)']
end

-- FUNCTION: retrieves timeline
-- following: JSON with userID's
-- RETURN: table with posts
function Posts:get_timeline(following)

  -- turn follower ID's into a string for query
  local processedFollowing = "0"
  for k, v in pairs(following) do
    processedFollowing = processedFollowing .. "," .. v
  end

  -- retrieve thread headers from database
  local timeline_data = db.select("* from `posts` WHERE userID IN ( " .. processedFollowing .. " ) order by postTime DESC")

  -- sort through user data
  local processedUsers = "0"
  for k, v in pairs(timeline_data) do
     processedUsers = processedUsers .. "," .. v['userID']
  end

  local users_data = db.select("* from `users` WHERE userID IN ( " .. processedUsers .. " )")

  local processed_data = self:merge_user_data(users_data, timeline_data)

  return processed_data
end

function Posts:get_profile(userHandle)

  -- check if user exists and retrieve userID
  local user_data = db.select("* from `users` WHERE userHandle = ?", userHandle)
  if #user_data < 1 then
    return false, "user doesn't exist"
  end

  -- check if posts exist and if so return them
  local profile_data = db.select("* from `posts` WHERE userID = ? order by postTime DESC LIMIT 20", user_data[1].userID)
  if #profile_data < 1 then
    return true, 0, user_data
  else

    --merge user data into post data
    profile_data = self:merge_user_data(user_data, profile_data)
    return true, profile_data, user_data
  end
end

-- FUNCTION: retrieves a conversational thread
-- postID: the post number to build thread for
-- userID: userID of the person who the post should belong to
function Posts:get_thread(postID, userID)
  local posts_data = db.select("* from `posts` WHERE postID = ?", postID)

  -- check if the post belongs to the supplied user
  if userID == posts_data[1].userID then

    posts_data = db.select("* from `posts` WHERE threadID = ?", posts_data[1].threadID)

    -- turn poster ID's into a string for query
    local processedUsers = "0"
    for k, v in pairs(posts_data) do
      processedUsers = processedUsers .. "," .. v.userID
    end

    -- retrieve thread headers from database
    local users_data = db.select("* from `users` WHERE userID IN ( " .. processedUsers .. " )")

    posts_data = self:merge_user_data(users_data, posts_data)

    return posts_data
  else
    return false
  end
end

-- FUNCTION: merges user data like handles with post data
-- userData: Array with the users you want to merge data from
-- postData: Array with posts you want to add user data to
function Posts:merge_user_data(userData, postData)

  for k, v in pairs(postData) do
    for a, b in pairs(userData) do
      if v['userID'] == b['userID'] then
       v['userHandle'] = b['userHandle']
       v['userName'] = b['userName']
       v['userGender'] = b['userGender']
      end
    end
  end

  return postData
end

-- FUNCTION: calculates and formats time elapsed for visible posts
-- current_time: current UNIX time / post_time: post UNIX time
-- RETURN: string
function Posts:elapsed(current_time, post_time)

  local time = current_time - post_time

  local function round(n)
    return math.floor((math.floor(n*2) + 1)/2)
  end

  if time < 60 then
    return time .. "s"
  elseif time < (60*60) then
    return round((time / 60)) .. "m"
  elseif time < (60*60*24) then
    return round((time / (60*60))) .. "h"
  elseif time < (60*60*24*30) then
    return round((time / (60*60*24))) .. " days"
  elseif time < (60*60*24*30*12) then
    return round((time / (60*60*24*30))) .. " months"
  end
end

-- FUNCTION: likes a post
-- userID: database ID of the user who is liking the post
-- postID: database ID of the post being liked
function Posts:like_post(userID, postID)

  -- retrieve userdata to
  local user_data = db.select("* from `userData` WHERE userID = ?", userID)

  local likes
  if user_data[1].userLikes ~= "none" then
    likes = util.from_json(user_data[1].userLikes)

    for k, v in ipairs(likes) do
      if postID == v then

      end
    end
  else
    likes = { tonumber(postID) }
  end

  db.update("userData", {
    userLikes = util.to_json(likes)
  },{
    userID = userID
  })
  return "API call received", likes
end

return Posts

local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local util     = require "lapis.util"
local magick   = require "magick"
local Text     = require "models.text"
local User     = require "models.user"
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

    -- if no reply ID is supplied post is made first post in thread
    if arg1.threadID == nil then
      arg1.threadID = postID
    end

    if arg1.replyID == nil then
      arg1.replyID = postID
    end

    -- write out a postImage to disk if it exists
    local imageLocation
    if arg1.postImage and arg1.postImage.filename ~= "" then

      --split file extension off
      local fileExt = arg1.postImage.filename:match("^.+(%..+)$")

      -- checks if the file is valid
      local image = magick.load_image_from_blob(arg1.postImage.content)

      if not image  then
        return false, "err_invalid_file"
      end

      -- resize the image
      if image:get_width() > 1200 or image:get_height() > 1200 then
        image:resize_and_crop(1200, 1200)
      end

      -- if image isn't a jpg convert it
      if image:get_format() ~= "jpg" then
        image:set_format("jpg")
      end

      -- set file path and write postImage to disk
      imageLocation = 'static/img/post_media/' .. postID .. ".jpg"
      local imageFile = io.open(imageLocation, 'w')
      if imageFile then
        imageFile:write(image:get_blob())
        imageFile:close()
        imageLocation = 1
      else
        imageLocation = nil
      end
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
      postImage   = imageLocation,
      postRef     = 0
    })

    local mentionList = {}
    for word in string.gmatch(arg1.postBody, "@([%w_]+)") do
      table.insert(mentionList, word)
    end

    if #mentionList >= 1 then
      local x = {
        notifType = "mentions",
        postID = postID,
        targetID = mentionList,
        userID = arg1.userID,
        notifTime = ngx.time()
      }
      -- x: { notifType = "like", postID = 0, targetID = 0, userID = 0, notifTime = 0 }
      User:notifications(x)
    end

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

    return true, postID
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
function Posts:thread_length(threadID)
  local thread_length = db.select("COUNT(*) from `posts` where threadID = ?", threadID)

  return thread_length[1]['COUNT(*)']
end

-- FUNCTION: retrieves timeline
-- following: JSON with userID's
-- currentID: ID of logged in user
-- RETURN: table with posts
function Posts:get_timeline(following, currentID, page)

  -- turn follower ID's into a string for query
  local processedFollowing = "0"
  for k, v in pairs(following) do
    processedFollowing = processedFollowing .. "," .. v
  end

  -- retrieve thread headers from database
  local timeline_data
  if page == nil then
    timeline_data = db.select("* from `posts` WHERE userID IN ( " .. processedFollowing .. " ) order by postTime DESC LIMIT 10")
  else
    timeline_data = db.select("* from `posts` WHERE userID IN ( " .. processedFollowing .. " ) order by postTime DESC LIMIT 10 OFFSET ?", page * 11)
  end

  timeline_data, users_data = self:merge_tags(timeline_data)

  local processed_data = self:merge_user_data(users_data, timeline_data, currentID)

  return processed_data
end

-- FUNCTION: retrieves a profile
-- userHandle: userHandle of the profile to retrieve
-- currentID: ID of logged in user
-- RETURN: table with posts: {{postID = 1, ... },{postID = 1, ... }}
function Posts:get_profile(userHandle, currentID, page)

  -- check if user exists and retrieve userID
  local user_data = db.select("* from `users` WHERE userHandle = ?", userHandle)
  if #user_data < 1 then
    return false, "user doesn't exist"
  end

  -- check if posts exist and if so return them
  local profile_data
  if page == nil then
    profile_data = db.select("* from `posts` WHERE userID = ? order by postTime DESC LIMIT 10", user_data[1].userID)
  else
    profile_data = db.select("* from `posts` WHERE userID = ? order by postTime DESC LIMIT 10 OFFSET ?", user_data[1].userID, page * 10)
  end
  if #profile_data < 1 then
    return true, 0, user_data
  else

    profile_data, users_data = self:merge_tags(profile_data)

    --merge user data into post data
    profile_data = self:merge_user_data(users_data, profile_data, currentID)
    return true, profile_data, user_data
  end
end

-- FUNCTION: extracts userIDs and tag refs to retrieve and merge into post data
-- post_data: table with post data: {{postID = 1, ... },{postID = 1, ... }}
-- RETURN: table with post data: {{postID = 1, ... },{postID = 1, ... }}
function Posts:merge_tags(posts_data)

  -- make a list of tagged tweets on timeline to retrieve
  local processedTags = "0"
  local processedUsers = "0"
  for k, v in ipairs(posts_data) do
    if v.postRef ~= 0 then
      processedTags  = processedTags .. "," .. v.postRef
      processedUsers = processedUsers .. "," .. v.userID
    end
  end

  local tags_data = db.select("* from `posts` WHERE postRef IN ( " .. processedTags .. " )")

  -- make a list of users to request data for in the database
  for k, v in pairs(tags_data) do
     processedUsers = processedUsers .. "," .. v.userID
  end

  local users_data = db.select("* from `users` WHERE userID IN ( " .. processedUsers .. " )")

  -- merge tagged posts into rest of timeline
  for k, v in ipairs(posts_data) do
    for a, b in ipairs(tags_data) do
      if v.postRef == b.postID then
        v.postID      = b.postID
        v.userName    = b.userName
        v.userID      = b.userID
        v.userHandle  = b.userHandle
        v.postTime    = b.postTime
        v.threadID    = b.threadID
        v.ReplyID     = b.replyID
        v.postBody    = b.postBody
      end
    end
  end
  return posts_data, users_data
end

-- FUNCTION: retrieves a conversational thread
-- postID: the post number to build thread for
-- userID: userID of the person who the post should belong to
function Posts:get_thread(postID, userID, currentID)
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

    posts_data = self:merge_user_data(users_data, posts_data, currentID)

    return posts_data
  else
    return false
  end
end

-- FUNCTION: merges user data like handles with post data
-- userData: Array with the users you want to merge data from
-- postData: Array with posts you want to add user data to
function Posts:merge_user_data(userData, postData, currentID)

  local likes_data = nil
  local tags_data = nil
  if currentID ~= nil then
    action_data = db.select("* from `userData` WHERE userID = ?", currentID)
    if action_data[1].userLikes ~= "none" then
      likes_data = util.from_json(action_data[1].userLikes)
    else
      likes_data = {}
    end
    if action_data[1].userTags ~= "none" then
      tags_data = util.from_json(action_data[1].userTags)
    else
      tags_data = {}
    end
  end

  -- merge the posts and their respective userdata
  local currenTime = ngx.time()
  for k, v in pairs(postData) do
    for a, b in pairs(userData) do
      if v['userID'] == b['userID'] then
       v['userHandle'] = b['userHandle']
       v['userName'] = b['userName']
       v['userGender'] = b['userGender']
       v['userAvatar'] = b['userAvatar']
      end
    end
    -- if called from a logged in session merge tag and like data in
    if currentID ~= nil then
      for a, b in ipairs(likes_data) do
        if v['postID'] == b then
          v['liked'] = true
        end
      end
      for a, b in ipairs(tags_data) do
        if v['postID'] == b then
          v['tagged'] = true
        end
      end
    end

    -- make timestamps readable
    v['postTime'] = self:elapsed(currenTime, v['postTime'])
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

  -- set default JSON response
  local msg = "added PostID: " .. postID .. " to your likes"

  -- check if user has likes, and if the post is liked or not. Then add or remove like.
  local likes
  if user_data[1].userLikes ~= "none" then
    likes = util.from_json(user_data[1].userLikes)
    local removed
    for k, v in ipairs(likes) do
      if tonumber(postID) == v then
        table.remove(likes, k)
        removed = true
        msg = "removed PostID: " .. postID .. " from your likes"
      end
    end

    if removed ~= true then
      table.insert(likes, tonumber(postID))
    end
  else
    likes = { tonumber(postID) }
  end

  -- if last like was removed set user likes to default again, if not, encode likes table
  if likes[1] == nil then
    likes = "none"
  else
    likes = util.to_json(likes)
  end

  -- push updated likes to the database
  db.update("userData", {
    userLikes = likes
  },{
    userID = userID
  })
  return true, msg
end

-- FUNCTION: tags a post
-- userID: database ID of the user who is retweeting the post
-- postID: database ID of the post being tagged
function Posts:tag_post(userID, postID)

  -- retrieve userdata to
  local user_data = db.select("* from `userData` WHERE userID = ?", userID)
  local tags

  -- set default JSON response
  local msg = "tagged PostID: " .. postID .. " onto your timeline"

  local post_data = db.select("* from `posts` WHERE postRef = ? AND userID = ?", tonumber(postID), userID)

  -- check if user already tagged the post
  if #post_data < 1 then

    -- get last post
    local new_data = db.select("* from `posts` order by postID DESC limit 1")
    new_data = new_data[1]['postID'] + 1

    -- insert new thread data into database
    db.insert( 'posts' , {
      postID      = new_data,
      threadID    = new_data,
      postTime    = ngx.time(),
      postRef     = postID,
      userID      = userID
    })

    if user_data[1].userTags ~= "none" then
      tags = util.from_json(user_data[1].userTags)
      table.insert(tags, tonumber(postID))
    else
      tags = { tonumber(postID) }
    end

  else
    db.delete('posts', {
      postRef = tonumber(postID),
      userID  = userID
    })

    tags = util.from_json(user_data[1].userTags)
    for k, v in ipairs(tags) do
      if tonumber(postID) == v then
        table.remove(tags, k)
      end
    end

    msg = "untagged PostID: " .. postID .. " from your timeline"
  end

  -- if last tag was removed set user likes to default again, if not, encode likes table
  if tags[1] == nil then
    tags = "none"
  else
    tags = util.to_json(tags)
  end

  -- push updated tags to the database
  db.update("userData", {
    userTags = tags
  },{
    userID = userID
  })

  return true, msg
end

-- FUNCTION: sorts a thread into a logical pattern
-- a: table with thread content
-- currentThreadID: self explanatory
function Posts:sort_thread(a, currentThreadID)

  local Node = {}

  function Node:create (x)
    local o = {}
    o = x
    o.children = {}
    return o
  end

  local nodes = {}
  for k, v in ipairs(a) do
    nodes[v.postID] = Node:create({
      postID     = v.postID,
      replyID    = v.replyID,
      threadID   = v.threadID,
      sessionID  = v.sessionID,
      postTime   = v.postTime,
      postBody   = v.postBody,
      userID     = v.userID,
      postRef    = v.postRef,
      userHandle = v.userHandle,
      userName   = v.userName,
      postImage  = v.postImage,
      userGender = v.userGender,
      userAvatar = v.userAvatar,
      tagged     = v.tagged,
      liked      = v.liked
    })
  end

  for ID, node in pairs(nodes) do
    if node.replyID ~= node.postID then
      table.insert(nodes[node.replyID].children, node)
    end
  end

  local sorted_convo = {}
  function construct_tree(root_node)
    --print(root_node.ID, root_node.time, root_node.reply)
    table.insert(sorted_convo, root_node)
    for k, child in ipairs(root_node.children) do
      construct_tree(child)
    end
  end

  construct_tree(nodes[currentThreadID])

  -- post_data only ending up with 1 post?
  return sorted_convo
end

-- FUNCTION: searches through posts
-- ARGUMENTS: users ID
-- RETURNS: table with all user data
function Posts:search(string)
  string = util.unescape(string)
  local posts_data = db.select("* FROM `posts` WHERE postBody LIKE ? LIMIT 10", "%" .. string .. "%")

  -- make a list of users to grab data for
  local processedUsers = "0"
  for k, v in ipairs(posts_data) do
    processedUsers = processedUsers .. "," .. v.userID
  end

  local users_data = db.select("* from `users` WHERE userID IN ( " .. processedUsers .. " )")

  posts_data = self:merge_user_data(users_data, posts_data)
  return posts_data
end

return Posts

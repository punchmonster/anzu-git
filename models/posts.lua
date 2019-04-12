local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local magick   = require "magick"
local Text     = require "models.text"
local Posts    = Model:extend("posts")

-- mapping database table to model
local Feeds       = Model:extend("feeds", {
  primary_key = { "feedName" }
})

-- FUNCTION: submits new posts to database
-- arg1: table which holds key/value pairs with the following structure:
-- { feedName = <string>, threadTitle = <string>, postBody = <string>, IP = <string>, thread = <int>, postImage = { filename = <string>, contents = <binary> } }
-- RETURN: always returns true because I'm shit
function Posts:submit(arg1)

  -- retrieve feed data from database
  local feed_data = Feeds:select("where feedName = ?", arg1.feedName)

  -- check if posting cooldown is complete
  if self:post_timer(arg1.feedName, arg1.IP) == false then
    return false, "err_time_limit"
  else
    -- retrieve last post data from database
    local post_data = db.select("* from `" .. feed_data[1]['feedName'] .. "` order by postID DESC limit 1")
    local postID = post_data[1]['postID'] + 1

    -- check if submitting a thread or post
    local threadNumber
    local thread_length
    local thread_time

    if arg1.thread ~= nil then
      threadNumber = arg1.thread
      thread_length = tonumber(self:thread_length(threadNumber, arg1.feedName))
      thread_time = db.NULL
      -- check thread length limit
      if thread_length > 256 then
        return false, "err_thread_max_length"
      end
    else
      threadNumber = postID
      thread_time = ngx.time()
    end

    -- make sure post title and body length are within spec
    if #arg1.postBody < 350 and #arg1.threadTitle < 40 then

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

      -- insert new thread data into database
      db.insert( feed_data[1]['feedName'] , {
        postID      = postID,
        threadID    = threadNumber,
        postTime    = ngx.time(),
        threadTime  = thread_time,
        threadTitle = arg1.threadTitle,
        postBody    = arg1.postBody, --LESSEN CPU LOAD: Text:post_sanitize(arg1.postBody, "http://anzu.bmrf.me:8080/feed/" .. feed_data[1]['feedName']),
        postImage   = imageLocation,
        postIP      = arg1.IP
      })

      -- update thread time or cull old threads
      if postID == threadNumber then
        self:cull_threads(feed_data[1]['feedName'])
      else
        db.update( feed_data[1]['feedName'], {
          threadTime = ngx.time()
        }, {
          postID = threadNumber
        })
      end

      return true
    else
      return false, "err_character_limit"
    end
  end
end

-- FUNCTION: internal checks last post time
-- feedName: name of feed / postIP
-- RETURN: boolean
function Posts:post_timer(feedName, postIP)

  local post_data = db.select("* from `" .. feedName .. "` where postIP = \"" .. postIP .. "\" order by postTime DESC limit 1")

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
  local thread_data = db.select("* from `" .. feedName .. "` where postID = threadID order by postTime DESC LIMIT 100 OFFSET 60")

  -- check if  threads to cull exist
  if #thread_data < 1 then
    return false
  else
    -- go through threads that should be deleted
    for k, v in pairs(thread_data) do
      db.delete(feedName, { threadID = v.threadID })

      -- delete images in the threads
      local thread_images = db.select("* from `" .. feedName .. "` where threadID = ?", v.threadID)
      for x, y in pairs(thread_images) do

        local imageLocation = 'static/media/' .. feedName .. '/' .. y.postImage
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

-- FUNCTION: retrieves threads
-- arg1: name of the feed
-- RETURN: table with threads
function Posts:get_threads(arg1)

  -- retrieve feed data from database
  local feed_data = Feeds:select("where feedName = ?", arg1)

  -- retrieve thread headers from database
  local thread_data = db.select("* from `" .. feed_data[1]['feedName'] .. "` where postID = threadID order by threadTime DESC")

  return thread_data
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

return Posts

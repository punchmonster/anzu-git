local db       = require "lapis.db"
local magick   = require "magick"
local Model    = require ("lapis.db.model").Model
local config   = require("lapis.config").get()
local util     = require("lapis.util")
local encoding = require("lapis.util.encoding")
local User     = Model:extend("user")

-- FUNCTION: create new user
-- arg1: IP of remote address
function User:create(userHandle, userPassword)

  -- make sure userHandle is legal
  if userHandle == nil then
   return false, "err_invalid_handle"
  end

  -- check if user exists
  local user_check = db.select("* from `users` where userHandle = ?", userHandle)
  if #user_check < 1 then

    -- retrieve last user from database
    local user_data = db.select("* from `users` order by userID DESC limit 1")
    local userID = user_data[1].userID + 1

    -- warm up RNG and generate usersalt
    local userSalt
    math.randomseed(ngx.time())
    for x = 1,5 do
        -- random generating
        userSalt = math.random(0,500000000)
    end

    -- encrypt userPassword
    userPassword = encoding.hmac_sha1(userSalt, userPassword)

    -- set default following
    local userFollowing = { 1 }
    table.insert(userFollowing, userID)

    -- pushing userdata to database
    db.insert("users", {
      userID = userID,
      userHandle = userHandle,
      userName = userHandle,
      userGender = "none",
      userBio = " ",
      userPassword = userPassword,
      userSalt = userSalt,
      userGroup = 1,
      userCreationDate = ngx.time(),
      userFollowing = util.to_json(userFollowing)
    })

    -- setting large user datasets to defaults
    local empty_JSON = "none"
    db.insert("userData", {
      userID = userID,
      userLikes = empty_JSON,
      userNotif = empty_JSON,
      userTags  = empty_JSON
    })

    return true, "account created"
  end
  return false,  "account with that username already exists"
end

-- FUNCTION: logs a user in
-- ARGUMENTS: username, email and password for the new user
-- RETURNS: boolean and information message
function User:login(userHandle, userPassword)

  -- retrieve userdata
  local user_data = db.select("* from `users` where userHandle = ?", userHandle)

  -- check if user exists
  if #user_data < 1 then
    return false, "user doesn't exist"
  end

  -- check if password matches
  local userPasswordStored = user_data[1].userPassword
  print(userPasswordStored)
  local userPasswordEncoded = encoding.hmac_sha1(user_data[1].userSalt, userPassword)

  if userPasswordStored == userPasswordEncoded then

    local sessionIDTime = ngx.time()

    -- update last client IP
    db.update("users", {
      sessionID = sessionIDTime
    },{
      userID = user_data[1].userID
    })

    return true, "login success", user_data[1].userID, sessionIDTime
  end

  return false, "wrong password"
end

-- FUNCTION: updates user settings
function User:update(x)

  -- make sure userHandle is legal
  if x.userHandle == nil then
   return false, "err_invalid_handle"
  end

  -- initiate variables for file uploads
  local imageLocation
  local userAvatar = x.userAvatar

  -- check if user with that handle exists
  local user_check = db.select("* from `users` where userHandle = ?", x.userHandle)
  if #user_check >= 1 then
    if user_check[1].userID ~= x.userID then
      return false, "err_user_exists"
    end
  end

  if x.postImage and x.postImage.filename ~= "" then

    --split file extension off
    local fileExt = x.postImage.filename:match("^.+(%..+)$")

    -- checks if the file is valid
    local image = magick.load_image_from_blob(x.postImage.content)

    if not image  then
      return false, "err_invalid_file"
    end

    -- resize image
    image:resize_and_crop(300,300)

    -- if image isn't a jpg convert it
    if image:get_format() ~= "jpg" then
      image:set_format("jpg")
    end

    -- set file path and write postImage to disk
    imageLocation = 'static/img/profiles/' .. x.userID .. "-avatar.jpg"
    local imageFile = io.open(imageLocation, 'w')
    if imageFile then
      imageFile:write(image:get_blob())
      imageFile:close()
      userAvatar = 1
    else
      imageLocation = nil
    end
  end

  if x.userGender ~= "he" and x.userGender ~= "she" and x.userGender ~= "they" and x.userGender ~= "none" and x.userGender ~= "other" and x.userGender ~= "bot" then
    x.userGender = "none"
  end

  -- push new user info to database
  db.update("users", {
    userName = x.userName,
    userHandle = x.userHandle,
    userGender = x.userGender,
    userAvatar = userAvatar
  },{
    userID = x.userID
  })

  return true
end

-- FUNCTION: adds notification changes
-- x: { notifType = "like", postID = 0, targetID = 0, userID = 0, notifTime = 0 }
function User:notifications(x)

  -- what to do when it's a like notification
  if x.notifType == "like" or x.notifType == "tag" then

    -- retrieve post info to grab target data
    local post_data = db.select("* from `posts` WHERE postID = ?", x.postID)
    x.targetID = post_data[1].userID
    local user_data = db.select("* from `userData` WHERE userID = ?", x.targetID)

    -- set default JSON response
    local msg = "added a like to " .. x.targetID .. "'s notifications"

    -- check if user has likes, and if the post is liked or not. Then add or remove like.
    local notifs
    if user_data[1].userNotif ~= "none" then
      notifs = util.from_json(user_data[1].userNotif)
      local existing
      for k, v in ipairs(notifs) do
        if x.postID == v.postID and x.userID == v.userID then
          existing = true
          msg = "notification already exists"
        end
      end

      if existing ~= true then
        table.insert(notifs, x)
      end
    else
      notifs = {}
      table.insert(notifs, x)
    end

    -- push updated likes to the database
    notifs = util.to_json(notifs)
    db.update("userData", {
      userNotif = notifs
    },{
      userID = x.targetID
    })

    return true, msg
  elseif x.notifType == "get_notif" then
    local user_data = db.select("* from `userData` WHERE userID = ?", x.userID)

    if user_data[1].userNotif ~= "none" then
      local notifs
      notifs = util.from_json(user_data[1].userNotif)

      local processedPosts = "0"
      local processedUsers = "0"
      for k, v in ipairs(notifs) do
        processedPosts = processedPosts .. "," .. v.postID
        processedUsers = processedUsers .. "," .. v.userID
      end

      local notifs_data = db.select("* from `posts` WHERE postID IN ( " .. processedPosts .. " )")
      local users_data = db.select("* from `users` WHERE userID IN ( " .. processedUsers .. " )")

      for k, v in pairs(notifs) do
        for k2, v2 in pairs(notifs_data) do
          if tonumber(v.postID) == v2.postID then
            v.postBody = v2.postBody
          end
        end

        for k2, v2 in pairs(users_data) do
          if tonumber(v.userID) == v2.userID then
            v.userName = v2.userName
            v.userAvatar = v2.userAvatar
          end
        end
      end

      function reversePosts(arr)
      	local i, j = 1, #arr

      	while i < j do
      		arr[i], arr[j] = arr[j], arr[i]

      		i = i + 1
      		j = j - 1
      	end

        return arr
      end

      notifs = reversePosts(notifs)

      return true, notifs
    end
    return true, "No notifications"
  end
end

-- FUNCTION: gets user data
-- ARGUMENTS: users ID
-- RETURNS: table with all user data
function User:get_user(userID)
  local user_data = db.select("* from `users` where userID = ?", userID)
  return user_data
end

function User:get_following(userID)
  local user_data = db.select("* from `users` where userID = ?", userID)
  return user_data
end


-- FUNCTION: makes user follow an account
-- userHandle: handle of the user who is executing follow request
-- followHandle: handle of the user who is being followed
-- boolean: tells us if we should follow or unfollow
-- RETURNS: boolean, status message
function User:follow(userHandle, followHandle, boolean)

  -- retrieve user data
  local user_data = db.select("* from `users` where userHandle = ?", userHandle)
  local follow_data = db.select("* from `users` where userHandle = ?", followHandle)

  local following = util.from_json(user_data[1].userFollowing)
  for k, v in pairs(following) do
    if v == follow_data[1].userID then
      -- checks if we should follow or unfollow
      if boolean then
        return false, "already following"
      else
        -- removes user ID from the following list
        table.remove(following, k)
      end
    end
  end

  function User:check_follow(userList, followList)

  end

  -- inserts user ID into the following list
  local msg
  if boolean then
    table.insert(following, follow_data[1].userID)
    msg = " has followed "
  else
    msg = " has unfollowed "
  end

  -- encode and send following data back to database
  following = util.to_json(following)
  db.update("users", {
    userFollowing = following
  },{
    userID = user_data[1].userID
  })
  return true, "" .. userHandle .. msg .. followHandle .. "."
end

return User

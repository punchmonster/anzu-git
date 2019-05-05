local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local config   = require("lapis.config").get()
local util     = require("lapis.util")
local encoding = require("lapis.util.encoding")
local User     = Model:extend("user")

-- FUNCTION: create new user
-- arg1: IP of remote address
function User:create(userHandle, userPassword)

  -- check if user exists
  local user_check = db.select("* from `users` where userHandle = ?", userHandle)
  if #user_check < 1 then

    -- retrieve last user from database
    local user_data = db.select("* from `users` order by userID DESC limit 1")
    local userID = user_data[1].userID + 1

    -- encrypt userPassword
    local userSalt
    math.randomseed(ngx.time())

    for x = 1,5 do
        -- random generating
        userSalt = math.random(0,500000000)

    end
    userPassword = encoding.hmac_sha1(userSalt, userPassword)

    -- set default following
    local userFollowing = { 1 }
    table.insert(userFollowing, userID)

    db.insert("users", {
      userID = userID,
      userHandle = userHandle,
      userName = userHandle,
      userGender = "other",
      userBio = " ",
      userPassword = userPassword,
      userSalt = userSalt,
      userGroup = 1,
      userFollowing = util.to_json(userFollowing)
    })

    local empty_JSON = "none"
    db.insert("userData", {
      userID = userID,
      userLikes = util.to_json(empty_JSON),
      userNotif = util.to_json(empty_JSON)
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

function User:update(x)

  db.update("users", {
    userName = x.userName,
    userHandle = x.userHandle,
    userGender = x.userGender,
    userBio = x.userBio
  },{
    userID = x.userID
  })

  -- write out a postImage to disk if it exists
  local imageLocation
  if x.postImage and x.postImage.filename ~= "" then

    --split file extension off
    local fileExt = x.postImage.filename:match("^.+(%..+)$")

    -- checks if the file is valid
    --[[local image = magick.load_image_from_blob(arg1.postImage.content)

    if not image and (fileExt ~= ".mp4" and fileExt ~= ".webm") then
      return false, "err_invalid_file"
    end]]

    -- set file path and write postImage to disk
    local imageLocation = 'static/img/profiles/' .. x.userID .. "-avatar" .. fileExt
    local imageFile = io.open(imageLocation, 'w')
    if true then
      imageFile:write(x.postImage.content)
      imageFile:close()
    else
      imageLocation = nil
    end
  end

  return true
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

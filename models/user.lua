local db       = require "lapis.db"
local hasher   = require 'hasher'
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
    local userID = user_data[1]['userID'] + 1

    -- encrypt userPassword
    userSalt = math.random()
    userPassword = encoding.hmac_sha1(userSalt, userPassword)

    db.insert("users", {
      userID = userID,
      userHandle = userHandle,
      userName = userHandle,
      userPassword = userPassword,
      userSalt = userSalt,
      userGroup = 1
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
  local userPasswordStored = user_data[1]['userPassword']
  print(userPasswordStored)
  local userPasswordEncoded = encoding.hmac_sha1(user_data[1]['userSalt'], userPassword)

  if userPasswordStored == userPasswordEncoded then

    local sessionIDTime = ngx.time()

    -- update last client IP
    db.update("users", {
      sessionID = sessionIDTime
    },{
      userID = user_data[1]['userID']
    })

    return true, "login success", user_data[1]['userID'], sessionIDTime
  end

  return false, "wrong password"
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

return User

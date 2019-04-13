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
    local userID = user_data[1]['userID'] + 1

    -- encrypt userPassword
    userPassword = encoding.hmac_sha1(config.secret, userPassword)

    db.insert("users", {
      userID = userID,
      userHandle = userHandle,
      userName = userHandle,
      userPassword = userPassword,
      userGroup = 1
    })

    return true, "account created"
  end
  return false,  "account with that email already exists"
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
  local userPasswordEncoded = userPassword --encoding.hmac_sha1(config.secret, userPassword)

  if userPasswordStored == userPasswordEncoded then

    --[[ update last client IP
    db.update("users", {
      userLastIP = clientIP
    },{
      userID = user_data[1]['userID']
    })]]

    return true, "login success"
  end

  return false, "password failure"
end

return User

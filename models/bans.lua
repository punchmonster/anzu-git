local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local Bans     = Model:extend("bans")

-- FUNCTION: checks if the IP is banned
-- arg1: IP of remote address
-- RETURN: true - IP banned / false - not banned
function Bans:check(arg1)

  -- retrieve bans from database
  local bans = db.select("* from `bans` where banIP = ?", arg1)

  -- check bans in database against remote address
  if #bans < 1 then
    return false
  else
    return true
  end
end

return Bans

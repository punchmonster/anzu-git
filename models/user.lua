local db       = require "lapis.db"
local Model    = require ("lapis.db.model").Model
local User     = Model:extend("users")

-- FUNCTION: create new user
-- arg1: IP of remote address
function User:create(user_id, user_name, user_date)

end

return User

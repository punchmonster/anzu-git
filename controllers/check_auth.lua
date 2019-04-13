local csrf  = require "lapis.csrf"
local db    = require "lapis.db"
local Model = require ("lapis.db.model").Model
local User  = require "models.user"

return function(self)

  -- check if session cookie exists
  if self.session.current_user then

    self.loggedUser = User:get_user(self.session.current_user)
    self.loggedIn = true
  end

end

local csrf  = require "lapis.csrf"
local db    = require "lapis.db"
local Model = require ("lapis.db.model").Model
local User  = require "models.user"

return function(self)

  -- check if session cookie exists
  if self.session.current_user then

    self.loggedUser = User:get_user(self.session.current_user)
    -- compare session ID to what's in the database
    if self.loggedUser[1]['sessionID'] == self.session.sessionID then
      self.loggedIn = true
    else
      self.loggedIn = false
      self.session.current_user = nil
      self.session.sessionID = nil
    end
  else
    self.loggedIn = false
  end

  if self.params.errorCode then
    self.header_vis = false
  end

end
